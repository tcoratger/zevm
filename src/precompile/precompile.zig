const std = @import("std");
const Allocator = std.mem.Allocator;

const StandardPrecompileFn = @import("../primitives/primitives.zig").StandardPrecompileFn;
const EnvPrecompileFn = @import("../primitives/primitives.zig").EnvPrecompileFn;
const SpecIdPrimitives = @import("../primitives/primitives.zig").SpecId;

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectFmt = std.testing.expectFmt;

/// Calculates the linear cost based on length, base, and word size.
///
/// This function computes the linear cost for a given length, base cost, and word size.
///
/// # Arguments
/// - `len`: Length of the input.
/// - `base`: Base cost.
/// - `word`: Word size.
///
/// # Returns
/// The calculated linear cost as a `u64`.
pub fn calcLinearCostU32(len: usize, base: u64, word: u64) u64 {
    return (@as(
        u64,
        @intCast(len),
    ) + 32 - 1) / 32 * word + base;
}

/// Represents a union of standard and environment precompile functions.
pub const Precompile = union(enum) {
    /// Reference to Self.
    const Self = @This();

    /// Function pointer to a standard precompile function.
    Standard: StandardPrecompileFn,
    /// Function pointer to an environment precompile function.
    Env: EnvPrecompileFn,

    /// Formats the Precompile union for display.
    ///
    /// # Arguments
    /// - `self`: Reference to the Precompile union.
    ///
    /// # Returns
    /// A `std.fmt.Formatter` containing the formatted representation of the Precompile union.
    pub fn fmt(self: *Self) std.fmt.Formatter([]const u8) {
        return switch (self.*) {
            // Formats 'Standard' variant as "Standard".
            .Standard => .{ .data = "Standard" },
            // Formats 'Env' variant as "Env".
            .Env => .{ .data = "Env" },
        };
    }
};

/// Represents a structure associating an address with a precompile function.
pub const PrecompileWithAddress = struct {
    /// Reference to Self.
    const Self = @This();

    /// The address associated with the precompile.
    address: [20]u8,
    /// The precompile function associated with the address.
    precompile: Precompile,

    /// Initializes a PrecompileWithAddress instance.
    ///
    /// # Arguments
    /// - `address`: The address associated with the precompile.
    /// - `precompile`: The precompile function.
    ///
    /// # Returns
    /// A new PrecompileWithAddress instance.
    pub fn init(address: [20]u8, precompile: Precompile) Self {
        return .{ .address = address, .precompile = precompile };
    }
};

/// Enum representing Ethereum specification IDs.
pub const SpecId = enum(u8) {
    /// Reference to Self.
    const Self = @This();

    /// Ethereum specification ID for Homestead.
    HOMESTEAD,
    /// Ethereum specification ID for Byzantium.
    BYZANTIUM,
    /// Ethereum specification ID for Istanbul.
    ISTANBUL,
    /// Ethereum specification ID for Berlin.
    BERLIN,
    /// Ethereum specification ID for Cancun.
    CANCUN,
    /// Latest Ethereum specification ID.
    LATEST,

    /// Initializes a SpecId from a SpecIdPrimitives enum.
    ///
    /// # Arguments
    /// - `spec_id`: SpecIdPrimitives enum value to initialize from.
    ///
    /// # Returns
    /// A SpecId corresponding to the given SpecIdPrimitives enum.
    pub fn initFromSpecId(spec_id: SpecIdPrimitives) Self {
        return switch (spec_id) {
            .FRONTIER, .FRONTIER_THAWING, .HOMESTEAD, .DAO_FORK, .TANGERINE, .SPURIOUS_DRAGON => .HOMESTEAD,
            .BYZANTIUM | .CONSTANTINOPLE | .PETERSBURG => .BYZANTIUM,
            .ISTANBUL | .MUIR_GLACIER => .ISTANBUL,
            .BERLIN | .LONDON | .ARROW_GLACIER | .GRAY_GLACIER | .MERGE | .SHANGHAI => .BERLIN,
            .CANCUN => .CANCUN,
            .LATEST => .LATEST,
        };
    }
};

/// Represents the output structure of a precompile operation.
pub const PrecompileOutput = struct {
    /// Reference to Self.
    const Self = @This();

    /// Cost of the operation.
    cost: u64,
    /// Output data as a list of bytes.
    output: std.ArrayList(u8),
    /// Logs generated during the operation.
    logs: std.ArrayList(Log),

    /// Initializes a PrecompileOutput instance without logs.
    ///
    /// # Arguments
    /// - `allocator`: Allocator for memory allocation.
    /// - `cost`: Cost of the operation.
    /// - `output`: Output data as a list of bytes.
    ///
    /// # Returns
    /// A new PrecompileOutput instance without logs or an error.
    pub fn initWithoutLogs(allocator: Allocator, cost: u64, output: std.ArrayList(u8)) !Self {
        return .{
            .cost = cost,
            .output = try output.clone(),
            .logs = std.ArrayList(Log).init(allocator),
        };
    }

    /// Deinitializes the PrecompileOutput instance, freeing associated memory.
    ///
    /// # Safety
    /// This function assumes proper initialization of PrecompileOutput and must be called
    /// to avoid memory leaks and ensure proper cleanup.
    pub fn deinit(self: *Self) void {
        self.output.deinit();
        for (self.logs.items) |*log| {
            log.topics.deinit();
        }
        self.logs.deinit();
    }
};

pub const Log = struct {
    const Self = @This();

    address: [20]u8,
    topics: std.ArrayList(u256),
    data: []u8,

    /// Frees all associated memory.
    pub fn deinit(self: *Self) void {
        self.topics.deinit();
    }
};

test "calcLinearCostU32: should calculate the linear cost based on length, base, and word size" {
    try expectEqual(@as(u64, 88), calcLinearCostU32(10, 64, 24));
    try expectEqual(@as(u64, 0), calcLinearCostU32(0, 0, 0));
}

test "PrecompileOutput: initWithoutLogs should initialize a PrecompileOutput with an empty log vector" {
    // Initialize an ArrayList of u8 using the testing allocator.
    var output = std.ArrayList(u8).init(std.testing.allocator);
    // Defer memory deallocation for 'output'.
    defer output.deinit();
    // Append 10 elements of value 8 to 'output'.
    try output.appendNTimes(8, 10);

    // Initialize a PrecompileOutput instance using initWithoutLogs function.
    var res = try PrecompileOutput.initWithoutLogs(std.testing.allocator, 123, output);
    // Defer memory deallocation for 'res'.
    defer res.deinit();

    // Expect 'cost' field in 'res' to equal 123.
    try expectEqual(@as(u64, 123), res.cost);

    // Expect the number of items in 'res.logs' to be 0 (empty log vector).
    try expectEqual(@as(usize, 0), res.logs.items.len);

    // Expect the contents of 'res.output.items' to be [8, 8, 8, 8, 8, 8, 8, 8, 8, 8].
    try expectEqualSlices(
        u8,
        &[_]u8{ 8, 8, 8, 8, 8, 8, 8, 8, 8, 8 },
        res.output.items,
    );
}
