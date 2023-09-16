const std = @import("std");
const state = @import("./state.zig");

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
    const allocator = std.heap.c_allocator;

    const managed_int = std.math.big.int.Managed.initSet(allocator, 0);
    const storageSlot = state.StorageSlot.init(managed_int);

    std.debug.print("{}\n", .{storageSlot});
}
