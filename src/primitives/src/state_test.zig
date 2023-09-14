const std = @import("std");
const state = @import("./state.zig");
const utils = @import("./utils.zig");
const bits = @import("./bits.zig");
const constants = @import("./constants.zig");
const bytecode = @import("./bytecode.zig");

test "Account: self destruct functions" {
    var map = std.HashMap(std.math.big.int.Mutable, state.StorageSlot, utils.BigIntContext(std.math.big.int.Mutable), std.hash_map.default_max_load_percentage).init(std.testing.allocator);
    defer map.deinit();
    const big_int_0 = std.math.big.int.Mutable.init(&state.AccountInfo.limbs, 0);
    try map.put(big_int_0, state.StorageSlot{ .original_value = big_int_0, .present_value = big_int_0 });

    var account = state.Account{
        .info = state.AccountInfo.default(),
        .storage = map,
        .status = state.AccountStatus.default(),
    };
    account.mark_selfdestruct();
    try std.testing.expectEqual(account.status.SelfDestructed, true);
    try std.testing.expectEqual(account.is_selfdestructed(), true);
    account.unmark_selfdestruct();
    try std.testing.expectEqual(account.status.SelfDestructed, false);
    try std.testing.expectEqual(account.is_selfdestructed(), false);
}

test "Account: touched functions" {
    var map = std.HashMap(std.math.big.int.Mutable, state.StorageSlot, utils.BigIntContext(std.math.big.int.Mutable), std.hash_map.default_max_load_percentage).init(std.testing.allocator);
    defer map.deinit();
    const big_int_0 = std.math.big.int.Mutable.init(&state.AccountInfo.limbs, 0);
    try map.put(big_int_0, state.StorageSlot{ .original_value = big_int_0, .present_value = big_int_0 });

    var account = state.Account{
        .info = state.AccountInfo.default(),
        .storage = map,
        .status = state.AccountStatus.default(),
    };
    account.mark_touch();
    try std.testing.expectEqual(account.status.Touched, true);
    try std.testing.expectEqual(account.is_touched(), true);
    account.unmark_touch();
    try std.testing.expectEqual(account.status.Touched, false);
    try std.testing.expectEqual(account.is_touched(), false);
}

test "Account: created functions" {
    var map = std.HashMap(std.math.big.int.Mutable, state.StorageSlot, utils.BigIntContext(std.math.big.int.Mutable), std.hash_map.default_max_load_percentage).init(std.testing.allocator);
    defer map.deinit();
    const big_int_0 = std.math.big.int.Mutable.init(&state.AccountInfo.limbs, 0);
    try map.put(big_int_0, state.StorageSlot{ .original_value = big_int_0, .present_value = big_int_0 });

    var account = state.Account{
        .info = state.AccountInfo.default(),
        .storage = map,
        .status = state.AccountStatus.default(),
    };
    account.mark_created();
    try std.testing.expectEqual(account.status.Created, true);
    try std.testing.expectEqual(account.is_created(), true);
    account.unmark_created();
    try std.testing.expectEqual(account.status.Created, false);
    try std.testing.expectEqual(account.is_created(), false);
}

test "Account: is_empty function" {
    var map = std.HashMap(std.math.big.int.Mutable, state.StorageSlot, utils.BigIntContext(std.math.big.int.Mutable), std.hash_map.default_max_load_percentage).init(std.testing.allocator);
    defer map.deinit();
    const big_int_0 = std.math.big.int.Mutable.init(&state.AccountInfo.limbs, 0);
    try map.put(big_int_0, state.StorageSlot{ .original_value = big_int_0, .present_value = big_int_0 });

    var account = state.Account{
        .info = state.AccountInfo.default(),
        .storage = map,
        .status = state.AccountStatus.default(),
    };
    try std.testing.expectEqual(account.is_empty(), true);
}

test "Account: new_not_existing function" {
    try std.testing.expectEqual(state.Account.new_not_existing(std.testing.allocator).status.LoadedAsNotExisting, true);
}

test "AccountStatus: default function" {
    try std.testing.expectEqual(state.AccountStatus.default().Loaded, true);
}

