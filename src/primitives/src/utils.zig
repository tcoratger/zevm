const std = @import("std");
const bits = @import("./bits.zig");
const constants = @import("./constants.zig");

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

pub fn BigIntContext(comptime K: type) type {
    return struct {
        pub fn hash(self: @This(), b: u256) u64 {
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

pub fn u8BytesFromU64(from: u64) [8]u8 {
    var result: [8]u8 = undefined;
    inline for (result, 0..) |_, i| {
        result[i] = @intCast((from >> 56 - i * 8) & 0xFF);
    }
    return result;
}

/// Returns the address for the legacy `CREATE` scheme
pub fn createAddress(caller: bits.B160, nonce: u64, allocator: std.mem.Allocator) !bits.B160 {
    var stream = std.ArrayList(u8).init(allocator);
    defer stream.deinit();

    try stream.appendSlice(&caller.bytes);
    for (u8BytesFromU64(nonce)) |b| {
        if (b != 0) {
            try stream.append(b);
        }
    }

    if (nonce >= 0x80) {
        try stream.insert(
            bits.B160.bytes_len,
            @as(
                u8,
                0x80 + @as(
                    u8,
                    @intCast(stream.items.len - bits.B160.bytes_len),
                ),
            ),
        );
    }

    try stream.insert(
        0,
        0x80 + @as(
            u8,
            @intCast(bits.B160.bytes_len),
        ),
    );
    try stream.insert(
        0,
        0xc0 + @as(
            u8,
            @intCast(stream.items.len),
        ),
    );

    return .{ .bytes = keccak256(stream.items).bytes[12..].* };
}

/// Returns the address for the `CREATE2` scheme
pub fn create2Address(
    caller: bits.B160,
    code_hash: bits.B256,
    salt: u256,
    allocator: std.mem.Allocator,
) !bits.B160 {
    var out: [32]u8 = undefined;
    var h = std.crypto.hash.sha3.Keccak256.init(.{});
    h.update(&[1]u8{0xff});
    h.update(&caller.bytes);

    var salt_bytes = std.ArrayList(u8).init(allocator);
    defer salt_bytes.deinit();

    var buf: [32]u8 = [_]u8{0} ** 32;

    std.mem.writeInt(
        u256,
        &buf,
        salt,
        .big,
    );

    try salt_bytes.appendSlice(&buf);

    h.update(salt_bytes.items);
    h.update(&code_hash.bytes);
    h.final(&out);
    return .{ .bytes = out[12..].* };
}

/// Calculates the `excess_blob_gas` from the parent header's `blob_gas_used` and `excess_blob_gas`.
///
/// See also [the EIP-4844 helpers](https://eips.ethereum.org/EIPS/eip-4844#helpers).
pub fn calcExcessBlobGas(parent_excess_blob_gas: u64, parent_blob_gas_used: u64) u64 {
    return (parent_excess_blob_gas + parent_blob_gas_used) -| constants.Constants.TARGET_BLOB_GAS_PER_BLOCK;
}

/// Calculates the blob gasprice from the header's excess blob gas field.
///
/// See also [the EIP-4844 helpers](https://eips.ethereum.org/EIPS/eip-4844#helpers).
pub fn calcBlobGasprice(excess_blob_gas: u64) u64 {
    return fakeExponential(
        constants.Constants.MIN_BLOB_GASPRICE,
        excess_blob_gas,
        constants.Constants.BLOB_GASPRICE_UPDATE_FRACTION,
    );
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
pub fn fakeExponential(factor: u64, numerator: u64, denominator: u64) u64 {
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

test "Utils: keccak256 function" {
    try expectEqual(
        bits.B256{ .bytes = [32]u8{ 121, 72, 47, 147, 234, 13, 113, 78, 41, 51, 102, 50, 41, 34, 150, 42, 243, 142, 205, 217, 92, 255, 100, 131, 85, 193, 175, 75, 64, 167, 139, 50 } },
        keccak256("c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"),
    );
}

test "Utils: createAddress function" {
    try expectEqual(
        bits.B160{ .bytes = [20]u8{ 4, 1, 133, 88, 123, 80, 98, 157, 3, 48, 181, 126, 60, 186, 109, 109, 136, 77, 127, 229 } },
        try createAddress(bits.B160.from(18_446_744_073_709_551_615), 2, std.testing.allocator),
    );

    try expectEqual(
        bits.B160{ .bytes = [20]u8{ 69, 197, 114, 224, 17, 22, 105, 149, 160, 191, 165, 217, 140, 56, 245, 219, 61, 76, 233, 120 } },
        try createAddress(bits.B160.from(1000), 2999999, std.testing.allocator),
    );

    try expectEqual(
        bits.B160{ .bytes = [20]u8{ 0, 21, 103, 35, 151, 52, 174, 173, 234, 33, 2, 60, 42, 124, 13, 155, 185, 174, 74, 249 } },
        try createAddress(bits.B160.from(1), 18_446_744_073_709_551_615, std.testing.allocator),
    );
}

test "Utils: u8BytesFromU64 function" {
    try expectEqual([8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 }, u8BytesFromU64(0));
    try expectEqual([8]u8{ 0, 0, 0, 0, 0, 0, 0, 10 }, u8BytesFromU64(10));
    try expectEqual(
        [8]u8{ 255, 255, 255, 255, 255, 255, 255, 255 },
        u8BytesFromU64(18_446_744_073_709_551_615),
    );
}

test "Utils: create2Address function" {
    try expectEqual(
        bits.B160{ .bytes = [20]u8{ 21, 108, 197, 97, 104, 190, 154, 181, 81, 131, 139, 5, 178, 141, 203, 240, 157, 66, 125, 96 } },
        try create2Address(
            bits.B160.from(18_446_744_073_709_551_615),
            bits.B256{ .bytes = [32]u8{ 121, 72, 47, 147, 234, 13, 113, 78, 41, 51, 102, 50, 41, 34, 150, 42, 243, 142, 205, 217, 92, 255, 100, 131, 85, 193, 175, 75, 64, 167, 139, 50 } },
            10000000000000000000000000000000,
            std.testing.allocator,
        ),
    );

    try expectEqual(
        bits.B160{ .bytes = [20]u8{ 142, 250, 209, 93, 4, 51, 82, 199, 205, 81, 218, 25, 155, 148, 82, 184, 92, 44, 84, 254 } },
        try create2Address(
            bits.B160.from(1000),
            bits.B256{ .bytes = [32]u8{ 121, 72, 47, 147, 234, 13, 113, 78, 41, 51, 102, 50, 41, 34, 150, 42, 243, 142, 205, 217, 92, 255, 100, 131, 85, 193, 175, 75, 64, 167, 139, 50 } },
            10000000000000000000000000000000,
            std.testing.allocator,
        ),
    );
}

test "Utils: fakeExponential function" {
    // https://github.com/ethereum/go-ethereum/blob/28857080d732857030eda80c69b9ba2c8926f221/consensus/misc/eip4844/eip4844_test.go#L78
    try expect(
        fakeExponential(
            1,
            0,
            1,
        ) == 1,
    );
    try expect(
        fakeExponential(
            38493,
            0,
            1000,
        ) == 38493,
    );
    try expect(
        fakeExponential(
            0,
            1234,
            2345,
        ) == 0,
    );
    try expect(
        fakeExponential(
            1,
            2,
            1,
        ) == 6,
    ); // approximate 7.389
    try expect(
        fakeExponential(
            1,
            4,
            2,
        ) == 6,
    );
    try expect(
        fakeExponential(
            1,
            3,
            1,
        ) == 16,
    ); // approximate 20.09
    try expect(
        fakeExponential(
            1,
            6,
            2,
        ) == 18,
    );
    try expect(
        fakeExponential(
            1,
            4,
            1,
        ) == 49,
    ); // approximate 54.60
    try expect(
        fakeExponential(
            1,
            8,
            2,
        ) == 50,
    );
    try expect(
        fakeExponential(
            10,
            8,
            2,
        ) == 542,
    ); // approximate 540.598
    try expect(
        fakeExponential(
            11,
            8,
            2,
        ) == 596,
    ); // approximate 600.58
    try expect(
        fakeExponential(
            1,
            5,
            1,
        ) == 136,
    ); // approximate 148.4
    try expect(
        fakeExponential(
            1,
            5,
            2,
        ) == 11,
    ); // approximate 12.18
    try expect(
        fakeExponential(
            2,
            5,
            2,
        ) == 23,
    ); // approximate 24.36
    try expect(
        fakeExponential(
            1,
            50000000,
            2225652,
        ) == 5709098764,
    );
    try expect(
        fakeExponential(
            1,
            380928,
            constants.Constants.BLOB_GASPRICE_UPDATE_FRACTION,
        ) == 1,
    );
}

test "Utils: calcExcessBlobGas function" {
    // https://github.com/ethereum/go-ethereum/blob/28857080d732857030eda80c69b9ba2c8926f221/consensus/misc/eip4844/eip4844_test.go#L27
    // The excess blob gas should not increase from zero if the used blob slots are below - or equal - to the target.
    try expect(
        calcExcessBlobGas(
            0,
            0 * constants.Constants.GAS_PER_BLOB,
        ) == 0,
    );
    try expect(
        calcExcessBlobGas(
            0,
            1 * constants.Constants.GAS_PER_BLOB,
        ) == 0,
    );
    try expect(
        calcExcessBlobGas(
            0,
            (constants.Constants.TARGET_BLOB_GAS_PER_BLOCK / constants.Constants.GAS_PER_BLOB) * constants.Constants.GAS_PER_BLOB,
        ) == 0,
    );
    // If the target blob gas is exceeded, the excessBlobGas should increase by however much it was overshot
    try expect(
        calcExcessBlobGas(
            0,
            ((constants.Constants.TARGET_BLOB_GAS_PER_BLOCK / constants.Constants.GAS_PER_BLOB) + 1) * constants.Constants.GAS_PER_BLOB,
        ) == constants.Constants.GAS_PER_BLOB,
    );
    try expect(
        calcExcessBlobGas(
            1,
            ((constants.Constants.TARGET_BLOB_GAS_PER_BLOCK / constants.Constants.GAS_PER_BLOB) + 1) * constants.Constants.GAS_PER_BLOB,
        ) == constants.Constants.GAS_PER_BLOB + 1,
    );
    try expect(
        calcExcessBlobGas(
            1,
            ((constants.Constants.TARGET_BLOB_GAS_PER_BLOCK / constants.Constants.GAS_PER_BLOB) + 2) * constants.Constants.GAS_PER_BLOB,
        ) == 2 * constants.Constants.GAS_PER_BLOB + 1,
    );
    // The excess blob gas should decrease by however much the target was under-shot, capped at zero.
    try expect(
        calcExcessBlobGas(
            constants.Constants.TARGET_BLOB_GAS_PER_BLOCK,
            (constants.Constants.TARGET_BLOB_GAS_PER_BLOCK / constants.Constants.GAS_PER_BLOB) * constants.Constants.GAS_PER_BLOB,
        ) == constants.Constants.TARGET_BLOB_GAS_PER_BLOCK,
    );
    try expect(
        calcExcessBlobGas(
            constants.Constants.TARGET_BLOB_GAS_PER_BLOCK,
            ((constants.Constants.TARGET_BLOB_GAS_PER_BLOCK / constants.Constants.GAS_PER_BLOB) - 1) * constants.Constants.GAS_PER_BLOB,
        ) == constants.Constants.TARGET_BLOB_GAS_PER_BLOCK - constants.Constants.GAS_PER_BLOB,
    );
    try expect(
        calcExcessBlobGas(
            constants.Constants.TARGET_BLOB_GAS_PER_BLOCK,
            ((constants.Constants.TARGET_BLOB_GAS_PER_BLOCK / constants.Constants.GAS_PER_BLOB) - 2) * constants.Constants.GAS_PER_BLOB,
        ) == constants.Constants.TARGET_BLOB_GAS_PER_BLOCK - (2 * constants.Constants.GAS_PER_BLOB),
    );
    try expect(
        calcExcessBlobGas(
            constants.Constants.GAS_PER_BLOB - 1,
            ((constants.Constants.TARGET_BLOB_GAS_PER_BLOCK / constants.Constants.GAS_PER_BLOB) - 1) * constants.Constants.GAS_PER_BLOB,
        ) == 0,
    );
}

test "Utils: calcBlobGasprice function" {
    // https://github.com/ethereum/go-ethereum/blob/28857080d732857030eda80c69b9ba2c8926f221/consensus/misc/eip4844/eip4844_test.go#L60

    try expect(calcBlobGasprice(0) == 1);
    try expect(calcBlobGasprice(2314057) == 1);
    try expect(calcBlobGasprice(2314058) == 2);
    try expect(calcBlobGasprice(10 * 1024 * 1024) == 23);
}
