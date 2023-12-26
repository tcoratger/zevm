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

    pub fn codeByHash(self: *Self, codeHash: [20]u8) !?Bytecode {
        switch (self) {
            inline else => |case| case.codeByHash(codeHash),
        }
    }

    pub fn storage(self: *Self, address: [20]u8, index: u256) !?u256 {
        switch (self) {
            inline else => |case| case.storage(address, index),
        }
    }

    pub fn blockHash(self: *Self, number: B256) !?B256 {
        switch (self) {
            inline else => |case| case.blockHash(number),
        }
    }
};
