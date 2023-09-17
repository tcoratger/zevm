pub const JumpMap = struct {};
const std = @import("std");

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

    pub fn new() Self {
        var buf: [1]u8 = .{0};
        return .{ .bytecode = buf[0..], .state = BytecodeState{ .Analysed = .{ .len = 0, .jump_map = JumpMap{} } } };
    }

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

    pub fn bytes(self: Self) []u8 {
        return self.bytecode;
    }

    pub fn original_bytes(self: Self) []u8 {
        return switch (self.state) {
            .Raw => self.bytecode,
            .Checked => |*item| self.bytecode[0..item.*.len],
            .Analysed => |*item| self.bytecode[0..item.*.len],
        };
    }

    pub fn state(self: Self) BytecodeState {
        return self.state;
    }

    pub fn is_empty(self: Self) bool {
        return switch (self.state) {
            .Raw => self.bytecode.len == 0,
            .Checked => |*item| item.*.len == 0,
            .Analysed => |*item| item.*.len == 0,
        };
    }

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
                var new_bytecode = std.ArrayList(u8).init(allocator);
                defer new_bytecode.deinit();
                try new_bytecode.appendSlice(self.bytecode);
                try new_bytecode.appendNTimes(0, 33);
                return .{ .bytecode = try new_bytecode.toOwnedSlice(), .state = BytecodeState{ .Checked = .{ .len = self.bytecode.len } } };
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
