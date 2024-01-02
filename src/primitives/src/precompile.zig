const std = @import("std");
const Env = @import("./env.zig").Env;

/// Represents the result of a precompile operation.
///
/// Returns either `Ok((gas_used, return_bytes))` or an error.
pub const PrecompileResult = PrecompileError!std.meta.Tuple(&.{
    u64,
    std.ArrayList(u8),
});

/// Represents a function signature for a standard precompile.
///
/// Accepts input bytes and gas limit, returns a `PrecompileResult`.
pub const StandardPrecompileFn = fn ([]u8, u64) PrecompileResult;

/// Represents a function signature for an environment-aware precompile.
///
/// Accepts input bytes, gas limit, and a reference to the environment, returns a `PrecompileResult`.
pub const EnvPrecompileFn = fn ([]u8, u64, *Env) PrecompileResult;

/// Enumerates errors related to precompile operations.
pub const PrecompileError = error{
    /// Indicates running out of gas during the operation.
    OutOfGas,
    /// Indicates an incorrect input length for blake2.
    Blake2WrongLength,
    /// Indicates an incorrect final indicator flag for blake2.
    Blake2WrongFinalIndicatorFlag,
    /// Indicates an overflow in exponentiation during modexp.
    ModexpExpOverflow,
    /// Indicates an overflow in the base during modexp.
    ModexpBaseOverflow,
    /// Indicates an overflow in the modulus during modexp.
    ModexpModOverflow,
    /// Indicates that a field point is not a member of bn128 curve.
    Bn128FieldPointNotAMember,
    /// Indicates failure in creating an affine g point for bn128 curve.
    Bn128AffineGFailedToCreate,
    /// Indicates an invalid pair length for bn128.
    Bn128PairLength,
};
