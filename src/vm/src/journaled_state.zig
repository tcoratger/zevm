const std = @import("std");
const Allocator = std.mem.Allocator;

const State = @import("../../primitives/primitives.zig").State;
const TransientStorage = @import("../../primitives/primitives.zig").TransientStorage;
const Log = @import("../../primitives/primitives.zig").Log;
const SpecId = @import("../../primitives/primitives.zig").SpecId;
const Account = @import("../../primitives/primitives.zig").Account;
const AccountInfo = @import("../../primitives/primitives.zig").AccountInfo;
const AccountStatus = @import("../../primitives/primitives.zig").AccountStatus;
const Bytecode = @import("../../primitives/primitives.zig").Bytecode;
const Constants = @import("../../primitives/primitives.zig").Constants;
const Utils = @import("../../primitives/primitives.zig").Utils;
const Database = @import("./db/db.zig").Database;
const StorageSlot = @import("../../primitives/primitives.zig").StorageSlot;

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;
const expectEqualSlices = std.testing.expectEqualSlices;

/// Represents a checkpoint in the journal.
pub const JournalCheckpoint = struct {
    const Self = @This();

    /// Index within the log.
    log_index: usize,

    /// Index within the journal.
    journal_index: usize,
};

pub const JournaledState = struct {
    const Self = @This();

    /// Current state.
    state: State,
    /// EIP 1153 transient storage
    transient_storage: TransientStorage,
    /// logs
    logs: std.ArrayList(Log),
    /// how deep are we in call stack.
    depth: usize,
    /// journal with changes that happened between calls.
    journal: std.ArrayList(std.ArrayListUnmanaged(JournalEntry)),
    /// Ethereum before EIP-161 differently defined empty and not-existing account
    /// Spec is needed for two things SpuriousDragon's `EIP-161 State clear`,
    /// and for Cancun's `EIP-6780: SELFDESTRUCT in same transaction`
    spec: SpecId,
    /// Precompiles addresses are used to check if loaded address
    /// should be considered cold or hot loaded. It is cloned from
    /// EvmContext to be directly accessed from JournaledState.
    ///
    /// Note that addresses are sorted.
    precompile_addresses: std.ArrayList([20]u8),

    /// Create new JournaledState.
    ///
    /// precompile_addresses is used to determine if address is precompile or not.
    ///
    /// Note: This function will journal state after Spurious Dragon fork.
    /// And will not take into account if account is not existing or empty.
    ///
    /// # Note
    ///
    /// Precompile addresses should be sorted.
    pub fn init(allocator: Allocator, spec: SpecId, precompile_addresses: std.ArrayList([20]u8)) !Self {
        return .{
            .state = std.AutoHashMap([20]u8, Account).init(allocator),
            .transient_storage = std.AutoHashMap(
                std.meta.Tuple(&.{ [20]u8, u256 }),
                u256,
            ).init(allocator),
            .logs = std.ArrayList(Log).init(allocator),
            .journal = std.ArrayList(std.ArrayListUnmanaged(JournalEntry)).init(allocator),
            .depth = 0,
            .spec = spec,
            .precompile_addresses = try precompile_addresses.clone(),
        };
    }

    /// Retrieves the last journal entry from the JournaledState.
    ///
    /// Returns a reference to the last recorded journal entry.
    /// If the journal is empty, returns an error indicating the journal is empty.
    pub fn getLastJournalEntry(self: *JournaledState) !*std.ArrayListUnmanaged(JournalEntry) {
        const journal_len = self.journal.items.len;
        return if (journal_len == 0)
            error.JournalIsEmpty
        else
            &self.journal.items[journal_len - 1];
    }

    /// Marks an account as touched, indicating its relevance for inclusion in the state.
    ///
    /// Touched accounts are crucial for state management operations like state clearing,
    /// where empty touched accounts need removal from the state.
    ///
    /// # Arguments
    /// - `address`: The address of the account to mark as touched.
    pub fn touch(self: *Self, allocator: Allocator, address: *[20]u8) !void {
        if (self.state.getPtr(address.*)) |account| {
            try Self.touchAccount(
                allocator,
                try self.getLastJournalEntry(),
                address.*,
                account,
            );
        }
    }

    /// Marks an account as touched within the provided journal.
    /// If the account hasn't been touched previously, it updates the journal and sets the account's touch flag.
    ///
    /// # Arguments
    /// - `journal`: A pointer to a dynamic array (`ArrayList`) of `JournalEntry` to log the account touch.
    /// - `address`: A pointer to a 20-byte array representing the account address.
    /// - `account`: A pointer to the account object to be marked as touched.
    ///
    /// # Errors
    /// Returns an error if appending to the journal fails or if account touch marking encounters an issue.
    pub fn touchAccount(
        allocator: Allocator,
        journal: *std.ArrayListUnmanaged(JournalEntry),
        address: [20]u8,
        account: *Account,
    ) !void {
        if (!account.isTouched()) {
            try journal.append(
                allocator,
                .{ .AccountTouched = .{ .address = address } },
            );
            account.markTouch();
        }
    }

    /// Performs cleanup and retrieves the modified state and logs as a tuple.
    ///
    /// This function finalizes the current state, clearing logs and freeing resources. It returns a
    /// tuple containing the modified state and logs before the cleanup.
    ///
    /// # Returns
    /// A tuple containing the modified state and logs after cleanup.
    ///
    /// # Errors
    /// May return an error if there's a failure in cloning or clearing resources.
    pub fn finalize(self: *Self) !std.meta.Tuple(&.{ State, std.ArrayList(Log) }) {
        const state = try self.state.clone();
        self.state.clearAndFree();
        const logs = try self.logs.clone();
        self.logs.clearAndFree();
        self.journal.clearAndFree();
        self.depth = 0;
        return .{ state, logs };
    }

    /// Retrieves the account associated with the provided address.
    ///
    /// This function attempts to fetch the account corresponding to the given address from the state.
    /// If the account exists, it returns a pointer to it.
    ///
    /// # Arguments
    /// - `address`: A 20-byte array representing the address of the account to retrieve.
    ///
    /// # Returns
    /// A pointer to the `Account` if it exists in the state.
    ///
    /// # Errors
    /// Returns an error `error.AccountExpectedToBeLoaded` if the account is expected to be loaded but is not found.
    pub fn getAccount(self: *Self, address: [20]u8) !*Account {
        return self.state.getPtr(address) orelse error.AccountExpectedToBeLoaded;
    }

    /// Sets the code for the account associated with the provided address.
    ///
    /// This function updates the code for the account at the given address within the JournaledState.
    /// It first retrieves the account, marks it as touched in the journal, records the code change,
    /// and then updates the code and its hash in the account information.
    ///
    /// # Arguments
    /// - `allocator`: The allocator used for memory allocation.
    /// - `address`: A 20-byte array representing the address of the account to update the code for.
    /// - `code`: The new bytecode to set for the account.
    pub fn setCode(self: *Self, allocator: Allocator, address: [20]u8, code: Bytecode) !void {
        // Retrieve the account associated with the provided address.
        const account = try self.getAccount(address);

        // Retrieve the last recorded journal entry.
        const last_journal_item = try self.getLastJournalEntry();

        // Mark the account as touched in the journal to signify the upcoming code change.
        try Self.touchAccount(
            allocator,
            last_journal_item,
            address,
            account,
        );

        // Append the code change to the journal for future reference.
        try last_journal_item.append(allocator, .{ .CodeChange = .{ .address = address } });

        // Update the account's code hash with the hash of the new code.
        account.info.code_hash = code.hash_slow();

        // Set the new bytecode as the code for the account.
        account.info.code = code;
    }

    /// Increments the nonce of the specified account and records the change in the journal.
    ///
    /// This function increments the nonce of the provided account within the JournaledState.
    /// It marks the account as touched in the journal, records the nonce change, and increments the nonce value.
    ///
    /// # Arguments
    /// - `allocator`: The allocator used for memory allocation.
    /// - `address`: A 20-byte array representing the address of the account to increment the nonce for.
    ///
    /// # Returns
    /// An optional u64 representing the incremented nonce value on success, or null if the maximum value is reached.
    pub fn incrementNonce(self: *Self, allocator: Allocator, address: [20]u8) !?u64 {
        const account = try self.getAccount(address);

        // Check if the account's nonce is at the maximum value.
        if (account.info.nonce == std.math.maxInt(u64)) return null;

        // Retrieve the last recorded journal entry.
        const last_journal_item = try self.getLastJournalEntry();

        // Mark the account as touched in the journal to signify the upcoming nonce change.
        try Self.touchAccount(
            allocator,
            last_journal_item,
            address,
            account,
        );

        // Append the nonce change to the journal for future reference.
        try last_journal_item.append(allocator, .{ .NonceChange = .{ .address = address } });

        // Increment the account's nonce.
        account.info.nonce += 1;

        // Return the incremented nonce.
        return account.info.nonce;
    }

    /// Creates a checkpoint in the journal to track state for potential reversion.
    /// Increases the depth and appends an empty journal entry.
    /// Returns a `JournalCheckpoint` representing log and journal indices at this checkpoint.
    pub fn addCheckpoint(self: *Self) !JournalCheckpoint {
        // Create a checkpoint representing the current state of the logs and journal.
        const checkpoint: JournalCheckpoint = .{
            .log_index = self.logs.items.len, // Index of logs at this checkpoint.
            .journal_index = self.journal.items.len, // Index of journal entries at this checkpoint.
        };

        // Increment the depth to track the checkpoint.
        self.depth += 1;

        // Append an empty ArrayListUnmanaged of JournalEntry for the new checkpoint.
        try self.journal.append(std.ArrayListUnmanaged(JournalEntry){});

        return checkpoint; // Return the created checkpoint.
    }

    /// Decreases the depth of the journal state after a checkpoint is committed.
    pub fn checkpointCommit(self: *Self) void {
        self.depth -= 1;
    }

    /// Retrieves a value from the transient storage associated with the provided address and key.
    ///
    /// EIP-1153 introduces transient storage opcodes, enabling manipulation of state that behaves
    /// similarly to storage but is discarded after every transaction.
    ///
    /// This function, TLOAD, mimics SLOAD by fetching a 32-byte word from the transient storage at the given address and key.
    ///
    /// If the value exists, it is returned; otherwise, a default value of 0 is returned.
    ///
    /// # Arguments
    /// - `address`: A 20-byte array representing the address used for transient storage retrieval.
    /// - `key`: A u256 value serving as the key for accessing data in the transient storage.
    ///
    /// # Returns
    /// A u256 value retrieved from the transient storage if found, otherwise 0.
    pub fn tload(self: *Self, address: [20]u8, key: u256) u256 {
        // Attempt to retrieve the value from the transient storage using the provided address and key.
        if (self.transient_storage.get(.{ address, key })) |value| {
            // If the value exists in the transient storage, return it.
            return value;
        }

        // Return 0 if the value does not exist in the transient storage.
        return 0;
    }

    /// Appends a log entry to the log associated with the JournaledState.
    ///
    /// This function facilitates adding a Log entry to the JournaledState's log.
    /// The provided Log instance is appended to the log ArrayList within the JournaledState.
    ///
    /// # Arguments
    /// - `lg`: A Log instance to be added to the log.
    ///
    /// # Errors
    /// May return an error if appending to the log fails.
    pub fn addLog(self: *Self, lg: Log) !void {
        try self.logs.append(lg);
    }

    /// Loads or retrieves an account from the state, creating a new one if not found, and logs the action.
    ///
    /// This function attempts to fetch an account associated with the provided address from the state.
    /// If the account exists in the state, it returns the account; otherwise, it creates a new account,
    /// logs the action, and returns the new account. It also tracks if the loaded account is considered 'cold'.
    ///
    /// # Arguments
    /// - `allocator`: The allocator used for memory allocation.
    /// - `address`: A 20-byte array representing the address of the account to load or retrieve.
    /// - `db`: The database for retrieving basic account information.
    ///
    /// # Returns
    /// A tuple containing the loaded/retrieved account and a boolean indicating if it is considered 'cold'.
    /// If the account exists, it returns the account and 'false' for 'cold'; if not found, it returns a new account
    /// and 'true' for 'cold'.
    ///
    /// # Errors
    /// May return an error if journaling or state manipulation fails.
    pub fn loadAccount(
        self: *Self,
        allocator: Allocator,
        address: [20]u8,
        db: Database,
    ) !std.meta.Tuple(&.{ Account, bool }) {
        if (self.state.getEntry(address)) |e| {
            // Check if the account entry exists in the state for the provided address.
            // If found, return the existing account entry.
            return .{ e.value_ptr.*, false };
        } else {
            // If the account entry doesn't exist in the state for the provided address, create a new account.

            // Attempt to fetch basic account information from the database.
            const account = if (try db.basic(address)) |a|
                // If basic information exists, create an account with the retrieved information.
                Account{
                    .info = a,
                    .storage = std.AutoHashMap(u256, StorageSlot).init(allocator),
                    .status = .{
                        .Loaded = false,
                        .Created = false,
                        .SelfDestructed = false,
                        .Touched = false,
                        .LoadedAsNotExisting = true,
                    },
                }
            else
                // If basic information doesn't exist, create a new 'not-existing' account.
                try Account.newNotExisting(allocator);

            // Log the action of loading the account.
            try (try self.getLastJournalEntry()).append(
                allocator,
                .{ .AccountLoaded = .{ .address = address } },
            );

            var is_cold = false;

            // Check if the loaded account should be considered 'cold'.
            for (self.precompile_addresses.items) |precompile_address| {
                if (std.mem.eql(u8, &precompile_address, &address)) {
                    is_cold = true;
                    break;
                }
            }

            // Add the newly created/fetched account to the state.
            try self.state.put(address, account);

            // Return the loaded account and whether it is considered 'cold'.
            return .{ account, is_cold };
        }
    }

    /// Determines account existence and touch status by loading the account from the state.
    ///
    /// This function is a modified version of `loadAccount` and is designed to assess the existence
    /// and touch status of an account within the state. It performs validations and returns boolean
    /// flags indicating the existence and touch status of the loaded account.
    ///
    /// # Arguments
    /// - `allocator`: The allocator used for memory allocation.
    /// - `address`: A 20-byte array representing the address of the account to assess.
    /// - `db`: The database for retrieving basic account information.
    ///
    /// # Returns
    /// A tuple containing boolean flags indicating the account's existence and touch status.
    /// If the account exists, the first value is 'true', and the second indicates whether the account is loaded.
    ///
    /// # Errors
    /// May return an error if journaling or state manipulation fails.
    pub fn loadAccountExist(
        self: *Self,
        allocator: Allocator,
        address: [20]u8,
        db: Database,
    ) !std.meta.Tuple(&.{ bool, bool }) {
        // Load the account using the `loadAccount` function.
        var load_account = try self.loadAccount(allocator, address, db);

        // If the `SPURIOUS_DRAGON` spec is enabled, return the appropriate flags.
        if (SpecId.enabled(self.spec, .SPURIOUS_DRAGON)) {
            return .{ load_account[1], !load_account[0].isEmpty() };
        }

        // Determine account existence and touch status based on loaded account properties.
        return .{
            load_account[1],
            !load_account[0].isLoadedAsNotExisting() or load_account[0].isTouched(),
        };
    }

    /// Loads the code associated with an account or initializes it if absent.
    ///
    /// # Arguments
    /// - `allocator`: The allocator used for memory allocation.
    /// - `address`: The 20-byte address representing the account.
    /// - `db`: The database for retrieving account code information.
    ///
    /// # Returns
    /// A tuple containing the loaded/retrieved account and a boolean indicating if it's initialized.
    pub fn loadCode(
        self: *Self,
        allocator: Allocator,
        address: [20]u8,
        db: Database,
    ) !std.meta.Tuple(&.{ Account, bool }) {
        // Load the account using the `loadAccount` function.
        var load_account = try self.loadAccount(allocator, address, db);

        if (load_account[0].info.code == null) {
            // If code is null, initialize it based on code hash.
            if (load_account[0].info.code_hash.eql(Constants.KECCAK_EMPTY)) {
                load_account[0].info.code = Bytecode.init();
            } else {
                load_account[0].info.code = try db.codeByHash(load_account[0].info.code_hash);
            }
        }

        return load_account;
    }

    /// Frees the resources owned by this instance.
    pub fn deinit(self: *Self) void {
        self.state.deinit();
        self.transient_storage.deinit();
        self.logs.deinit();
        self.journal.deinit();
        self.precompile_addresses.deinit();
    }
};

