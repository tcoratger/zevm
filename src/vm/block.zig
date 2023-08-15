pub const Block = struct {
    block_number: u64,
    gas_limit: u64,
    difficulty: u256,
    timestamp: u256,
    coinbase: [20]u8,
    chainId: u64,
};
