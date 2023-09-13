const std = @import("std");

pub fn Option(comptime T: type) type {
    return union(enum) { None: bool, Some: T };
}

pub fn BigIntContext(comptime K: type) type {
    return struct {
        pub fn hash(self: @This(), b: std.math.big.int.Mutable) u64 {
            _ = b;
            _ = self;
            var hasher = std.hash.Wyhash.init(0);
            return hasher.final();
        }
        pub const eql = std.hash_map.getAutoEqlFn(K, @This());
    };
}
