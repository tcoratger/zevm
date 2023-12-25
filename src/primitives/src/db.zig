const std = @import("std");
pub const AccountInfo = @import("./state.zig").AccountInfo;
pub const B256 = @import("./bits.zig").B256;
pub const Bytecode = @import("./bytecode.zig").Bytecode;

pub const Database = struct {
    const Self = @This();

    basicFn: fn (*Self, [20]u8) anyerror!?AccountInfo,
    codeByHashFn: fn (*Self, B256) anyerror!?Bytecode,
    storageFn: fn (*Self, [20]u8, u256) anyerror!?u256,
    blockHashFn: fn (*Self, B256) anyerror!?B256,

    pub fn basic(comptime self: *Self, address: [20]u8) anyerror!?AccountInfo {
        return self.basicFn(self, address);
    }

    pub fn codeByHash(comptime self: *Self, codeHash: B256) anyerror!?Bytecode {
        return self.codeByHashFn(self, codeHash);
    }

    pub fn storage(comptime self: *Self, address: [20]u8, index: u256) anyerror!?u256 {
        return self.storageFn(self, address, index);
    }

    pub fn blockHash(comptime self: *Self, number: B256) anyerror!?B256 {
        return self.blockHashFn(self, number);
    }
};

pub const DatabaseRef = struct {
    const Self = @This();

    basicRef: fn (self: *Self, address: [20]u8) anyerror!?AccountInfo,
    codeByHashRef: fn (self: *Self, codeHash: B256) anyerror!?Bytecode,
    storageRef: fn (self: *Self, address: [20]u8, index: u256) anyerror!?u256,
    blockHashRef: fn (self: *Self, number: B256) anyerror!?B256,
};

pub const WrapDatabaseRef = struct {
    const Self = @This();

    db: DatabaseRef,

    pub fn from(db: DatabaseRef) Self {
        return .{ .db = db };
    }

    pub fn basic(self: *Self, address: [20]u8) !?AccountInfo {
        return try self.db.basicRef(address);
    }

    pub fn codeByHash(self: *Self, code_hash: B256) !Bytecode {
        return self.db.codeByHashRef(code_hash);
    }

    pub fn storage(self: *Self, address: [20]u8, index: u256) !u256 {
        return self.db.storageRef(address, index);
    }

    pub fn blockHash(self: *Self, number: u256) !B256 {
        return self.db.blockHashRef(number);
    }
};
