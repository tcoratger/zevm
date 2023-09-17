const std = @import("std");
const bytecode = @import("./bytecode.zig");
const constants = @import("./constants.zig");
const bits = @import("./bits.zig");

test "Bytecode: new_raw function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try std.testing.expect(bytecode.Bytecode.eql(bytecode.Bytecode.new_raw(buf[0..]), bytecode.Bytecode{ .bytecode = buf[0..], .state = bytecode.BytecodeState.Raw }));
}

test "Bytecode: new_checked function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try std.testing.expectEqual(bytecode.Bytecode.new_checked(buf[0..], 10).bytecode, buf[0..]);
    try std.testing.expectEqual(bytecode.Bytecode.new_checked(buf[0..], 10).state, bytecode.BytecodeState{ .Checked = .{ .len = 10 } });

    try std.testing.expect(bytecode.Bytecode.eql(bytecode.Bytecode.new_checked(buf[0..], 10), bytecode.Bytecode{
        .bytecode = buf[0..],
        .state = bytecode.BytecodeState{ .Checked = .{ .len = 10 } },
    }));
}

test "Bytecode: bytes function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    var x = bytecode.Bytecode.new_checked(buf[0..], 10);
    try std.testing.expectEqual(x.bytes(), buf[0..]);
}

test "Bytecode: original_bytes function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try std.testing.expectEqual(bytecode.Bytecode.new_checked(buf[0..], 3).original_bytes(), buf[0..3]);
    try std.testing.expectEqual(bytecode.Bytecode.new_raw(buf[0..]).original_bytes(), buf[0..]);
}

test "Bytecode: state function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try std.testing.expectEqual(bytecode.Bytecode.state(bytecode.Bytecode.new_checked(buf[0..], 3)), bytecode.BytecodeState{ .Checked = .{ .len = 3 } });
    try std.testing.expectEqual(bytecode.Bytecode.state(bytecode.Bytecode.new_raw(buf[0..])), bytecode.BytecodeState.Raw);
}

test "Bytecode: is_empty function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try std.testing.expect(!bytecode.Bytecode.is_empty(bytecode.Bytecode.new_checked(buf[0..], 3)));
    try std.testing.expect(bytecode.Bytecode.is_empty(bytecode.Bytecode.new_raw(buf[0..0])));
    try std.testing.expect(!bytecode.Bytecode.is_empty(bytecode.Bytecode.new_raw(buf[0..])));
}

test "Bytecode: len function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try std.testing.expectEqual(bytecode.Bytecode.get_len(bytecode.Bytecode.new_checked(buf[0..], 3)), 3);
    try std.testing.expectEqual(bytecode.Bytecode.get_len(bytecode.Bytecode.new_raw(buf[0..0])), 0);
    try std.testing.expectEqual(bytecode.Bytecode.get_len(bytecode.Bytecode.new_raw(buf[0..])), 5);
}

test "Bytecode: to_check function" {
    var buf: [5]u8 = .{ 0, 1, 2, 3, 4 };
    var expected_buf: [38]u8 = .{ 0, 1, 2, 3, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

    var check = try bytecode.Bytecode.new_raw(buf[0..]).to_check(std.testing.allocator);
    defer std.mem.Allocator.free(std.testing.allocator, check.bytecode);
    try std.testing.expect(bytecode.Bytecode.eql(check, bytecode.Bytecode.new_checked(expected_buf[0..], 5)));
}

test "Bytecode: hash_slow function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try std.testing.expectEqual(bytecode.Bytecode.new_raw(buf[0..0]).hash_slow(), constants.Constants.KECCAK_EMPTY);
    const expected_hash = bits.B256{ .bytes = [32]u8{ 125, 135, 197, 234, 117, 247, 55, 139, 183, 1, 228, 4, 197, 6, 57, 22, 26, 243, 239, 246, 98, 147, 233, 243, 117, 181, 241, 126, 181, 4, 118, 244 } };
    try std.testing.expectEqual(bytecode.Bytecode.new_raw(buf[0..]).hash_slow(), expected_hash);
}
