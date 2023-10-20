const std = @import("std");
const gas = @import("./gas.zig");

test "Gas: new" {
    try std.testing.expectEqual(gas.Gas.new(12), gas.Gas{
        .limit = 12,
        .used = 0,
        .memory = 0,
        .refunded = 0,
        .all_used_gas = 0,
    });
}

test "Gas: limit" {
    var g = gas.Gas.new(12);
    try std.testing.expectEqual(gas.Gas.limit(&g), 12);
}

test "Gas: memory" {
    var g = gas.Gas.new(12);
    try std.testing.expectEqual(gas.Gas.memory(&g), 0);
}

test "Gas: refunded" {
    var g = gas.Gas.new(12);
    try std.testing.expectEqual(gas.Gas.refunded(&g), 0);
}

test "Gas: spend" {
    var g = gas.Gas.new(12);
    try std.testing.expectEqual(gas.Gas.spend(&g), 0);
}

test "Gas: remaining" {
    var g = gas.Gas.new(12);
    try std.testing.expectEqual(gas.Gas.remaining(&g), 12);
}

test "Gas: erase_cost" {
    var g = gas.Gas{
        .limit = 15,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 15,
    };
    gas.Gas.erase_cost(&g, 5);
    try std.testing.expectEqual(g, gas.Gas{
        .limit = 15,
        .used = 15,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 10,
    });
}

test "Gas: record_refund" {
    var g = gas.Gas{
        .limit = 15,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 15,
    };
    gas.Gas.record_refund(&g, 5);
    try std.testing.expectEqual(g, gas.Gas{
        .limit = 15,
        .used = 20,
        .memory = 25,
        .refunded = 31,
        .all_used_gas = 15,
    });
}

test "Gas: set_refund" {
    var g = gas.Gas{
        .limit = 15,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 15,
    };
    gas.Gas.set_refund(&g, 5);
    try std.testing.expectEqual(g, gas.Gas{
        .limit = 15,
        .used = 20,
        .memory = 25,
        .refunded = 5,
        .all_used_gas = 15,
    });
}

test "Gas: record_cost with exceeded gas limit" {
    var g = gas.Gas{
        .limit = 15,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 10,
    };
    try std.testing.expectEqual(gas.Gas.record_cost(&g, 10), false);
}

test "Gas: record_cost not exceeded gas limit" {
    var g = gas.Gas{
        .limit = 15,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 10,
    };
    try std.testing.expectEqual(gas.Gas.record_cost(&g, 2), true);
    try std.testing.expectEqual(g, gas.Gas{
        .limit = 15,
        .used = 22,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 12,
    });
}

test "Gas: record_memory gas_memory lower than memory limit" {
    var g = gas.Gas{
        .limit = 15,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 10,
    };
    try std.testing.expectEqual(gas.Gas.record_memory(&g, 10), true);
    try std.testing.expectEqual(g, gas.Gas{
        .limit = 15,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 10,
    });
}

test "Gas: record_memory gas_memory higher than memory limit with gas used lower than limit" {
    var g = gas.Gas{
        .limit = 100,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 10,
    };
    try std.testing.expectEqual(gas.Gas.record_memory(&g, 28), true);
    try std.testing.expectEqual(g, gas.Gas{
        .limit = 100,
        .used = 20,
        .memory = 28,
        .refunded = 26,
        .all_used_gas = 38,
    });
}

test "Gas: record_memory gas_memory higher than memory limit with gas used higher than limit" {
    var g = gas.Gas{
        .limit = 10,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 10,
    };
    try std.testing.expectEqual(gas.Gas.record_memory(&g, 28), false);
    try std.testing.expectEqual(g, gas.Gas{
        .limit = 10,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 10,
    });
}
