const std = @import("std");
const bits = @import("./bits.zig");
const constants = @import("./constants.zig");

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

pub fn u8_bytes_from_u64(from: u64) [8]u8 {
    var result: [8]u8 = undefined;
    inline for (result, 0..) |_, i| {
        result[i] = @intCast((from >> 56 - i * 8) & 0xFF);
    }
    return result;
}

/// Returns the address for the legacy `CREATE` scheme
pub fn create_address(caller: bits.B160, nonce: u64, allocator: std.mem.Allocator) !bits.B160 {
    var stream = std.ArrayList(u8).init(allocator);
    defer stream.deinit();

    try stream.appendSlice(&caller.bytes);
    var count_non_zero_nonce_bits: u8 = 0;
    for (u8_bytes_from_u64(nonce)) |b| {
        if (b != 0) {
            count_non_zero_nonce_bits += 1;
            try stream.append(b);
        }
    }

    if (nonce >= 128) {
        try stream.insert(stream.items.len - count_non_zero_nonce_bits, @as(u8, 0x80 + count_non_zero_nonce_bits));
    }

    try stream.insert(0, 0x80 + 20);
    try stream.insert(0, 0xc0 + @as(u8, @intCast(stream.items.len)));

    const slice = try stream.toOwnedSlice();
    defer std.mem.Allocator.free(allocator, slice);

    return bits.B160{ .bytes = keccak256(slice).bytes[12..].* };
}