test "AccountInfo: default function" {
    var lb = [_]usize{ 0, 0, 0, 0 };
    var buf: [1]u8 = .{0};
    try std.testing.expectEqualSlices(usize, state.AccountInfo.default().balance.limbs, lb[0..]);
    try std.testing.expectEqual(state.AccountInfo.default().balance.len, 1);
    try std.testing.expectEqual(state.AccountInfo.default().balance.positive, true);
    try std.testing.expectEqual(state.AccountInfo.default().nonce, 0);
    try std.testing.expectEqual(state.AccountInfo.default().code_hash, bits.B256{ .bytes = [32]u8{ 197, 210, 70, 1, 134, 247, 35, 60, 146, 126, 125, 178, 220, 199, 3, 192, 229, 0, 182, 83, 202, 130, 39, 59, 123, 250, 216, 4, 93, 133, 164, 112 } });
    try std.testing.expectEqualSlices(u8, state.AccountInfo.default().code.Some.bytecode, buf[0..]);
    try std.testing.expectEqual(state.AccountInfo.default().code.Some.state.Analysed.len, 0);
}

test "AccountInfo: eq function" {
    try std.testing.expectEqual(state.AccountInfo.eq(state.AccountInfo.default(), state.AccountInfo.default()), true);
}

test "AccountInfo: new function" {
    var lb = [_]usize{ 0, 0, 0, 0 };
    var buf: [1]u8 = .{0};
    var accountInfo = state.AccountInfo.new(std.math.big.int.Mutable.init(&state.AccountInfo.limbs, 0), 0, constants.Constants.KECCAK_EMPTY, bytecode.Bytecode.new());
    try std.testing.expectEqualSlices(usize, accountInfo.balance.limbs, lb[0..]);
    try std.testing.expectEqual(accountInfo.balance.len, 1);
    try std.testing.expectEqual(accountInfo.balance.positive, true);
    try std.testing.expectEqual(accountInfo.nonce, 0);
    try std.testing.expectEqual(accountInfo.code_hash, constants.Constants.KECCAK_EMPTY);
    try std.testing.expectEqualSlices(u8, accountInfo.code.Some.bytecode, buf[0..]);
    try std.testing.expectEqual(accountInfo.code.Some.state.Analysed.len, 0);
}

test "AccountInfo: is_empty function" {
    try std.testing.expectEqual(state.AccountInfo.is_empty(state.AccountInfo.default()), true);
}

test "AccountInfo: exists function" {
    try std.testing.expectEqual(state.AccountInfo.exists(state.AccountInfo.default()), false);
}

test "state.AccountInfo: code_hash function" {
    try std.testing.expectEqual(state.AccountInfo.default().get_code_hash(), constants.Constants.KECCAK_EMPTY);
}

test "AccountInfo: take_bytecode function" {
    var buf: [1]u8 = .{0};
    var accountInfo = state.AccountInfo.default();
    var result_take_bytecode = accountInfo.take_bytecode();
    try std.testing.expectEqualSlices(u8, result_take_bytecode.Some.bytecode, buf[0..]);
    try std.testing.expectEqual(result_take_bytecode.Some.state.Analysed.len, 0);
    try std.testing.expectEqual(accountInfo.take_bytecode().None, true);
}

test "AccountInfo: from_balance function" {
    var lb = [_]usize{ 100, 0, 0, 0 };
    var buf: [1]u8 = .{0};
    var balance = std.math.big.int.Mutable.init(&state.AccountInfo.limbs, 100);

    try std.testing.expectEqualSlices(usize, state.AccountInfo.from_balance(balance).balance.limbs, lb[0..]);
    try std.testing.expectEqual(state.AccountInfo.from_balance(balance).balance.len, 1);
    try std.testing.expectEqual(state.AccountInfo.from_balance(balance).balance.positive, true);
    try std.testing.expectEqual(state.AccountInfo.from_balance(balance).nonce, 0);
    try std.testing.expectEqual(state.AccountInfo.from_balance(balance).code_hash, constants.Constants.KECCAK_EMPTY);
    try std.testing.expectEqualSlices(u8, state.AccountInfo.from_balance(balance).code.Some.bytecode, buf[0..]);
    try std.testing.expectEqual(state.AccountInfo.from_balance(balance).code.Some.state.Analysed.len, 0);
}
