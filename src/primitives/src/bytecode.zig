pub const JumpMap = struct {};
const std = @import("std");
const constants = @import("./constants.zig");
const utils = @import("./utils.zig");
const bits = @import("./bits.zig");

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

/// State of the `Bytecode` analysis.
pub const BytecodeState = union(enum) {
    /// No analysis has been performed.
    Raw,
    /// The bytecode has been checked for validity.
    Checked: struct { len: usize },
    /// The bytecode has been analyzed for valid jump destinations.
    Analysed: struct { len: usize, jump_map: JumpMap },
};

pub const Bytecode = struct {
    const Self = @This();
    bytecode: []u8,
    state: BytecodeState,

    pub fn default() Self {
        return Self.new();
    }

    /// Creates a new `Bytecode` with exactly one STOP opcode.
    pub fn new() Self {
        var buf: [1]u8 = .{0};
        return .{ .bytecode = buf[0..], .state = BytecodeState{ .Analysed = .{ .len = 0, .jump_map = JumpMap{} } } };
    }

    /// Calculate hash of the bytecode.
    pub fn hash_slow(self: Self) bits.B256 {
        return if (self.is_empty()) constants.Constants.KECCAK_EMPTY else utils.keccak256(self.original_bytes());
    }

    /// Creates a new raw `Bytecode`.
    pub fn new_raw(bytecode: []u8) Self {
        return .{ .bytecode = bytecode, .state = BytecodeState.Raw };
    }

    /// Create new checked bytecode
    ///
    /// # Safety
    /// Bytecode need to end with STOP (0x00) opcode as checked bytecode assumes
    /// that it is safe to iterate over bytecode without checking lengths
    pub fn new_checked(bytecode: []u8, len: usize) Self {
        return .{
            .bytecode = bytecode,
            .state = BytecodeState{ .Checked = .{ .len = len } },
        };
    }

    /// Returns a reference to the bytecode.
    pub fn bytes(self: Self) []u8 {
        return self.bytecode;
    }

    /// Returns a reference to the original bytecode.
    pub fn original_bytes(self: Self) []u8 {
        return switch (self.state) {
            .Raw => self.bytecode,
            .Checked => |*item| self.bytecode[0..item.*.len],
            .Analysed => |*item| self.bytecode[0..item.*.len],
        };
    }

    /// Returns the [`BytecodeState`].
    pub fn state(self: Self) BytecodeState {
        return self.state;
    }

    /// Returns whether the bytecode is empty.
    pub fn is_empty(self: Self) bool {
        return switch (self.state) {
            .Raw => self.bytecode.len == 0,
            .Checked => |*item| item.*.len == 0,
            .Analysed => |*item| item.*.len == 0,
        };
    }

    /// Returns the length of the bytecode.
    pub fn get_len(self: Self) usize {
        return switch (self.state) {
            .Raw => self.bytecode.len,
            .Checked => |*item| item.*.len,
            .Analysed => |*item| item.*.len,
        };
    }

    pub fn to_check(self: Self, allocator: std.mem.Allocator) !Self {
        return switch (self.state) {
            .Raw => {
                var padded_bytecode = std.ArrayList(u8).init(allocator);
                defer padded_bytecode.deinit();
                try padded_bytecode.appendSlice(self.bytecode);
                try padded_bytecode.appendNTimes(0, 33);
                return .{ .bytecode = try padded_bytecode.toOwnedSlice(), .state = BytecodeState{ .Checked = .{ .len = self.bytecode.len } } };
            },
            else => self,
        };
    }

    pub fn eql(self: Self, other: Self) bool {
        return std.mem.eql(u8, self.bytecode, other.bytecode) and switch (self.state) {
            .Raw => other.state == BytecodeState.Raw,
            .Checked => {
                return if (other.state == BytecodeState.Checked) self.state.Checked.len == other.state.Checked.len else false;
            },
            .Analysed => {
                return if (other.state == BytecodeState.Analysed) self.state.Analysed.len == other.state.Analysed.len else false;
            },
        };
    }
};

test "Bytecode: new_raw function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try expect(Bytecode.eql(Bytecode.new_raw(buf[0..]), Bytecode{ .bytecode = buf[0..], .state = BytecodeState.Raw }));
}

test "Bytecode: new_checked function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try expectEqual(Bytecode.new_checked(buf[0..], 10).bytecode, buf[0..]);
    try expectEqual(Bytecode.new_checked(buf[0..], 10).state, BytecodeState{ .Checked = .{ .len = 10 } });

    try expect(Bytecode.eql(Bytecode.new_checked(buf[0..], 10), Bytecode{
        .bytecode = buf[0..],
        .state = BytecodeState{ .Checked = .{ .len = 10 } },
    }));
}

test "Bytecode: bytes function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    var x = Bytecode.new_checked(buf[0..], 10);
    try expectEqual(x.bytes(), buf[0..]);
}

test "Bytecode: original_bytes function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try expectEqual(
        Bytecode.new_checked(buf[0..], 3).original_bytes(),
        buf[0..3],
    );
    try expectEqual(
        Bytecode.new_raw(buf[0..]).original_bytes(),
        buf[0..],
    );
}

test "Bytecode: state function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try expectEqual(
        Bytecode.state(Bytecode.new_checked(buf[0..], 3)),
        BytecodeState{ .Checked = .{ .len = 3 } },
    );
    try expectEqual(
        Bytecode.state(Bytecode.new_raw(buf[0..])),
        BytecodeState.Raw,
    );
}

test "Bytecode: is_empty function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try expect(!Bytecode.is_empty(Bytecode.new_checked(buf[0..], 3)));
    try expect(Bytecode.is_empty(Bytecode.new_raw(buf[0..0])));
    try expect(!Bytecode.is_empty(Bytecode.new_raw(buf[0..])));
}

test "Bytecode: len function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try expectEqual(Bytecode.get_len(Bytecode.new_checked(buf[0..], 3)), 3);
    try expectEqual(Bytecode.get_len(Bytecode.new_raw(buf[0..0])), 0);
    try expectEqual(Bytecode.get_len(Bytecode.new_raw(buf[0..])), 5);
}

test "Bytecode: to_check function" {
    var buf: [5]u8 = .{ 0, 1, 2, 3, 4 };
    var expected_buf: [38]u8 = .{ 0, 1, 2, 3, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

    var check = try Bytecode.new_raw(buf[0..]).to_check(std.testing.allocator);
    defer std.mem.Allocator.free(std.testing.allocator, check.bytecode);
    try expect(Bytecode.eql(check, Bytecode.new_checked(expected_buf[0..], 5)));
}

test "Bytecode: hash_slow function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try expectEqual(
        Bytecode.new_raw(buf[0..0]).hash_slow(),
        constants.Constants.KECCAK_EMPTY,
    );
    const expected_hash = bits.B256{ .bytes = [32]u8{
        125,
        135,
        197,
        234,
        117,
        247,
        55,
        139,
        183,
        1,
        228,
        4,
        197,
        6,
        57,
        22,
        26,
        243,
        239,
        246,
        98,
        147,
        233,
        243,
        117,
        181,
        241,
        126,
        181,
        4,
        118,
        244,
    } };
    try expectEqual(Bytecode.new_raw(buf[0..]).hash_slow(), expected_hash);
}
