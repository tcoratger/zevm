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
    var limbs: [4]std.math.big.Limb = undefined;
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

test "Account: self destruct functions" {
    var map = std.HashMap(std.math.big.int.Mutable, StorageSlot, utils.BigIntContext(std.math.big.int.Mutable), std.hash_map.default_max_load_percentage).init(std.testing.allocator);
    defer map.deinit();
    const big_int_0 = std.math.big.int.Mutable.init(&AccountInfo.limbs, 0);
    try map.put(big_int_0, StorageSlot{ .original_value = big_int_0, .present_value = big_int_0 });

    var account = Account{
        .info = AccountInfo.default(),
        .storage = map,
        .status = AccountStatus.default(),
    };
    account.mark_selfdestruct();
    try std.testing.expectEqual(account.status.SelfDestructed, true);
    try std.testing.expectEqual(account.is_selfdestructed(), true);
    account.unmark_selfdestruct();
    try std.testing.expectEqual(account.status.SelfDestructed, false);
    try std.testing.expectEqual(account.is_selfdestructed(), false);
}

test "Account: touched functions" {
    var map = std.HashMap(std.math.big.int.Mutable, StorageSlot, utils.BigIntContext(std.math.big.int.Mutable), std.hash_map.default_max_load_percentage).init(std.testing.allocator);
    defer map.deinit();
    const big_int_0 = std.math.big.int.Mutable.init(&AccountInfo.limbs, 0);
    try map.put(big_int_0, StorageSlot{ .original_value = big_int_0, .present_value = big_int_0 });

    var account = Account{
        .info = AccountInfo.default(),
        .storage = map,
        .status = AccountStatus.default(),
    };
    account.mark_touch();
    try std.testing.expectEqual(account.status.Touched, true);
    try std.testing.expectEqual(account.is_touched(), true);
    account.unmark_touch();
    try std.testing.expectEqual(account.status.Touched, false);
    try std.testing.expectEqual(account.is_touched(), false);
}

test "Account: created functions" {
    var map = std.HashMap(std.math.big.int.Mutable, StorageSlot, utils.BigIntContext(std.math.big.int.Mutable), std.hash_map.default_max_load_percentage).init(std.testing.allocator);
    defer map.deinit();
    const big_int_0 = std.math.big.int.Mutable.init(&AccountInfo.limbs, 0);
    try map.put(big_int_0, StorageSlot{ .original_value = big_int_0, .present_value = big_int_0 });

    var account = Account{
        .info = AccountInfo.default(),
        .storage = map,
        .status = AccountStatus.default(),
    };
    account.mark_created();
    try std.testing.expectEqual(account.status.Created, true);
    try std.testing.expectEqual(account.is_created(), true);
    account.unmark_created();
    try std.testing.expectEqual(account.status.Created, false);
    try std.testing.expectEqual(account.is_created(), false);
}

test "Account: is_empty function" {
    var map = std.HashMap(std.math.big.int.Mutable, StorageSlot, utils.BigIntContext(std.math.big.int.Mutable), std.hash_map.default_max_load_percentage).init(std.testing.allocator);
    defer map.deinit();
    const big_int_0 = std.math.big.int.Mutable.init(&AccountInfo.limbs, 0);
    try map.put(big_int_0, StorageSlot{ .original_value = big_int_0, .present_value = big_int_0 });

    var account = Account{
        .info = AccountInfo.default(),
        .storage = map,
        .status = AccountStatus.default(),
    };
    try std.testing.expectEqual(account.is_empty(), true);
}

test "Account: new_not_existing function" {
    try std.testing.expectEqual(Account.new_not_existing(std.testing.allocator).status.LoadedAsNotExisting, true);
}

test "AccountStatus: default function" {
    try std.testing.expectEqual(AccountStatus.default().Loaded, true);
}

