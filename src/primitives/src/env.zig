const std = @import("std");
const bits = @import("./bits.zig");
const utils = @import("./utils.zig");
const constants = @import("./constants.zig");
const specifications = @import("./specifications.zig");
const kzg_env = @import("./kzg/env_settings.zig");

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

/// Ethereum Environment.
pub const Env = struct {
    const Self = @This();

    /// Configuration Environment Structure
    cfg: CfgEnv,
    /// Ethereum Block Environment.
    block: BlockEnv,
    /// Ethereum Transaction Environment.
    tx: TxEnv,

    pub fn default(allocator: std.mem.Allocator) !Self {
        return .{
            .cfg = CfgEnv.default(),
            .block = BlockEnv.default(),
            .tx = try TxEnv.default(allocator),
        };
    }

    /// Calculates the effective gas price of the transaction.
    pub fn effective_gas_price(self: Self) !u256 {
        if (self.tx.gas_priority_fee) |gas_priority_fee| {
            const basefee_plus_gas_priority_fee = self.block.base_fee + gas_priority_fee;

            return switch (self.tx.gas_price < basefee_plus_gas_priority_fee) {
                true => self.tx.gas_price,
                false => basefee_plus_gas_priority_fee,
            };
        }

        return self.tx.gas_price;
    }

    /// Calculates the [EIP-4844] `data_fee` of the transaction.
    ///
    /// Returns `None` if `Cancun` is not enabled. This is enforced in [`Env::validate_block_env`].
    ///
    /// [EIP-4844]: https://eips.ethereum.org/EIPS/eip-4844
    pub fn calc_data_fee(self: Self) ?u64 {
        // const blob_gas_price = self.block.get_blob_gasprice();
        // return if (blob_gas_price == null) null else blob_gas_price * self.tx.get_total_blob_gas();

        return self.block.get_blob_gasprice().? * self.tx.get_total_blob_gas();
    }

    /// Frees all associated memory.
    pub fn deinit(self: *Self) void {
        self.tx.deinit();
    }
};

pub const BlobExcessGasAndPrice = struct {
    const Self = @This();

    excess_blob_gas: u64,
    excess_blob_gasprice: u64,

    /// Takes excess blob gas and calculated blob fee with [`calc_blob_fee`]
    pub fn new(excess_blob_gas: u64) Self {
        return .{
            .excess_blob_gas = excess_blob_gas,
            .excess_blob_gasprice = utils.calc_blob_gasprice(excess_blob_gas),
        };
    }

    pub fn eql(self: Self, other: Self) bool {
        return self.excess_blob_gas == other.excess_blob_gas and self.excess_blob_gasprice == other.excess_blob_gasprice;
    }
};

/// Ethereum Block Environment.
pub const BlockEnv = struct {
    const Self = @This();

    /// The number of ancestor blocks of this block (block height)
    number: u256,
    /// Coinbase or miner or address that created and signed the block.
    ///
    /// This is the receiver address of all the gas spent in the block.
    coinbase: bits.B160,
    /// The timestamp of the block in seconds since the UNIX epoch.
    timestamp: u256,
    /// The gas limit of the block
    gas_limit: u256,
    /// The base fee per gas, added in the London upgrade with [EIP-1559].
    ///
    /// [EIP-1559]: https://eips.ethereum.org/EIPS/eip-1559
    base_fee: u256,
    /// The difficulty of the block.
    ///
    /// Unused after the Paris (AKA the merge) upgrade, and replaced by `prevrandao`.
    difficulty: u256,
    /// The output of the randomness beacon provided by the beacon chain.
    ///
    /// Replaces `difficulty` after the Paris (AKA the merge) upgrade with [EIP-4399].
    ///
    /// NOTE: `prevrandao` can be found in a block in place of `mix_hash`.
    ///
    /// [EIP-4399]: https://eips.ethereum.org/EIPS/eip-4399
    prev_randao: ?bits.B256,
    /// Excess blob gas and blob gasprice.
    /// See also [`calc_excess_blob_gas`](crate::calc_excess_blob_gas)
    /// and [`calc_blob_gasprice`](crate::calc_blob_gasprice).
    ///
    /// Incorporated as part of the Cancun upgrade via [EIP-4844].
    ///
    /// [EIP-4844]: https://eips.ethereum.org/EIPS/eip-4844
    blob_excess_gas_and_price: ?BlobExcessGasAndPrice,

    /// Returns the "default value" for each type.
    pub fn default() Self {
        return .{
            .number = 0,
            .coinbase = bits.B160.from(0),
            .timestamp = 0,
            .gas_limit = 0,
            .base_fee = 0,
            .difficulty = 0,
            .prev_randao = bits.B256.zero(),
            .blob_excess_gas_and_price = BlobExcessGasAndPrice.new(0),
        };
    }

    /// Takes `blob_excess_gas` saves it inside env
    /// and calculates `blob_fee` with [`BlobGasAndFee`].
    pub fn set_blob_excess_gas_and_price(self: *Self, excess_blob_gas: u64) void {
        self.blob_excess_gas_and_price = .{
            .excess_blob_gas = excess_blob_gas,
            .excess_blob_gasprice = 0,
        };
    }

    /// See [EIP-4844] and [`crate::calc_blob_gasprice`].
    ///
    /// Returns `None` if `Cancun` is not enabled. This is enforced in [`Env::validate_block_env`].
    ///
    /// [EIP-4844]: https://eips.ethereum.org/EIPS/eip-4844
    pub fn get_blob_gasprice(self: Self) ?u64 {
        return self.blob_excess_gas_and_price.?.excess_blob_gasprice;
    }

    /// Return `blob_excess_gas` header field. See [EIP-4844].
    ///
    /// Returns `None` if `Cancun` is not enabled. This is enforced in [`Env::validate_block_env`].
    ///
    /// [EIP-4844]: https://eips.ethereum.org/EIPS/eip-4844
    pub fn get_blob_excess_gas(self: Self) ?u64 {
        return self.blob_excess_gas_and_price.?.excess_blob_gas;
    }
};

