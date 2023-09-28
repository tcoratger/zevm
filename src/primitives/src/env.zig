const std = @import("std");
const bits = @import("./bits.zig");
const utils = @import("./utils.zig");
const constants = @import("./constants.zig");
const specifications = @import("./specifications.zig");
const kzg_env = @import("./kzg/env_settings.zig");

pub const BlobExcessGasAndPrice = struct {
    const Self = @This();

    excess_blob_gas: u64,
    excess_blob_gasprice: u64,

    /// Takes excess blob gas and calculated blob fee with [`calc_blob_fee`]
    pub fn new(excess_blob_gas: u64) Self {
        return .{ .excess_blob_gas = excess_blob_gas, .excess_blob_gasprice = utils.calc_blob_gasprice(excess_blob_gas) };
    }

    pub fn eql(self: Self, other: Self) bool {
        return self.excess_blob_gas == other.excess_blob_gas and self.excess_blob_gasprice == other.excess_blob_gasprice;
    }
};

pub const BlockEnv = struct {
    const Self = @This();

    /// The number of ancestor blocks of this block (block height)
    number: std.math.big.int.Managed,
    /// Coinbase or miner or address that created and signed the block.
    ///
    /// This is the receiver address of all the gas spent in the block.
    coinbase: bits.B160,
    /// The timestamp of the block in seconds since the UNIX epoch.
    timestamp: std.math.big.int.Managed,
    /// The gas limit of the block
    gas_limit: std.math.big.int.Managed,
    /// The base fee per gas, added in the London upgrade with [EIP-1559].
    ///
    /// [EIP-1559]: https://eips.ethereum.org/EIPS/eip-1559
    base_fee: std.math.big.int.Managed,
    /// The difficulty of the block.
    ///
    /// Unused after the Paris (AKA the merge) upgrade, and replaced by `prevrandao`.
    difficulty: std.math.big.int.Managed,
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
    pub fn default() !Self {
        return .{
            .number = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0),
            .coinbase = bits.B160.from(0),
            .timestamp = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0),
            .gas_limit = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0),
            .base_fee = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0),
            .difficulty = try std.math.big.int.Managed.initSet(std.heap.c_allocator, 0),
            .prev_randao = bits.B256.zero(),
            .blob_excess_gas_and_price = BlobExcessGasAndPrice.new(0),
        };
    }

    /// Takes `blob_excess_gas` saves it inside env
    /// and calculates `blob_fee` with [`BlobGasAndFee`].
    pub fn set_blob_excess_gas_and_price(self: *Self, excess_blob_gas: u64) void {
        self.blob_excess_gas_and_price = .{ .excess_blob_gas = excess_blob_gas, .excess_blob_gasprice = 0 };
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

/// Enumeration representing analysis options for bytecode.
pub const AnalysisKind = enum {
    /// Do not perform bytecode analysis.
    Raw,
    /// Check the bytecode for validity.
    Check,
    /// Perform bytecode analysis.
    Analyze,
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
