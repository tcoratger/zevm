const std = @import("std");

/// Represents the state of gas during execution.
pub const Gas = struct {
    const Self = @This();

    /// The initial gas limit.
    limit: u64,
    /// The total used gas.
    all_used_gas: u64,
    /// Used gas without memory expansion.
    used: u64,
    /// Used gas for memory expansion.
    memory: u64,
    /// Refunded gas. This is used only at the end of execution.
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
