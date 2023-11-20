const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

/// Represents the state of gas during execution.
pub const Gas = struct {
    const Self = @This();

    /// The initial gas limit.
    limit: u64,
    /// The total used
    all_used_gas: u64,
    /// Used gas without memory expansion.
    used: u64,
    /// Used gas for memory expansion.
    memory: u64,
    /// Refunded  This is used only at the end of execution.
    refunded: i64,

    /// Creates a new `Gas` struct with the given gas limit.
    pub fn new(lim: u64) Self {
        return .{
            .limit = lim,
            .used = 0,
            .memory = 0,
            .refunded = 0,
            .all_used_gas = 0,
        };
    }

    /// Returns the gas limit.
    pub fn limit(self: *Self) u64 {
        return self.limit;
    }

    /// Returns the amount of gas that was used.
    pub fn memory(self: *Self) u64 {
        return self.memory;
    }

    /// Returns the amount of gas that was refunded.
    pub fn refunded(self: *Self) i64 {
        return self.refunded;
    }

    /// Returns all the gas used in the execution.
    pub fn spend(self: *Self) u64 {
        return self.all_used_gas;
    }

    /// Returns the amount of gas remaining.
    pub fn remaining(self: *Self) u64 {
        return self.limit - self.all_used_gas;
    }

    /// Erases a gas cost from the totals.
    pub fn erase_cost(self: *Self, returned: u64) void {
        self.used -= returned;
        self.all_used_gas -= returned;
    }

    /// Records a refund value.
    ///
    /// `refund` can be negative but `self.refunded` should always be positive at the end of transact.
    pub fn record_refund(self: *Self, refund: i64) void {
        self.refunded += refund;
    }

    /// Set a refund value
    pub fn set_refund(self: *Self, refund: i64) void {
        self.refunded = refund;
    }

    /// Records an explicit cost.
    ///
    /// Returns `false` if the gas limit is exceeded.
    ///
    /// This function is called on every instruction in the interpreter if the feature
    /// `no_gas_measuring` is not enabled.
    pub fn record_cost(self: *Self, cost: u64) bool {
        const all_used_gas = self.all_used_gas +| cost;

        if (self.limit < all_used_gas) {
            return false;
        }

        self.used += cost;
        self.all_used_gas = all_used_gas;
        return true;
    }

    /// used to record gas used for memory expansion.
    pub fn record_memory(self: *Self, gas_memory: u64) bool {
        if (gas_memory > self.memory) {
            const all_used_gas = self.all_used_gas +| gas_memory;
            if (self.limit < all_used_gas) {
                return false;
            }
            self.memory = gas_memory;
            self.all_used_gas = all_used_gas;
        }
        return true;
    }
};

test "Gas: new" {
    try expectEqual(Gas.new(12), Gas{
        .limit = 12,
        .used = 0,
        .memory = 0,
        .refunded = 0,
        .all_used_gas = 0,
    });
}

test "Gas: limit" {
    var g = Gas.new(12);
    try expectEqual(Gas.limit(&g), 12);
}

test "Gas: memory" {
    var g = Gas.new(12);
    try expectEqual(Gas.memory(&g), 0);
}

test "Gas: refunded" {
    var g = Gas.new(12);
    try expectEqual(Gas.refunded(&g), 0);
}

test "Gas: spend" {
    var g = Gas.new(12);
    try expectEqual(Gas.spend(&g), 0);
}

test "Gas: remaining" {
    var g = Gas.new(12);
    try expectEqual(Gas.remaining(&g), 12);
}

test "Gas: erase_cost" {
    var g = Gas{
        .limit = 15,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 15,
    };
    Gas.erase_cost(&g, 5);
    try expectEqual(g, Gas{
        .limit = 15,
        .used = 15,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 10,
    });
}

test "Gas: record_refund" {
    var g = Gas{
        .limit = 15,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 15,
    };
    Gas.record_refund(&g, 5);
    try expectEqual(g, Gas{
        .limit = 15,
        .used = 20,
        .memory = 25,
        .refunded = 31,
        .all_used_gas = 15,
    });
}

test "Gas: set_refund" {
    var g = Gas{
        .limit = 15,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 15,
    };
    Gas.set_refund(&g, 5);
    try expectEqual(g, Gas{
        .limit = 15,
        .used = 20,
        .memory = 25,
        .refunded = 5,
        .all_used_gas = 15,
    });
}

test "Gas: record_cost with exceeded gas limit" {
    var g = Gas{
        .limit = 15,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 10,
    };
    try expectEqual(Gas.record_cost(&g, 10), false);
}

test "Gas: record_cost not exceeded gas limit" {
    var g = Gas{
        .limit = 15,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 10,
    };
    try expectEqual(Gas.record_cost(&g, 2), true);
    try expectEqual(g, Gas{
        .limit = 15,
        .used = 22,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 12,
    });
}

test "Gas: record_memory gas_memory lower than memory limit" {
    var g = Gas{
        .limit = 15,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 10,
    };
    try expectEqual(Gas.record_memory(&g, 10), true);
    try expectEqual(g, Gas{
        .limit = 15,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 10,
    });
}

test "Gas: record_memory gas_memory higher than memory limit with gas used lower than limit" {
    var g = Gas{
        .limit = 100,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 10,
    };
    try expectEqual(Gas.record_memory(&g, 28), true);
    try expectEqual(g, Gas{
        .limit = 100,
        .used = 20,
        .memory = 28,
        .refunded = 26,
        .all_used_gas = 38,
    });
}

test "Gas: record_memory gas_memory higher than memory limit with gas used higher than limit" {
    var g = Gas{
        .limit = 10,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 10,
    };
    try expectEqual(Gas.record_memory(&g, 28), false);
    try expectEqual(g, Gas{
        .limit = 10,
        .used = 20,
        .memory = 25,
        .refunded = 26,
        .all_used_gas = 10,
    });
}
