const std = @import("std");
pub const AccountInfo = @import("./state.zig").AccountInfo;
pub const B256 = @import("./bits.zig").B256;
pub const Bytecode = @import("./bytecode.zig").Bytecode;

pub fn DatabaseRef(comptime E: type) type {
    return struct {
        const Self = @This();

        basic: fn (self: *Self, address: [20]u8) E!?AccountInfo,
        codeByHash: fn (self: *Self, codeHash: B256) E!?Bytecode,
        storage: fn (self: *Self, address: [20]u8, index: u256) E!?u256,
        blockHashRef: fn (self: *Self, number: B256) E!?B256,
    };
}

pub fn WrapDatabaseRef(comptime E: type) type {
    return struct {
        const Self = @This();

        db: DatabaseRef(E),

        pub fn from(db: DatabaseRef) Self {
            return .{ .db = db };
        }

        pub fn basic(self: *Self, address: [20]u8) !?AccountInfo {
            return try self.db.basic(address);
        }

        pub fn codeByHash(self: *Self, code_hash: B256) !Bytecode {
            return self.db.codeByHash(code_hash);
        }

        pub fn storage(self: *Self, address: [20]u8, index: u256) !u256 {
            return self.db.storage(address, index);
        }

        pub fn blockHash(self: *Self, number: u256) !B256 {
            return self.db.blockHashRef(number);
        }
    };
}
