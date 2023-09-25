const std = @import("std");
const utils = @import("./utils.zig");
const constants = @import("./constants.zig");
const bits = @import("./bits.zig");
const env = @import("./env.zig");

test "TxEnv: get_total_blob_gas function" {
    var default_tx_env = try env.TxEnv.default(std.testing.allocator);
    try std.testing.expect(default_tx_env.get_total_blob_gas() == 0);
}
