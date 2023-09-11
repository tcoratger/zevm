const std = @import("std");

pub const SpecId = enum(u8) {
    /// Frontier - 0
    FRONTIER = 0,
    /// Frontier Thawing - Block 200000
    FRONTIER_THAWING = 1,
    /// Homestead - Block 1150000
    HOMESTEAD = 2,
    /// DAO Fork - Block 1920000
    DAO_FORK = 3,
    /// Tangerine Whistle - Block 2463000
    TANGERINE = 4,
    /// Spurious Dragon - Block 2675000
    SPURIOUS_DRAGON = 5,
    /// Byzantium - Block 4370000
    BYZANTIUM = 6,
    /// Constantinople - Block 7280000 is overwritten with PETERSBURG
    CONSTANTINOPLE = 7,
    /// Petersburg - Block 7280000
    PETERSBURG = 8,
    /// Istanbul - Block 9069000
    ISTANBUL = 9,
    /// Muir Glacier - Block 9200000
    MUIR_GLACIER = 10,
    /// Berlin - Block 12244000
    BERLIN = 11,
    /// London - Block 12965000
    LONDON = 12,
    /// Arrow Glacier - Block 13773000
    ARROW_GLACIER = 13,
    /// Gray Glacier - Block 15050000
    GRAY_GLACIER = 14,
    /// Paris/Merge - Block TBD (Depends on difficulty)
    MERGE = 15,
    SHANGHAI = 16,
    CANCUN = 17,
    LATEST = 18,

    // For the moment zig doesn't support switch on string
    pub fn from(name: []const u8) SpecId {
        if (std.mem.eql(u8, name, "Frontier")) {
            return SpecId.FRONTIER;
        } else if (std.mem.eql(u8, name, "Homestead")) {
            return SpecId.HOMESTEAD;
        } else if (std.mem.eql(u8, name, "Tangerine")) {
            return SpecId.TANGERINE;
        } else if (std.mem.eql(u8, name, "Spurious")) {
            return SpecId.SPURIOUS_DRAGON;
        } else if (std.mem.eql(u8, name, "Byzantium")) {
            return SpecId.BYZANTIUM;
        } else if (std.mem.eql(u8, name, "Constantinople")) {
            return SpecId.CONSTANTINOPLE;
        } else if (std.mem.eql(u8, name, "Petersburg")) {
            return SpecId.PETERSBURG;
        } else if (std.mem.eql(u8, name, "Istanbul")) {
            return SpecId.ISTANBUL;
        } else if (std.mem.eql(u8, name, "MuirGlacier")) {
            return SpecId.MUIR_GLACIER;
        } else if (std.mem.eql(u8, name, "Berlin")) {
            return SpecId.BERLIN;
        } else if (std.mem.eql(u8, name, "London")) {
            return SpecId.LONDON;
        } else if (std.mem.eql(u8, name, "Merge")) {
            return SpecId.MERGE;
        } else if (std.mem.eql(u8, name, "Shanghai")) {
            return SpecId.SHANGHAI;
        } else if (std.mem.eql(u8, name, "Cancun")) {
            return SpecId.CANCUN;
        } else {
            return SpecId.LATEST;
        }
    }

    pub fn enabled(our: SpecId, other: SpecId) bool {
        return @intFromEnum(our) >= @intFromEnum(other);
    }

    pub fn from_u8(spec_id: u8) SpecId {
        return @as(SpecId, @enumFromInt(spec_id));
    }
};
