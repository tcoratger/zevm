const std = @import("std");
const specifications = @import("./specifications.zig");

const specId = specifications.SpecId;

test "SpecId: enabled function" {
    try std.testing.expect(specId.enabled(specId.FRONTIER_THAWING, specId.FRONTIER) == true);
    try std.testing.expect(specId.enabled(specId.HOMESTEAD, specId.DAO_FORK) == false);
}

test "SpecId: from_u8 function" {
    try std.testing.expect(specId.from_u8(0) == specId.FRONTIER);
    try std.testing.expect(specId.from_u8(1) == specId.FRONTIER_THAWING);
    try std.testing.expect(specId.from_u8(2) == specId.HOMESTEAD);
    try std.testing.expect(specId.from_u8(3) == specId.DAO_FORK);
    try std.testing.expect(specId.from_u8(4) == specId.TANGERINE);
    try std.testing.expect(specId.from_u8(5) == specId.SPURIOUS_DRAGON);
    try std.testing.expect(specId.from_u8(6) == specId.BYZANTIUM);
    try std.testing.expect(specId.from_u8(7) == specId.CONSTANTINOPLE);
    try std.testing.expect(specId.from_u8(8) == specId.PETERSBURG);
    try std.testing.expect(specId.from_u8(9) == specId.ISTANBUL);
    try std.testing.expect(specId.from_u8(10) == specId.MUIR_GLACIER);
    try std.testing.expect(specId.from_u8(11) == specId.BERLIN);
    try std.testing.expect(specId.from_u8(12) == specId.LONDON);
    try std.testing.expect(specId.from_u8(13) == specId.ARROW_GLACIER);
    try std.testing.expect(specId.from_u8(14) == specId.GRAY_GLACIER);
    try std.testing.expect(specId.from_u8(15) == specId.MERGE);
    try std.testing.expect(specId.from_u8(16) == specId.SHANGHAI);
    try std.testing.expect(specId.from_u8(17) == specId.CANCUN);
    try std.testing.expect(specId.from_u8(18) == specId.LATEST);
}
