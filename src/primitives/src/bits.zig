const std = @import("std");

/// zevm 256 bits type.
pub const B256 = struct {
    bytes: [32]u8,

    pub fn zero() B256 {
        return B256{ .bytes = [_]u8{0} ** 32 };
    }

    pub fn serialize(self: B256) ![]const u8 {
        var slice = [_]u8{0} ** (2 + 2 * 32);
        return Serialize.serialize_raw(&slice, &self.bytes);
    }

    pub fn eql(self: B256, other: B256) bool {
        return std.mem.eql(u8, &self.bytes, &other.bytes);
    }
};

/// zevm 256 bits type.
pub const B160 = struct {
    pub const bytes_len: usize = 20;
    bytes: [bytes_len]u8,

    pub fn from(fr: u64) B160 {
        // Big endian byte order
        return B160{ .bytes = [bytes_len]u8{
            0,                           0,                           0,                           0,                           0,                           0,                           0,                          0,                   0, 0, 0, 0,
            @intCast((fr >> 56) & 0xFF), @intCast((fr >> 48) & 0xFF), @intCast((fr >> 40) & 0xFF), @intCast((fr >> 32) & 0xFF), @intCast((fr >> 24) & 0xFF), @intCast((fr >> 16) & 0xFF), @intCast((fr >> 8) & 0xFF), @intCast(fr & 0xFF),
        } };
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
