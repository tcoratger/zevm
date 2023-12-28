const std = @import("std");
const Allocator = std.mem.Allocator;

const Database = @import("../../../primitives/primitives.zig").Database;
const AccountInfo = @import("../../../primitives/primitives.zig").AccountInfo;
const B256 = @import("../../../primitives/primitives.zig").B256;
const Bytecode = @import("../../../primitives/primitives.zig").Bytecode;
const Utils = @import("../../../primitives/primitives.zig").Utils;

const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;

/// Represents an empty database structure.
pub const EmptyDatabase = struct {
    const Self = @This();

    /// Initializes an instance of EmptyDatabase.
    pub fn init() Self {
        return .{};
    }

    /// Fetches account information associated with the provided address.
    pub fn basic(_: *const Self, _: [20]u8) !?AccountInfo {
        return null;
    }

    /// Retrieves bytecode based on the given hash.
    pub fn codeByHash(_: *const Self, _: B256) !Bytecode {
        return Bytecode.init();
    }

    /// Retrieves data from storage using the provided address and index.
    pub fn storage(_: *const Self, _: [20]u8, _: u256) !u256 {
        return 0;
    }

    /// Generates the hash of a given number to facilitate block identification.
    pub fn blockHash(_: *const Self, number: u256) !B256 {
        var buf: [32]u8 = undefined;
        std.mem.writeInt(u256, &buf, number, .big);
        return Utils.keccak256(&buf);
    }
};

test "EmptyDatabase: init function should return an empty database" {
    // Prepare an address for testing purposes.
    const address = [_]u8{0x00} ** 20;

    // Initialize an instance of EmptyDatabase for testing.
    var empty_db = EmptyDatabase.init();

    // Ensure the basic function returns null for the given address.
    try expectEqual(
        @as(?AccountInfo, null),
        try empty_db.basic(address),
    );

    // Ensure codeByHash returns Bytecode.init() for B256.zero().
    try expect((try empty_db.codeByHash(B256.zero())).eql(Bytecode.init()));

    // Verify that storage returns 0 for the given address and index 150.
    try expectEqual(
        @as(u256, 0),
        try empty_db.storage(address, 150),
    );

    // Validate the blockHash function output for the number 1.
    try expectEqual(
        @as(
            B256,
            B256{ .bytes = [32]u8{
                177,
                14,
                45,
                82,
                118,
                18,
                7,
                59,
                38,
                238,
                205,
                253,
                113,
                126,
                106,
                50,
                12,
                244,
                75,
                74,
                250,
                194,
                176,
                115,
                45,
                159,
                203,
                226,
                183,
                250,
                12,
                246,
            } },
        ),
        try empty_db.blockHash(1),
    );
}
