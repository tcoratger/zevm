pub const JumpMap = struct {};

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
};
