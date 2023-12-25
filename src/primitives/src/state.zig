const std = @import("std");
const bits = @import("./bits.zig");
const bytecode = @import("./bytecode.zig");
const constants = @import("./constants.zig");
const utils = @import("./utils.zig");

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

/// EVM State is a mapping from addresses to accounts.
pub const State = std.AutoHashMap(
    [20]u8,
    Account,
);

/// Structure used for EIP-1153 transient storage.
pub const TransientStorage = std.AutoHashMap(
    std.meta.Tuple(&.{ [20]u8, u256 }),
    u256,
);

pub const StorageSlot = struct {
    const Self = @This();

    original_value: u256,
    /// When loaded with sload present value is set to original value
    present_value: u256,

    pub fn init(new_original_value: u256) Self {
        return .{
            .original_value = new_original_value,
            .present_value = new_original_value,
        };
    }

    pub fn set(self: *Self, new_original_value: u256) void {
        self.original_value = new_original_value;
        self.present_value = new_original_value;
    }

    pub fn is_changed(self: *Self) bool {
        return self.original_value == self.present_value;
    }

    pub fn get_original_value(self: Self) u256 {
        return self.original_value;
    }

    pub fn get_present_value(self: Self) u256 {
        return self.present_value;
    }
};

pub const Account = struct {
    const Self = @This();

    /// Balance of the account.
    info: AccountInfo,
    /// storage cache
    // Account status flags.
    storage: std.AutoHashMap(u256, StorageSlot),
    status: AccountStatus,

    /// Mark account as self destructed.
    pub fn mark_selfdestruct(self: *Self) void {
        self.status.SelfDestructed = true;
    }

    /// Unmark account as self destructed.
    pub fn unmark_selfdestruct(self: *Self) void {
        self.status.SelfDestructed = false;
    }

    /// Is account marked for self destruct.
    pub fn is_selfdestructed(self: *Self) bool {
        return self.status.SelfDestructed;
    }

    /// Mark account as touched
    pub fn mark_touch(self: *Self) void {
        self.status.Touched = true;
    }

    /// Unmark the touch flag.
    pub fn unmark_touch(self: *Self) void {
        self.status.Touched = false;
    }

    /// If account status is marked as touched.
    pub fn is_touched(self: *Self) bool {
        return self.status.Touched;
    }

    /// Mark account as newly created.
    pub fn mark_created(self: *Self) void {
        self.status.Created = true;
    }

    /// Unmark created flag.
    pub fn unmark_created(self: *Self) void {
        self.status.Created = false;
    }

    /// If account status is marked as created.
    pub fn is_created(self: *Self) bool {
        return self.status.Created;
    }

    /// Is account loaded as not existing from database
    /// This is needed for pre spurious dragon hardforks where
    /// existing and empty were two separate states.
    pub fn is_loaded_as_not_existing(self: *Self) bool {
        return self.status.LoadedAsNotExisting;
    }

    /// Is account empty, check if nonce and balance are zero and code is empty.
    pub fn is_empty(self: *Self) bool {
        return self.info.is_empty();
    }

    /// Create new account and mark it as non existing.
    pub fn new_not_existing(allocator: std.mem.Allocator) !Self {
        return .{
            .info = try AccountInfo.init(),
            .storage = std.AutoHashMap(
                u256,
                StorageSlot,
            ).init(allocator),
            .status = .{
                .Loaded = false,
                .Created = false,
                .SelfDestructed = false,
                .Touched = false,
                .LoadedAsNotExisting = true,
            },
        };
    }

    /// Frees all associated memory.
    pub fn deinit(self: *Self) void {
        self.storage.deinit();
    }
};

pub const AccountStatus = struct {
    const Self = @This();

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

    pub fn init() Self {
        return .{
            .Loaded = true,
            .Created = false,
            .SelfDestructed = false,
            .Touched = false,
            .LoadedAsNotExisting = false,
        };
    }
};

