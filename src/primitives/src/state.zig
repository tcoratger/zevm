const std = @import("std");
const bits = @import("./bits.zig");
const bytecode = @import("./bytecode.zig");
const constants = @import("./constants.zig");
const utils = @import("./utils.zig");

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
};

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
