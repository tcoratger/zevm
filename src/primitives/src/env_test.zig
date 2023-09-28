const std = @import("std");
const env = @import("./env.zig");
const bits = @import("./bits.zig");
const utils = @import("./utils.zig");
const constants = @import("./constants.zig");

test "Block env: Init" {
    const block_env = try env.BlockEnv.init();

    var managed_int = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0);
    defer managed_int.deinit();

    try std.testing.expect(block_env.base_fee.eql(managed_int));
    try std.testing.expect(block_env.number.eql(managed_int));
    try std.testing.expect(block_env.timestamp.eql(managed_int));
    try std.testing.expect(block_env.gas_limit.eql(managed_int));
    try std.testing.expect(block_env.excess_blob_gas == null);
    try std.testing.expectEqual(block_env.coinbase, bits.B160{ .bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } });
}

test "Block env: set_blob_excess_gas_and_price and get_blob_excess_gas" {
    var block_env = try env.BlockEnv.init();

    var managed_int = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0);
    defer managed_int.deinit();

    block_env.set_blob_excess_gas_and_price(10);

    try std.testing.expectEqual(block_env.excess_blob_gas.?.excess_blob_gas, 10);
    try std.testing.expectEqual(block_env.get_blob_excess_gas(), 10);
    try std.testing.expectEqual(block_env.get_blob_gasprice(), 0);
}

test "Block env: new" {
    try std.testing.expect(env.BlobExcessGasAndPrice.new(0).eql(env.BlobExcessGasAndPrice{ .excess_blob_gas = 0, .excess_blob_gasprice = 1 }));
    try std.testing.expect(env.BlobExcessGasAndPrice.new(2314057).eql(env.BlobExcessGasAndPrice{ .excess_blob_gas = 2314057, .excess_blob_gasprice = 1 }));
    try std.testing.expect(env.BlobExcessGasAndPrice.new(2314058).eql(env.BlobExcessGasAndPrice{ .excess_blob_gas = 2314058, .excess_blob_gasprice = 2 }));
    try std.testing.expect(env.BlobExcessGasAndPrice.new(10 * 1024 * 1024).eql(env.BlobExcessGasAndPrice{ .excess_blob_gas = 10 * 1024 * 1024, .excess_blob_gasprice = 23 }));
}

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

test "TransactTo: is_create function" {
    var create = env.TransactTo.create();
    try std.testing.expect(create.is_create());

    var call = env.TransactTo.call(bits.B160.from(18_446_744_073_709_551_615));
    try std.testing.expect(!call.is_create());

    var salt_mock = try std.math.big.int.Managed.initSet(std.testing.allocator, 10000000000000000000000000000000);
    defer salt_mock.deinit();
    var create2 = env.TransactTo.create2(salt_mock);
    try std.testing.expect(create2.is_create());
}