/// Journal entries that are used to track changes to the state and are used to revert it.
pub const JournalEntry = union(enum) {
    const Self = @This();

    /// Used to mark account that is warm inside EVM in regards to EIP-2929 AccessList.
    /// Action: We will add Account to state.
    /// Revert: we will remove account from state.
    AccountLoaded: struct { address: [20]u8 },
    /// Mark account to be destroyed and journal balance to be reverted
    /// Action: Mark account and transfer the balance
    /// Revert: Unmark the account and transfer balance back
    AccountDestroyed: struct {
        address: [20]u8,
        target: [20]u8,
        was_destroyed: bool, // if account had already been destroyed before this journal entry
        had_balance: u256,
    },
    /// Loading account does not mean that account will need to be added to MerkleTree (touched).
    /// Only when account is called (to execute contract or transfer balance) only then account is made touched.
    /// Action: Mark account touched
    /// Revert: Unmark account touched
    AccountTouched: struct { address: [20]u8 },
    /// Transfer balance between two accounts
    /// Action: Transfer balance
    /// Revert: Transfer balance back
    BalanceTransfer: struct {
        from: [20]u8,
        to: [20]u8,
        balance: u256,
    },
    /// Increment nonce
    /// Action: Increment nonce by one
    /// Revert: Decrement nonce by one
    NonceChange: struct {
        address: [20]u8, //geth has nonce value,
    },
    /// Create account:
    /// Actions: Mark account as created
    /// Revert: Unmart account as created and reset nonce to zero.
    AccountCreated: struct { address: [20]u8 },
    /// It is used to track both storage change and warm load of storage slot. For warm load in regard
    /// to EIP-2929 AccessList had_value will be None
    /// Action: Storage change or warm load
    /// Revert: Revert to previous value or remove slot from storage
    StorageChange: struct {
        address: [20]u8,
        key: u256,
        had_value: ?u256, //if none, storage slot was cold loaded from db and needs to be removed
    },
    /// It is used to track an EIP-1153 transient storage change.
    /// Action: Transient storage changed.
    /// Revert: Revert to previous value.
    TransientStorageChange: struct {
        address: [20]u8,
        key: u256,
        had_value: u256,
    },
    /// Code changed
    /// Action: Account code changed
    /// Revert: Revert to previous bytecode.
    CodeChange: struct { address: [20]u8 },
};