/// AccountInfo account information.
pub const AccountInfo = struct {
    const Self = @This();

    /// Account balance.
    balance: u256,
    /// Account nonce.
    nonce: u64,
    /// code hash,
    code_hash: bits.B256,
    /// code: if None, `code_by_hash` will be used to fetch it if code needs to be loaded from
    /// inside of revm.
    code: ?bytecode.Bytecode,

    pub fn init() !Self {
        return .{
            .balance = 0,
            .nonce = 0,
            .code_hash = constants.Constants.KECCAK_EMPTY,
            .code = bytecode.Bytecode.new(),
        };
    }

    pub fn eq(self: Self, other: Self) bool {
        return self.balance == other.balance and self.nonce == other.nonce and self.code_hash.eql(other.code_hash);
    }

    pub fn new(
        balance: u256,
        nonce: u64,
        code_hash: bits.B256,
        code: bytecode.Bytecode,
    ) Self {
        return .{
            .balance = balance,
            .nonce = nonce,
            .code_hash = code_hash,
            .code = code,
        };
    }

    pub fn is_empty(self: Self) bool {
        return self.balance == 0 and self.nonce == 0 and (self.code_hash.eql(constants.Constants.KECCAK_EMPTY) or self.code_hash.eql(bits.B256.zero()));
    }

    pub fn exists(self: Self) bool {
        return !self.is_empty();
    }

    /// Return bytecode hash associated with this account.
    /// If account does not have code, it return's `KECCAK_EMPTY` hash.
    pub fn get_code_hash(self: *Self) bits.B256 {
        return self.code_hash;
    }

    /// Take bytecode from account. Code will be set to None.
    pub fn take_bytecode(self: *Self) ?bytecode.Bytecode {
        const y = self.code;
        self.code = null;
        return y;
    }

    pub fn from_balance(balance: u256) Self {
        return .{
            .balance = balance,
            .nonce = 0,
            .code_hash = constants.Constants.KECCAK_EMPTY,
            .code = bytecode.Bytecode.new(),
        };
    }
};

test "State - StorageSlot : init" {
    const storage_slot = StorageSlot.init(0);

    try expectEqual(@as(u256, 0), storage_slot.original_value);
    try expectEqual(@as(u256, 0), storage_slot.present_value);
}

test "State - StorageSlot : set" {
    var storage_slot = StorageSlot.init(0);
    storage_slot.set(2);

    try expectEqual(@as(u256, 2), storage_slot.original_value);
    try expectEqual(@as(u256, 2), storage_slot.present_value);
}

test "State - StorageSlot : is_changed" {
    var storage_slot = StorageSlot.init(0);
    storage_slot.set(2);

    try expect(storage_slot.is_changed());
}

test "State - StorageSlot : get_original_value" {
    var storage_slot = StorageSlot.init(0);
    try expectEqual(@as(u256, 0), storage_slot.get_original_value());

    storage_slot.set(2);
    try expectEqual(@as(u256, 2), storage_slot.get_original_value());
}

test "State - StorageSlot : get_present_value" {
    var storage_slot = StorageSlot.init(0);
    try expectEqual(@as(u256, 0), storage_slot.get_present_value());

    storage_slot.set(2);
    try expectEqual(@as(u256, 2), storage_slot.get_present_value());
}

test "Account: self destruct functions" {
    var map = std.AutoHashMap(u256, StorageSlot).init(std.testing.allocator);

    defer map.deinit();

    try map.put(0, .{ .original_value = 0, .present_value = 0 });

    const default_account = try AccountInfo.init();

    var account = Account{
        .info = default_account,
        .storage = map,
        .status = AccountStatus.init(),
    };
    account.mark_selfdestruct();
    try expect(account.status.SelfDestructed);
    try expect(account.is_selfdestructed());
    account.unmark_selfdestruct();
    try expect(!account.status.SelfDestructed);
    try expect(!account.is_selfdestructed());
}

test "Account: touched functions" {
    var map = std.AutoHashMap(u256, StorageSlot).init(std.testing.allocator);
    defer map.deinit();

    try map.put(0, .{ .original_value = 0, .present_value = 0 });

    const default_account = try AccountInfo.init();

    var account = Account{
        .info = default_account,
        .storage = map,
        .status = AccountStatus.init(),
    };
    account.mark_touch();
    try expect(account.status.Touched);
    try expect(account.is_touched());
    account.unmark_touch();
    try expect(!account.status.Touched);
    try expect(!account.is_touched());
}

test "Account: created functions" {
    var map = std.AutoHashMap(u256, StorageSlot).init(std.testing.allocator);
    defer map.deinit();

    try map.put(0, .{ .original_value = 0, .present_value = 0 });

    const default_account = try AccountInfo.init();

    var account = Account{
        .info = default_account,
        .storage = map,
        .status = AccountStatus.init(),
    };
    account.mark_created();
    try expect(account.status.Created);
    try expect(account.is_created());
    account.unmark_created();
    try expect(!account.status.Created);
    try expect(!account.is_created());
}

