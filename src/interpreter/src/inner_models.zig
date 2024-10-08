const std = @import("std");
const primitives = @import("../../primitives/primitives.zig");

const B160 = primitives.B160;
const B256 = primitives.B256;
const ZERO_ADDRESS = primitives.Constants.ZERO_ADDRESS;

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

/// Inputs for a call.
pub const CallInputs = struct {
    /// The target of the call.
    contract: [20]u8,
    /// The transfer, if any, in this call.
    transfer: Transfer,
    /// The call data of the call.
    input: []u8,
    /// The gas limit of the call.
    gas_limit: u64,
    /// The context of the call.
    context: CallContext,
    /// Whether this is a static call.
    is_static: bool,
};

/// Inputs for a create call.
pub const CreateInputs = struct {
    const Self = @This();

    /// Caller address of the EVM.
    caller: [20]u8,
    /// The create scheme.
    scheme: primitives.CreateScheme,
    /// The value to transfer.
    value: u256,
    /// The init code of the contract.
    init_code: []u8,
    /// The gas limit of the call.
    gas_limit: u64,

    /// Returns the address that this create call will create.
    pub fn createAddress(
        self: *const Self,
        nonce: u64,
        allocator: std.mem.Allocator,
    ) ![20]u8 {
        return switch (self.scheme) {
            .Create => (try primitives.Utils.createAddress(
                primitives.B160.fromSlice(&self.caller),
                nonce,
                allocator,
            )).bytes,
            .Create2 => |*scheme| (try primitives.Utils.create2Address(
                primitives.B160.fromSlice(&self.caller),
                primitives.B256.fromSlice(self.init_code),
                scheme.*.salt,
                allocator,
            )).bytes,
        };
    }

    /// Returns the address that this create call will create, without calculating the init code hash.
    ///
    /// Note: `hash` must be `keccak256(&self.init_code)`.
    pub fn created_address_with_hash(
        self: *const Self,
        nonce: u64,
        hash: primitives.B256,
        allocator: std.mem.Allocator,
    ) ![20]u8 {
        const end: usize = 20;
        return switch (self.scheme) {
            .Create => (try primitives.Utils.createAddress(
                primitives.B160.fromSlice(self.caller[0..end]),
                nonce,
                allocator,
            )).bytes,
            .Create2 => |*scheme| (try primitives.Utils.create2Address(
                primitives.B160.fromSlice(self.caller[0..end]),
                hash,
                scheme.*.salt,
                allocator,
            )).bytes,
        };
    }
};

/// Call schemes.
pub const CallScheme = enum {
    /// `CALL`
    Call,
    /// `CALLCODE`
    CallCode,
    /// `DELEGATECALL`
    DelegateCall,
    /// `STATICCALL`
    StaticCall,
};

/// Context of a runtime call.
pub const CallContext = struct {
    const Self = @This();

    /// Execution address.
    address: [20]u8,
    /// Caller address of the EVM.
    caller: [20]u8,
    /// The address the contract code was loaded from, if any.
    code_address: [20]u8,
    /// Apparent value of the EVM.
    apparent_value: u256,
    /// The scheme used for the call.
    scheme: CallScheme,

    /// Initializes a default `CallContext`.
    pub fn default() !Self {
        return .{
            .address = ZERO_ADDRESS,
            .caller = ZERO_ADDRESS,
            .code_address = ZERO_ADDRESS,
            .apparent_value = 0,
            .scheme = .Call,
        };
    }
};

/// Transfer from source to target, with given value.
pub const Transfer = struct {
    /// The source address.
    source: [20]u8,
    /// The target address.
    target: [20]u8,
    /// The transfer value.
    value: u256,
};

/// Result of a call that resulted in a self destruct.
pub const SelfDestructResult = struct {
    /// Indicates if the initiating account had a non-zero balance before the self-destruct action.
    had_value: bool,
    /// Indicates if the target account exists before the self-destruct action.
    target_exists: bool,
    /// Indicates if the target account exists but is inactive (cold) before the self-destruct action.
    is_cold: bool,
    /// Indicates if the initiating account was previously self-destructed.
    previously_destroyed: bool,
};

test "CreateInputs: createAddress function with Create scheme" {
    var tmp = [3]u8{ 1, 2, 3 };
    const create_inputs: CreateInputs = .{
        .caller = B160.from(18_446_744_073_709_551_615).bytes,
        .scheme = .Create,
        .value = 10,
        .init_code = &tmp,
        .gas_limit = 4,
    };

    try expectEqual(
        [20]u8{ 4, 1, 133, 88, 123, 80, 98, 157, 3, 48, 181, 126, 60, 186, 109, 109, 136, 77, 127, 229 },
        try create_inputs.createAddress(2, std.testing.allocator),
    );
}

test "CreateInputs: createAddress function with Create2 scheme" {
    var tmp = [32]u8{ 121, 72, 47, 147, 234, 13, 113, 78, 41, 51, 102, 50, 41, 34, 150, 42, 243, 142, 205, 217, 92, 255, 100, 131, 85, 193, 175, 75, 64, 167, 139, 50 };
    const create_inputs: CreateInputs = .{
        .caller = B160.from(18_446_744_073_709_551_615).bytes,
        .scheme = .{ .Create2 = .{ .salt = 10000000000000000000000000000000 } },
        .value = 10,
        .init_code = &tmp,
        .gas_limit = 4,
    };

    try expectEqual(
        [20]u8{ 21, 108, 197, 97, 104, 190, 154, 181, 81, 131, 139, 5, 178, 141, 203, 240, 157, 66, 125, 96 },
        try create_inputs.createAddress(2, std.testing.allocator),
    );
}

test "CreateInputs: created_address_with_hash function with Create scheme" {
    var tmp = [3]u8{ 1, 2, 3 };
    const create_inputs: CreateInputs = .{
        .caller = B160.from(18_446_744_073_709_551_615).bytes,
        .scheme = .Create,
        .value = 10,
        .init_code = &tmp,
        .gas_limit = 4,
    };

    const hash = B256{ .bytes = [32]u8{ 121, 72, 47, 147, 234, 13, 113, 78, 41, 51, 102, 50, 41, 34, 150, 42, 243, 142, 205, 217, 92, 255, 100, 131, 85, 193, 175, 75, 64, 167, 139, 50 } };

    try expectEqual(
        [20]u8{ 4, 1, 133, 88, 123, 80, 98, 157, 3, 48, 181, 126, 60, 186, 109, 109, 136, 77, 127, 229 },
        try create_inputs.created_address_with_hash(2, hash, std.testing.allocator),
    );
}

test "CreateInputs: created_address_with_hash function with Create2 scheme" {
    var tmp = [3]u8{ 1, 2, 3 };
    const create_inputs: CreateInputs = .{
        .caller = B160.from(18_446_744_073_709_551_615).bytes,
        .scheme = .{ .Create2 = .{ .salt = 10000000000000000000000000000000 } },
        .value = 10,
        .init_code = &tmp,
        .gas_limit = 4,
    };

    const hash = B256{ .bytes = [32]u8{ 121, 72, 47, 147, 234, 13, 113, 78, 41, 51, 102, 50, 41, 34, 150, 42, 243, 142, 205, 217, 92, 255, 100, 131, 85, 193, 175, 75, 64, 167, 139, 50 } };

    try expectEqual(
        [20]u8{ 21, 108, 197, 97, 104, 190, 154, 181, 81, 131, 139, 5, 178, 141, 203, 240, 157, 66, 125, 96 },
        try create_inputs.created_address_with_hash(2, hash, std.testing.allocator),
    );
}