test "JournaledState: touchAccount an account not already touched" {
    // Create a new account that does not exist using the testing allocator.
    var account = try Account.newNotExisting(std.testing.allocator);

    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Initialize an ArrayList of JournalEntry for logging account touches and defer its deinit().
    var journal = std.ArrayListUnmanaged(JournalEntry){};
    defer journal.deinit(std.testing.allocator);

    // Ensure that the account's status initially indicates it hasn't been touched.
    try expect(!account.status.Touched);

    // Invoke the touchAccount function on JournaledState to mark the account as touched.
    try JournaledState.touchAccount(
        std.testing.allocator,
        &journal,
        address,
        &account,
    );

    // Define the expected journal entry representing the account touch event.
    const expected_journal = [_]JournalEntry{.{ .AccountTouched = .{ .address = [_]u8{0x00} ** 20 } }};

    // Assert that the actual journal items match the expected journal entry.
    try expectEqualSlices(JournalEntry, &expected_journal, journal.items);

    // Ensure that the account's status is updated to indicate it has been touched.
    try expect(account.status.Touched);
}

test "JournaledState: touchAccount an account already touched" {
    // Create a new account that does not exist using the testing allocator.
    var account = try Account.newNotExisting(std.testing.allocator);

    // Mark the account as touched to simulate an already touched account.
    account.markTouch();

    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Initialize an ArrayList of JournalEntry for logging account touches and defer its deinit().
    var journal = std.ArrayListUnmanaged(JournalEntry){};
    defer journal.deinit(std.testing.allocator);

    // Ensure that the account's status initially indicates it has been touched.
    try expect(account.status.Touched);

    // Invoke the touchAccount function on JournaledState.
    // As the account is already touched, the function should not append anything to the journal.
    try JournaledState.touchAccount(
        std.testing.allocator,
        &journal,
        address,
        &account,
    );

    // Assert that the actual journal items are empty since the account was already touched.
    try expect(journal.items.len == 0);

    // Ensure that the account's status remains updated, confirming that touchAccount did not modify it.
    try expect(account.status.Touched);
}

