const std = @import("std");
const utils = @import("./utils.zig");
const constants = @import("./constants.zig");
const bits = @import("./bits.zig");

test "Utils: keccak256 function" {
    try std.testing.expectEqual(utils.keccak256("c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"), bits.B256{ .bytes = [32]u8{ 121, 72, 47, 147, 234, 13, 113, 78, 41, 51, 102, 50, 41, 34, 150, 42, 243, 142, 205, 217, 92, 255, 100, 131, 85, 193, 175, 75, 64, 167, 139, 50 } });
}

test "Utils: create_address function" {
    try std.testing.expectEqual(try utils.create_address(bits.B160.from(18_446_744_073_709_551_615), 2, std.testing.allocator), bits.B160{ .bytes = [20]u8{ 4, 1, 133, 88, 123, 80, 98, 157, 3, 48, 181, 126, 60, 186, 109, 109, 136, 77, 127, 229 } });

    try std.testing.expectEqual(try utils.create_address(bits.B160.from(1000), 2999999, std.testing.allocator), bits.B160{ .bytes = [20]u8{ 69, 197, 114, 224, 17, 22, 105, 149, 160, 191, 165, 217, 140, 56, 245, 219, 61, 76, 233, 120 } });

    try std.testing.expectEqual(try utils.create_address(bits.B160.from(1), 18_446_744_073_709_551_615, std.testing.allocator), bits.B160{ .bytes = [20]u8{ 0, 21, 103, 35, 151, 52, 174, 173, 234, 33, 2, 60, 42, 124, 13, 155, 185, 174, 74, 249 } });
}
