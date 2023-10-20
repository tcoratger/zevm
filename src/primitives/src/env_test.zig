const std = @import("std");
const env = @import("./env.zig");
const bits = @import("./bits.zig");
const utils = @import("./utils.zig");
const constants = @import("./constants.zig");

test "Block env: Init" {
    var block_env = try env.BlockEnv.default(std.testing.allocator);
    defer block_env.deinit();

    var managed_int = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0);
    defer managed_int.deinit();

    try std.testing.expect(block_env.base_fee.eql(managed_int));
    try std.testing.expect(block_env.number.eql(managed_int));
    try std.testing.expect(block_env.timestamp.eql(managed_int));
    try std.testing.expect(block_env.gas_limit.eql(managed_int));
    try std.testing.expect(block_env.difficulty.eql(managed_int));
    try std.testing.expect(block_env.blob_excess_gas_and_price.?.eql(env.BlobExcessGasAndPrice{ .excess_blob_gas = 0, .excess_blob_gasprice = 1 }));
    try std.testing.expectEqual(block_env.coinbase, bits.B160{ .bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } });
    try std.testing.expect(block_env.prev_randao.?.is_zero());
}

test "Block env: set_blob_excess_gas_and_price and get_blob_excess_gas" {
    var block_env = try env.BlockEnv.default(std.testing.allocator);
    defer block_env.deinit();

    var managed_int = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0);
    defer managed_int.deinit();

    block_env.set_blob_excess_gas_and_price(10);

    try std.testing.expectEqual(block_env.blob_excess_gas_and_price.?.excess_blob_gas, 10);
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
    default_tx_env.deinit();
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

test "Env: effective_gas_price without gas_priority_fee" {
    var env_default = try env.Env.default(std.testing.allocator);
    defer env_default.deinit();
    var effective_gas_price = try env.Env.effective_gas_price(env_default, std.testing.allocator);
    defer effective_gas_price.deinit();
    var expected = try std.math.big.int.Managed.initSet(std.testing.allocator, 0);
    defer expected.deinit();
    try std.testing.expect(effective_gas_price.eql(expected));
}

test "Env: effective_gas_price with gas_priority_fee returning gas_price" {
    var tx_env = env.TxEnv{
        .caller = bits.B160.from(0),
        .gas_limit = constants.Constants.UINT_64_MAX,
        .gas_price = try std.math.big.int.Managed.initSet(std.testing.allocator, 1),
        .gas_priority_fee = try std.math.big.int.Managed.initSet(std.testing.allocator, 10),
        .transact_to = env.TransactTo{ .Call = .{ .to = bits.B160.from(0) } },
        .value = try std.math.big.int.Managed.initSet(std.testing.allocator, 0),
        .data = undefined,
        .chain_id = null,
        .nonce = null,
        .access_list = std.ArrayList(@TypeOf(.{ bits.B160, std.ArrayList(std.math.big.int.Managed) })).init(std.testing.allocator),
        .blob_hashes = std.ArrayList(bits.B256).init(std.testing.allocator),
        .max_fee_per_blob_gas = null,
    };
    defer tx_env.deinit();

    var env_env = env.Env{
        .block = try env.BlockEnv.default(std.testing.allocator),
        .cfg = env.CfgEnv.default(),
        .tx = tx_env,
    };
    defer env_env.block.deinit();

    var expected = try std.math.big.int.Managed.initSet(std.testing.allocator, 1);
    defer expected.deinit();

    var effective_gas_price = try env.Env.effective_gas_price(env_env, std.testing.allocator);
    defer effective_gas_price.deinit();

    try std.testing.expect(effective_gas_price.eql(expected));
}

test "Env: effective_gas_price with gas_priority_fee returning gas_priority_fee + base_fee" {
    var tx_env = env.TxEnv{
        .caller = bits.B160.from(0),
        .gas_limit = constants.Constants.UINT_64_MAX,
        .gas_price = try std.math.big.int.Managed.initSet(std.testing.allocator, 11),
        .gas_priority_fee = try std.math.big.int.Managed.initSet(std.testing.allocator, 10),
        .transact_to = env.TransactTo{ .Call = .{ .to = bits.B160.from(0) } },
        .value = try std.math.big.int.Managed.initSet(std.testing.allocator, 0),
        .data = undefined,
        .chain_id = null,
        .nonce = null,
        .access_list = std.ArrayList(@TypeOf(.{ bits.B160, std.ArrayList(std.math.big.int.Managed) })).init(std.testing.allocator),
        .blob_hashes = std.ArrayList(bits.B256).init(std.testing.allocator),
        .max_fee_per_blob_gas = null,
    };
    defer tx_env.deinit();

    var env_env = env.Env{
        .block = try env.BlockEnv.default(std.testing.allocator),
        .cfg = env.CfgEnv.default(),
        .tx = tx_env,
    };
    defer env_env.block.deinit();

    var expected = try std.math.big.int.Managed.initSet(std.testing.allocator, 10);
    defer expected.deinit();

    var effective_gas_price = try env.Env.effective_gas_price(env_env, std.testing.allocator);
    defer effective_gas_price.deinit();

    try std.testing.expect(effective_gas_price.eql(expected));
}
