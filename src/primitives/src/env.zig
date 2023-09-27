const std = @import("std");
const bits = @import("./bits.zig");

pub const BlobExcessGasAndPrice = struct {
    excess_blob_gas: u64,
    excess_blob_gasprice: u64,
};

pub const BlockEnv = struct {
    const Self = @This();

    // The number of ancestor blocks of this block (block height)
    number: std.math.big.int.Managed,
    // The miner or the address that created and signed this block
    coinbase: bits.B160,
    // The timestamp of the block
    timestamp: std.math.big.int.Managed,
    // The gas limit of the block
    gas_limit: std.math.big.int.Managed,
    // The base fee per gas, added in the London upgrade with [EIP-1559]
    base_fee: std.math.big.int.Managed,
    // The output of the randomness beacon provided by the beacon chain
    prev_randao: ?bits.B256,
    // Excess blob gas. See also ['calc_express_blob_gas']
    excess_blob_gas: ?BlobExcessGasAndPrice,

    pub fn init() !Self {
        return .{
            .number = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0),
            .coinbase = bits.B160.from(0),
            .timestamp = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0),
            .gas_limit = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0),
            .base_fee = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0),
            .prev_randao = null,
            .excess_blob_gas = null,
        };
    }

    pub fn set_blob_excess_gas_and_price(self: *Self, excess_blob_gas: u64) void {
        self.excess_blob_gas = .{.excess_blob_gas = excess_blob_gas, .excess_blob_gasprice = 0};
    }

    pub fn get_blob_gasprice(self: Self) ?u64 {
        return self.excess_blob_gas.?.excess_blob_gasprice;
    }

    pub fn get_blob_excess_gas(self: Self) ?u64 {
        return self.excess_blob_gas.?.excess_blob_gas;
    }
};
