const block = @import("./block.zig");
const block_header = @import("./blockHeader.zig");
const consensus = @import("./consensus.zig");
const chain = @import("./chain.zig");
const state = @import("./state.zig");

pub const VM = struct {
    block_class: ?block.Block = null,
    block: ?block.Block = null,
    consensus: ?consensus.Consensus = null,
    extra_data_max_bytes: u8 = 32,
    fork: ?[]const u8 = null,
    chaindb: chain.ChainDatabase,
    state_class: ?state.State = null,
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

    pub fn get_header(self: VM) block_header.BlockHeader {
        return if (self.block) |b| b.header else self.initial_header;
    }

    pub fn get_block(self: VM) block.Block {
        if (self.block) |b| {
            return b;
        } else {
            const bc = self.get_block_class();
            _ = bc;
        }
    }

    pub fn get_block_class(self: VM) !block.Block {
        return if (self.block_class) |b| b else error.No_Block_Class_Set;
    }
};
