const std = @import("std");
const specifications = @import("primitives").SpecId;
const constants = @import("./gas_constants.zig");

pub fn sstore_refund(
    comptime spec: specifications,
    original: std.math.big.int.Managed,
    current: std.math.big.int.Managed,
    new: std.math.big.int.Managed,
    allocator: std.mem.Allocator,
) i64 {
    if (specifications.enabled(
        spec,
        specifications.ISTANBUL,
    )) {
        const sstore_clears_schedule = if (specifications.enabled(spec, specifications.LONDON)) @as(
            i64,
            constants.Constants.SSTORE_RESET - constants.Constants.COLD_SLOAD_COST + constants.Constants.ACCESS_LIST_STORAGE_KEY,
        ) else constants.Constants.REFUND_SSTORE_CLEARS;

        if (current.eql(new)) {
            return 0;
        } else {
            if (original.eql(current) and new.eqlZero()) {
                return sstore_clears_schedule;
            } else {
                var refund: i64 = 0;
                if (!original.eqlZero()) {
                    if (current.eqlZero()) {
                        refund -= sstore_clears_schedule;
                    } else if (new.eqlZero()) {
                        refund += sstore_clears_schedule;
                    }
                }

                if (original.eql(new)) {
                    var gas_sstore_reset_sload = if (specifications.enabled(spec, specifications.BERLIN)) .{
                        constants.Constants.SSTORE_RESET - constants.Constants.COLD_SLOAD_COST,
                        constants.Constants.WARM_STORAGE_READ_COST,
                    } else .{
                        constants.Constants.SSTORE_RESET,
                        sload_cost(spec, false),
                    };

                    if (original.eqlZero()) {
                        refund += @as(i64, constants.Constants.SSTORE_SET - gas_sstore_reset_sload[1]);
                    } else {
                        refund += @as(
                            i64,
                            gas_sstore_reset_sload[0] - gas_sstore_reset_sload[1],
                        );
                    }

                    return refund;
                }
            }
        }
    } else {
        var zero = try std.math.big.int.Managed.initSet(
            allocator,
            0,
        );
        defer zero.deinit();
        if (!current.eqlZero() and new.eqlZero()) {
            return constants.Constants.REFUND_SSTORE_CLEARS;
        } else {
            return 0;
        }
    }
}

pub fn create2_cost(len: usize) ?u64 {
    const base = constants.Constants.CREATE;
    const len_u64 = @as(u64, len);
    const sha_addup_base = @as(u64, (len_u64 / 32)) + @as(u64, @mod(len, 32) != 0);
    const sha_addup = @mulWithOverflow(constants.Constants.KECCAK256WORD, sha_addup_base);
    if (sha_addup[1] != 0) {
        return null;
    }
    const gas = @addWithOverflow(base, sha_addup[0]);
    if (gas[1] != 0) {
        return null;
    } else {
        return gas[0];
    }
}

pub fn log2floor(
    value: std.math.big.int.Managed,
) u64 {
    std.debug.assert(!value.eqlZero());
    var l: u64 = 256;

    for (0..4) |i| {
        var j = 3 - i;

        if (value.limbs[j] == 0) {
            l -= 64;
        } else {
            l -= @as(u64, @clz(value.limbs[j]));

            if (l == 0) {
                return l;
            } else {
                return l - 1;
            }
        }
    }
    return l;
}

pub fn exp_cost(
    comptime spec: specifications,
    power: std.math.big.int.Managed,
    allocator: std.mem.Allocator,
) !?u64 {
    if (power.eqlZero()) {
        return constants.Constants.EXP;
    } else {
        // EIP-160: EXP cost increase
        var gas_byte = try std.math.big.int.Managed.initSet(
            allocator,
            if (specifications.enabled(spec, specifications.SPURIOUS_DRAGON)) 50 else 10,
        );
        defer gas_byte.deinit();

        var gas = try std.math.big.int.Managed.initSet(allocator, constants.Constants.EXP);
        defer gas.deinit();

        var coeff = try std.math.big.int.Managed.initSet(allocator, log2floor(power) / 8 + 1);
        defer coeff.deinit();

        try gas.add(&gas, &gas_byte.mul(&gas_byte, &coeff));

        if (gas.to(u64) == error.TargetTooSmall) {
            return null;
        } else {
            return gas;
        }
    }
}

