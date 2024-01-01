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

    pub fn init(allocator: std.mem.Allocator) !Self {
        return .{
            .cfg = CfgEnv.init(),
            .block = BlockEnv.init(),
            .tx = try TxEnv.init(allocator),
        };
    }

    /// Calculates the effective gas price of the transaction.
    pub fn effective_gas_price(self: Self) !u256 {
        if (self.tx.gas_priority_fee) |gas_priority_fee| {
            const basefee_plus_gas_priority_fee = self.block.base_fee + gas_priority_fee;

            return switch (std.math.order(self.tx.gas_price, basefee_plus_gas_priority_fee)) {
                .lt => self.tx.gas_price,
                else => basefee_plus_gas_priority_fee,
            };
        }

        return self.tx.gas_price;
    }

    /// Calculates the [EIP-4844] `data_fee` of the transaction.
    ///
    /// Returns `None` if `Cancun` is not enabled. This is enforced in [`Env::validate_block_env`].
    ///
    /// [EIP-4844]: https://eips.ethereum.org/EIPS/eip-4844
    pub fn calcDataFee(self: Self) ?u64 {
        return self.block.getBlobGasprice().? * self.tx.get_total_blob_gas();
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
    pub fn init(excess_blob_gas: u64) Self {
        return .{
            .excess_blob_gas = excess_blob_gas,
            .excess_blob_gasprice = utils.calcBlobGasprice(excess_blob_gas),
        };
    }

    pub fn eql(self: Self, other: Self) bool {
        return self.excess_blob_gas == other.excess_blob_gas and
            self.excess_blob_gasprice == other.excess_blob_gasprice;
    }
};

/// Ethereum Block Environment.
pub const BlockEnv = struct {
    const Self = @This();

    /// Represents the number of ancestor blocks or the block height.
    ///
    /// `number` corresponds to a scalar value equal to the number of ancestor blocks. The genesis block holds a number of zero.
    ///
    /// The block number is the parent’s block number incremented by one.
    number: u256,
    /// Refers to the address that receives all fees collected from successfully mining this block.
    ///
    /// `coinbase` represents the receiver address where all the gas spent in the block is deposited.
    coinbase: bits.B160,
    /// The timestamp of the block in seconds since the UNIX epoch.
    timestamp: u256,
    /// Indicates the current limit of gas expenditure per block.
    ///
    /// `gas_limit` denotes the maximum amount of gas that can be spent within the block.
    gas_limit: u256,
    /// The base fee per gas, added in the London upgrade with [EIP-1559].
    ///
    /// [EIP-1559]: https://eips.ethereum.org/EIPS/eip-1559
    base_fee: u256,
    /// Represents the difficulty level of the block.
    ///
    /// `difficulty` refers to a scalar value corresponding to the difficulty level of the block.
    ///
    /// It was utilized up until the Paris upgrade (also known as the merge) and has been replaced by `prevrandao`.
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
    /// See also [`calcExcessBlobGas`](crate::calcExcessBlobGas)
    /// and [`calcBlobGasprice`](crate::calcBlobGasprice).
    ///
    /// Incorporated as part of the Cancun upgrade via [EIP-4844].
    ///
    /// [EIP-4844]: https://eips.ethereum.org/EIPS/eip-4844
    blob_excess_gas_and_price: ?BlobExcessGasAndPrice,

    /// Returns the "default value" for each type.
    pub fn init() Self {
        return .{
            .number = 0,
            .coinbase = bits.B160.from(0),
            .timestamp = 0,
            .gas_limit = 0,
            .base_fee = 0,
            .difficulty = 0,
            .prev_randao = bits.B256.zero(),
            .blob_excess_gas_and_price = BlobExcessGasAndPrice.init(0),
        };
    }

    /// Takes `blob_excess_gas` saves it inside env
    /// and calculates `blob_fee` with [`BlobGasAndFee`].
    pub fn setBlobExcessGasAndPrice(self: *Self, excess_blob_gas: u64) void {
        self.blob_excess_gas_and_price = .{
            .excess_blob_gas = excess_blob_gas,
            .excess_blob_gasprice = 0,
        };
    }

    /// See [EIP-4844] and [`crate::calcBlobGasprice`].
    ///
    /// Returns `None` if `Cancun` is not enabled. This is enforced in [`Env::validate_block_env`].
    ///
    /// [EIP-4844]: https://eips.ethereum.org/EIPS/eip-4844
    pub fn getBlobGasprice(self: Self) ?u64 {
        return self.blob_excess_gas_and_price.?.excess_blob_gasprice;
    }

    /// Return `blob_excess_gas` header field. See [EIP-4844].
    ///
    /// Returns `None` if `Cancun` is not enabled. This is enforced in [`Env::validate_block_env`].
    ///
    /// [EIP-4844]: https://eips.ethereum.org/EIPS/eip-4844
    pub fn getBlobExcessGas(self: Self) ?u64 {
        return self.blob_excess_gas_and_price.?.excess_blob_gas;
    }
};

