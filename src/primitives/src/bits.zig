const std = @import("std");
const utils = @import("./utils.zig");
const constants = @import("./constants.zig");

const expect = std.testing.expect;

/// zevm 256 bits type.
pub const B256 = struct {
    const Self = @This();

    bytes: [32]u8,

    /// Returns a new zero-initialized fixed hash.
    pub fn zero() Self {
        return .{ .bytes = [_]u8{0} ** 32 };
    }

    /// Returns true if no bits are set.
    pub fn is_zero(self: Self) bool {
        return self.eql(Self.zero());
    }

    pub fn serialize(self: Self) ![]const u8 {
        var slice = [_]u8{0} ** (2 + 2 * 32);
        return Serialize.serialize_raw(&slice, &self.bytes);
    }

    pub fn eql(self: Self, other: Self) bool {
        return std.mem.eql(u8, &self.bytes, &other.bytes);
    }

    /// Create a new fixed-hash from big number.
    pub fn from(fr: u256, allocator: std.mem.Allocator) !Self {
        var fr_bytes = std.ArrayList(u8).init(allocator);
        defer fr_bytes.deinit();
        try fr_bytes.appendNTimes(0, 32 - 8 * 4);

        var buf: [32]u8 = [_]u8{0} ** 32;

        std.mem.writeInt(
            u256,
            &buf,
            fr,
            .big,
        );
        try fr_bytes.appendSlice(&buf);

        return .{ .bytes = fr_bytes.items[0..32].* };
    }

    /// Extracts a byte slice containing the entire fixed hash.
    pub fn as_bytes(self: *Self) *[32]u8 {
        return &self.bytes;
    }

    /// Create a new fixed-hash from the given slice src.
    ///
    /// ## Note
    /// The given bytes are interpreted in big endian order.
    ///
    /// ## Panic
    /// If the length of src and the number of bytes in Self do not match.
    pub fn from_slice(src: *[]u8) Self {
        std.debug.assert(src.len == 32);
        return .{ .bytes = src.*[0..32].* };
    }
};

/// zevm 256 bits type.
pub const B160 = struct {
    const Self = @This();
    pub const bytes_len: usize = 20;

    bytes: [bytes_len]u8,

    /// Returns a new zero-initialized fixed hash.
    pub fn zero() Self {
        return .{ .bytes = [_]u8{0} ** 20 };
    }

    /// Returns true if no bits are set.
    pub fn is_zero(self: Self) bool {
        return self.eql(Self.zero());
    }

    /// Create a new fixed-hash from u64.
    pub fn from(fr: u64) Self {
        // Big endian byte order
        return .{ .bytes = [bytes_len]u8{
            0,                           0,                           0,                           0,                           0,                           0,                           0,                          0,                   0, 0, 0, 0,
            @intCast((fr >> 56) & 0xFF), @intCast((fr >> 48) & 0xFF), @intCast((fr >> 40) & 0xFF), @intCast((fr >> 32) & 0xFF), @intCast((fr >> 24) & 0xFF), @intCast((fr >> 16) & 0xFF), @intCast((fr >> 8) & 0xFF), @intCast(fr & 0xFF),
        } };
    }

    pub fn eql(self: Self, other: Self) bool {
        return std.mem.eql(u8, &self.bytes, &other.bytes);
    }

    /// Extracts a byte slice containing the entire fixed hash.
    pub fn as_bytes(self: *Self) *[20]u8 {
        return &self.bytes;
    }

    /// Create a new fixed-hash from the given slice src.
    ///
    /// ## Note
    /// The given bytes are interpreted in big endian order.
    ///
    /// ## Panic
    /// If the length of src and the number of bytes in Self do not match.
    pub fn from_slice(src: *[]u8) Self {
        std.debug.assert(src.len == 20);
        return .{ .bytes = src.*[0..20].* };
    }
};

pub const Serialize = struct {
    const CHARS = "0123456789abcdef";

    pub fn to_hex_raw(v: []u8, bytes: []const u8, skip_leading_zero: bool) ![]const u8 {
        std.debug.assert(v.len > 2 + bytes.len * 2);

        v[0] = '0';
        v[1] = 'x';

        var idx: usize = 2;
        var first_nibble: u8 = bytes[0] >> 4;

        if (first_nibble != 0 or !skip_leading_zero) {
            v[idx] = CHARS[@as(usize, first_nibble)];
            idx += 1;
        }

        v[idx] = CHARS[@as(usize, bytes[0] & 0xf)];
        idx += 1;

        for (bytes[1..]) |byte| {
            v[idx] = CHARS[@as(usize, byte >> 4)];
            v[idx + 1] = CHARS[@as(usize, byte & 0xf)];
            idx += 2;
        }

        return v[0..idx];
    }

    /// Serializes a slice of bytes.
    pub fn serialize_raw(slice: []u8, bytes: []const u8) ![]const u8 {
        if (bytes.len == 0) {
            return "0x";
        } else {
            return Serialize.to_hex_raw(slice, bytes, false);
        }
    }
};

test "B256: zero function" {
    try expect(B256.zero().eql(B256{ .bytes = [_]u8{0} ** 32 }));
    try expect(B256.zero().is_zero());
}

test "B256: from_slice function" {
    var src = [_]u8{0} ** (32);
    var slice: []u8 = src[0..src.len];
    try expect(B256.from_slice(&slice).is_zero());
}

test "B256: as_bytes function" {
    var b = B256.zero();
    try expect(std.mem.eql(u8, b.as_bytes(), &[_]u8{0} ** 32));
}

test "B256: from function" {
    try expect(
        (try B256.from(1000000000, std.testing.allocator)).eql(.{ .bytes = [32]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 59, 154, 202, 0 } }),
    );

    try expect(
        (try B256.from(constants.Constants.UINT_256_MAX, std.testing.allocator)).eql(.{ .bytes = [32]u8{ 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 } }),
    );
}

test "B160: as_bytes function" {
    var b = B160.zero();
    try expect(std.mem.eql(u8, b.as_bytes(), &[_]u8{0} ** 20));
}

test "B160: from_slice function" {
    var src = [_]u8{0} ** (20);
    var slice: []u8 = src[0..src.len];
    try expect(B160.from_slice(&slice).is_zero());
}

test "B160: zero function" {
    try expect(B160.zero().eql(B160{ .bytes = [_]u8{0} ** 20 }));
    try expect(B160.zero().is_zero());
}

test "B160: from u64 function" {
    try expect(B160.from(34353535).eql(B160{ .bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 12, 49, 127 } }));
    try expect(B160.from(11111111).eql(B160{ .bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 169, 138, 199 } }));
    try expect(B160.from(0).eql(B160{ .bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } }));
    try expect(B160.from(std.math.maxInt(u64)).eql(B160{ .bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255 } }));
}
