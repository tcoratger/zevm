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

    pub fn enabled(our: SpecId, other: SpecId) bool {
        return @intFromEnum(our) >= @intFromEnum(other);
    }

    pub fn from_u8(spec_id: u8) SpecId {
        return @as(SpecId, @enumFromInt(spec_id));
    }
};