test "Account: is_empty function" {
    var map = std.AutoHashMap(u256, StorageSlot).init(std.testing.allocator);
    defer map.deinit();

    try map.put(0, StorageSlot{ .original_value = 0, .present_value = 0 });

    const default_account = try AccountInfo.init();

    var account = Account{
        .info = default_account,
        .storage = map,
        .status = AccountStatus.init(),
    };
    try expect(account.is_empty());
}

test "Account: new_not_existing function" {
    var not_existing = try Account.new_not_existing(std.testing.allocator);
    defer not_existing.deinit();

    try expect(not_existing.status.LoadedAsNotExisting);
}

test "AccountStatus: default function" {
    try expect(AccountStatus.init().Loaded);
}

test "AccountInfo: default function" {
    var buf: [1]u8 = .{0};

    const default_account = try AccountInfo.init();

    try expectEqual(@as(u256, 0), default_account.balance);
    try expectEqual(default_account.nonce, 0);
    try expectEqual(default_account.code_hash, bits.B256{ .bytes = [32]u8{ 197, 210, 70, 1, 134, 247, 35, 60, 146, 126, 125, 178, 220, 199, 3, 192, 229, 0, 182, 83, 202, 130, 39, 59, 123, 250, 216, 4, 93, 133, 164, 112 } });
    try std.testing.expectEqualSlices(u8, default_account.code.?.bytecode, &buf);
    try expectEqual(default_account.code.?.state.Analysed.len, 0);
}

test "AccountInfo: eq function" {
    const default_account = try AccountInfo.init();

    try expect(AccountInfo.eq(default_account, default_account));
}

test "AccountInfo: new function" {
    var buf: [1]u8 = .{0};

    const accountInfo = AccountInfo.new(
        0,
        0,
        constants.Constants.KECCAK_EMPTY,
        bytecode.Bytecode.new(),
    );
    try expectEqual(@as(u256, 0), accountInfo.balance);
    try expectEqual(@as(u64, 0), accountInfo.nonce);
    try expectEqual(constants.Constants.KECCAK_EMPTY, accountInfo.code_hash);
    try std.testing.expectEqualSlices(
        u8,
        &buf,
        accountInfo.code.?.bytecode,
    );
    try expectEqual(
        @as(usize, 0),
        accountInfo.code.?.state.Analysed.len,
    );
}

test "AccountInfo: is_empty function" {
    const default_account = try AccountInfo.init();

    try expect(AccountInfo.is_empty(default_account));
}

test "AccountInfo: exists function" {
    const default_account = try AccountInfo.init();

    try expectEqual(
        false,
        AccountInfo.exists(default_account),
    );
}

test "AccountInfo: code_hash function" {
    var default_account = try AccountInfo.init();

    try expectEqual(
        constants.Constants.KECCAK_EMPTY,
        default_account.get_code_hash(),
    );
}

test "AccountInfo: take_bytecode function" {
    var buf: [1]u8 = .{0};
    const default_account = try AccountInfo.init();

    var accountInfo = default_account;
    const result_take_bytecode = accountInfo.take_bytecode();
    try std.testing.expectEqualSlices(u8, result_take_bytecode.?.bytecode, buf[0..]);
    try expectEqual(@as(usize, 0), result_take_bytecode.?.state.Analysed.len);
    try expectEqual(@as(?bytecode.Bytecode, null), accountInfo.take_bytecode());
}

test "AccountInfo: from_balance function" {
    var buf: [1]u8 = .{0};

    try expectEqual(@as(u256, 100), AccountInfo.from_balance(100).balance);
    try expectEqual(@as(u256, 0), AccountInfo.from_balance(100).nonce);
    try expectEqual(
        constants.Constants.KECCAK_EMPTY,
        AccountInfo.from_balance(100).code_hash,
    );
    try std.testing.expectEqualSlices(
        u8,
        &buf,
        AccountInfo.from_balance(100).code.?.bytecode,
    );
    try expectEqual(
        @as(usize, 0),
        AccountInfo.from_balance(100).code.?.state.Analysed.len,
    );
}
