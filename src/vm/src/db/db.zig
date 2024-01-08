const std = @import("std");

const Allocator = std.mem.Allocator;

const EmptyDatabase = @import("./emptydb.zig").EmptyDatabase;
const AccountInfo = @import("../../../primitives/primitives.zig").AccountInfo;
const Bytecode = @import("../../../primitives/primitives.zig").Bytecode;
const B256 = @import("../../../primitives/primitives.zig").B256;

pub const Database = union(enum) {
    const Self = @This();

    empty_database: EmptyDatabase,

    pub fn initEmpty() Self {
        return .{ .empty_database = EmptyDatabase.init() };
    }

    pub fn basic(self: *const Self, address: [20]u8) !?AccountInfo {
        return switch (self.*) {
            inline else => |case| try case.basic(address),
        };
    }

    pub fn codeByHash(self: *const Self, allocator: Allocator, codeHash: B256) !Bytecode {
        return switch (self.*) {
            inline else => |case| try case.codeByHash(allocator, codeHash),
        };
    }

    pub fn storage(self: *const Self, address: [20]u8, index: u256) !u256 {
        return switch (self.*) {
            inline else => |case| try case.storage(address, index),
        };
    }

    pub fn blockHash(self: *const Self, number: B256) !B256 {
        return switch (self.*) {
            inline else => |case| try case.blockHash(number),
        };
    }
};
