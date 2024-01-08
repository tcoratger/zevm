const std = @import("std");

const JumpMap = @import("../../../primitives/primitives.zig").JumpMap;

const Allocator = std.mem.Allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

/// Represents a structure to store locked bytecode.
pub const BytecodeLocked = struct {
    /// Represents the `BytecodeLocked` struct itself.
    const Self = @This();

    /// Stores the bytecode as a slice of unsigned 8-bit integers.
    bytecode: []u8,
    /// Represents the length of the stored bytecode.
    len: usize,
    /// Represents the jump map associated with the bytecode.
    jump_map: JumpMap,

    /// Initializes a `BytecodeLocked` instance with the provided allocator.
    pub fn init(allocator: Allocator) Self {
        return .{
            .bytecode = &[_]u8{},
            .len = 0,
            .jump_map = JumpMap.init(allocator),
        };
    }

    /// Deinitializes the `BytecodeLocked`, freeing associated memory.
    ///
    /// Ensure to call this function to free memory after use.
    pub fn deinit(self: *Self) void {
        self.jump_map.deinit();
    }
};

test "BytecodeLocked: init initializes with default values" {
    // Initialize a new BytecodeLocked instance using the testing allocator.
    var bytecodelocked = BytecodeLocked.init(std.testing.allocator);

    // Ensure that allocated resources are deallocated when the test scope is exited.
    defer bytecodelocked.deinit();

    // Check if the initialized bytecode slice is an empty slice.
    try expectEqualSlices(u8, &[_]u8{}, bytecodelocked.bytecode);

    // Check if the initialized length of bytecode is 0.
    try expect(bytecodelocked.len == 0);

    // Get an owned slice of bytes from the jump map associated with the BytecodeLocked.
    const jumpmap_slice = try bytecodelocked.jump_map.asSlice();

    // Ensure that the allocated memory for the jump map slice is freed when the test scope is exited.
    defer std.testing.allocator.free(jumpmap_slice);

    // Check if the obtained slice from the jump map is an empty slice.
    try expectEqualSlices(u8, &[_]u8{}, jumpmap_slice);
}
