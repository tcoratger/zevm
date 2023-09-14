const std = @import("std");
const bits = @import("./bits.zig");
const bytecode = @import("./bytecode.zig");
const constants = @import("./constants.zig");
const utils = @import("./utils.zig");

pub const StorageSlot = struct {
    original_value: std.math.big.int.Mutable,
    /// When loaded with sload present value is set to original value
    present_value: std.math.big.int.Mutable,
};

pub const Account = struct {
    /// Balance of the account.
    info: AccountInfo,
    /// storage cache
    storage: std.HashMap(std.math.big.int.Mutable, StorageSlot, utils.BigIntContext(std.math.big.int.Mutable), std.hash_map.default_max_load_percentage),
    // Account status flags.
    status: AccountStatus,

    /// Mark account as self destructed.
    pub fn mark_selfdestruct(self: *Account) void {
        self.status.SelfDestructed = true;
    }

    /// Unmark account as self destructed.
    pub fn unmark_selfdestruct(self: *Account) void {
        self.status.SelfDestructed = false;
    }

    /// Is account marked for self destruct.
    pub fn is_selfdestructed(self: *Account) bool {
        return self.status.SelfDestructed;
    }

    /// Mark account as touched
    pub fn mark_touch(self: *Account) void {
        self.status.Touched = true;
    }

    /// Unmark the touch flag.
    pub fn unmark_touch(self: *Account) void {
        self.status.Touched = false;
    }

    /// If account status is marked as touched.
    pub fn is_touched(self: Account) bool {
        return self.status.Touched;
    }

    /// Mark account as newly created.
    pub fn mark_created(self: *Account) void {
        self.status.Created = true;
    }

    /// Unmark created flag.
    pub fn unmark_created(self: *Account) void {
        self.status.Created = false;
    }

    /// If account status is marked as created.
    pub fn is_created(self: Account) bool {
        return self.status.Created;
    }

    /// Is account loaded as not existing from database
    /// This is needed for pre spurious dragon hardforks where
    /// existing and empty were two separate states.
    pub fn is_loaded_as_not_existing(self: Account) bool {
        return self.status.LoadedAsNotExisting;
    }

    /// Is account empty, check if nonce and balance are zero and code is empty.
    pub fn is_empty(self: Account) bool {
        return self.info.is_empty();
    }

    /// Create new account and mark it as non existing.
    pub fn new_not_existing(allocator: std.mem.Allocator) Account {
        var map = std.HashMap(std.math.big.int.Mutable, StorageSlot, utils.BigIntContext(std.math.big.int.Mutable), std.hash_map.default_max_load_percentage).init(allocator);
        defer map.deinit();
        return Account{
            .info = AccountInfo.default(),
            .storage = map,
            .status = AccountStatus{ .Loaded = false, .Created = false, .SelfDestructed = false, .Touched = false, .LoadedAsNotExisting = true },
        };
    }
};

pub const AccountStatus = struct {
    /// When account is loaded but not touched or interacted with.
    /// This is the default state.
    Loaded: bool,
    /// When account is newly created we will not access database
    /// to fetch storage values
    Created: bool,
    /// If account is marked for self destruction.
    SelfDestructed: bool,
    /// Only when account is marked as touched we will save it to database.
    Touched: bool,
    /// used only for pre spurious dragon hardforks where existing and empty were two separate states.
    /// it became same state after EIP-161: State trie clearing
    LoadedAsNotExisting: bool,

    pub fn default() AccountStatus {
        return AccountStatus{ .Loaded = true, .Created = false, .SelfDestructed = false, .Touched = false, .LoadedAsNotExisting = false };
    }
};

/// AccountInfo account information.
pub const AccountInfo = struct {
    pub var limbs: [4]std.math.big.Limb = undefined;
    /// Account balance.
    balance: std.math.big.int.Mutable,
    /// Account nonce.
    nonce: u64,
    /// code hash,
    code_hash: bits.B256,
    /// code: if None, `code_by_hash` will be used to fetch it if code needs to be loaded from
    /// inside of revm.
    code: utils.Option(bytecode.Bytecode),

    pub fn default() AccountInfo {
        return AccountInfo{ .balance = std.math.big.int.Mutable.init(&AccountInfo.limbs, 0), .nonce = 0, .code_hash = constants.Constants.KECCAK_EMPTY, .code = utils.Option(bytecode.Bytecode){ .Some = bytecode.Bytecode.new() } };
    }

    pub fn eq(self: AccountInfo, other: AccountInfo) bool {
        return self.balance.toConst().eql(other.balance.toConst()) and self.nonce == other.nonce and self.code_hash.eql(other.code_hash);
    }

    pub fn new(balance: std.math.big.int.Mutable, nonce: u64, code_hash: bits.B256, code: bytecode.Bytecode) AccountInfo {
        return AccountInfo{ .balance = balance, .nonce = nonce, .code_hash = code_hash, .code = utils.Option(bytecode.Bytecode){ .Some = code } };
    }

    pub fn is_empty(self: AccountInfo) bool {
        return self.balance.eqlZero() and self.nonce == 0 and (self.code_hash.eql(constants.Constants.KECCAK_EMPTY) or self.code_hash.eql(bits.B256.zero()));
    }

    pub fn exists(self: AccountInfo) bool {
        return !self.is_empty();
    }

    /// Return bytecode hash associated with this account.
    /// If account does not have code, it return's `KECCAK_EMPTY` hash.
    pub fn get_code_hash(self: AccountInfo) bits.B256 {
        return self.code_hash;
    }

    /// Take bytecode from account. Code will be set to None.
    pub fn take_bytecode(self: *AccountInfo) utils.Option(bytecode.Bytecode) {
        const y = self.code;
        self.code = utils.Option(bytecode.Bytecode){ .None = true };
        return y;
    }

    pub fn from_balance(balance: std.math.big.int.Mutable) AccountInfo {
        return AccountInfo{ .balance = balance, .nonce = 0, .code_hash = constants.Constants.KECCAK_EMPTY, .code = utils.Option(bytecode.Bytecode){ .Some = bytecode.Bytecode.new() } };
    }
};
