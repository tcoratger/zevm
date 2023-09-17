const std = @import("std");
const bits = @import("./bits.zig");

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
    express_blob_gas: ?u64,

    pub fn init() Self {
        return .{
            .number = std.math.big.int.from_u64(0),
            .coinbase = bits.B160.from_u64(0),
            .timestamp = std.math.big.int.from_u64(0),
            .gas_limit = std.math.big.int.from_u64(0),
            .base_fee = std.math.big.int.from_u64(0),
            .prev_randao = null,
            .express_blob_gas = null,
        };
    }
};
