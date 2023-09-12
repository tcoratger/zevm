const std = @import("std");
const b256 = @import("./bits.zig");
const bytecode = @import("./bytecode.zig");
const constants = @import("./constants.zig");

/// AccountInfo account information.
pub const AccountInfo = struct {
    var limbs: [4]std.math.big.Limb = undefined;
    /// Account balance.
    balance: std.math.big.int.Mutable,
    /// Account nonce.
    nonce: u64,
    /// code hash,
    code_hash: b256.B256,
    /// code: if None, `code_by_hash` will be used to fetch it if code needs to be loaded from
    /// inside of revm.
    code: bytecode.Bytecode,

    pub fn default() AccountInfo {
        return AccountInfo{ .balance = std.math.big.int.Mutable.init(&AccountInfo.limbs, 0), .nonce = 0, .code_hash = constants.Constants.KECCAK_EMPTY, .code = bytecode.Bytecode.new() };
    }

    pub fn eq(self: AccountInfo, other: AccountInfo) bool {
        return self.balance.toConst().eql(other.balance.toConst()) and self.nonce == other.nonce and self.code_hash.eql(other.code_hash);
    }
};

test "AccountInfo: default function" {
    var lb = [_]usize{ 0, 0, 0, 0 };
    var buf: [1]u8 = .{0};
    try std.testing.expectEqualSlices(usize, AccountInfo.default().balance.limbs, lb[0..]);
    try std.testing.expectEqual(AccountInfo.default().balance.len, 1);
    try std.testing.expectEqual(AccountInfo.default().balance.positive, true);
    try std.testing.expectEqual(AccountInfo.default().nonce, 0);
    try std.testing.expectEqual(AccountInfo.default().code_hash, b256.B256{ .bytes = [32]u8{ 197, 210, 70, 1, 134, 247, 35, 60, 146, 126, 125, 178, 220, 199, 3, 192, 229, 0, 182, 83, 202, 130, 39, 59, 123, 250, 216, 4, 93, 133, 164, 112 } });
    try std.testing.expectEqualSlices(u8, AccountInfo.default().code.bytecode, buf[0..]);
    try std.testing.expectEqual(AccountInfo.default().code.state.Analysed.len, 0);
}

test "AccountInfo: eq function" {
    try std.testing.expectEqual(AccountInfo.eq(AccountInfo.default(), AccountInfo.default()), true);
}
