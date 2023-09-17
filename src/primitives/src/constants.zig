const std = @import("std");
const bits = @import("./bits.zig");

pub const Constants = struct {
    pub const ANY = "any";
    pub const UINT256 = "uint256";
    pub const BYTES = "bytes";

    pub const UINT_256_MAX = std.math.maxInt(u256);
    pub const UINT_256_CEILING = std.math.pow(u257, 2, 256);
    pub const UINT_255_CEILING = std.math.pow(u256, 2, 255);
    pub const UINT_255_NEGATIVE_ONE = UINT_256_CEILING - 1;
    pub const UINT_64_MAX = std.math.maxInt(u64);
    pub const UINT_160_CEILING = std.math.pow(u256, 2, 160);

    // Address, bytes, hash
    pub const NULL_BYTE = [_]u8{0x00};
    pub const EMPTY_WORD = NULL_BYTE ** 32;
    pub const CREATE_CONTRACT_ADDRESS = [_]u8{};
    pub const ZERO_ADDRESS = [_]u8{0x00} ** 20;
    pub const ZERO_HASH32 = [_]u8{0x00} ** 32;

    /// Interpreter stack limit
    pub const STACK_LIMIT: u64 = 1024;
    /// EVM call stack limit
    pub const CALL_STACK_LIMIT: u64 = 1024;

    // Gas cost and refund
    pub const GAS_NULL = 0;
    pub const GAS_ZERO = 0;
    pub const GAS_BASE = 2;
    pub const GAS_VERYLOW = 3;
    pub const GAS_LOW = 5;
    pub const GAS_MID = 8;
    pub const GAS_HIGH = 10;
    pub const GAS_EXTCODE = 20;
    pub const GAS_BALANCE = 20;
    pub const GAS_SLOAD = 50;
    pub const GAS_JUMPDEST = 1;
    pub const GAS_SSET = 20000;
    pub const GAS_SRESET = 5000;
    pub const REFUND_SCLEAR = 15000;
    pub const GAS_SELFDESTRUCT = 0;
    pub const GAS_SELFDESTRUCT_NEWACCOUNT = 25000;
    pub const GAS_CREATE = 32000;
    pub const GAS_CALL = 40;
    pub const GAS_CALLVALUE = 9000;
    pub const GAS_CALLSTIPEND = 2300;
    pub const GAS_NEWACCOUNT = 25000;
    pub const GAS_EXP = 10;
    pub const GAS_EXPBYTE = 10;
    pub const GAS_MEMORY = 3;
    pub const GAS_TXCREATE = 32000;
    pub const GAS_TXDATAZERO = 4;
    pub const GAS_TXDATANONZERO = 68;
    pub const GAS_TX = 21000;
    pub const GAS_LOG = 375;
    pub const GAS_LOGDATA = 8;
    pub const GAS_LOGTOPIC = 375;
    pub const GAS_SHA3 = 30;
    pub const GAS_SHA3WORD = 6;
    pub const GAS_COPY = 3;
    pub const GAS_BLOCKHASH = 20;
    pub const GAS_CODEDEPOSIT = 200;
    pub const GAS_MEMORY_QUADRATIC_DENOMINATOR = 512;

    // Pre-compile contract gas costs
    pub const GAS_SHA256 = 60;
    pub const GAS_SHA256WORD = 12;
    pub const GAS_RIPEMD160 = 600;
    pub const GAS_RIPEMD160WORD = 120;
    pub const GAS_IDENTITY = 15;
    pub const GAS_IDENTITYWORD = 3;
    pub const GAS_ECRECOVER = 3000;
    pub const GAS_ECADD = 500;
    pub const GAS_ECMUL = 40000;
    pub const GAS_ECPAIRING_BASE = 100000;
    pub const GAS_ECPAIRING_PER_POINT = 80000;

    // Gas Limit
    pub const GAS_LIMIT_EMA_DENOMINATOR = 1024;
    pub const GAS_LIMIT_ADJUSTMENT_FACTOR = 1024;
    pub const GAS_LIMIT_MINIMUM = 5000;
    pub const GAS_LIMIT_MAXIMUM = std.math.pow(u64, 2, 63) - 1;
    pub const GAS_LIMIT_USAGE_ADJUSTMENT_NUMERATOR = 3;
    pub const GAS_LIMIT_USAGE_ADJUSTMENT_DENOMINATOR = 2;

    // Difficulty
    pub const DIFFICULTY_ADJUSTMENT_DENOMINATOR = 2048;
    pub const DIFFICULTY_MINIMUM = 131072;
    pub const BOMB_EXPONENTIAL_PERIOD = 100000;
    pub const BOMB_EXPONENTIAL_FREE_PERIODS = 2;

    // Mining
    pub const BLOCK_REWARD = 5 * 1000000000000000000;
    pub const UNCLE_DEPTH_PENALTY_FACTOR = 8;
    pub const MAX_UNCLE_DEPTH = 6;
    pub const MAX_UNCLES = 2;

    // SECPK1N
    pub const SECPK1_P = std.math.pow(u257, 2, 256) - std.math.pow(u257, 2, 32) - 977;
    pub const SECPK1_N =
        115792089237316195423570985008687907852837564279074904382605163141518161494337;
    pub const SECPK1_A = 0;
    pub const SECPK1_B = 7;
    pub const SECPK1_Gx =
        55066263022277343669578718895168534326250603453777594175500187360389116729240;
    pub const SECPK1_Gy =
        32670510020758816978083085130507043184471273380659243275938904335757337482424;
    pub const SECPK1_G = .{
        SECPK1_Gx,
        SECPK1_Gy,
    };

    // Block and Header
    /// noqa: E501
    pub const EMPTY_UNCLE_HASH = [32]u8{ 0x1d, 0xcc, 0x4d, 0xe8, 0xde, 0xc7, 0x5d, 0x7a, 0xab, 0x85, 0xb5, 0x67, 0xb6, 0xcc, 0xd4, 0x1a, 0xd3, 0x12, 0x45, 0x1b, 0x94, 0x8a, 0x74, 0x13, 0xf0, 0xa1, 0x42, 0xfd, 0x40, 0xd4, 0x93, 0x47 };

    // Genesis Data
    pub const GENESIS_BLOCK_NUMBER = 0;
    pub const GENESIS_DIFFICULTY = 17179869184;
    pub const GENESIS_GAS_LIMIT = 5000;
    pub const GENESIS_PARENT_HASH = ZERO_HASH32;
    pub const GENESIS_COINBASE = ZERO_ADDRESS;
    pub const GENESIS_NONCE = [_]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x42 };
    pub const GENESIS_MIX_HASH = ZERO_HASH32;
    pub const GENESIS_EXTRA_DATA = [_]u8{};
    pub const GENESIS_BLOOM = 0;
    pub const GENESIS_GAS_USED = 0;

    // Sha3 Keccak
    pub const EMPTY_SHA3 = [32]u8{ 0xc5, 0xd2, 0x46, 0x01, 0x86, 0xf7, 0x23, 0x3c, 0x92, 0x7e, 0x7d, 0xb2, 0xdc, 0xc7, 0x03, 0xc0, 0xe5, 0x00, 0xb6, 0x53, 0xca, 0x82, 0x27, 0x3b, 0x7b, 0xfa, 0xd8, 0x04, 0x5d, 0x85, 0xa4, 0x70 };
    pub const BLANK_ROOT_HASH = [32]u8{ 0x56, 0xe8, 0x1f, 0x17, 0x1b, 0xcc, 0x55, 0xa6, 0xff, 0x83, 0x45, 0xe6, 0x92, 0xc0, 0xf8, 0x6e, 0x5b, 0x48, 0xe0, 0x1b, 0x99, 0x6c, 0xad, 0xc0, 0x01, 0x62, 0x2f, 0xb5, 0xe3, 0x63, 0xb4, 0x21 };

    pub const GAS_MOD_EXP_QUADRATIC_DENOMINATOR = 20;

    // BLOCKHASH opcode maximum depth
    pub const MAX_PREV_HEADER_DEPTH = 256;

    // Call overrides
    pub const DEFAULT_SPOOF_Y_PARITY = 1;
    pub const DEFAULT_SPOOF_R = 1;
    pub const DEFAULT_SPOOF_S = 1;

    // Merge / EIP-3675 constants
    pub const POST_MERGE_OMMERS_HASH = EMPTY_UNCLE_HASH;
    pub const POST_MERGE_DIFFICULTY = 0;
    pub const POST_MERGE_MIX_HASH = ZERO_HASH32;
    pub const POST_MERGE_NONCE = [_]u8{0x00} ** 8;

    // Keccak-256 of empty string: c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
    pub const KECCAK_EMPTY = bits.B256{ .bytes = [32]u8{ 197, 210, 70, 1, 134, 247, 35, 60, 146, 126, 125, 178, 220, 199, 3, 192, 229, 0, 182, 83, 202, 130, 39, 59, 123, 250, 216, 4, 93, 133, 164, 112 } };

    /// Precompile 3 is special in few places
    pub const PRECOMPILE3 = bits.B160{ .bytes = [20]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3 } };

    /// EIP-170: Contract code size limit
    /// By default limit is 0x6000 (~25kb)
    pub const MAX_CODE_SIZE: usize = 0x6000;

    /// EIP-3860: Limit and meter initcode
    ///
    /// Limit of maximum initcode size is 2 * MAX_CODE_SIZE
    pub const MAX_INITCODE_SIZE: usize = 2 * Constants.MAX_CODE_SIZE;

    // EIP-4844 constants
    /// Maximum consumable blob gas for data blobs per block.
    pub const MAX_BLOB_GAS_PER_BLOCK: u64 = 6 * GAS_PER_BLOB;
    /// Target consumable blob gas for data blobs per block (for 1559-like pricing).
    pub const TARGET_BLOB_GAS_PER_BLOCK: u64 = 3 * GAS_PER_BLOB;
    /// Gas consumption of a single data blob (== blob byte size).
    pub const GAS_PER_BLOB: u64 = 1 << 17;
    /// Minimum gas price for data blobs.
    pub const MIN_BLOB_GASPRICE: u64 = 1;
    /// Controls the maximum rate of change for blob gas price.
    pub const BLOB_GASPRICE_UPDATE_FRACTION: u64 = 3338477;
};
