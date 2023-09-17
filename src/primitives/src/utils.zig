const std = @import("std");
const bits = @import("./bits.zig");

pub fn Option(comptime T: type) type {
    return union(enum) { None: bool, Some: T };
}

pub fn BigIntContext(comptime K: type) type {
    return struct {
        pub fn hash(self: @This(), b: std.math.big.int.Managed) u64 {
            _ = b;
            _ = self;
            var hasher = std.hash.Wyhash.init(0);
            return hasher.final();
        }
        pub const eql = std.hash_map.getAutoEqlFn(K, @This());
    };
}

pub fn keccak256(input: []const u8) bits.B256 {
    var out: [32]u8 = undefined;
    std.crypto.hash.sha3.Keccak256.hash(input, &out, .{});
    return bits.B256{ .bytes = out };
}
