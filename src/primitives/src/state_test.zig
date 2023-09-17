const std = @import("std");
const state = @import("./state.zig");
const utils = @import("./utils.zig");
const constants = @import("./constants.zig");
const bytecode = @import("./bytecode.zig");
const bits = @import("./bits.zig");

// test "Fibonacci with managed" {
//     const begin = std.time.timestamp();

//     const Managed = std.math.big.int.Managed;

//     const allocator = std.heap.c_allocator;

//     var a = try Managed.initSet(allocator, 0);
//     defer a.deinit();

//     var b = try Managed.initSet(allocator, 1);
//     defer b.deinit();

//     var c = try Managed.init(allocator);
//     defer c.deinit();

//     var i: u128 = 0;

//     while (i < 1000000) : (i += 1) {
//         try c.add(&a, &b);

//         a.swap(&b);
//         b.swap(&c);
//     }

//     const as = try a.toString(allocator, 10, std.fmt.Case.lower);
//     defer allocator.free(as);

//     const end = std.time.timestamp();
//     std.debug.print("\nExecution time with managed: {any}\n", .{end - begin});
// }

test "State - StorageSlot : init" {
    var managed_int = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0);
    defer managed_int.deinit();

    const storage_slot = state.StorageSlot.init(managed_int);

    try std.testing.expect(storage_slot.original_value.limbs[0] == 0);
    try std.testing.expect(storage_slot.present_value.limbs[0] == 0);
}

test "State - StorageSlot : set" {
    var managed_int = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0);
    defer managed_int.deinit();

    var managed_int_2 = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 2);
    defer managed_int_2.deinit();

    var storage_slot = state.StorageSlot.init(managed_int);

    storage_slot.set(managed_int_2);

    try std.testing.expect(storage_slot.original_value.limbs[0] == 2);
}

test "State - StorageSlot : is_changed" {
    var managed_int = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0);
    defer managed_int.deinit();

    var managed_int_2 = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 2);
    defer managed_int_2.deinit();

    var storage_slot = state.StorageSlot.init(managed_int);

    storage_slot.set(managed_int_2);

    try std.testing.expect(storage_slot.is_changed() == true);
}

test "Account: self destruct functions" {
    var map = std.HashMap(std.math.big.int.Managed, state.StorageSlot, utils.BigIntContext(std.math.big.int.Managed), std.hash_map.default_max_load_percentage).init(std.testing.allocator);

    defer map.deinit();

    var big_int_0 = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0);
    defer big_int_0.deinit();

    try map.put(big_int_0, state.StorageSlot{ .original_value = big_int_0, .present_value = big_int_0 });

    var default_account = try state.AccountInfo.init();

    var account = state.Account{
        .info = default_account,
        .storage = map,
        .status = state.AccountStatus.init(),
    };
    account.mark_selfdestruct();
    try std.testing.expectEqual(account.status.SelfDestructed, true);
    try std.testing.expectEqual(account.is_selfdestructed(), true);
    account.unmark_selfdestruct();
    try std.testing.expectEqual(account.status.SelfDestructed, false);
    try std.testing.expectEqual(account.is_selfdestructed(), false);
}

test "Account: touched functions" {
    var map = std.HashMap(std.math.big.int.Managed, state.StorageSlot, utils.BigIntContext(std.math.big.int.Managed), std.hash_map.default_max_load_percentage).init(std.testing.allocator);
    defer map.deinit();

    var big_int_0 = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0);
    defer big_int_0.deinit();

    try map.put(big_int_0, state.StorageSlot{ .original_value = big_int_0, .present_value = big_int_0 });

    var default_account = try state.AccountInfo.init();

    var account = state.Account{
        .info = default_account,
        .storage = map,
        .status = state.AccountStatus.init(),
    };
    account.mark_touch();
    try std.testing.expectEqual(account.status.Touched, true);
    try std.testing.expectEqual(account.is_touched(), true);
    account.unmark_touch();
    try std.testing.expectEqual(account.status.Touched, false);
    try std.testing.expectEqual(account.is_touched(), false);
}

test "Account: created functions" {
    var map = std.HashMap(std.math.big.int.Managed, state.StorageSlot, utils.BigIntContext(std.math.big.int.Managed), std.hash_map.default_max_load_percentage).init(std.testing.allocator);
    defer map.deinit();

    var big_int_0 = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0);
    defer big_int_0.deinit();

    try map.put(big_int_0, state.StorageSlot{ .original_value = big_int_0, .present_value = big_int_0 });

    var default_account = try state.AccountInfo.init();

    var account = state.Account{
        .info = default_account,
        .storage = map,
        .status = state.AccountStatus.init(),
    };
    account.mark_created();
    try std.testing.expectEqual(account.status.Created, true);
    try std.testing.expectEqual(account.is_created(), true);
    account.unmark_created();
    try std.testing.expectEqual(account.status.Created, false);
    try std.testing.expectEqual(account.is_created(), false);
}

