pub const JumpMap = struct {};
const std = @import("std");

pub const BytecodeState = union(enum) {
    Raw,
    Checked: struct { len: usize },
    Analysed: struct { len: usize, jump_map: JumpMap },
};

pub const Bytecode = struct {
    bytecode: []u8,
    state: BytecodeState,

    pub fn default() Bytecode {
        return Bytecode.new();
    }

    pub fn new() Bytecode {
        var buf: [1]u8 = .{0};
        return Bytecode{ .bytecode = buf[0..], .state = BytecodeState{ .Analysed = .{ .len = 0, .jump_map = JumpMap{} } } };
    }

    pub fn new_raw(bytecode: []u8) Bytecode {
        return Bytecode{ .bytecode = bytecode, .state = BytecodeState.Raw };
    }

    /// Create new checked bytecode
    ///
    /// # Safety
    /// Bytecode need to end with STOP (0x00) opcode as checked bytecode assumes
    /// that it is safe to iterate over bytecode without checking lengths
    pub fn new_checked(bytecode: []u8, len: usize) Bytecode {
        return Bytecode{
            .bytecode = bytecode,
            .state = BytecodeState{ .Checked = .{ .len = len } },
        };
    }

    pub fn bytes(self: Bytecode) []u8 {
        return self.bytecode;
    }

    pub fn original_bytes(self: Bytecode) []u8 {
        return switch (self.state) {
            .Raw => self.bytecode,
            .Checked => |*item| self.bytecode[0..item.*.len],
            .Analysed => |*item| self.bytecode[0..item.*.len],
        };
    }

    pub fn state(self: Bytecode) BytecodeState {
        return self.state;
    }

    pub fn is_empty(self: Bytecode) bool {
        return switch (self.state) {
            .Raw => self.bytecode.len == 0,
            .Checked => |*item| item.*.len == 0,
            .Analysed => |*item| item.*.len == 0,
        };
    }

    pub fn get_len(self: Bytecode) usize {
        return switch (self.state) {
            .Raw => self.bytecode.len,
            .Checked => |*item| item.*.len,
            .Analysed => |*item| item.*.len,
        };
    }

    pub fn to_check(self: Bytecode, allocator: std.mem.Allocator) !Bytecode {
        return switch (self.state) {
            .Raw => {
                var new_bytecode = std.ArrayList(u8).init(allocator);
                defer new_bytecode.deinit();
                try new_bytecode.appendSlice(self.bytecode);
                try new_bytecode.appendNTimes(0, 33);
                return Bytecode{ .bytecode = try new_bytecode.toOwnedSlice(), .state = BytecodeState{ .Checked = .{ .len = self.bytecode.len } } };
            },
            else => self,
        };
    }

    pub fn eql(self: Bytecode, other: Bytecode) bool {
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
