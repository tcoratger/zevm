const std = @import("std");
const log = @import("./log.zig");
const utils = @import("./utils.zig");

pub const ExecutionResultEnum = enum { Success, Revert, Halt };

pub const ExecutionResult = union(ExecutionResultEnum) {
    /// Returned successfully
    Success: struct { reason: Eval, gas_used: u64, gas_refunded: u64, logs: []log.Log, output: Output },
    /// Reverted by `REVERT` opcode that doesn't spend all gas.
    Revert: struct { gas_used: u64, output: u64 },
    /// Reverted for various reasons and spend all gas.
    Halt: struct {
        reason: Halt,
        /// Halting will spend all the gas, and will be equal to gas_limit.
        gas_used: u64,
    },

    /// Returns if transaction execution is successful.
    /// 1 indicates success, 0 indicates revert.
    /// https://eips.ethereum.org/EIPS/eip-658
    pub fn is_success(execution_result: ExecutionResult) bool {
        return execution_result == ExecutionResultEnum.Success;
    }

    /// Return logs, if execution is not successful, function will return empty vec.
    pub fn logs(execution_result: ExecutionResult) []log.Log {
        return switch (execution_result) {
            .Success => execution_result.Success.logs,
            else => undefined,
        };
    }
};

pub const Eval = enum {
    Stop,
    Return,
    SelfDestruct,
};

pub const OutputEnum = enum { Call, Create };

pub const Output = union(OutputEnum) {
    Call: struct { bytes: []u8 },
    Create: struct { bytes: []u8, option: utils.Option(u64) },

    /// Returns the output data of the execution output.
    pub fn into_data(output: Output) []u8 {
        return switch (output) {
            .Call => output.Call.bytes,
            .Create => output.Create.bytes,
        };
    }

    /// Returns the output data of the execution output.
    pub fn data(output: *Output) *[]u8 {
        return switch (output.*) {
            .Call => &output.Call.bytes,
            .Create => &output.Create.bytes,
        };
    }
};

pub const Halt = enum { OutOfGasError, OpcodeNotFound, InvalidFEOpcode, InvalidJump, NotActivated, StackUnderflow, StackOverflow, OutOfOffset, CreateCollision, PrecompileError, NonceOverflow, CreateContractSizeLimit, CreateContractStartingWithEF, CreateInitcodeSizeLimit, OverflowPayment, StateChangeDuringStaticCall, CallNotAllowedInsideStatic, OutOfFund, CallTooDeep };

pub const OutOfGasError = enum {
    // Basic OOG error
    BasicOutOfGas,
    // Tried to expand past REVM limit
    MemoryLimit,
    // Basic OOG error from memory expansion
    Memory,
    // Precompile threw OOG error
    Precompile,
    // When performing something that takes a U256 and casts down to a u64, if its too large this would fire
    // i.e. in `as_usize_or_fail`
    InvalidOperand,
};

pub fn main() void {
    var buf: [4]u8 = .{ 0, 0, 4, 0 };
    var u = Output{ .Create = .{ .bytes = @as([]u8, @ptrCast(&buf)), .option = utils.Option(u64){ .Some = 67 } } };

    std.debug.print("test = {any}\n", .{Output.data(&u)});
}
