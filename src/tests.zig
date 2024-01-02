const std = @import("std");
const interpreter = @import("./interpreter/lib.zig");
const primitives = @import("./primitives/lib.zig");
const vm = @import("./vm/lib.zig");
const precompile = @import("./precompile/lib.zig");

test {
    std.testing.log_level = std.log.Level.err;
    std.testing.refAllDecls(interpreter);
    std.testing.refAllDecls(primitives);
    std.testing.refAllDecls(vm);
    std.testing.refAllDecls(precompile);
}
