pub const InstructionResult = enum(u8) {
    const Self = @This();

    /// Success - Instruction continues execution.
    Continue = 0x00,
    /// Success - Instruction stops execution.
    Stop,
    /// Success - Instruction returns.
    Return,
    /// Success - Self-destructs.
    SelfDestruct,

    // Revert codes
    /// Revert opcode encountered.
    Revert = 0x10,
    /// Call depth limit reached.
    CallTooDeep,
    /// Insufficient funds.
    OutOfFund,

    // Actions
    /// Call or create instruction.
    CallOrCreate = 0x20,

    // Error codes
    /// Out of gas.
    OutOfGas = 0x50,
    /// Out of memory.
    MemoryOOG,
    /// Memory limit exceeded.
    MemoryLimitOOG,
    /// Precompile out of gas.
    PrecompileOOG,
    /// Invalid operand for out of gas.
    InvalidOperandOOG,
    /// Opcode not found.
    OpcodeNotFound,
    /// Call not allowed inside static context.
    CallNotAllowedInsideStatic,
    /// State change during static call.
    StateChangeDuringStaticCall,
    /// Invalid front-end opcode.
    InvalidFEOpcode,
    /// Invalid jump instruction.
    InvalidJump,
    /// Not activated.
    NotActivated,
    /// Stack underflow.
    StackUnderflow,
    /// Stack overflow.
    StackOverflow,
    /// Out of offset.
    OutOfOffset,
    /// Create collision.
    CreateCollision,
    /// Overflow payment.
    OverflowPayment,
    /// Precompile error.
    PrecompileError,
    /// Nonce overflow.
    NonceOverflow,
    /// Runtime error - Create init code size exceeds limit.
    CreateContractSizeLimit,
    /// Runtime error - Created contract begins with EF.
    CreateContractStartingWithEF,
    /// EIP-3860: Initcode size limit exceeded.
    CreateInitcodeSizeLimit,

    /// Fatal external error returned by the database.
    FatalExternalError,

    /// Returns whether the result is a success.
    pub fn is_ok(self: *Self) bool {
        return switch (self.*) {
            .Continue, .Stop, .Return, .SelfDestruct => true,
            else => false,
        };
    }

    /// Returns whether the result is a revert.
    pub fn is_revert(self: *Self) bool {
        return switch (self.*) {
            .Revert, .CallTooDeep, .OutOfFund => true,
            else => false,
        };
    }

    /// Returns whether the result is an error.
    pub fn is_error(self: *Self) bool {
        return switch (self.*) {
            .OutOfGas,
            .MemoryOOG,
            .MemoryLimitOOG,
            .PrecompileOOG,
            .InvalidOperandOOG,
            .OpcodeNotFound,
            .CallNotAllowedInsideStatic,
            .StateChangeDuringStaticCall,
            .InvalidFEOpcode,
            .InvalidJump,
            .NotActivated,
            .StackUnderflow,
            .StackOverflow,
            .OutOfOffset,
            .CreateCollision,
            .OverflowPayment,
            .PrecompileError,
            .NonceOverflow,
            .CreateContractSizeLimit,
            .CreateContractStartingWithEF,
            .CreateInitcodeSizeLimit,
            .FatalExternalError,
            => true,
            else => false,
        };
    }
};