test "JournaledState: touch should mark the account as touched" {
    // Create a 20-byte address filled with zeros.
    var address = [_]u8{0x00} ** 20;

    // Initialize an ArrayList for precompile addresses and defer its deinitialization.
    var precompile_addresses = std.ArrayList([20]u8).init(std.testing.allocator);
    defer precompile_addresses.deinit();

    // Create a new JournaledState instance for testing with a specific arrow type and precompile addresses.
    var journal_state = try JournaledState.init(
        std.testing.allocator,
        .ARROW_GLACIER,
        precompile_addresses,
    );
    defer journal_state.deinit();

    // Initialize an unmanaged ArrayList for the journal entry and defer its deinitialization.
    var journal_entry = std.ArrayListUnmanaged(JournalEntry){};
    defer journal_entry.deinit(std.testing.allocator);

    // Append an account touch event to the journal entry.
    try journal_entry.append(std.testing.allocator, .{ .AccountTouched = .{ .address = address } });

    // Append the journal entry to the journal state's journal.
    try journal_state.journal.append(journal_entry);

    // Create a new account for the address in the state and ensure it's initially untouched.
    try journal_state.state.put(address, try Account.newNotExisting(std.testing.allocator));
    try expect(!journal_state.state.get(address).?.status.Touched);

    // Invoke the 'touch' function on the journal state for the provided address.
    try journal_state.touch(std.testing.allocator, &address);

    // Define the expected journal entry representing the account touch event.
    const expected_journal = [_]JournalEntry{
        .{ .AccountTouched = .{ .address = [_]u8{0x00} ** 20 } },
        .{ .AccountTouched = .{ .address = [_]u8{0x00} ** 20 } },
    };

    // Ensure the account at the address is marked as touched in the journal state.
    try expect(journal_state.state.get(address).?.status.Touched);

    // Assert that the actual journal items match the expected journal entry.
    try expectEqualSlices(JournalEntry, &expected_journal, journal_state.journal.items[0].items);
}

