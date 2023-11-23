pub const vm = struct {
    pub usingnamespace @import("block.zig");
    pub usingnamespace @import("transaction.zig");
    pub usingnamespace @import("vm.zig");

    pub usingnamespace @import("src/journaled_state.zig");
};
