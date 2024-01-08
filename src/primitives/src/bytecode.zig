const std = @import("std");
const constants = @import("./constants.zig");
const utils = @import("./utils.zig");
const bits = @import("./bits.zig");

const Allocator = std.mem.Allocator;

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

/// Represents a JumpMap used for some purpose.
pub const JumpMap = struct {
    /// Represents the JumpMap struct itself.
    const Self = @This();

    /// Internal storage for bit vector using an ArrayList.
    bit_vec: std.ArrayList(u8),

    /// Initializes a JumpMap instance with a provided allocator.
    pub fn init(allocator: Allocator) Self {
        return .{ .bit_vec = std.ArrayList(u8).init(allocator) };
    }

    /// Constructs a JumpMap instance from a provided byte slice.
    pub fn fromSlice(allocator: Allocator, slice: []u8) !Self {
        // Initialize an ArrayList to store u8 values.
        var v = std.ArrayList(u8).init(allocator);
        // Ensure deallocation of ArrayList resources in case of errors.
        errdefer v.deinit();
        // Insert the provided byte slice into the ArrayList at index 0.
        try v.insertSlice(0, slice);
        // Return a new JumpMap instance initialized with the ArrayList containing the inserted slice.
        return .{ .bit_vec = v };
    }

    /// Retrieves the bit vector as a slice.
    ///
    /// Returns an owned slice of bytes.
    pub fn asSlice(self: *Self) ![]u8 {
        return try self.bit_vec.toOwnedSlice();
    }

    /// Checks if the provided program counter (pc) is within the bounds of the bit vector length.
    ///
    /// Returns `true` if the program counter is less than the length of the bit vector, indicating validity,
    /// or `false` otherwise, indicating the program counter is out of bounds.
    pub fn isValid(self: *Self, pc: usize) bool {
        return pc < self.bit_vec.items.len;
    }

    /// Deinitializes the JumpMap, freeing associated memory.
    ///
    /// Ensure to call this function to free memory after use.
    pub fn deinit(self: *Self) void {
        self.bit_vec.deinit();
    }
};

/// State of the `Bytecode` analysis.
pub const BytecodeState = union(enum) {
    const Self = @This();

    /// No analysis has been performed.
    Raw,
    /// The bytecode has been checked for validity.
    Checked: struct { len: usize },
    /// The bytecode has been analyzed for valid jump destinations.
    Analysed: struct { len: usize, jump_map: JumpMap },

    /// Frees all associated memory.
    pub fn deinit(self: *Self) void {
        switch (self.*) {
            .Analysed => |*analysed| analysed.jump_map.deinit(),
            else => {},
        }
    }
};

pub const Bytecode = struct {
    const Self = @This();
    bytecode: []u8,
    state: BytecodeState,

    /// Creates a new `Bytecode` with exactly one STOP opcode.
    pub fn init(allocator: Allocator) Self {
        var buf: [1]u8 = .{0};
        return .{
            .bytecode = &buf,
            .state = .{
                .Analysed = .{
                    .len = 0,
                    .jump_map = JumpMap.init(allocator),
                },
            },
        };
    }

    /// Calculate hash of the bytecode.
    pub fn hashSlow(self: Self) bits.B256 {
        if (self.isEmpty()) {
            return constants.Constants.KECCAK_EMPTY;
        } else {
            return utils.keccak256(self.originalBytes());
        }
    }

    /// Creates a new raw `Bytecode`.
    pub fn newRaw(bytecode: []u8) Self {
        return .{ .bytecode = bytecode, .state = .Raw };
    }

    /// Create new checked bytecode
    ///
    /// # Safety
    /// Bytecode need to end with STOP (0x00) opcode as checked bytecode assumes
    /// that it is safe to iterate over bytecode without checking lengths
    pub fn newChecked(bytecode: []u8, len: usize) Self {
        return .{
            .bytecode = bytecode,
            .state = .{ .Checked = .{ .len = len } },
        };
    }

    /// Returns a reference to the bytecode.
    pub fn bytes(self: Self) []u8 {
        return self.bytecode;
    }

    /// Returns a reference to the original bytecode.
    pub fn originalBytes(self: Self) []u8 {
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
    pub fn isEmpty(self: Self) bool {
        return switch (self.state) {
            .Raw => self.bytecode.len == 0,
            .Checked => |*item| item.*.len == 0,
            .Analysed => |*item| item.*.len == 0,
        };
    }

    /// Returns the length of the bytecode.
    pub fn getLen(self: Self) usize {
        return switch (self.state) {
            .Raw => self.bytecode.len,
            .Checked => |*item| item.*.len,
            .Analysed => |*item| item.*.len,
        };
    }

    pub fn toCheck(self: Self, allocator: std.mem.Allocator) !Self {
        return switch (self.state) {
            .Raw => {
                var padded_bytecode = std.ArrayList(u8).init(allocator);
                defer padded_bytecode.deinit();
                try padded_bytecode.appendSlice(self.bytecode);
                try padded_bytecode.appendNTimes(0, 33);
                return .{
                    .bytecode = try padded_bytecode.toOwnedSlice(),
                    .state = .{ .Checked = .{ .len = self.bytecode.len } },
                };
            },
            else => self,
        };
    }

    pub fn eql(self: Self, other: Self) bool {
        return std.mem.eql(u8, self.bytecode, other.bytecode) and switch (self.state) {
            .Raw => other.state == .Raw,
            .Checked => {
                if (other.state == .Checked) {
                    return self.state.Checked.len == other.state.Checked.len;
                } else {
                    return false;
                }
            },
            .Analysed => {
                if (other.state == .Analysed) {
                    return self.state.Analysed.len == other.state.Analysed.len;
                } else {
                    return false;
                }
            },
        };
    }

    pub fn deinit(self: *Self) void {
        self.state.deinit();
    }
};

test "Bytecode: newRaw function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try expect(Bytecode.eql(Bytecode.newRaw(buf[0..]), .{ .bytecode = buf[0..], .state = .Raw }));
}