pub fn verylowcopy_cost(len: u64) ?u64 {
    const wordd = len / 32;
    const wordr = @mod(len, 32);

    const res = @addWithOverflow(constants.Constants.VERYLOW, @mulWithOverflow(constants.Constants.COPY, if (wordr == 0) wordd else wordd + 1)[0]);

    if (res[1] != 0) {
        return null;
    } else {
        return res[0];
    }
}

pub fn extcodecopy_cost(comptime spec: specifications, len: u64, is_cold: bool) ?u64 {
    const wordd = len / 32;
    const wordr = @mod(len, 32);

    const base_gas: u64 = if (specifications.enabled(
        spec,
        specifications.BERLIN,
    )) (if (is_cold) constants.Constants.COLD_ACCOUNT_ACCESS_COST else constants.Constants.WARM_STORAGE_READ_COST) else if (specifications.enabled(
        spec,
        specifications.TANGERINE,
    )) 700 else 20;

    const res = @addWithOverflow(base_gas, @mulWithOverflow(constants.Constants.COPY, if (wordr == 0) wordd else wordd + 1)[0]);

    if (res[1] != 0) {
        return null;
    } else {
        return res[0];
    }
}

pub fn account_access_gas(comptime spec: specifications, is_cold: bool) u64 {
    return if (specifications.enabled(
        spec,
        specifications.BERLIN,
    )) (if (is_cold) constants.Constants.COLD_ACCOUNT_ACCESS_COST else constants.Constants.WARM_STORAGE_READ_COST) else if (specifications.enabled(
        spec,
        specifications.ISTANBUL,
    )) 700 else 20;
}

pub fn log_cost(n: u8, len: u64) ?u64 {
    const res = @addWithOverflow(
        constants.Constants.LOG,
        @addWithOverflow(@mulWithOverflow(
            constants.Constants.LOGDATA,
            len,
        ), @as(
            u64,
            constants.Constants.LOGTOPIC * n,
        )),
    );

    if (res[1] != 0) {
        return null;
    } else {
        return res[0];
    }
}

pub fn keccak256_cost(len: u64) ?u64 {
    const wordd = len / 32;
    const wordr = @mod(len, 32);

    const res = @addWithOverflow(
        constants.Constants.KECCAK256,
        @mulWithOverflow(
            constants.Constants.KECCAK256WORD,
            if (wordr == 0) wordd else wordd + 1,
        ),
    );

    if (res[1] != 0) {
        return null;
    } else {
        return res[0];
    }
}

/// EIP-3860: Limit and meter initcode
///
/// Apply extra gas cost of 2 for every 32-byte chunk of initcode.
///
/// This cannot overflow as the initcode length is assumed to be checked.
pub fn initcode_cost(len: u64) u64 {
    const wordd = len / 32;
    const wordr = @mod(len, 32);

    return constants.Constants.INITCODE_WORD_COST * if (wordr == 0) wordd else wordd + 1;
}

pub fn sload_cost(comptime spec: specifications, is_cold: bool) u64 {
    return if (specifications.enabled(
        spec,
        specifications.BERLIN,
    )) (if (is_cold) constants.Constants.COLD_ACCOUNT_ACCESS_COST else constants.Constants.WARM_STORAGE_READ_COST) else if (specifications.enabled(
        spec,
        specifications.ISTANBUL,
    ))
        // EIP-1884: Repricing for trie-size-dependent opcodes
        800
    else if (specifications.enabled(
        spec,
        specifications.TANGERINE,
    ))
        // EIP-150: Gas cost changes for IO-heavy operations
        200
    else
        50;
}

pub fn sstore_cost(comptime spec: specifications, original: std.math.big.int.Managed, current: std.math.big.int.Managed, new: std.math.big.int.Managed, gas: u64, is_cold: bool) ?u64 {
    _ = is_cold;
    _ = gas;
    _ = new;
    _ = current;
    _ = original;
    _ = spec;
}