test "JournaledState: touch should return an error if the journal is empty" {
    // Create a 20-byte address filled with zeros.
    var address = [_]u8{0x00} ** 20;

    // Initialize an ArrayList for precompile addresses and defer its deinitialization.
    var precompile_addresses = std.ArrayList([20]u8).init(std.testing.allocator);
    defer precompile_addresses.deinit();

    // Create a new JournaledState instance for testing with a specific arrow type and precompile addresses.
    var journal_state = try JournaledState.init(
        std.testing.allocator,
        .ARROW_GLACIER,
        precompile_addresses,
    );
    defer journal_state.deinit();

    // Create a new account for the address in the state and ensure it's initially untouched.
    try journal_state.state.put(address, try Account.newNotExisting(std.testing.allocator));
    try expect(!journal_state.state.get(address).?.status.Touched);

    // Assert that calling 'touch' on an empty journal returns an expected error.
    try expectError(
        error.JournalIsEmpty,
        journal_state.touch(std.testing.allocator, &address),
    );
}

test "JournaledState: finalize should clean up and return modified state" {
    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Create a new JournaledState instance for testing with specific configurations.
    var journal_state = try JournaledState.init(
        std.testing.allocator,
        .ARROW_GLACIER,
        std.ArrayList([20]u8).init(std.testing.allocator),
    );
    defer journal_state.deinit();

    // Initialize an unmanaged ArrayList for the journal entry and defer its deinitialization.
    var journal_entry = std.ArrayListUnmanaged(JournalEntry){};
    defer journal_entry.deinit(std.testing.allocator);

    // Append an account touch event to the journal entry.
    try journal_entry.append(
        std.testing.allocator,
        .{ .AccountTouched = .{ .address = address } },
    );

    // Append the journal entry to the journal state's journal.
    try journal_state.journal.append(journal_entry);

    // Set the depth to a specific value.
    journal_state.depth = 15;

    // Put a new account into the state with the given address.
    try journal_state.state.put(
        address,
        try Account.newNotExisting(std.testing.allocator),
    );

    // Append an entry to the log for the given address.
    try journal_state.logs.append(.{ .address = address });

    // Assertions to check the initial state.
    try expect(journal_state.depth != 0);
    try expect(journal_state.state.count() != 0);
    try expect(journal_state.journal.items.len != 0);
    try expect(journal_state.logs.items.len != 0);

    // Finalize the journal state and retrieve the modified state and logs as a tuple.
    var result = try journal_state.finalize();
    defer result[0].deinit();
    defer result[1].deinit();

    // Initialize an expected log ArrayList for comparison and defer its deinitialization.
    var expected_log = std.ArrayList(Log).init(std.testing.allocator);
    defer expected_log.deinit();

    // Append an expected log entry for the address.
    try expected_log.append(.{ .address = address });

    // Assertions to validate the modified state and logs after finalization.
    try expect(result[0].count() == 1);
    try expectEqual(
        @as(?Account, try Account.newNotExisting(std.testing.allocator)),
        result[0].get(address).?,
    );
    try expectEqualSlices(
        Log,
        expected_log.items,
        result[1].items,
    );

    // Assertions to ensure the cleanup of the journal state.
    try expect(journal_state.depth == 0);
    try expect(journal_state.state.count() == 0);
    try expect(journal_state.journal.items.len == 0);
    try expect(journal_state.logs.items.len == 0);
}

test "JournaledState: account should return the account corresponding to the given address" {
    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Create a new JournaledState instance for testing with a specific arrow type and precompile addresses.
    var journal_state = try JournaledState.init(
        std.testing.allocator,
        .ARROW_GLACIER,
        std.ArrayList([20]u8).init(std.testing.allocator),
    );
    defer journal_state.deinit(); // Ensures cleanup after the test runs

    // Create a new account instance (not existing initially) using the testing allocator.
    const account = try Account.newNotExisting(std.testing.allocator);

    // Expect an error when attempting to get an account that's expected to be loaded but isn't found.
    try expectError(
        error.AccountExpectedToBeLoaded,
        journal_state.getAccount(address),
    );

    // Create a new account for the address in the state and ensure it's initially untouched.
    try journal_state.state.put(address, account);

    // Retrieve the account associated with the address from the JournaledState and compare it to the created account.
    try expectEqual(
        account,
        (try journal_state.getAccount(address)).*, // Dereferencing the pointer to the retrieved account
    );
}