test "AccountInfo: default function" {
    var lb = [_]usize{ 0, 0, 0, 0 };
    var buf: [1]u8 = .{0};
    try std.testing.expectEqualSlices(usize, AccountInfo.default().balance.limbs, lb[0..]);
    try std.testing.expectEqual(AccountInfo.default().balance.len, 1);
    try std.testing.expectEqual(AccountInfo.default().balance.positive, true);
    try std.testing.expectEqual(AccountInfo.default().nonce, 0);
    try std.testing.expectEqual(AccountInfo.default().code_hash, bits.B256{ .bytes = [32]u8{ 197, 210, 70, 1, 134, 247, 35, 60, 146, 126, 125, 178, 220, 199, 3, 192, 229, 0, 182, 83, 202, 130, 39, 59, 123, 250, 216, 4, 93, 133, 164, 112 } });
    try std.testing.expectEqualSlices(u8, AccountInfo.default().code.Some.bytecode, buf[0..]);
    try std.testing.expectEqual(AccountInfo.default().code.Some.state.Analysed.len, 0);
}

test "AccountInfo: eq function" {
    try std.testing.expectEqual(AccountInfo.eq(AccountInfo.default(), AccountInfo.default()), true);
}

test "AccountInfo: new function" {
    var lb = [_]usize{ 0, 0, 0, 0 };
    var buf: [1]u8 = .{0};
    var accountInfo = AccountInfo.new(std.math.big.int.Mutable.init(&AccountInfo.limbs, 0), 0, constants.Constants.KECCAK_EMPTY, bytecode.Bytecode.new());
    try std.testing.expectEqualSlices(usize, accountInfo.balance.limbs, lb[0..]);
    try std.testing.expectEqual(accountInfo.balance.len, 1);
    try std.testing.expectEqual(accountInfo.balance.positive, true);
    try std.testing.expectEqual(accountInfo.nonce, 0);
    try std.testing.expectEqual(accountInfo.code_hash, constants.Constants.KECCAK_EMPTY);
    try std.testing.expectEqualSlices(u8, accountInfo.code.Some.bytecode, buf[0..]);
    try std.testing.expectEqual(accountInfo.code.Some.state.Analysed.len, 0);
}

test "AccountInfo: is_empty function" {
    try std.testing.expectEqual(AccountInfo.is_empty(AccountInfo.default()), true);
}

test "AccountInfo: exists function" {
    try std.testing.expectEqual(AccountInfo.exists(AccountInfo.default()), false);
}

test "AccountInfo: code_hash function" {
    try std.testing.expectEqual(AccountInfo.default().get_code_hash(), constants.Constants.KECCAK_EMPTY);
}

test "AccountInfo: take_bytecode function" {
    var buf: [1]u8 = .{0};
    var accountInfo = AccountInfo.default();
    var result_take_bytecode = accountInfo.take_bytecode();
    try std.testing.expectEqualSlices(u8, result_take_bytecode.Some.bytecode, buf[0..]);
    try std.testing.expectEqual(result_take_bytecode.Some.state.Analysed.len, 0);
    try std.testing.expectEqual(accountInfo.take_bytecode().None, true);
}

test "AccountInfo: from_balance function" {
    var lb = [_]usize{ 100, 0, 0, 0 };
    var buf: [1]u8 = .{0};
    var balance = std.math.big.int.Mutable.init(&AccountInfo.limbs, 100);

    try std.testing.expectEqualSlices(usize, AccountInfo.from_balance(balance).balance.limbs, lb[0..]);
    try std.testing.expectEqual(AccountInfo.from_balance(balance).balance.len, 1);
    try std.testing.expectEqual(AccountInfo.from_balance(balance).balance.positive, true);
    try std.testing.expectEqual(AccountInfo.from_balance(balance).nonce, 0);
    try std.testing.expectEqual(AccountInfo.from_balance(balance).code_hash, constants.Constants.KECCAK_EMPTY);
    try std.testing.expectEqualSlices(u8, AccountInfo.from_balance(balance).code.Some.bytecode, buf[0..]);
    try std.testing.expectEqual(AccountInfo.from_balance(balance).code.Some.state.Analysed.len, 0);
}