/// Create scheme
pub const CreateScheme = union(enum) {
    /// Legacy create scheme of `CREATE`.
    Create,
    /// Create scheme of `CREATE2`.
    Create2: struct {
        /// Salt.
        salt: u256,
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
        return .{ .Create = .{ .scheme = .Create } };
    }

    /// Creates a contract with the given salt using `CREATE2`.
    pub fn create2(salt: u256) Self {
        return .{ .Create = .{ .scheme = .{ .Create2 = .{ .salt = salt } } } };
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

/// Ethereum Transaction Environment.
pub const TxEnv = struct {
    const Self = @This();

    /// The caller, author or signer of the transaction.
    caller: bits.B160,
    /// The gas limit of the transaction.
    gas_limit: u64,
    /// The gas price of the transaction.
    gas_price: u256,
    /// The destination of the transaction.
    transact_to: TransactTo,
    /// The value sent to `transact_to`.
    value: u256,
    /// The data of the transaction.
    data: []u8,
    /// The nonce of the transaction. If set to `None`, no checks are performed.
    nonce: ?u64,
    /// The chain ID of the transaction. If set to `None`, no checks are performed.
    ///
    /// Incorporated as part of the Spurious Dragon upgrade via [EIP-155].
    ///
    /// [EIP-155]: https://eips.ethereum.org/EIPS/eip-155
    chain_id: ?u64,
    /// A list of addresses and storage keys that the transaction plans to access.
    ///
    /// Added in [EIP-2930].
    ///
    /// [EIP-2930]: https://eips.ethereum.org/EIPS/eip-2930
    access_list: std.ArrayList(@TypeOf(.{ bits.B160, std.ArrayList(u256) })),
    /// The priority fee per gas.
    ///
    /// Incorporated as part of the London upgrade via [EIP-1559].
    ///
    /// [EIP-1559]: https://eips.ethereum.org/EIPS/eip-1559
    gas_priority_fee: ?u256,
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
    max_fee_per_blob_gas: ?u256,

    pub fn default(allocator: std.mem.Allocator) !Self {
        return .{
            .caller = bits.B160.from(0),
            .gas_limit = constants.Constants.UINT_64_MAX,
            .gas_price = 0,
            .gas_priority_fee = null,
            .transact_to = .{ .Call = .{ .to = bits.B160.from(0) } },
            .value = 0,
            .data = undefined,
            .chain_id = null,
            .nonce = null,
            .access_list = std.ArrayList(@TypeOf(.{ bits.B160, std.ArrayList(u256) })).init(allocator),
            .blob_hashes = std.ArrayList(bits.B256).init(allocator),
            .max_fee_per_blob_gas = null,
        };
    }

    /// See [EIP-4844] and [`Env::calc_data_fee`].
    ///
    /// [EIP-4844]: https://eips.ethereum.org/EIPS/eip-4844
    pub fn get_total_blob_gas(self: *Self) u64 {
        return constants.Constants.GAS_PER_BLOB * @as(u64, self.blob_hashes.items.len);
    }

    /// Frees all associated memory.
    pub fn deinit(self: *Self) void {
        self.access_list.deinit();
        self.blob_hashes.deinit();
    }
};

/// Enumeration representing analysis options for bytecode.
pub const AnalysisKind = enum {
    const Self = @This();

    /// Do not perform bytecode analysis.
    Raw,
    /// Check the bytecode for validity.
    Check,
    /// Perform bytecode analysis.
    Analyze,

    pub fn default() Self {
        return .Analyze;
    }
};

/// Configuration Environment Structure
pub const CfgEnv = struct {
    const Self = @This();

    /// Unique identifier for the blockchain chain.
    chain_id: u64,
    /// Specification identifier.
    spec_id: specifications.SpecId,
    /// KZG Settings for point evaluation precompile. By default, loaded from the Ethereum mainnet trusted setup.
    kzg_settings: kzg_env.EnvKzgSettings,
    /// Bytecode that is created with CREATE/CREATE2 is by default analyzed, and a jumptable is created.
    ///
    /// This is very beneficial for testing and speeds up execution of that bytecode if called multiple times.
    /// Default: Analyze
    perf_analyze_created_bytecodes: AnalysisKind,
    /// If some it will affect EIP-170: Contract code size limit. Useful to increase this because of tests.
    /// Default: 0x6000 (~25kb)
    limit_contract_code_size: ?usize,
    /// Disables the coinbase tip during the finalization of the transaction. Useful for rollups that redirect the tip to the sequencer.
    disable_coinbase_tip: bool,
    /// A hard memory limit in bytes beyond which [Memory] cannot be resized.
    ///
    /// In cases where the gas limit may be extraordinarily high, it is recommended to set this to
    /// a sane value to prevent memory allocation panics. Defaults to `2^32 - 1` bytes per EIP-1985.
    memory_limit: u64,
    /// Skip balance checks if true. Adds transaction cost to balance to ensure execution doesn't fail.
    disable_balance_check: bool,
    /// There are use cases where it's allowed to provide a gas limit that's higher than a block's gas limit. To that
    /// end, you can disable the block gas limit validation.
    ///
    /// By default, it is set to `false`.
    disable_block_gas_limit: bool,
    /// EIP-3607 rejects transactions from senders with deployed code. In development, it can be desirable to simulate
    /// calls from contracts, which this setting allows.
    ///
    /// By default, it is set to `false`.
    disable_eip3607: bool,
    /// Disables all gas refunds. This is useful when using chains that have gas refunds disabled e.g. Avalanche.
    ///
    /// Reasoning behind removing gas refunds can be found in EIP-3298.
    /// By default, it is set to `false`.
    disable_gas_refund: bool,
    /// Disables base fee checks for EIP-1559 transactions.
    /// This is useful for testing method calls with zero gas price.
    disable_base_fee: bool,

    pub fn default() Self {
        return .{
            .chain_id = 1,
            .spec_id = .LATEST,
            .perf_analyze_created_bytecodes = AnalysisKind.default(),
            .limit_contract_code_size = null,
            .disable_coinbase_tip = false,
            .kzg_settings = .Default,
            .memory_limit = (1 << 32) - 1,
            .disable_balance_check = false,
            .disable_block_gas_limit = false,
            .disable_eip3607 = false,
            .disable_gas_refund = false,
            .disable_base_fee = false,
        };
    }

    /// Returns `true` if EIP-3607 check is disabled.
    pub fn is_eip3607_disabled(self: Self) bool {
        return self.disable_eip3607;
    }

    /// Returns `true` if balance checks are disabled.
    pub fn is_balance_check_disabled(self: Self) bool {
        self.disable_balance_check;
    }

    /// Returns `true` if gas refunds are disabled.
    pub fn is_gas_refund_disabled(self: Self) bool {
        self.disable_gas_refund;
    }

    /// Returns `true` if base fee checks for EIP-1559 transactions are disabled.
    pub fn is_base_fee_check_disabled(self: Self) bool {
        self.disable_base_fee;
    }

    /// Returns `true` if block gas limit validation is disabled.
    pub fn is_block_gas_limit_disabled(self: Self) bool {
        return self.disable_block_gas_limit;
    }
};

test "Block env: Init" {
    var block_env = BlockEnv.default();

    try expectEqual(@as(u256, 0), block_env.base_fee);
    try expectEqual(@as(u256, 0), block_env.number);
    try expectEqual(@as(u256, 0), block_env.timestamp);
    try expectEqual(@as(u256, 0), block_env.gas_limit);
    try expectEqual(@as(u256, 0), block_env.difficulty);
    try expect(block_env.blob_excess_gas_and_price.?.eql(.{ .excess_blob_gas = 0, .excess_blob_gasprice = 1 }));
    try expectEqual(
        bits.B160{ .bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } },
        block_env.coinbase,
    );
    try expect(block_env.prev_randao.?.is_zero());
}

test "Block env: set_blob_excess_gas_and_price and get_blob_excess_gas" {
    var block_env = BlockEnv.default();

    block_env.set_blob_excess_gas_and_price(10);

    try expectEqual(@as(u64, 10), block_env.blob_excess_gas_and_price.?.excess_blob_gas);
    try expectEqual(@as(?u64, 10), block_env.get_blob_excess_gas());
    try expectEqual(@as(?u64, 0), block_env.get_blob_gasprice());
}

test "Block env: new" {
    try expect(
        BlobExcessGasAndPrice.new(0).eql(.{
            .excess_blob_gas = 0,
            .excess_blob_gasprice = 1,
        }),
    );
    try expect(BlobExcessGasAndPrice.new(2314057).eql(.{
        .excess_blob_gas = 2314057,
        .excess_blob_gasprice = 1,
    }));
    try expect(BlobExcessGasAndPrice.new(2314058).eql(BlobExcessGasAndPrice{
        .excess_blob_gas = 2314058,
        .excess_blob_gasprice = 2,
    }));
    try expect(BlobExcessGasAndPrice.new(10 * 1024 * 1024).eql(BlobExcessGasAndPrice{
        .excess_blob_gas = 10 * 1024 * 1024,
        .excess_blob_gasprice = 23,
    }));
}

test "TxEnv: get_total_blob_gas function" {
    var default_tx_env = try TxEnv.default(std.testing.allocator);
    default_tx_env.deinit();
    try expectEqual(@as(u64, 0), default_tx_env.get_total_blob_gas());
}

test "TransactTo: call function" {
    try expectEqual(
        TransactTo{ .Call = .{ .to = bits.B160.from(18_446_744_073_709_551_615) } },
        TransactTo.call(bits.B160.from(18_446_744_073_709_551_615)),
    );
}

test "TransactTo: create function" {
    try expectEqual(
        TransactTo{ .Create = .{ .scheme = .Create } },
        TransactTo.create(),
    );
}

test "TransactTo: create2 function" {
    try expectEqual(
        TransactTo{ .Create = .{ .scheme = .{ .Create2 = .{ .salt = 10000000000000000000000000000000 } } } },
        TransactTo.create2(10000000000000000000000000000000),
    );
}

test "TransactTo: is_call function" {
    var create2 = TransactTo.create2(10000000000000000000000000000000);
    try expect(!create2.is_call());

    var call = TransactTo.call(bits.B160.from(18_446_744_073_709_551_615));
    try expect(call.is_call());
}

test "TransactTo: is_create function" {
    var create = TransactTo.create();
    try expect(create.is_create());

    var call = TransactTo.call(bits.B160.from(18_446_744_073_709_551_615));
    try expect(!call.is_create());

    var create2 = TransactTo.create2(10000000000000000000000000000000);
    try expect(create2.is_create());
}

test "Env: effective_gas_price without gas_priority_fee" {
    var env_default = try Env.default(std.testing.allocator);
    defer env_default.deinit();
    try expectEqual(@as(u256, 0), try Env.effective_gas_price(env_default));
}

test "Env: effective_gas_price with gas_priority_fee returning gas_price" {
    var tx_env = TxEnv{
        .caller = bits.B160.from(0),
        .gas_limit = constants.Constants.UINT_64_MAX,
        .gas_price = 1,
        .gas_priority_fee = 10,
        .transact_to = .{ .Call = .{ .to = bits.B160.from(0) } },
        .value = 0,
        .data = undefined,
        .chain_id = null,
        .nonce = null,
        .access_list = std.ArrayList(@TypeOf(.{ bits.B160, std.ArrayList(u256) })).init(std.testing.allocator),
        .blob_hashes = std.ArrayList(bits.B256).init(std.testing.allocator),
        .max_fee_per_blob_gas = null,
    };
    defer tx_env.deinit();

    try expectEqual(
        @as(u256, 1),
        try Env.effective_gas_price(.{
            .block = BlockEnv.default(),
            .cfg = CfgEnv.default(),
            .tx = tx_env,
        }),
    );
}

test "Env: effective_gas_price with gas_priority_fee returning gas_priority_fee + base_fee" {
    var tx_env = TxEnv{
        .caller = bits.B160.from(0),
        .gas_limit = constants.Constants.UINT_64_MAX,
        .gas_price = 11,
        .gas_priority_fee = 10,
        .transact_to = .{ .Call = .{ .to = bits.B160.from(0) } },
        .value = 0,
        .data = undefined,
        .chain_id = null,
        .nonce = null,
        .access_list = std.ArrayList(@TypeOf(.{ bits.B160, std.ArrayList(u256) })).init(std.testing.allocator),
        .blob_hashes = std.ArrayList(bits.B256).init(std.testing.allocator),
        .max_fee_per_blob_gas = null,
    };
    defer tx_env.deinit();

    try expectEqual(
        @as(u256, 10),
        try Env.effective_gas_price(.{
            .block = BlockEnv.default(),
            .cfg = CfgEnv.default(),
            .tx = tx_env,
        }),
    );
}
