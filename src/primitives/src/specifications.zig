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
    try expect(SpecId.enabled(.FRONTIER_THAWING, .FRONTIER) == true);
    try expect(SpecId.enabled(.HOMESTEAD, .DAO_FORK) == false);
}

test "SpecId: from_u8 function" {
    try expect(SpecId.from_u8(0) == .FRONTIER);
    try expect(SpecId.from_u8(1) == .FRONTIER_THAWING);
    try expect(SpecId.from_u8(2) == .HOMESTEAD);
    try expect(SpecId.from_u8(3) == .DAO_FORK);
    try expect(SpecId.from_u8(4) == .TANGERINE);
    try expect(SpecId.from_u8(5) == .SPURIOUS_DRAGON);
    try expect(SpecId.from_u8(6) == .BYZANTIUM);
    try expect(SpecId.from_u8(7) == .CONSTANTINOPLE);
    try expect(SpecId.from_u8(8) == .PETERSBURG);
    try expect(SpecId.from_u8(9) == .ISTANBUL);
    try expect(SpecId.from_u8(10) == .MUIR_GLACIER);
    try expect(SpecId.from_u8(11) == .BERLIN);
    try expect(SpecId.from_u8(12) == .LONDON);
    try expect(SpecId.from_u8(13) == .ARROW_GLACIER);
    try expect(SpecId.from_u8(14) == .GRAY_GLACIER);
    try expect(SpecId.from_u8(15) == .MERGE);
    try expect(SpecId.from_u8(16) == .SHANGHAI);
    try expect(SpecId.from_u8(17) == .CANCUN);
    try expect(SpecId.from_u8(18) == .LATEST);
}
