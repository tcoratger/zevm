const std = @import("std");

pub const Log = struct {
    address: u64,
    pub fn log(comptime message: []const u8) void {
        std.debug.print("{s}\n", .{message});
    }
};