test "Bytecode: newChecked function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try expectEqual(
        @as([]u8, buf[0..]),
        Bytecode.newChecked(buf[0..], 10).bytecode,
    );
    try expectEqual(
        BytecodeState{ .Checked = .{ .len = 10 } },
        Bytecode.newChecked(buf[0..], 10).state,
    );

    try expect(Bytecode.eql(Bytecode.newChecked(buf[0..], 10), Bytecode{
        .bytecode = buf[0..],
        .state = BytecodeState{ .Checked = .{ .len = 10 } },
    }));
}

test "Bytecode: bytes function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    var x = Bytecode.newChecked(buf[0..], 10);
    try expectEqual(@as([]u8, buf[0..]), x.bytes());
}

test "Bytecode: originalBytes function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try expectEqual(
        @as([]u8, buf[0..3]),
        Bytecode.newChecked(buf[0..], 3).originalBytes(),
    );
    try expectEqual(
        @as([]u8, buf[0..]),
        Bytecode.newRaw(buf[0..]).originalBytes(),
    );
}

test "Bytecode: state function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try expectEqual(
        BytecodeState{ .Checked = .{ .len = 3 } },
        Bytecode.state(Bytecode.newChecked(buf[0..], 3)),
    );
    try expectEqual(
        BytecodeState.Raw,
        Bytecode.state(Bytecode.newRaw(buf[0..])),
    );
}

test "Bytecode: isEmpty function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try expect(!Bytecode.isEmpty(Bytecode.newChecked(buf[0..], 3)));
    try expect(Bytecode.isEmpty(Bytecode.newRaw(buf[0..0])));
    try expect(!Bytecode.isEmpty(Bytecode.newRaw(buf[0..])));
}

test "Bytecode: len function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try expectEqual(
        @as(usize, 3),
        Bytecode.getLen(Bytecode.newChecked(buf[0..], 3)),
    );
    try expectEqual(
        @as(usize, 0),
        Bytecode.getLen(Bytecode.newRaw(buf[0..0])),
    );
    try expectEqual(
        @as(usize, 5),
        Bytecode.getLen(Bytecode.newRaw(buf[0..])),
    );
}

test "Bytecode: toCheck function" {
    var buf: [5]u8 = .{ 0, 1, 2, 3, 4 };
    var expected_buf: [38]u8 = .{ 0, 1, 2, 3, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

    const check = try Bytecode.newRaw(buf[0..]).toCheck(std.testing.allocator);
    defer std.mem.Allocator.free(std.testing.allocator, check.bytecode);
    try expect(Bytecode.eql(check, Bytecode.newChecked(expected_buf[0..], 5)));
}

test "Bytecode: hashSlow function" {
    var buf: [5]u8 = .{ 1, 2, 3, 4, 5 };
    try expectEqual(
        constants.Constants.KECCAK_EMPTY,
        Bytecode.newRaw(buf[0..0]).hashSlow(),
    );

    try expectEqual(
        bits.B256{ .bytes = [32]u8{ 125, 135, 197, 234, 117, 247, 55, 139, 183, 1, 228, 4, 197, 6, 57, 22, 26, 243, 239, 246, 98, 147, 233, 243, 117, 181, 241, 126, 181, 4, 118, 244 } },
        Bytecode.newRaw(buf[0..]).hashSlow(),
    );
}

test "JumpMap: asSlice should return a proper slice corresponding to the content of bit_vec" {
    // Create a new JumpMap instance using the testing allocator.
    var jumpmap = JumpMap.init(std.testing.allocator);

    // Ensure the allocated resources are deallocated when the test scope is exited.
    defer jumpmap.deinit();

    // Append 10 instances of the value 4 to the bit vector of the JumpMap.
    try jumpmap.bit_vec.appendNTimes(10, 4);

    // Get an owned slice of bytes from the bit vector of the JumpMap.
    const slice = try jumpmap.asSlice();

    // Ensure that the allocated memory for the slice is freed when the test scope is exited.
    defer std.testing.allocator.free(slice);

    // Check if the obtained slice matches the expected slice of bytes [10, 10, 10, 10].
    try expectEqualSlices(u8, &[_]u8{ 10, 10, 10, 10 }, slice);
}

test "JumpMap: fromSlice should return a proper slice corresponding to the content of bit_vec" {
    // Define a byte array with specific content.
    var arr = [_]u8{ 11, 11, 11, 11 };

    // Create a new JumpMap instance from the provided byte array using the testing allocator.
    var jumpmap = try JumpMap.fromSlice(std.testing.allocator, &arr);

    // Ensure that allocated resources are deallocated when the test scope is exited.
    defer jumpmap.deinit();

    // Get an owned slice of bytes from the bit vector of the JumpMap.
    const slice = try jumpmap.asSlice();

    // Ensure that the allocated memory for the slice is freed when the test scope is exited.
    defer std.testing.allocator.free(slice);

    // Check if the obtained slice matches the expected slice of bytes [11, 11, 11, 11].
    try expectEqualSlices(u8, &[_]u8{ 11, 11, 11, 11 }, slice);
}
