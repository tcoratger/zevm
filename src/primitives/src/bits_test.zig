const std = @import("std");
const bits = @import("./bits.zig");

test "B256: zero function" {
    try std.testing.expectEqual(bits.B256.zero(), bits.B256{ .bytes = [_]u8{0} ** 32 });
}

test "B160: from u64 function" {
    try std.testing.expectEqual(bits.B160.from(34353535), bits.B160{ .bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 12, 49, 127 } });
    try std.testing.expectEqual(bits.B160.from(11111111), bits.B160{ .bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 169, 138, 199 } });
    try std.testing.expectEqual(bits.B160.from(0), bits.B160{ .bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } });
    try std.testing.expectEqual(bits.B160.from(std.math.maxInt(u64)), bits.B160{ .bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255 } });
}
