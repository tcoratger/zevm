const std = @import("std");
const bits = @import("./bits.zig");
const constants = @import("./constants.zig");

test "B256: zero function" {
    try std.testing.expect(bits.B256.zero().eql(bits.B256{ .bytes = [_]u8{0} ** 32 }));
    try std.testing.expect(bits.B256.zero().is_zero());
}

test "B256: from function" {
    var bigint_mock = try std.math.big.int.Managed.initSet(std.testing.allocator, 1000000000);
    defer bigint_mock.deinit();

    try std.testing.expect((try bits.B256.from(bigint_mock, std.testing.allocator)).eql(bits.B256{ .bytes = [32]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 59, 154, 202, 0 } }));

    var bigint_mock1 = try std.math.big.int.Managed.initSet(std.testing.allocator, constants.Constants.UINT_256_MAX);
    defer bigint_mock1.deinit();

    try std.testing.expect((try bits.B256.from(bigint_mock1, std.testing.allocator)).eql(bits.B256{ .bytes = [32]u8{ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 } }));
}

test "B160: zero function" {
    try std.testing.expect(bits.B160.zero().eql(bits.B160{ .bytes = [_]u8{0} ** 20 }));
    try std.testing.expect(bits.B160.zero().is_zero());
}

test "B160: from u64 function" {
    try std.testing.expect(bits.B160.from(34353535).eql(bits.B160{ .bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 12, 49, 127 } }));
    try std.testing.expect(bits.B160.from(11111111).eql(bits.B160{ .bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 169, 138, 199 } }));
    try std.testing.expect(bits.B160.from(0).eql(bits.B160{ .bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } }));
    try std.testing.expect(bits.B160.from(std.math.maxInt(u64)).eql(bits.B160{ .bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255 } }));
}