test "JournaledState: setCode should set the code properly at the provided address" {
    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Initialize an ArrayList for precompile addresses and defer its deinitialization.
    var precompile_addresses = std.ArrayList([20]u8).init(std.testing.allocator);
    defer precompile_addresses.deinit();

    // Create a new JournaledState instance for testing with a specific arrow type and precompile addresses.
    var journal_state = try JournaledState.init(
        std.testing.allocator,
        .ARROW_GLACIER,
        precompile_addresses,
    );
    defer journal_state.deinit();

    // Initialize an unmanaged ArrayList for the journal entry and defer its deinitialization.
    var journal_entry = std.ArrayListUnmanaged(JournalEntry){};
    defer journal_entry.deinit(std.testing.allocator);

    // Append an account touch event to the journal entry.
    try journal_entry.append(std.testing.allocator, .{ .AccountTouched = .{ .address = address } });

    // Append the journal entry to the journal state's journal.
    try journal_state.journal.append(journal_entry);

    // Create a new account for the address in the state and ensure it's initially untouched.
    try journal_state.state.put(address, try Account.newNotExisting(std.testing.allocator));

    // Ensure that the newly created account is initially untouched.
    try expect(!journal_state.state.get(address).?.status.Touched);

    // Ensure that the code hash for the account is initially set to Constants.KECCAK_EMPTY.
    try expectEqual(Constants.KECCAK_EMPTY, (try journal_state.getAccount(address)).info.code_hash);

    // Define a buffer and create a Bytecode instance.
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    const code = Bytecode.new_checked(buf[0..], 3);

    // Set the code for the account at the specified address.
    try journal_state.setCode(std.testing.allocator, address, code);

    // Define the expected journal entry representing the account touch event and code change.
    const expected_journal = [_]JournalEntry{
        .{ .AccountTouched = .{ .address = [_]u8{0x00} ** 20 } },
        .{ .AccountTouched = .{ .address = [_]u8{0x00} ** 20 } },
        .{ .CodeChange = .{ .address = address } },
    };

    // Ensure that the account at the address is marked as touched after setting the code.
    try expect(journal_state.state.get(address).?.status.Touched);

    // Ensure that the code hash for the account matches the keccak256 hash of the provided code.
    try expectEqual(
        Utils.keccak256(code.original_bytes()),
        (try journal_state.getAccount(address)).info.code_hash,
    );

    // Ensure that the code for the account matches the provided code.
    try expectEqual(
        @as(?Bytecode, code),
        (try journal_state.getAccount(address)).info.code,
    );

    // Ensure that the actual journal entry matches the expected journal entry.
    try expectEqualSlices(JournalEntry, &expected_journal, journal_state.journal.items[0].items);
}

test "JournaledState: incrementNonce should increment the nonce" {
    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Initialize an ArrayList for precompile addresses and defer its deinitialization.
    var precompile_addresses = std.ArrayList([20]u8).init(std.testing.allocator);
    defer precompile_addresses.deinit();

    // Create a new JournaledState instance for testing with a specific arrow type and precompile addresses.
    var journal_state = try JournaledState.init(
        std.testing.allocator,
        .ARROW_GLACIER,
        precompile_addresses,
    );
    defer journal_state.deinit();

    // Initialize an unmanaged ArrayList for the journal entry and defer its deinitialization.
    var journal_entry = std.ArrayListUnmanaged(JournalEntry){};
    defer journal_entry.deinit(std.testing.allocator);

    // Append an account touch event to the journal entry.
    try journal_entry.append(std.testing.allocator, .{ .AccountTouched = .{ .address = address } });

    // Append the journal entry to the journal state's journal.
    try journal_state.journal.append(journal_entry);

    // Create a new account for the address in the state and ensure it's initially untouched.
    try journal_state.state.put(address, try Account.newNotExisting(std.testing.allocator));

    // Ensure that the newly created account is initially untouched.
    try expect(!journal_state.state.get(address).?.status.Touched);

    // Ensure that the initial nonce for the account is zero.
    try expect(journal_state.state.get(address).?.info.nonce == 0);

    // Call the 'incrementNonce' function with the specified allocator and address.
    const nonce = try journal_state.incrementNonce(std.testing.allocator, address);

    // Define the expected journal entry representing the account touch event and nonce change.
    const expected_journal = [_]JournalEntry{
        .{ .AccountTouched = .{ .address = [_]u8{0x00} ** 20 } },
        .{ .AccountTouched = .{ .address = [_]u8{0x00} ** 20 } },
        .{ .NonceChange = .{ .address = address } },
    };

    // Ensure that the account at the address is marked as touched after setting the code.
    try expect(journal_state.state.get(address).?.status.Touched);

    // Ensure that the returned nonce is incremented by one from the initial value (0).
    try expect(nonce == 1);

    // Ensure that the account's nonce in the state matches the incremented value (1).
    try expect(journal_state.state.get(address).?.info.nonce == 1);

    // Ensure that the actual journal entry matches the expected journal entry.
    try expectEqualSlices(JournalEntry, &expected_journal, journal_state.journal.items[0].items);
}

