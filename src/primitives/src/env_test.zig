const std = @import("std");
const env = @import("./env.zig");
const bits = @import("./bits.zig");

test "Block env: Init"{
    const block_env = try env.BlockEnv.init();

    var managed_int = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0);
    defer managed_int.deinit();

    try std.testing.expect(block_env.base_fee.eql(managed_int));
    try std.testing.expect(block_env.number.eql(managed_int));
    try std.testing.expect(block_env.timestamp.eql(managed_int));
    try std.testing.expect(block_env.gas_limit.eql(managed_int));
    try std.testing.expect(block_env.prev_randao == null);
    try std.testing.expect(block_env.excess_blob_gas == null);
    try std.testing.expectEqual(block_env.coinbase, bits.B160{.bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }});
}

test "Block env: set_blob_excess_gas_and_price and get_blob_excess_gas"{
    var block_env = try env.BlockEnv.init();

    var managed_int = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0);
    defer managed_int.deinit();

    block_env.set_blob_excess_gas_and_price(10);

    try std.testing.expectEqual(block_env.excess_blob_gas.?.excess_blob_gas, 10);
    try std.testing.expectEqual(block_env.get_blob_excess_gas(), 10);
    try std.testing.expectEqual(block_env.get_blob_gasprice(), 0);
}