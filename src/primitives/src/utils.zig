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
    for (u8_bytes_from_u64(nonce)) |b| {
        if (b != 0) {
            try stream.append(b);
        }
    }

    if (nonce >= 0x80) {
        try stream.insert(bits.B160.bytes_len, @as(u8, 0x80 + @as(u8, @intCast(stream.items.len - bits.B160.bytes_len))));
    }

    try stream.insert(0, 0x80 + @as(u8, @intCast(bits.B160.bytes_len)));
    try stream.insert(0, 0xc0 + @as(u8, @intCast(stream.items.len)));

    const slice = try stream.toOwnedSlice();
    defer std.mem.Allocator.free(allocator, slice);

    return bits.B160{ .bytes = keccak256(slice).bytes[12..].* };
}

/// Returns the address for the `CREATE2` scheme
pub fn create2_address(caller: bits.B160, code_hash: bits.B256, salt: std.math.big.int.Managed, allocator: std.mem.Allocator) !bits.B160 {
    var out: [32]u8 = undefined;
    var h = std.crypto.hash.sha3.Keccak256.init(.{});
    h.update(&[1]u8{0xff});
    h.update(&caller.bytes);

    var salt_bytes = std.ArrayList(u8).init(allocator);
    defer salt_bytes.deinit();
    const salt_limbs = salt.toConst().limbs;
    var nbr_limbs = salt_limbs.len;
    try salt_bytes.appendNTimes(0, 8 * (salt.limbs.len - nbr_limbs));
    while (nbr_limbs > 0) : (nbr_limbs -= 1) {
        try salt_bytes.appendSlice(&u8_bytes_from_u64(salt_limbs[nbr_limbs - 1]));
    }
    h.update(salt_bytes.items);
    h.update(&code_hash.bytes);
    h.final(&out);
    return bits.B160{ .bytes = out[12..].* };
}

/// Approximates `factor * e ** (numerator / denominator)` using Taylor expansion.
///
/// This is used to calculate the blob price.
///
/// See also [the EIP-4844 helpers](https://eips.ethereum.org/EIPS/eip-4844#helpers).
///
/// # Panic
///
/// Panics if `denominator` is zero.
pub fn fake_exponential(factor: u64, numerator: u64, denominator: u64) u64 {
    std.debug.assert(denominator != 0);
    const f: u128 = @intCast(factor);
    const n: u128 = @intCast(numerator);
    const d: u128 = @intCast(denominator);

    var i: u128 = 1;
    var output: u128 = 0;
    var numerator_accum = f * d;

    while (numerator_accum > 0) : (i += 1) {
        output += numerator_accum;
        // Denominator is asserted as not zero at the start of the function.
        numerator_accum = (numerator_accum * n) / (d * i);
    }

    return @intCast(output / denominator);
}