test "JournaledState: tload should return the transient storage tied to the account" {
    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Initialize an ArrayList for precompile addresses and defer its deinitialization.
    var precompile_addresses = std.ArrayList([20]u8).init(std.testing.allocator);
    defer precompile_addresses.deinit();

    // Create a new JournaledState instance for testing with a specific arrow type and precompile addresses.
    var journal_state = try JournaledState.init(
        std.testing.allocator,
        .ARROW_GLACIER,
        precompile_addresses,
    );
    defer journal_state.deinit();

    // Verify that initially, the value tied to address and key 10 in the transient storage is 0.
    try expectEqual(@as(u256, 0), journal_state.tload(address, 10));

    // Store the value 111 in the transient storage tied to address and key 10.
    try journal_state.transient_storage.put(.{ address, 10 }, 111);

    // Verify that after storing, the value retrieved from transient storage tied to address and key 10 is 111.
    try expectEqual(@as(u256, 111), journal_state.tload(address, 10));
}

test "JournaledState: addLog should push a new log to the journaled state" {
    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Create a new JournaledState instance for testing with specific configurations.
    var journal_state = try JournaledState.init(
        std.testing.allocator,
        .ARROW_GLACIER,
        std.ArrayList([20]u8).init(std.testing.allocator),
    );
    defer journal_state.deinit();

    // Initialize an expected log ArrayList for comparison and defer its deinitialization.
    var expected_log = std.ArrayList(Log).init(std.testing.allocator);
    defer expected_log.deinit();

    // Append an expected log entry for the address.
    try expected_log.append(.{ .address = address });

    // Ensure the initial length of the log in the JournaledState is 0.
    try expect(journal_state.logs.items.len == 0);

    // Add a log entry to the JournaledState for the provided address.
    try journal_state.addLog(.{ .address = address });

    // Ensure that the resulting log in the JournaledState matches the expected log.
    try expectEqualSlices(Log, expected_log.items, journal_state.logs.items);
}

test "JournaledState: addCheckpoint should add a checkpoint in the journaled state" {
    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Create a new JournaledState instance for testing with specific configurations.
    var journal_state = try JournaledState.init(
        std.testing.allocator,
        .ARROW_GLACIER,
        std.ArrayList([20]u8).init(std.testing.allocator),
    );
    defer journal_state.deinit();

    // Appends an account touch event to the log multiple times.
    try journal_state.logs.appendNTimes(.{ .address = address }, 10);

    // Initialize an unmanaged ArrayList for the journal entry and defer its deinitialization.
    var journal_entry = std.ArrayListUnmanaged(JournalEntry){};
    defer journal_entry.deinit(std.testing.allocator);

    // Append an account touch event to the journal entry.
    try journal_entry.append(std.testing.allocator, .{ .AccountTouched = .{ .address = address } });

    // Appends the journal entry to the journal state's journal multiple times.
    try journal_state.journal.appendNTimes(journal_entry, 5);

    // Ensure that the depth of the journal state is initially 0.
    try expect(journal_state.depth == 0);

    // Create a checkpoint in the journal state.
    const checkpoint = try journal_state.addCheckpoint();

    // Ensure that the generated checkpoint matches the expected log and journal indices.
    try expectEqual(@as(JournalCheckpoint, .{ .log_index = 10, .journal_index = 5 }), checkpoint);

    // Ensure that the depth of the journal state is incremented to 1 after adding a checkpoint.
    try expect(journal_state.depth == 1);

    // Initialize an unmanaged ArrayList for the expected last journal entry and defer its deinitialization.
    var expected_last_journal_entry = std.ArrayListUnmanaged(JournalEntry){};
    defer expected_last_journal_entry.deinit(std.testing.allocator);

    // Ensure the last journal entry matches the expected empty journal entry.
    try expectEqualSlices(JournalEntry, expected_last_journal_entry.items, journal_state.journal.items[5].items);
}

test "JournaledState: checkpointCommit should decrease the depth of the journal by 1" {
    // Create a new JournaledState instance for testing with specific configurations.
    var journal_state = try JournaledState.init(
        std.testing.allocator,
        .ARROW_GLACIER,
        std.ArrayList([20]u8).init(std.testing.allocator),
    );
    defer journal_state.deinit();

    // Set the depth of the journal state to a specific value (134 in this case).
    journal_state.depth = 134;

    // Commit the checkpoint, which should decrease the depth by 1.
    journal_state.checkpointCommit();

    // Ensure that the depth has been decremented by 1.
    try expect(journal_state.depth == 133);
}

test "JournaledState: loadAccount should return constructed account and is cold if account doesn't exist in state" {
    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Initialize an empty database.
    const db = Database.initEmpty();

    // Initialize an ArrayList for precompile addresses and defer its deinitialization.
    var precompile_addresses = std.ArrayList([20]u8).init(std.testing.allocator);
    defer precompile_addresses.deinit();
    try precompile_addresses.append(address);

    // Create a new JournaledState instance for testing with specific arrow type and precompile addresses.
    var journal_state = try JournaledState.init(
        std.testing.allocator,
        .ARROW_GLACIER,
        precompile_addresses,
    );
    defer journal_state.deinit();

    // Initialize an unmanaged ArrayList for the journal entry and defer its deinitialization.
    var journal_entry = std.ArrayListUnmanaged(JournalEntry){};
    defer journal_entry.deinit(std.testing.allocator);

    // Append an account touch event to the journal entry.
    try journal_entry.append(std.testing.allocator, .{ .AccountTouched = .{ .address = address } });

    // Append the journal entry to the journal state's journal.
    try journal_state.journal.append(journal_entry);

    // Load the account using the test function.
    const res = try journal_state.loadAccount(std.testing.allocator, address, db);

    // Define the expected journal entry representing the account touch event and nonce change.
    const expected_journal = [_]JournalEntry{
        .{ .AccountTouched = .{ .address = [_]u8{0x00} ** 20 } },
        .{ .AccountLoaded = .{ .address = [_]u8{0x00} ** 20 } },
    };

    // Ensure that the actual journal entry matches the expected journal entry.
    try expectEqualSlices(JournalEntry, &expected_journal, journal_state.journal.items[0].items);

    // Assert that the loaded account is considered 'cold'.
    try expect(res[1]);

    // Check that the account status matches the expected 'LoadedAsNotExisting' state.
    try expectEqual(
        AccountStatus{
            .Loaded = false,
            .Created = false,
            .SelfDestructed = false,
            .Touched = false,
            .LoadedAsNotExisting = true,
        },
        res[0].status,
    );

    // Check if the loaded account information matches the expected default values.
    try expect(res[0].info.eq(.{
        .balance = 0,
        .nonce = 0,
        .code_hash = Constants.KECCAK_EMPTY,
        .code = Bytecode.init(),
    }));

    // Check that the storage count of the loaded account is zero.
    try expectEqual(@as(usize, 0), res[0].storage.count());
}