test "Account: is_empty function" {
    var map = std.HashMap(std.math.big.int.Managed, state.StorageSlot, utils.BigIntContext(std.math.big.int.Managed), std.hash_map.default_max_load_percentage).init(std.testing.allocator);
    defer map.deinit();

    var big_int_0 = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0);
    defer big_int_0.deinit();

    try map.put(big_int_0, state.StorageSlot{ .original_value = big_int_0, .present_value = big_int_0 });

    var default_account = try state.AccountInfo.init();

    var account = state.Account{
        .info = default_account,
        .storage = map,
        .status = state.AccountStatus.init(),
    };
    try std.testing.expectEqual(account.is_empty(), true);
}

test "Account: new_not_existing function" {
    var not_existing = try state.Account.new_not_existing(std.testing.allocator);

    try std.testing.expectEqual(not_existing.status.LoadedAsNotExisting, true);
}

test "AccountStatus: default function" {
    try std.testing.expectEqual(state.AccountStatus.init().Loaded, true);
}

test "AccountInfo: default function" {
    var lb = [_]usize{ 0, 0, 0, 0 };
    var buf: [1]u8 = .{0};

    var default_account = try state.AccountInfo.init();

    try std.testing.expectEqualSlices(usize, default_account.balance.limbs, lb[0..]);
    try std.testing.expectEqual(default_account.balance.len(), 1);
    try std.testing.expectEqual(default_account.balance.isPositive(), true);
    try std.testing.expectEqual(default_account.nonce, 0);
    try std.testing.expectEqual(default_account.code_hash, bits.B256{ .bytes = [32]u8{ 197, 210, 70, 1, 134, 247, 35, 60, 146, 126, 125, 178, 220, 199, 3, 192, 229, 0, 182, 83, 202, 130, 39, 59, 123, 250, 216, 4, 93, 133, 164, 112 } });
    try std.testing.expectEqualSlices(u8, default_account.code.Some.bytecode, buf[0..]);
    try std.testing.expectEqual(default_account.code.Some.state.Analysed.len, 0);
}

test "AccountInfo: eq function" {
    var default_account = try state.AccountInfo.init();

    try std.testing.expectEqual(state.AccountInfo.eq(default_account, default_account), true);
}

test "AccountInfo: new function" {
    var buf: [1]u8 = .{0};

    var managed = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0);
    defer managed.deinit();

    var managed_to_compare = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0);
    defer managed_to_compare.deinit();

    var accountInfo = state.AccountInfo.new(managed, 0, constants.Constants.KECCAK_EMPTY, bytecode.Bytecode.new());
    try std.testing.expect(accountInfo.balance.limbs[0] == 0);
    try std.testing.expectEqual(accountInfo.balance.len(), 1);
    try std.testing.expectEqual(accountInfo.balance.isPositive(), true);
    try std.testing.expectEqual(accountInfo.nonce, 0);
    try std.testing.expectEqual(accountInfo.code_hash, constants.Constants.KECCAK_EMPTY);
    try std.testing.expectEqualSlices(u8, accountInfo.code.Some.bytecode, buf[0..]);
    try std.testing.expectEqual(accountInfo.code.Some.state.Analysed.len, 0);
}

test "AccountInfo: is_empty function" {
    var default_account = try state.AccountInfo.init();

    try std.testing.expectEqual(state.AccountInfo.is_empty(default_account), true);
}

test "AccountInfo: exists function" {
    var default_account = try state.AccountInfo.init();

    try std.testing.expectEqual(state.AccountInfo.exists(default_account), false);
}

test "AccountInfo: code_hash function" {
    var default_account = try state.AccountInfo.init();

    try std.testing.expectEqual(default_account.get_code_hash(), constants.Constants.KECCAK_EMPTY);
}

test "AccountInfo: take_bytecode function" {
    var buf: [1]u8 = .{0};
    var default_account = try state.AccountInfo.init();

    var accountInfo = default_account;
    var result_take_bytecode = accountInfo.take_bytecode();
    try std.testing.expectEqualSlices(u8, result_take_bytecode.Some.bytecode, buf[0..]);
    try std.testing.expectEqual(result_take_bytecode.Some.state.Analysed.len, 0);
    try std.testing.expectEqual(accountInfo.take_bytecode().None, true);
}

test "AccountInfo: from_balance function" {
    var lb = [_]usize{ 100, 0, 0, 0 };
    _ = lb;
    var buf: [1]u8 = .{0};
    var balance = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 100);
    defer balance.deinit();

    try std.testing.expect(state.AccountInfo.from_balance(balance).balance.limbs[0] == 100);
    try std.testing.expectEqual(state.AccountInfo.from_balance(balance).balance.len(), 1);
    try std.testing.expectEqual(state.AccountInfo.from_balance(balance).balance.isPositive(), true);
    try std.testing.expectEqual(state.AccountInfo.from_balance(balance).nonce, 0);
    try std.testing.expectEqual(state.AccountInfo.from_balance(balance).code_hash, constants.Constants.KECCAK_EMPTY);
    try std.testing.expectEqualSlices(u8, state.AccountInfo.from_balance(balance).code.Some.bytecode, buf[0..]);
    try std.testing.expectEqual(state.AccountInfo.from_balance(balance).code.Some.state.Analysed.len, 0);
}
