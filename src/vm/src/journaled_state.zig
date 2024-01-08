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
const SelfDestructResult = @import("../../interpreter/lib.zig").interpreter.SelfDestructResult;

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
        account.info.code_hash = code.hashSlow();

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

    /// Reverts all changes made in the given journal entries within a blockchain state and transient storage.
    ///
    /// This function iterates through the journal entries in reverse order and reverts the changes made
    /// to the blockchain state and transient storage, undoing operations like account loading, touching, destruction,
    /// balance transfer, nonce change, account creation, storage change, transient storage change, and code change.
    ///
    /// # Arguments
    ///
    /// - `state`: A pointer to the blockchain state.
    /// - `transient_storage`: A pointer to the transient storage.
    /// - `journal_entries`: An unmanaged ArrayList of JournalEntry instances representing the recorded changes.
    /// - `is_spurious_dragon_enabled`: A boolean flag indicating whether a specific condition is enabled.
    ///
    /// # Throws
    ///
    /// This function can throw exceptions if there are issues with the state or transient storage access.
    ///
    /// # Note
    ///
    /// The function takes in the state, transient storage, and a list of journal entries,
    /// then reverts changes performed in these journal entries on the state and transient storage.
    ///
    /// The code uses a while loop to iterate through the journal entries in reverse order and applies
    /// different actions based on the type of journal entry.
    pub fn journalRevert(
        state: *State,
        transient_storage: *TransientStorage,
        journal_entries: std.ArrayListUnmanaged(JournalEntry),
        is_spurious_dragon_enabled: bool,
    ) !void {
        var idx = journal_entries.items.len;

        while (idx >= 1) : (idx -= 1) {
            switch (journal_entries.items[idx - 1]) {
                // Reverts changes related to loading an account.
                .AccountLoaded => |account| {
                    _ = state.remove(account.address);
                },
                // Reverts changes related to touching an account.
                .AccountTouched => |account| {
                    // Specific condition check for spurious dragon.
                    if (is_spurious_dragon_enabled and std.mem.eql(
                        u8,
                        &account.address,
                        &Constants.PRECOMPILE3.bytes,
                    )) {
                        continue; // Skips further action if condition is met.
                    }
                    state.getPtr(account.address).?.unmarkTouch();
                },
                // Reverts changes related to destroying an account.
                .AccountDestroyed => |account| {
                    // Obtains account and adjusts based on previous destruction status.
                    const acc = state.getPtr(account.address).?;

                    if (account.was_destroyed) acc.markSelfdestruct() else acc.unmarkSelfdestruct();

                    // Adjusts balance changes after destruction.
                    acc.info.balance += account.had_balance;

                    // Verify that address is not the target before decreasing target balance
                    if (!std.mem.eql(
                        u8,
                        &account.address,
                        &account.target,
                    )) {
                        state.getPtr(account.target).?.info.balance -= account.had_balance;
                    }
                },
                // Reverts changes related to balance transfer.
                .BalanceTransfer => |transfer| {
                    // Reverts the transferred balance.
                    state.getPtr(transfer.from).?.info.balance += transfer.balance;
                    state.getPtr(transfer.to).?.info.balance -= transfer.balance;
                },
                // Reverts changes related to nonce change.
                .NonceChange => |change| {
                    // Reverts the nonce change.
                    state.getPtr(change.address).?.info.nonce -= 1;
                },
                // Reverts changes related to account creation.
                .AccountCreated => |account| {
                    // Reverts account creation flags and nonce.
                    const acc = state.getPtr(account.address).?;
                    acc.unmarkCreated();
                    acc.info.nonce = 0;
                },
                // Reverts changes related to storage.
                .StorageChange => |change| {
                    // Reverts changes in storage.
                    var storage = state.getPtr(change.address).?.storage;
                    if (change.had_value) |v|
                        storage.getPtr(change.key).?.present_value = v
                    else
                        _ = storage.remove(change.key);
                },
                // Reverts changes related to transient storage.
                .TransientStorageChange => |ts| {
                    // Reverts changes in transient storage.
                    if (ts.had_value == 0)
                        _ = transient_storage.remove(.{ ts.address, ts.key })
                    else
                        try transient_storage.put(.{ ts.address, ts.key }, ts.had_value);
                },
                // Reverts changes related to code change.
                .CodeChange => |code| {
                    // Reverts code change by nullifying code and hash.
                    const acc = state.getPtr(code.address).?;
                    acc.info.code_hash = Constants.KECCAK_EMPTY;
                    acc.info.code = null;
                },
            }
        }
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

    /// Reverts changes in the blockchain state and transient storage to a previously created checkpoint.
    ///
    /// This function decreases the depth of the journal state and iterates through journal entries
    /// after the specified checkpoint, reverting changes made to the state and transient storage
    /// using the `journalRevert` function. It also trims logs and journal entries beyond the checkpoint.
    ///
    /// # Arguments
    ///
    /// - `self`: A pointer to the current state.
    /// - `checkpoint`: A JournalCheckpoint representing the checkpoint to which the state needs to be reverted.
    ///
    /// # Throws
    ///
    /// Throws exceptions if there are issues while reverting changes or resizing logs and journal entries.
    pub fn checkpointRevert(self: *Self, checkpoint: JournalCheckpoint) !void {
        // Retrieve boolean flag indicating if Spurious Dragon is enabled.
        const is_spurious_dragon_enabled = SpecId.enabled(self.spec, .SPURIOUS_DRAGON);

        // Decrease the depth of the journal state after a checkpoint is committed.
        self.depth -= 1;

        // Counter to track the number of journal entries to revert.
        var count: usize = 0;

        // Iterate through the journal entries after the checkpoint to revert changes.
        while (count < (self.journal.items.len - checkpoint.journal_index)) : (count += 1) {
            // Revert changes made in the journal entry using journalRevert function.
            try Self.journalRevert(
                &self.state, // Pointer to blockchain state.
                &self.transient_storage, // Pointer to transient storage.
                self.journal.items[self.journal.items.len - 1 - count], // Journal entry to revert.
                is_spurious_dragon_enabled, // Flag indicating Spurious Dragon condition.
            );
        }

        // Resize logs to the checkpoint log index.
        try self.logs.resize(checkpoint.log_index);

        // Resize journal entries to the checkpoint journal index.
        try self.journal.resize(checkpoint.journal_index);
    }

    /// Performs a self-destruct action, transferring Ether balance between Ethereum accounts based on Ethereum Improvement Proposal (EIP) 6780 specifications.
    ///
    /// This function handles the SELFDESTRUCT opcode behavior changes, ensuring fund transfers and account deletions based on transaction context and Cancun specification status.
    ///
    /// Parameters:
    /// - `self`: Ethereum state instance.
    /// - `allocator`: Memory allocator for Ziglang.
    /// - `address`: Address of the Ethereum account initiating the self-destruct.
    /// - `target`: Address of the Ethereum account receiving the funds or being deleted.
    /// - `db`: Database instance for Ethereum state information.
    ///
    /// Returns a `SelfDestructResult` containing information about the self-destruct action's outcome:
    /// - `had_value`: Indicates if the initiating account had a non-zero balance before self-destruct.
    /// - `is_cold`: Indicates if the target account exists but is inactive (cold).
    /// - `target_exists`: Indicates if the target account exists.
    /// - `previously_destroyed`: Indicates if the initiating account was previously self-destructed.
    ///
    /// References:
    /// - EIP-6780: https://eips.ethereum.org/EIPS/eip-6780
    /// - Rust Implementation: Provided Rust implementation for selfdestruct action.
    pub fn selfDestruct(
        self: *Self,
        allocator: Allocator,
        address: [20]u8,
        target: [20]u8,
        db: Database,
    ) !SelfDestructResult {
        // Check if the target account exists.
        const load_account_exist = try self.loadAccountExist(allocator, target, db);

        // Retrieve the initiating account and handle fund transfers or deletions based on SELFDESTRUCT operation.
        const account = if (!std.mem.eql(u8, &address, &target)) blk: {
            // Initialize accounts for the initiating and target addresses.
            const base_account = self.state.getPtr(address).?;
            const target_account = self.state.getPtr(target).?;

            // Ensure the target account is activated.
            try Self.touchAccount(
                allocator,
                try self.getLastJournalEntry(),
                target,
                target_account,
            );

            // Transfer funds from the initiating to the target account.
            target_account.info.balance += base_account.info.balance;

            break :blk base_account;
        } else self.state.getPtr(address).?;

        // Retrieve balance and previous self-destruct status of the initiating account.
        const balance = account.info.balance;
        const previously_destroyed = account.isSelfdestructed();
        const is_cancun_enabled = SpecId.enabled(self.spec, .CANCUN);

        // Define the journal entry based on Cancun specification and account conditions.
        const journal_entry: ?JournalEntry = if (account.isCreated() or !is_cancun_enabled) blk: {
            // Mark the account as self-destructed and reset the balance if Cancun is not enabled.
            account.markSelfdestruct();
            account.info.balance = 0;
            break :blk .{ .AccountDestroyed = .{
                .address = address,
                .target = target,
                .was_destroyed = previously_destroyed,
                .had_balance = balance,
            } };
        } else if (!std.mem.eql(u8, &address, &target)) blk: {
            // Reset balance if the accounts are different (fund transfer case).
            account.info.balance = 0;
            break :blk .{ .BalanceTransfer = .{
                .from = address,
                .to = target,
                .balance = balance,
            } };
        } else null;

        // Append the journal entry if available.
        if (journal_entry) |entry| {
            try (try self.getLastJournalEntry()).append(allocator, entry);
        }

        // Return the self-destruct result.
        return .{
            .had_value = balance != 0,
            .is_cold = load_account_exist[0],
            .target_exists = load_account_exist[1],
            .previously_destroyed = previously_destroyed,
        };
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

    /// Store transient storage tied to the account.
    ///
    /// Manipulates transient storage using Ethereum Improvement Proposal EIP-1153,
    /// enabling manipulation of state discarded after each transaction.
    ///
    /// # Arguments
    ///
    /// * `address` - Address (20 bytes) associated with the value in transient storage.
    /// * `key` - Key (256-bit unsigned integer) representing the value's identifier.
    /// * `new` - New value (256-bit unsigned integer) to store in transient storage.
    ///
    /// # EIP-1153 Specifications
    ///
    /// The function interacts with transient storage, akin to storage but cleared after transactions.
    /// It offers gas-efficient communication between frames and contracts, resolving reentrancy issues
    /// and reducing the impact of EIP-3529 limitations on refunds for transiently-set storage slots.
    ///
    /// # Gas Costs and Behavior
    ///
    /// Gas cost for `TSTORE` is equivalent to a warm `SSTORE` of a dirty slot (currently 100 gas).
    /// Gas cost for `TLOAD` mirrors a hot `SLOAD` (currently 100 gas).
    ///
    /// All values in transient storage are discarded at the transaction's end.
    /// Transient storage is private to the owning contract, accessible only by owning contract frames.
    ///
    /// # Security Considerations
    ///
    /// Smart contract developers must understand transient storage lifetimes to avoid unintended bugs,
    /// especially in reentrancy-sensitive scenarios. Using transient storage as in-memory mappings
    /// requires caution due to differing behaviors compared to memory.
    pub fn tstore(
        self: *Self,
        allocator: Allocator,
        address: [20]u8,
        key: u256,
        new: u256,
    ) !void {
        // Check if the new value is 0 (indicating removal) or set a new value in transient storage
        const had_value: ?u256 = if (new == 0) blk: {
            // Attempt to remove the value associated with the address and key
            break :blk if (self.transient_storage.fetchRemove(.{ address, key })) |v|
                v.value
            else
                null;
        } else blk: {
            // Attempt to set a new value for the given address and key
            const previous_value = if (try self.transient_storage.fetchPut(
                .{ address, key },
                new,
            )) |kv|
                kv.value
            else
                0;

            // If the previous value is different from the new value, break to exit block
            break :blk if (previous_value != new) previous_value else null;
        };

        // If a value was present in the transient storage
        if (had_value) |v| {
            // Append the change to the transaction's journal
            try (try self.getLastJournalEntry()).append(
                allocator,
                .{ .TransientStorageChange = .{
                    .address = address,
                    .key = key,
                    .had_value = v,
                } },
            );
        }
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
                load_account[0].info.code = Bytecode.init(allocator);
            } else {
                load_account[0].info.code = try db.codeByHash(
                    allocator,
                    load_account[0].info.code_hash,
                );
            }
        }

        return load_account;
    }

    /// Loads a storage slot value from the current account's storage onto the stack.
    ///
    /// # Note
    /// Assumes the account is already present and loaded.
    ///
    /// # Arguments
    /// - `allocator`: The allocator used for memory allocation.
    /// - `address`: A 20-byte array representing the address of the account.
    /// - `key`: The key of the storage slot.
    /// - `db`: The database for retrieving storage information.
    ///
    /// # Returns
    /// A tuple containing the loaded storage value and a boolean indicating if the value was loaded.
    /// If the storage slot exists, it returns the value and 'false'; if not found, it returns '0' and 'true'.
    ///
    /// # Errors
    /// May return an error if the account is missing or if storage retrieval fails.
    pub fn sload(
        self: *Self,
        allocator: Allocator,
        address: [20]u8,
        key: u256,
        db: Database,
    ) !std.meta.Tuple(&.{ u256, bool }) {
        // Retrieve the account pointer or return an error if missing.
        const account = try self.getAccount(address);

        // Attempt to get the storage entry.
        return if (account.storage.getEntry(key)) |occ|
            .{ occ.value_ptr.*.present_value, false }
        else blk: {
            // Load the storage value or use '0' if the account is newly created.
            const value = if (account.isCreated()) 0 else try db.storage(address, key);

            // Append the storage change to the journal.
            try (try self.getLastJournalEntry()).append(
                allocator,
                .{ .StorageChange = .{
                    .address = address,
                    .key = key,
                    .had_value = null,
                } },
            );

            // Insert the storage slot into the account.
            try account.storage.put(key, StorageSlot.init(value));

            break :blk .{ value, true };
        };
    }

    /// Stores a storage slot value and returns (original, present, new, is_cold) tuple.
    ///
    /// # Arguments
    /// - `self`: The JournaledState instance.
    /// - `allocator`: The allocator used for memory allocation.
    /// - `address`: A 20-byte array representing the address of the account.
    /// - `key`: The key of the storage slot.
    /// - `new`: The new value to be stored in the storage slot.
    /// - `db`: The database for retrieving storage information.
    ///
    /// # Returns
    /// A tuple containing the original, present, and new values of the storage slot,
    /// along with a boolean indicating if the value was cold loaded.
    ///
    /// # Errors
    /// May return an error if the account is missing or if storage retrieval fails.
    pub fn sstore(
        self: *Self,
        allocator: Allocator,
        address: [20]u8,
        key: u256,
        new: u256,
        db: Database,
    ) !std.meta.Tuple(&.{ u256, u256, u256, bool }) {
        // Load the storage slot using the 'sload' function.
        const load = try self.sload(allocator, address, key, db);

        // Retrieve the account pointer or return an error if missing.
        const account = try self.getAccount(address);

        // Retrieve the storage slot pointer or return an error if missing.
        const slot = account.storage.getPtr(key) orelse return error.StorageSlotIsMissing;

        // If the new value is the same as the present, no further action is needed.
        if (load[0] == new) return .{ slot.previous_or_original_value, load[0], new, load[1] };

        // Append the storage change to the journal.
        try (try self.getLastJournalEntry()).append(
            allocator,
            .{ .StorageChange = .{
                .address = address,
                .key = key,
                .had_value = load[0],
            } },
        );

        // Update the present value of the storage slot.
        slot.present_value = new;

        // Return the original, present, new values, and the 'is_cold' flag.
        return .{ slot.previous_or_original_value, load[0], new, load[1] };
    }

    /// Frees the resources owned by this instance.
    pub fn deinit(self: *Self) void {
        self.state.deinit();
        self.transient_storage.deinit();
        self.logs.deinit();
        self.journal.deinit();
        self.precompile_addresses.deinit();
    }

    pub fn deinitJournal(self: *Self, allocator: Allocator) void {
        for (self.journal.items) |*v| {
            v.deinit(allocator);
        }
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
    const code = Bytecode.newChecked(buf[0..], 3);

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
        Utils.keccak256(code.originalBytes()),
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

test "JournaledState: tsore should store transient storage tied to the account with new equal to zero" {
    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Initialize an ArrayList for precompile addresses and defer its deinitialization.
    var precompile_addresses = std.ArrayList([20]u8).init(std.testing.allocator);
    defer precompile_addresses.deinit();

    // Append the zero-filled address to the precompile addresses ArrayList.
    try precompile_addresses.append(address);

    // Create a new JournaledState instance for testing with a specific arrow type and precompile addresses.
    var journal_state = try JournaledState.init(
        std.testing.allocator,
        .ARROW_GLACIER,
        precompile_addresses,
    );
    defer journal_state.deinit();

    // Put a new 'not-existing' account into the state at the given address.
    try journal_state.state.put(address, try Account.newNotExisting(std.testing.allocator));

    // Initialize an unmanaged ArrayList for the journal entry and defer its deinitialization.
    var journal_entry = std.ArrayListUnmanaged(JournalEntry){};
    defer journal_entry.deinit(std.testing.allocator);

    // Append an account touch event to the journal entry.
    try journal_entry.append(std.testing.allocator, .{ .AccountTouched = .{ .address = address } });

    // Append the journal entry to the journal state's journal.
    try journal_state.journal.append(journal_entry);

    // Put a value (111) in transient storage at a specific address and key.
    try journal_state.transient_storage.put(.{ address, 10 }, 111);

    // Call the tstore function with the address, key (10), and new value (0).
    try journal_state.tstore(std.testing.allocator, address, 10, 0);

    // Assert that the count of transient storage is 0 after the operation.
    try expectEqual(@as(usize, 0), journal_state.transient_storage.count());

    // Construct an expected journal state with an account touch event and a transient storage change event.
    const expected_journal = [_]JournalEntry{
        .{ .AccountTouched = .{ .address = [_]u8{0x00} ** 20 } },
        .{ .TransientStorageChange = .{ .address = [_]u8{0x00} ** 20, .key = 10, .had_value = 111 } },
    };

    // Assert that the actual journal state matches the expected journal state.
    try expectEqualSlices(JournalEntry, &expected_journal, journal_state.journal.items[0].items);
}

test "JournaledState: tsore should store transient storage tied to the account with new not equal to zero" {
    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Initialize an ArrayList for precompile addresses and defer its deinitialization.
    var precompile_addresses = std.ArrayList([20]u8).init(std.testing.allocator);
    defer precompile_addresses.deinit();

    // Append the zero-filled address to the precompile addresses ArrayList.
    try precompile_addresses.append(address);

    // Create a new JournaledState instance for testing with a specific arrow type and precompile addresses.
    var journal_state = try JournaledState.init(
        std.testing.allocator,
        .ARROW_GLACIER,
        precompile_addresses,
    );
    defer journal_state.deinit();

    // Put a new 'not-existing' account into the state at the given address.
    try journal_state.state.put(address, try Account.newNotExisting(std.testing.allocator));

    // Initialize an unmanaged ArrayList for the journal entry and defer its deinitialization.
    var journal_entry = std.ArrayListUnmanaged(JournalEntry){};
    defer journal_entry.deinit(std.testing.allocator);

    // Append an account touch event to the journal entry.
    try journal_entry.append(std.testing.allocator, .{ .AccountTouched = .{ .address = address } });

    // Append the journal entry to the journal state's journal.
    try journal_state.journal.append(journal_entry);

    // Put a value (111) in transient storage at a specific address and key.
    try journal_state.transient_storage.put(.{ address, 10 }, 111);

    // Call the tstore function with the address, key (10), and new value (23).
    try journal_state.tstore(std.testing.allocator, address, 10, 23);

    // Assert that the count of transient storage is 1 after the operation.
    try expectEqual(@as(usize, 1), journal_state.transient_storage.count());

    // Assert that the value in transient storage at the given address and key is 23.
    try expectEqual(
        @as(u256, 23),
        journal_state.transient_storage.get(.{ address, 10 }).?,
    );

    // Construct an expected journal state with an account touch event and a transient storage change event.
    const expected_journal = [_]JournalEntry{
        .{ .AccountTouched = .{ .address = [_]u8{0x00} ** 20 } },
        .{ .TransientStorageChange = .{ .address = [_]u8{0x00} ** 20, .key = 10, .had_value = 111 } },
    };

    // Assert that the actual journal state matches the expected journal state.
    try expectEqualSlices(JournalEntry, &expected_journal, journal_state.journal.items[0].items);
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
        .code = Bytecode.init(std.testing.allocator),
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
        .code = Bytecode.init(std.testing.allocator),
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
    try expect(load_code[0].info.code.?.eql(Bytecode.init(std.testing.allocator)));

    // Assert that the loaded code is initialized, indicating the code was created.
    try expect(load_code[1]);
}

test "JournaledState: sload should load storage slot and return slot value and true if vacant entry" {
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

    // Put a new 'not-existing' account into the state at the given address.
    try journal_state.state.put(address, try Account.newNotExisting(std.testing.allocator));

    // Initialize an unmanaged ArrayList for the journal entry and defer its deinitialization.
    var journal_entry = std.ArrayListUnmanaged(JournalEntry){};
    defer journal_entry.deinit(std.testing.allocator);

    // Append an account touch event to the journal entry.
    try journal_entry.append(std.testing.allocator, .{ .AccountTouched = .{ .address = address } });

    // Append the journal entry to the journal state's journal.
    try journal_state.journal.append(journal_entry);

    // Load the storage slot using the 'sload' function.
    const res = try journal_state.sload(std.testing.allocator, address, 10, db);

    // Ensure the loaded storage value and true is returned for a vacant entry.
    try expectEqual(
        @as(
            std.meta.Tuple(&.{ u256, bool }),
            .{ 0, true },
        ),
        res,
    );

    // Define the expected journal entries.
    const expected_journal = [_]JournalEntry{
        .{ .AccountTouched = .{ .address = [_]u8{0x00} ** 20 } },
        .{ .StorageChange = .{ .address = address, .key = 10, .had_value = null } },
    };

    // Ensure that the actual journal entry matches the expected journal entry.
    try expectEqualSlices(JournalEntry, &expected_journal, journal_state.journal.items[0].items);

    // Get the account at the specified address.
    const account = (try journal_state.getAccount(address));
    defer account.deinit();

    // Ensure that the retrieved account's storage at key 10 matches the expected StorageSlot.
    try expectEqual(
        StorageSlot{
            .previous_or_original_value = 0,
            .present_value = 0,
        },
        account.storage.get(10).?,
    );
}

test "JournaledState: sstore should store a storage slot value and return a tuple" {
    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Initialize an empty database.
    const db = Database.initEmpty();

    // Initialize an ArrayList for precompile addresses and defer its deinitialization.
    var precompile_addresses = std.ArrayList([20]u8).init(std.testing.allocator);
    defer precompile_addresses.deinit();

    // Append the zero-filled address to the precompile addresses ArrayList.
    try precompile_addresses.append(address);

    // Create a new JournaledState instance for testing with a specific arrow type and precompile addresses.
    var journal_state = try JournaledState.init(
        std.testing.allocator,
        .ARROW_GLACIER,
        precompile_addresses,
    );
    defer journal_state.deinit();

    // Put a new 'not-existing' account into the state at the given address.
    try journal_state.state.put(address, try Account.newNotExisting(std.testing.allocator));

    // Initialize an unmanaged ArrayList for the journal entry and defer its deinitialization.
    var journal_entry = std.ArrayListUnmanaged(JournalEntry){};
    defer journal_entry.deinit(std.testing.allocator);

    // Append an account touch event to the journal entry.
    try journal_entry.append(std.testing.allocator, .{ .AccountTouched = .{ .address = address } });

    // Append the journal entry to the journal state's journal.
    try journal_state.journal.append(journal_entry);

    // Store the value '111' in the storage slot using the 'sstore' function.
    const res = try journal_state.sstore(std.testing.allocator, address, 10, 111, db);

    // Retrieve the account pointer for the given address and defer its deinitialization.
    const account = (try journal_state.getAccount(address));
    defer account.deinit();

    // Ensure that the expected tuple is returned from the 'sstore' function.
    try expectEqual(
        @as(
            std.meta.Tuple(&.{ u256, u256, u256, bool }),
            .{ 0, 0, 111, true },
        ),
        res,
    );

    // Define the expected journal entries after the storage change.
    const expected_journal = [_]JournalEntry{
        .{ .AccountTouched = .{ .address = [_]u8{0x00} ** 20 } },
        .{ .StorageChange = .{ .address = address, .key = 10, .had_value = null } },
        .{ .StorageChange = .{ .address = address, .key = 10, .had_value = 0 } },
    };

    // Ensure that the actual journal entry matches the expected journal entry.
    try expectEqualSlices(JournalEntry, &expected_journal, journal_state.journal.items[0].items);

    // Ensure that the storage slot value has been updated as expected.
    try expectEqual(
        StorageSlot{
            .previous_or_original_value = 0,
            .present_value = 111,
        },
        account.storage.get(10).?,
    );
}

test "JournaledState: journalRevert for AccountLoaded" {
    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Initialize an ArrayList for precompile addresses and defer its deinitialization.
    var precompile_addresses = std.ArrayList([20]u8).init(std.testing.allocator);
    defer precompile_addresses.deinit();

    // Append the zero-filled address to the precompile addresses ArrayList.
    try precompile_addresses.append(address);

    // Create a new JournaledState instance for testing with a specific arrow type and precompile addresses.
    var journal_state = try JournaledState.init(
        std.testing.allocator,
        .ARROW_GLACIER,
        precompile_addresses,
    );
    defer journal_state.deinit();

    // Put a new 'not-existing' account into the state at the given address.
    try journal_state.state.put(address, try Account.newNotExisting(std.testing.allocator));

    // Initialize an unmanaged ArrayList for the journal entry and defer its deinitialization.
    var journal_entry = std.ArrayListUnmanaged(JournalEntry){};
    defer journal_entry.deinit(std.testing.allocator);

    // Append an account touch event to the journal entry.
    try journal_entry.append(std.testing.allocator, .{ .AccountLoaded = .{ .address = address } });

    // Invoke the `journalRevert` function to revert the changes made by the journal entry.
    try JournaledState.journalRevert(
        &journal_state.state, // Blockchain state pointer.
        &journal_state.transient_storage, // Transient storage pointer.
        journal_entry, // Journal entry containing the AccountLoaded event.
        false, // Flag indicating Spurious Dragon is disabled.
    );

    // Assert that the state does not contain the previously added address after the revert operation.
    try expect(!journal_state.state.contains(address));

    // TODO: Add a larger set of unit tests to cover all `JournalEntry` configurations
}

test "JournaledState: checkpointRevert should revert changes to a previously created checkpoint" {
    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Create a new JournaledState instance for testing with specific configurations.
    var journal_state = try JournaledState.init(std.testing.allocator, .ARROW_GLACIER, std.ArrayList([20]u8).init(std.testing.allocator));
    defer journal_state.deinit(); // Defer the deinitialization of the journal state.

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
    try expect(journal_state.depth == 0); // Assert the initial depth state.

    // Create a checkpoint in the journal state.
    const checkpoint = try journal_state.addCheckpoint(); // Create a checkpoint.

    // Assert the depth after creating the checkpoint.
    try expect(journal_state.depth == 1);
    // Assert the length of journal items after creating the checkpoint.
    try expect(journal_state.journal.items.len == 6);

    // Revert changes using the checkpoint.
    try journal_state.checkpointRevert(checkpoint);

    // Assert the depth after reverting the checkpoint.
    try expect(journal_state.depth == 0);
    // Assert the length of log items after reverting the checkpoint.
    try expect(journal_state.logs.items.len == 10);
    // Assert the length of journal items after reverting the checkpoint.
    try expect(journal_state.journal.items.len == 5);
}

test "JournaledState: selfDestruct should perform a selfdestruct action" {
    // Create a 20-byte address filled with zeros.
    const address = [_]u8{0x00} ** 20;

    // Create a distinct 20-byte target address filled with ones.
    const target_address = [_]u8{0x01} ** 20;

    // Initialize an empty database for testing.
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

    // Put 'not-existing' accounts into the state at given addresses for testing.
    try journal_state.state.put(address, try Account.newNotExisting(std.testing.allocator));
    try journal_state.state.put(target_address, try Account.newNotExisting(std.testing.allocator));

    // Initialize an unmanaged ArrayList for the journal entry and defer its deinitialization.
    var journal_entry = std.ArrayListUnmanaged(JournalEntry){};
    defer journal_entry.deinit(std.testing.allocator);

    // Append an account touch event to the journal entry for the initiating address.
    try journal_entry.append(std.testing.allocator, .{ .AccountTouched = .{ .address = address } });

    // Append the journal entry to the journal state's journal.
    try journal_state.journal.append(journal_entry);

    // Set a balance of 54 for the initiating account.
    journal_state.state.getPtr(address).?.info.balance = 54;

    // Verify that the initiating account's balance equals 54.
    try expect(journal_state.state.getPtr(address).?.info.balance == 54);

    // Perform the self-destruct action.
    const res = try journal_state.selfDestruct(std.testing.allocator, address, target_address, db);

    // Verify the outcome of the self-destruct action matches the expected result.
    try expectEqual(
        SelfDestructResult{
            .had_value = true,
            .target_exists = false,
            .is_cold = false,
            .previously_destroyed = false,
        },
        res,
    );

    // Verify that the initiating account is marked as self-destructed.
    try expect(journal_state.state.getPtr(address).?.isSelfdestructed());

    // Verify that the initiating account's balance is now 0 after the self-destruct action.
    try expect(journal_state.state.getPtr(address).?.info.balance == 0);

    // Define the expected journal entries reflecting the performed actions.
    const expected_journal = [_]JournalEntry{
        .{ .AccountTouched = .{ .address = [_]u8{0x00} ** 20 } },
        .{ .AccountTouched = .{ .address = [_]u8{0x01} ** 20 } },
        .{ .AccountDestroyed = .{
            .address = address,
            .target = target_address,
            .was_destroyed = false,
            .had_balance = 54,
        } },
    };

    // Verify that the recorded journal matches the expected journal entries.
    try expectEqualSlices(JournalEntry, &expected_journal, journal_state.journal.items[0].items);
}
