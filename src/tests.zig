const std = @import("std");

const tests = struct {
    // pub usingnamespace @import("interpreter/src/gas_calc.zig");
    pub usingnamespace @import("interpreter/src/gas.zig");
    pub usingnamespace @import("interpreter/src/inner_models.zig");
    pub usingnamespace @import("interpreter/src/instruction_result.zig");

    pub usingnamespace @import("primitives/src/bits.zig");
    pub usingnamespace @import("primitives/src/bytecode.zig");
    pub usingnamespace @import("primitives/src/env.zig");
    pub usingnamespace @import("primitives/src/log.zig");
    pub usingnamespace @import("primitives/src/precompile.zig");
    pub usingnamespace @import("primitives/src/result.zig");
    pub usingnamespace @import("primitives/src/specifications.zig");
    pub usingnamespace @import("primitives/src/state.zig");
    pub usingnamespace @import("primitives/src/utils.zig");

    // pub usingnamespace @import("vm/block.zig");
    // pub usingnamespace @import("vm/transaction.zig");
    // pub usingnamespace @import("vm/vm.zig");
};

test {
    std.testing.log_level = std.log.Level.err;
    std.testing.refAllDecls(tests);
}
