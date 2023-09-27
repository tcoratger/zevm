const std = @import("std");
const bits = @import("./bits.zig");
const utils = @import("./utils.zig");
const constants = @import("./constants.zig");

pub const BlobExcessGasAndPrice = struct {
    excess_blob_gas: u64,
    excess_blob_gasprice: u64,
};

pub const BlockEnv = struct {
    const Self = @This();

    // The number of ancestor blocks of this block (block height)
    number: std.math.big.int.Managed,
    // The miner or the address that created and signed this block
    coinbase: bits.B160,
    // The timestamp of the block
    timestamp: std.math.big.int.Managed,
    // The gas limit of the block
    gas_limit: std.math.big.int.Managed,
    // The base fee per gas, added in the London upgrade with [EIP-1559]
    base_fee: std.math.big.int.Managed,
    // The output of the randomness beacon provided by the beacon chain
    prev_randao: ?bits.B256,
    // Excess blob gas. See also ['calc_express_blob_gas']
    excess_blob_gas: ?BlobExcessGasAndPrice,

    pub fn init() !Self {
        return .{
            .number = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0),
            .coinbase = bits.B160.from(0),
            .timestamp = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0),
            .gas_limit = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0),
            .base_fee = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0),
            .prev_randao = null,
            .excess_blob_gas = null,
        };
    }

    pub fn set_blob_excess_gas_and_price(self: *Self, excess_blob_gas: u64) void {
        self.excess_blob_gas = .{.excess_blob_gas = excess_blob_gas, .excess_blob_gasprice = 0};
    }

    pub fn get_blob_gasprice(self: Self) ?u64 {
        return self.excess_blob_gas.?.excess_blob_gasprice;
    }

    pub fn get_blob_excess_gas(self: Self) ?u64 {
        return self.excess_blob_gas.?.excess_blob_gas;
    }
};

/// Create scheme
pub const CreateScheme = union(enum) {
    /// Legacy create scheme of `CREATE`.
    Create,
    /// Create scheme of `CREATE2`.
    Create2: struct {
        /// Salt.
        salt: std.math.big.int.Managed,
    },
};

/// Transaction destination.
pub const TransactTo = union(enum) {
    const Self = @This();

    /// Simple call to an address.
    Call: struct { to: bits.B160 },
    /// Contract creation.
    Create: struct { scheme: CreateScheme },

    /// Calls the given address.
    pub fn call(address: bits.B160) Self {
        return .{ .Call = .{ .to = address } };
    }

    /// Creates a contract.
    pub fn create() Self {
        return .{ .Create = .{ .scheme = CreateScheme.Create } };
    }

    /// Creates a contract with the given salt using `CREATE2`.
    pub fn create2(salt: std.math.big.int.Managed) Self {
        return .{ .Create = .{ .scheme = CreateScheme{ .Create2 = .{ .salt = salt } } } };
    }

    /// Returns `true` if the transaction is `Call`.
    pub fn is_call(self: *Self) bool {
        return switch (self.*) {
            .Call => true,
            else => false,
        };
    }

    /// Returns `true` if the transaction is `Create` or `Create2`.
    pub fn is_create(self: *Self) bool {
        return switch (self.*) {
            .Create => true,
            else => false,
        };
    }
};

pub const TxEnv = struct {
    const Self = @This();

    /// The caller, author or signer of the transaction.
    caller: bits.B160,
    /// The gas limit of the transaction.
    gas_limit: u64,
    /// The gas price of the transaction.
    gas_price: std.math.big.int.Managed,
    /// The destination of the transaction.
    transact_to: TransactTo,
    /// The value sent to `transact_to`.
    value: std.math.big.int.Managed,
    /// The data of the transaction.
    data: []u8,
    /// The nonce of the transaction. If set to `None`, no checks are performed.
    nonce: utils.Option(u64),
    /// The chain ID of the transaction. If set to `None`, no checks are performed.
    ///
    /// Incorporated as part of the Spurious Dragon upgrade via [EIP-155].
    ///
    /// [EIP-155]: https://eips.ethereum.org/EIPS/eip-155
    chain_id: utils.Option(u64),
    /// A list of addresses and storage keys that the transaction plans to access.
    ///
    /// Added in [EIP-2930].
    ///
    /// [EIP-2930]: https://eips.ethereum.org/EIPS/eip-2930
    access_list: std.ArrayList(@TypeOf(.{ bits.B160, std.ArrayList(std.math.big.int.Managed) })),
    /// The priority fee per gas.
    ///
    /// Incorporated as part of the London upgrade via [EIP-1559].
    ///
    /// [EIP-1559]: https://eips.ethereum.org/EIPS/eip-1559
    gas_priority_fee: utils.Option(std.math.big.int.Managed),
    /// The list of blob versioned hashes. Per EIP there should be at least
    /// one blob present if [`Self::max_fee_per_blob_gas`] is `Some`.
    ///
    /// Incorporated as part of the Cancun upgrade via [EIP-4844].
    ///
    /// [EIP-4844]: https://eips.ethereum.org/EIPS/eip-4844
    blob_hashes: std.ArrayList(bits.B256),
    /// The max fee per blob gas.
    ///
    /// Incorporated as part of the Cancun upgrade via [EIP-4844].
    ///
    /// [EIP-4844]: https://eips.ethereum.org/EIPS/eip-4844
    max_fee_per_blob_gas: utils.Option(std.math.big.int.Managed),

    pub fn default(allocator: std.mem.Allocator) !Self {
        var gas_price_default = try std.math.big.int.Managed.initSet(allocator, 0);
        var value_default = try std.math.big.int.Managed.initSet(allocator, 0);
        var access_list_default = std.ArrayList(@TypeOf(.{ bits.B160, std.ArrayList(std.math.big.int.Managed) })).init(allocator);
        var blob_hashes_default = std.ArrayList(bits.B256).init(allocator);
        defer gas_price_default.deinit();
        defer value_default.deinit();
        defer access_list_default.deinit();
        defer blob_hashes_default.deinit();
        return .{
            .caller = bits.B160.from(0),
            .gas_limit = constants.Constants.UINT_64_MAX,
            .gas_price = gas_price_default,
            .gas_priority_fee = utils.Option(std.math.big.int.Managed){ .None = true },
            .transact_to = TransactTo{ .Call = .{ .to = bits.B160.from(0) } },
            .value = value_default,
            .data = undefined,
            .chain_id = utils.Option(u64){ .None = true },
            .nonce = utils.Option(u64){ .None = true },
            .access_list = access_list_default,
            .blob_hashes = blob_hashes_default,
            .max_fee_per_blob_gas = utils.Option(std.math.big.int.Managed){ .None = true },
        };
    }

    /// See [EIP-4844] and [`Env::calc_data_fee`].
    ///
    /// [EIP-4844]: https://eips.ethereum.org/EIPS/eip-4844
    pub fn get_total_blob_gas(self: *Self) u64 {
        return constants.Constants.GAS_PER_BLOB * @as(u64, self.blob_hashes.items.len);
    }
};
