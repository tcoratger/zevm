const std = @import("std");
const expect = std.testing.expect;

pub const SpecId = enum(u8) {
    const Self = @This();

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

    pub fn enabled(our: Self, other: Self) bool {
        return @intFromEnum(our) >= @intFromEnum(other);
    }

    pub fn from_u8(spec_id: u8) Self {
        return @as(Self, @enumFromInt(spec_id));
    }
};

test "SpecId: enabled function" {
    try expect(SpecId.enabled(SpecId.FRONTIER_THAWING, SpecId.FRONTIER) == true);
    try expect(SpecId.enabled(SpecId.HOMESTEAD, SpecId.DAO_FORK) == false);
}

test "SpecId: from_u8 function" {
    try expect(SpecId.from_u8(0) == SpecId.FRONTIER);
    try expect(SpecId.from_u8(1) == SpecId.FRONTIER_THAWING);
    try expect(SpecId.from_u8(2) == SpecId.HOMESTEAD);
    try expect(SpecId.from_u8(3) == SpecId.DAO_FORK);
    try expect(SpecId.from_u8(4) == SpecId.TANGERINE);
    try expect(SpecId.from_u8(5) == SpecId.SPURIOUS_DRAGON);
    try expect(SpecId.from_u8(6) == SpecId.BYZANTIUM);
    try expect(SpecId.from_u8(7) == SpecId.CONSTANTINOPLE);
    try expect(SpecId.from_u8(8) == SpecId.PETERSBURG);
    try expect(SpecId.from_u8(9) == SpecId.ISTANBUL);
    try expect(SpecId.from_u8(10) == SpecId.MUIR_GLACIER);
    try expect(SpecId.from_u8(11) == SpecId.BERLIN);
    try expect(SpecId.from_u8(12) == SpecId.LONDON);
    try expect(SpecId.from_u8(13) == SpecId.ARROW_GLACIER);
    try expect(SpecId.from_u8(14) == SpecId.GRAY_GLACIER);
    try expect(SpecId.from_u8(15) == SpecId.MERGE);
    try expect(SpecId.from_u8(16) == SpecId.SHANGHAI);
    try expect(SpecId.from_u8(17) == SpecId.CANCUN);
    try expect(SpecId.from_u8(18) == SpecId.LATEST);
}
