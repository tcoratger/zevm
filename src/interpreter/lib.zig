pub const interpreter = struct {
    pub usingnamespace @import("src/gas_calc.zig");
    pub usingnamespace @import("src/gas.zig");
    pub usingnamespace @import("src/inner_models.zig");
    pub usingnamespace @import("src/instruction_result.zig");
    pub usingnamespace @import("src/interpreter/analysis.zig");
};
