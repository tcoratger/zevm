const std = @import("std");
const titi = @import("./src/primitives/src/specifications.zig");
const tutu = @import("./src/primitives/src/result.zig");
const log = @import("./src/primitives/src/log.zig");
const util = @import("./src/primitives/src/utils.zig");
const mem = @import("std").mem;
const expect = @import("std").testing.expect;

pub fn main() void {
    const EMPTY_UNCLE_HASH = [32]u8{ 0x1d, 0xcc, 0x4d, 0xe8, 0xde, 0xc7, 0x5d, 0x7a, 0xab, 0x85, 0xb5, 0x67, 0xb6, 0xcc, 0xd4, 0x1a, 0xd3, 0x12, 0x45, 0x1b, 0x94, 0x8a, 0x74, 0x13, 0xf0, 0xa1, 0x42, 0xfd, 0x40, 0xd4, 0x93, 0x47 };
    _ = EMPTY_UNCLE_HASH;

    // const original: u128 = 99999999999999999999000000000000000000000;
    // const divisor: u128 = 10000000000000000000000000000000000000000;
    // std.debug.print("Division operation: {}  (correct)\n", .{original / divisor});

    std.debug.print("Hello, {s}!\n", .{"World"});

    std.debug.print("EMPTY_UNCLE_HASH = {any}\n", .{titi.SpecId.enabled(titi.SpecId.CONSTANTINOPLE, titi.SpecId.BERLIN)});

    // // const t = tutu.ExecutionResult{ .Revert = .{ .gas_used = 1, .output = 5 } };
    // // const t = log.Log{ .address = 43 };
    // const t = log.Log{ .address = 43 };
    // var buf: [4]u64 = .{ 0, 0, 0, 0 };
    // var buf: [2]log.Log = .{ t, t };

    // const u = tutu.ExecutionResult{ .Success = .{ .gas_used = 1, .logs = @as([]log.Log, @ptrCast(&buf)) } };

    // // const u = tutu.ExecutionResult{ .Revert = .{ .gas_used = 1, .output = 43 } };
    // std.debug.print("EMPTY_UNCLE_HASH = {any}\n", .{u});

    // std.debug.print("EMPTY_UNCLE_HASH = {any}\n", .{tutu.ExecutionResult.logs(u)});

    // std.debug.print("EMPTY_UNCLE_HASH = {any}\n", .{tutu.ExecutionResult.isSuccess(t)});

    // const maybeString: util.Option.T = util.Option.some("Hello, Zig!");
    // _ = maybeString;

}
