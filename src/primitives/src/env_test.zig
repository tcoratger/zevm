const std = @import("std");
const utils = @import("./utils.zig");
const constants = @import("./constants.zig");
const bits = @import("./bits.zig");
const env = @import("./env.zig");

test "TxEnv: get_total_blob_gas function" {
    var default_tx_env = try env.TxEnv.default(std.testing.allocator);
    try std.testing.expect(default_tx_env.get_total_blob_gas() == 0);
}

test "TransactTo: call function" {
    try std.testing.expectEqual(env.TransactTo.call(bits.B160.from(18_446_744_073_709_551_615)), env.TransactTo{ .Call = .{ .to = bits.B160.from(18_446_744_073_709_551_615) } });
}

test "TransactTo: create function" {
    try std.testing.expectEqual(env.TransactTo.create(), env.TransactTo{ .Create = .{ .scheme = env.CreateScheme.Create } });
}

test "TransactTo: create2 function" {
    var salt_mock = try std.math.big.int.Managed.initSet(std.testing.allocator, 10000000000000000000000000000000);
    defer salt_mock.deinit();
    try std.testing.expectEqual(env.TransactTo.create2(salt_mock), env.TransactTo{ .Create = .{ .scheme = env.CreateScheme{ .Create2 = .{ .salt = salt_mock } } } });
}

test "TransactTo: is_call function" {
    var salt_mock = try std.math.big.int.Managed.initSet(std.testing.allocator, 10000000000000000000000000000000);
    defer salt_mock.deinit();
    var create2 = env.TransactTo.create2(salt_mock);
    try std.testing.expect(!create2.is_call());

    var call = env.TransactTo.call(bits.B160.from(18_446_744_073_709_551_615));
    try std.testing.expect(call.is_call());
}
