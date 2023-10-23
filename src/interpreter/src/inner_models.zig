const std = @import("std");
const primitives = @import("primitives");

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
    value: std.math.big.int.Managed,
    /// The init code of the contract.
    init_code: []u8,
    /// The gas limit of the call.
    gas_limit: u64,

    /// Returns the address that this create call will create.
    pub fn create_address(
        self: *Self,
        nonce: u64,
        allocator: std.mem.Allocator,
    ) [20]u8 {
        return switch (self.scheme) {
            .Create => primitives.Utils.create_address(
                primitives.B160.from_slice(self.caller[0..]),
                nonce,
                allocator,
            ),
            .Create2 => |*scheme| primitives.Utils.create2_address(
                primitives.B160.from_slice(self.caller[0..]),
                primitives.B256.from_slice(&self.init_code),
                scheme.*.salt,
                allocator,
            ),
        };
    }

    /// Returns the address that this create call will create, without calculating the init code hash.
    ///
    /// Note: `hash` must be `keccak256(&self.init_code)`.
    pub fn created_address_with_hash(
        self: *Self,
        nonce: u64,
        hash: *primitives.B256,
        allocator: std.mem.Allocator,
    ) [20]u8 {
        return switch (self.scheme) {
            .Create => primitives.Utils.create_address(
                primitives.B160.from_slice(self.caller[0..]),
                nonce,
                allocator,
            ),
            .Create2 => |*scheme| primitives.Utils.create2_address(
                primitives.B160.from_slice(self.caller[0..]),
                hash,
                scheme.*.salt,
                allocator,
            ),
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
    apparent_value: std.math.big.int.Managed,
    /// The scheme used for the call.
    scheme: CallScheme,

    pub fn default(allocator: std.mem.Allocator) !Self {
        return .{
            .address = [20]u8{0},
            .caller = [20]u8{0},
            .code_address = [20]u8{0},
            .apparent_value = try std.math.big.int.Managed.initSet(allocator, 0),
            .scheme = CallScheme.Call,
        };
    }

    /// Frees all associated memory.
    pub fn deinit(self: *Self) void {
        self.apparent_value.deinit();
    }
};

/// Transfer from source to target, with given value.
pub const Transfer = struct {
    /// The source address.
    source: [20]u8,
    /// The target address.
    target: [20]u8,
    /// The transfer value.
    value: std.math.big.int.Managed,
};

/// Result of a call that resulted in a self destruct.
pub const SelfDestructResult = struct {
    had_value: bool,
    target_exists: bool,
    is_cold: bool,
    previously_destroyed: bool,
};
