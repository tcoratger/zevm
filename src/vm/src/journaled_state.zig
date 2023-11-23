const std = @import("std");
const State = @import("../../primitives/primitives.zig").State;
const TransientStorage = @import("../../primitives/primitives.zig").TransientStorage;
const Log = @import("../../primitives/primitives.zig").Log;
const SpecId = @import("../../primitives/primitives.zig").SpecId;

pub const JournaledState = struct {
    const Self = @This();

    /// Current state.
    state: State,
    /// EIP 1153 transient storage
    transient_storage: TransientStorage,
    /// logs
    log: Log,
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
