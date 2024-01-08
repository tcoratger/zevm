const JumpMap = @import("../../../primitives/primitives.zig").JumpMap;

pub const BytecodeLocked = struct {
    const Self = @This();

    bytecode: []u8,
    len: usize,
    jump_map: JumpMap,
};