/// Create scheme for contract deployment within the Ethereum Virtual Machine (EVM).
///
/// The `CreateScheme` union enum encapsulates different contract creation schemes utilized within the Ethereum network.
/// It provides a mechanism to delineate between distinct methods of generating contract addresses based on specific
/// opcodes or proposals within the Ethereum ecosystem.
///
/// This union enum currently encompasses two major contract creation schemes: `Create` and `Create2`.
///
/// - `Create`: Represents the conventional contract creation scheme within the EVM, employing the `CREATE` opcode (0xf0).
///   Contract addresses are derived using the sender's address and nonce, providing deterministic but non-predictable
///   address derivation. Each new contract creation by the same sender increments the nonce, ensuring unique addresses
///   for each contract deployment.
///
/// - `Create2`: Embodies the creation scheme introduced by Ethereum Improvement Proposal 1014 (EIP-1014) known as
///   `CREATE2`. This scheme utilizes the `CREATE2` opcode (0xf5) and involves a salted address derivation mechanism
///   for deploying contracts on-chain. It enables interactions with addresses that don't exist on-chain yet, ensuring
///   deterministic and predictable address derivation through the use of a specified salt value.
///
/// The documentation for each instance within this union enum provides detailed information on the specific contract
/// creation methodology and the associated references for further understanding.
///
/// References:
/// - Ethereum Yellow Paper: https://ethereum.github.io/yellowpaper/paper.pdf
/// - EIP-1014: https://eips.ethereum.org/EIPS/eip-1014
pub const CreateScheme = union(enum) {
    /// Legacy create scheme of `CREATE`.
    ///
    /// The `Create` instance represents the traditional contract creation scheme within the Ethereum Virtual Machine (EVM),
    /// where the contract address is derived using the sender's address and nonce, via the `CREATE` opcode (0xf0).
    ///
    /// This method generates contract addresses by hashing the sender's address and nonce, providing a deterministic but
    /// non-predictable address derivation. Each new contract creation by the same sender increments the nonce, ensuring
    /// unique addresses for each contract deployment.
    ///
    /// Reference:
    /// - Ethereum Yellow Paper: https://ethereum.github.io/yellowpaper/paper.pdf
    Create,
    /// Create scheme for the `CREATE2` opcode based on EIP-1014 specifications.
    ///
    /// The `Create2` instance represents the creation scheme introduced by the Ethereum
    /// Improvement Proposal 1014 (EIP-1014) known as `CREATE2`.
    ///
    /// EIP-1014 introduces a new opcode, `CREATE2` at `0xf5`, extending the functionality
    /// of contract creation within the Ethereum Virtual Machine (EVM). This opcode utilizes
    /// a salted address derivation mechanism for deploying contracts on-chain.
    ///
    /// The `Create2` instance encapsulates this scheme, specifically handling the derivation
    /// of contract addresses using a salt value. The `salt` field within `Create2` is employed
    /// during the contract address calculation process as specified in EIP-1014.
    ///
    /// This enhancement in contract creation allows interactions with addresses that don't exist
    /// on-chain yet, providing deterministic address derivation. It is pivotal for use cases like
    /// state channels, enabling counterfactual interactions with contracts, even before their
    /// actual existence on the blockchain.
    ///
    /// Reference:
    /// - EIP-1014: https://eips.ethereum.org/EIPS/eip-1014
    ///
    /// Please cite EIP-1014 as:
    /// Vitalik Buterin (@vbuterin), "EIP-1014: Skinny CREATE2," Ethereum Improvement Proposals,
    /// no. 1014, April 2018. [Online serial]. Available: https://eips.ethereum.org/EIPS/eip-1014
    Create2: struct {
        /// Salt used for contract address derivation based on EIP-1014.
        ///
        /// In accordance with EIP-1014, this salt is used in the CREATE2 opcode
        /// to derive the contract address from the `init_code`, sender's address,
        /// and the specified salt value.
        ///
        /// This salt allows interactions to occur with addresses that don't yet
        /// exist on-chain, ensuring deterministic and predictable address derivation.
        ///
        /// Reference: https://eips.ethereum.org/EIPS/eip-1014
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
    /// Represents the gas limit of the transaction.
    ///
    /// The `gas_limit` field denotes a scalar value that defines the maximum amount of gas allowed
    /// for executing this transaction. This gas limit is paid upfront, before any computation begins,
    /// and it cannot be increased later during the transaction execution process.
    ///
    /// It is a crucial parameter as it determines the upper limit of computational steps or operations
    /// that can be performed by the transaction before it terminates. Exceeding this limit leads to
    /// the termination of the transaction's execution.
    gas_limit: u64,
    /// Represents the transaction's gas price, denoting the number of Wei to be paid per unit of gas.
    ///
    /// The `gas_price` field stands for the value paid for each unit of gas utilized during the execution of
    /// the transaction, expressed in Wei.
    gas_price: u256,
    /// Represents the destination of the transaction.
    ///
    /// The `transact_to` field signifies the 160-bit address of the recipient in a message call. In the
    /// case of a contract creation transaction, it's denoted as ∅, which signifies the sole member of
    /// the empty set B0.
    ///
    /// This field designates where the transaction is directed. For regular transactions, it identifies
    /// the address of the intended recipient of the transaction, while for contract creation transactions,
    /// it symbolizes the absence of a specific recipient (hence the symbol ∅ representing the empty set).
    transact_to: TransactTo,
    /// Represents the value sent to the recipient of the transaction.
    ///
    /// The `value` field signifies a scalar value equal to the number of Wei intended to be transferred
    /// to the message call’s recipient. In the case of a contract creation transaction, this value serves
    /// as an endowment to the newly created account.
    ///
    /// This field denotes the amount of Wei to be transferred with the transaction, whether to a regular
    /// recipient or as an endowment for a newly created contract.
    value: u256,
    /// Represents the transaction's input data, which is an array of unlimited size containing bytes.
    ///
    /// The `data` field stands for the input data of the message call, formally denoted as an array of bytes (`[]u8`).
    data: []u8,

    /// The nonce of the transaction. If set to `null`, no checks are performed.
    nonce: ?u64,
    /// The chain ID of the transaction. If set to `null`, no checks are performed.
    ///
    /// Incorporated as part of the Spurious Dragon upgrade via [EIP-155].
    ///
    /// [EIP-155]: https://eips.ethereum.org/EIPS/eip-155
    chain_id: ?u64,
    /// Represents a list of addresses and associated storage keys that the transaction intends to access.
    ///
    /// The `access_list` field embodies a list of access entries that serve as a pre-warmed set. Each access
    /// entry consists of a tuple comprising an account address (`Ea`) and a list of associated storage keys (`Es`).
    ///
    /// Introduced in [EIP-2930].
    ///
    /// [EIP-2930]: https://eips.ethereum.org/EIPS/eip-2930
    access_list: std.ArrayList(std.meta.Tuple(&.{
        bits.B160,
        std.ArrayList(u256),
    })),
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

    pub fn init(allocator: std.mem.Allocator) !Self {
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
            .access_list = std.ArrayList(std.meta.Tuple(&.{
                bits.B160,
                std.ArrayList(u256),
            })).init(allocator),
            .blob_hashes = std.ArrayList(bits.B256).init(allocator),
            .max_fee_per_blob_gas = null,
        };
    }

    /// See [EIP-4844] and [`Env::calcDataFee`].
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

    pub fn init() Self {
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

    pub fn init() Self {
        return .{
            .chain_id = 1,
            .spec_id = .LATEST,
            .perf_analyze_created_bytecodes = AnalysisKind.init(),
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
    pub fn isEip3607Disabled(self: Self) bool {
        return self.disable_eip3607;
    }

    /// Returns `true` if balance checks are disabled.
    pub fn isBalanceCheckDisabled(self: Self) bool {
        self.disable_balance_check;
    }

    /// Returns `true` if gas refunds are disabled.
    pub fn isGasRefundDisabled(self: Self) bool {
        self.disable_gas_refund;
    }

    /// Returns `true` if base fee checks for EIP-1559 transactions are disabled.
    pub fn isBaseFeeCheckDisabled(self: Self) bool {
        self.disable_base_fee;
    }

    /// Returns `true` if block gas limit validation is disabled.
    pub fn isBlockGasLimitDisabled(self: Self) bool {
        return self.disable_block_gas_limit;
    }
};

test "Block env: Init" {
    var block_env = BlockEnv.init();

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
    try expect(block_env.prev_randao.?.isZero());
}

test "Block env: setBlobExcessGasAndPrice and getBlobExcessGas" {
    var block_env = BlockEnv.init();

    block_env.setBlobExcessGasAndPrice(10);

    try expectEqual(@as(u64, 10), block_env.blob_excess_gas_and_price.?.excess_blob_gas);
    try expectEqual(@as(?u64, 10), block_env.getBlobExcessGas());
    try expectEqual(@as(?u64, 0), block_env.getBlobGasprice());
}

test "Block env: new" {
    try expect(
        BlobExcessGasAndPrice.init(0).eql(.{
            .excess_blob_gas = 0,
            .excess_blob_gasprice = 1,
        }),
    );
    try expect(BlobExcessGasAndPrice.init(2314057).eql(.{
        .excess_blob_gas = 2314057,
        .excess_blob_gasprice = 1,
    }));
    try expect(BlobExcessGasAndPrice.init(2314058).eql(BlobExcessGasAndPrice{
        .excess_blob_gas = 2314058,
        .excess_blob_gasprice = 2,
    }));
    try expect(BlobExcessGasAndPrice.init(10 * 1024 * 1024).eql(BlobExcessGasAndPrice{
        .excess_blob_gas = 10 * 1024 * 1024,
        .excess_blob_gasprice = 23,
    }));
}

test "TxEnv: get_total_blob_gas function" {
    var default_tx_env = try TxEnv.init(std.testing.allocator);
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
    var env_default = try Env.init(std.testing.allocator);
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
        .access_list = std.ArrayList(std.meta.Tuple(&.{
            bits.B160,
            std.ArrayList(u256),
        })).init(std.testing.allocator),
        .blob_hashes = std.ArrayList(bits.B256).init(std.testing.allocator),
        .max_fee_per_blob_gas = null,
    };
    defer tx_env.deinit();

    try expectEqual(
        @as(u256, 1),
        try Env.effective_gas_price(.{
            .block = BlockEnv.init(),
            .cfg = CfgEnv.init(),
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
        .access_list = std.ArrayList(std.meta.Tuple(&.{
            bits.B160,
            std.ArrayList(u256),
        })).init(std.testing.allocator),
        .blob_hashes = std.ArrayList(bits.B256).init(std.testing.allocator),
        .max_fee_per_blob_gas = null,
    };
    defer tx_env.deinit();

    try expectEqual(
        @as(u256, 10),
        try Env.effective_gas_price(.{
            .block = BlockEnv.init(),
            .cfg = CfgEnv.init(),
            .tx = tx_env,
        }),
    );
}
