const block = @import("./block.zig");
const block_header = @import("./blockHeader.zig");
const consensus = @import("./consensus.zig");
const chain = @import("./chain.zig");
const state = @import("./state.zig");

pub const VM = struct {
    block: ?block.Block = null,
    consensus: ?consensus.Consensus = null,
    extra_data_max_bytes: u8 = 32,
    fork: ?[]const u8 = null,
    chaindb: chain.ChainDatabase,
    state: ?state.State = null,

    initial_header: block_header.BlockHeader,
    chain_context: chain.ChainContext,
    consensus_context: consensus.ConsensusContext,

    pub fn init(_header: block_header.BlockHeader, _chaindb: chain.ChainDatabase, _chain_context: chain.ChainContext, _consensus_context: consensus.ConsensusContext) VM {
        return VM{
            .initial_header = _header,
            .chaindb = _chaindb,
            .chain_context = _chain_context,
            .consensus_context = _consensus_context,
        };
    }
};
