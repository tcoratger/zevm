const std = @import("std");
const log = @import("./log.zig");
const utils = @import("./utils.zig");

pub const ExecutionResultEnum = enum {
    Success,
    Revert,
    Halt,
};

pub const ExecutionResult = union(ExecutionResultEnum) {
    const Self = @This();

    /// Returned successfully
    Success: struct {
        reason: Eval,
        gas_used: u64,
        gas_refunded: u64,
        logs: log.Log,
        output: Output,
    },
    /// Reverted by `REVERT` opcode that doesn't spend all gas.
    Revert: struct { gas_used: u64, output: u64 },
    /// Reverted for various reasons and spend all gas.
    Halt: struct {
        reason: Halt,
        /// Halting will spend all the gas, and will be equal to gas_limit.
        gas_used: u64,
    },

    /// Returns if transaction execution is successful.
    /// 1 indicates success, 0 indicates revert.
    /// https://eips.ethereum.org/EIPS/eip-658
    pub fn is_success(execution_result: Self) bool {
        return execution_result == .Success;
    }

    /// Return logs, if execution is not successful, function will return empty vec.
    pub fn logs(execution_result: Self) log.Log {
        return switch (execution_result) {
            .Success => execution_result.Success.logs,
            else => undefined,
        };
    }
};

pub const Eval = enum {
    Stop,
    Return,
    SelfDestruct,
};

pub const OutputEnum = enum { Call, Create };

pub const Output = union(OutputEnum) {
    const Self = @This();

    Call: struct { bytes: []u8 },
    Create: struct { bytes: []u8, option: ?u64 },

    /// Returns the output data of the execution output.
    pub fn into_data(output: Self) []u8 {
        return switch (output) {
            .Call => output.Call.bytes,
            .Create => output.Create.bytes,
        };
    }

    /// Returns the output data of the execution output.
    pub fn data(output: *Self) *[]u8 {
        return switch (output.*) {
            .Call => &output.Call.bytes,
            .Create => &output.Create.bytes,
        };
    }
};

pub const Halt = enum {
    OutOfGasError,
    OpcodeNotFound,
    InvalidFEOpcode,
    InvalidJump,
    NotActivated,
    StackUnderflow,
    StackOverflow,
    OutOfOffset,
    CreateCollision,
    PrecompileError,
    NonceOverflow,
    CreateContractSizeLimit,
    CreateContractStartingWithEF,
    CreateInitcodeSizeLimit,
    OverflowPayment,
    StateChangeDuringStaticCall,
    CallNotAllowedInsideStatic,
    OutOfFund,
    CallTooDeep,
};

/// InvalidTransaction enumeration represents various reasons for invalid Ethereum transactions.
pub const InvalidTransaction = union(enum) {
    /// Gas max fee is greater than priority fee.
    GasMaxFeeGreaterThanPriorityFee,
    /// Gas price is less than basefee.
    GasPriceLessThanBasefee,
    /// Caller's gas limit exceeds block gas limit.
    CallerGasLimitMoreThanBlock,
    /// Call's gas cost exceeds the specified gas limit.
    CallGasCostMoreThanGasLimit,
    /// EIP-3607: Reject transactions from senders with deployed code.
    RejectCallerWithCode,
    /// Transaction sender doesn't have enough funds to cover max fee.
    LackOfFundForMaxFee: struct {
        fee: u64,
        balance: u256,
    },
    /// Overflow in payment within the transaction.
    OverflowPaymentInTransaction,
    /// Nonce overflow within the transaction.
    NonceOverflowInTransaction,
    /// Transaction nonce is too high compared to state.
    NonceTooHigh: struct {
        tx: u64,
        state: u64,
    },
    /// Transaction nonce is too low compared to state.
    NonceTooLow: struct {
        tx: u64,
        state: u64,
    },
    /// EIP-3860: Initcode size exceeds the limit.
    CreateInitcodeSizeLimit,
    /// Invalid chain ID in the transaction.
    InvalidChainId,
    /// Access list is not supported for blocks before Berlin hardfork.
    AccessListNotSupported,
    /// `max_fee_per_blob_gas` is not supported for blocks before the Cancun hardfork.
    MaxFeePerBlobGasNotSupported,
    /// `blob_hashes`/`blob_versioned_hashes` is not supported for blocks before the Cancun hardfork.
    BlobVersionedHashesNotSupported,
    /// Block `blob_gas_price` is greater than tx-specified `max_fee_per_blob_gas` after Cancun.
    BlobGasPriceGreaterThanMax,
    /// There should be at least one blob in Blob transaction.
    EmptyBlobs,
    /// Blob transaction can't be a create transaction.
    /// `to` must be present
    BlobCreateTransaction,
    /// Transaction has more then [`crate::MAX_BLOB_NUMBER_PER_BLOCK`] blobs
    TooManyBlobs,
    /// Blob transaction contains a versioned hash with an incorrect version
    BlobVersionNotSupported,
    /// System transactions are not supported
    /// post-regolith hardfork.
    DepositSystemTxPostRegolith,
};

pub const OutOfGasError = error{
    // Basic OOG error
    BasicOutOfGas,
    // Tried to expand past REVM limit
    MemoryLimit,
    // Basic OOG error from memory expansion
    Memory,
    // Precompile threw OOG error
    Precompile,
    // When performing something that takes a U256 and casts down to a u64, if its too large this would fire
    // i.e. in `as_usize_or_fail`
    InvalidOperand,
};