test "JournaledState: loadAccount should return account corresponding to provided address if account exists in state" {
    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Initialize an empty database.
    const db = Database.initEmpty();

    // Initialize an ArrayList for precompile addresses and defer its deinitialization.
    var precompile_addresses = std.ArrayList([20]u8).init(std.testing.allocator);
    defer precompile_addresses.deinit();

    // Create a new JournaledState instance for testing with specific arrow type and precompile addresses.
    var journal_state = try JournaledState.init(
        std.testing.allocator,
        .ARROW_GLACIER,
        precompile_addresses,
    );
    defer journal_state.deinit();

    // Add a 'not-existing' account to the state for the provided address.
    try journal_state.state.put(address, try Account.newNotExisting(std.testing.allocator));

    // Load the account using the test function.
    const res = try journal_state.loadAccount(std.testing.allocator, address, db);

    // Assert that the loaded account is not considered 'cold'.
    try expect(!res[1]);

    // Check that the account status matches the expected state.
    try expectEqual(
        AccountStatus{
            .Loaded = false,
            .Created = false,
            .SelfDestructed = false,
            .Touched = false,
            .LoadedAsNotExisting = true,
        },
        res[0].status,
    );

    // Check if the loaded account information matches the expected default values.
    try expect(res[0].info.eq(.{
        .balance = 0,
        .nonce = 0,
        .code_hash = Constants.KECCAK_EMPTY,
        .code = Bytecode.init(),
    }));

    // Check that the storage count of the loaded account is zero.
    try expectEqual(@as(usize, 0), res[0].storage.count());
}

test "JournaledState: loadAccountExist should return is_cold and is_exists about account with SPURIOUS_DRAGON enabled" {
    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Initialize an empty database.
    const db = Database.initEmpty();

    // Initialize an ArrayList for precompile addresses and defer its deinitialization.
    var precompile_addresses = std.ArrayList([20]u8).init(std.testing.allocator);
    defer precompile_addresses.deinit();

    // Append the zero-filled address to the precompile addresses ArrayList.
    try precompile_addresses.append(address);

    // Create a new JournaledState instance for testing with specific arrow type and precompile addresses.
    var journal_state = try JournaledState.init(
        std.testing.allocator,
        .ARROW_GLACIER,
        precompile_addresses,
    );
    defer journal_state.deinit();

    // Initialize an unmanaged ArrayList for the journal entry and defer its deinitialization.
    var journal_entry = std.ArrayListUnmanaged(JournalEntry){};
    defer journal_entry.deinit(std.testing.allocator);

    // Append an account touch event to the journal entry.
    try journal_entry.append(std.testing.allocator, .{ .AccountTouched = .{ .address = address } });

    // Append the journal entry to the journal state's journal.
    try journal_state.journal.append(journal_entry);

    // Load the account using the test function.
    const load_account_exist = try journal_state.loadAccountExist(std.testing.allocator, address, db);

    // Assert that the loaded account is considered 'cold'.
    try expect(load_account_exist[0]);

    // Assert that the loaded account didn't exist.
    try expect(!load_account_exist[1]);
}

test "JournaledState: loadCode should create a new code if code hash is Keccak Empty" {
    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Initialize an empty database.
    const db = Database.initEmpty();

    // Initialize an ArrayList for precompile addresses and defer its deinitialization.
    var precompile_addresses = std.ArrayList([20]u8).init(std.testing.allocator);
    defer precompile_addresses.deinit();

    // Append the zero-filled address to the precompile addresses ArrayList.
    try precompile_addresses.append(address);

    // Create a new JournaledState instance for testing with specific arrow type and precompile addresses.
    var journal_state = try JournaledState.init(
        std.testing.allocator,
        .ARROW_GLACIER,
        precompile_addresses,
    );
    defer journal_state.deinit();

    // Initialize an unmanaged ArrayList for the journal entry and defer its deinitialization.
    var journal_entry = std.ArrayListUnmanaged(JournalEntry){};
    defer journal_entry.deinit(std.testing.allocator);

    // Append an account touch event to the journal entry.
    try journal_entry.append(std.testing.allocator, .{ .AccountTouched = .{ .address = address } });

    // Append the journal entry to the journal state's journal.
    try journal_state.journal.append(journal_entry);

    // Load the code using the `loadCode` function.
    const load_code = try journal_state.loadCode(std.testing.allocator, address, db);

    // Assert that the loaded code is initialized if the code hash is Keccak Empty.
    try expect(load_code[0].info.code.?.eql(Bytecode.init()));

    // Assert that the loaded code is initialized, indicating the code was created.
    try expect(load_code[1]);
}
