const std = @import("std");

const JumpMap = @import("../../../primitives/primitives.zig").JumpMap;
const Bytecode = @import("../../../primitives/primitives.zig").Bytecode;

const Allocator = std.mem.Allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;
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

    /// Tries to create a `BytecodeLocked` instance from a given `Bytecode`.
    ///
    /// Attempts to convert the provided `Bytecode` instance into a `BytecodeLocked` by extracting
    /// relevant information based on the state of the input bytecode. If the state is `Analysed`,
    /// it constructs a `BytecodeLocked` with bytecode, length, and jump map details. If the state
    /// is not `Analysed`, it returns an error indicating an incompatible bytecode state.
    ///
    /// Returns the created `BytecodeLocked` instance on success, or an error indicating an
    /// incompatible bytecode state.
    pub fn tryFromBytecode(bytecode: Bytecode) !Self {
        return switch (bytecode.state) {
            .Analysed => |analysed| .{
                .bytecode = bytecode.bytecode,
                .len = analysed.len,
                .jump_map = analysed.jump_map,
            },
            else => error.IncompatibleBytecodeState,
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

test "BytecodeLocked: tryFromBytecode initializes with default values for empty bytecode" {
    // Initialize a new `BytecodeLocked` instance using the testing allocator
    var bytecodelocked = try BytecodeLocked.tryFromBytecode(Bytecode.init(std.testing.allocator));

    // Ensure that allocated resources are deallocated when the test scope is exited
    defer bytecodelocked.deinit();

    // Check if the initialized bytecode slice is a slice containing a single zero byte
    try expectEqualSlices(u8, &[_]u8{0}, bytecodelocked.bytecode);

    // Check if the initialized length of bytecode is 0
    try expect(bytecodelocked.len == 0);

    // Get an owned slice of bytes from the jump map associated with the `BytecodeLocked`
    const jumpmap_slice = try bytecodelocked.jump_map.asSlice();

    // Ensure that the allocated memory for the jump map slice is freed when the test scope is exited
    defer std.testing.allocator.free(jumpmap_slice);

    // Check if the obtained slice from the jump map is an empty slice
    try expectEqualSlices(u8, &[_]u8{}, jumpmap_slice);
}

test "BytecodeLocked: tryFromBytecode handles incompatible bytecode state" {
    // Define a byte buffer with a single zero byte.
    var buf = [_]u8{0};

    // Expect an error of type `IncompatibleBytecodeState` when trying to create `BytecodeLocked`
    // from a `Bytecode` instance created with the newRaw method using the defined buffer.
    try expectError(
        error.IncompatibleBytecodeState,
        BytecodeLocked.tryFromBytecode(Bytecode.newRaw(&buf)),
    );
}
