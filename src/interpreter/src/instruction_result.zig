const primitives = @import("../../primitives/primitives.zig");

const Eval = primitives.Eval;
const Halt = primitives.Halt;

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
    pub fn isOk(self: *Self) bool {
        return switch (self.*) {
            .Continue, .Stop, .Return, .SelfDestruct => true,
            else => false,
        };
    }

    /// Returns whether the result is a revert.
    pub fn isRevert(self: *Self) bool {
        return switch (self.*) {
            .Revert, .CallTooDeep, .OutOfFund => true,
            else => false,
        };
    }

    /// Returns whether the result is an error.
    pub fn isError(self: *Self) bool {
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

pub const SuccessOrHalt = union(enum) {
    const Self = @This();

    Success: Eval,
    Revert,
    Halt: Halt,
    FatalExternalError,
    /// Internal instruction that signals Interpreter should continue running.
    InternalContinue,
    /// Internal instruction that signals subcall.
    InternalCallOrCreate,

    /// Returns true if the transaction returned successfully without halts.
    pub fn isSuccess(self: *Self) bool {
        return switch (self.*) {
            .Success => true,
            else => false,
        };
    }

    /// Returns the [Eval] value if this a successful result
    pub fn toSuccess(self: *Self) ?Eval {
        return switch (self.*) {
            .Success => |eval| eval,
            else => null,
        };
    }

    /// Returns true if the EVM has experienced an exceptional halt
    pub fn isHalt(self: *Self) bool {
        return switch (self.*) {
            .Halt => true,
            else => false,
        };
    }

    /// Returns the [Halt] value the EVM has experienced an exceptional halt
    pub fn toHalt(self: *Self) ?Halt {
        return switch (self.*) {
            .Halt => |halt| halt,
            else => null,
        };
    }

    pub fn from(result: InstructionResult) Self {
        return switch (result) {
            .Continue => .InternalContinue,
            .Stop => .{ .Success = .Stop },
            .Return => .{ .Success = .Return },
            .SelfDestruct => .{ .Success = .SelfDestruct },
            .Revert => .Revert,
            .CallOrCreate => .InternalCallOrCreate,
            .CallTooDeep => .{ .Halt = .CallTooDeep },
            .OutOfFund => .{ .Halt = .OutOfFund },
            .OutOfGas => .{ .Halt = .OutOfGasError },
            .MemoryLimitOOG => .{ .Halt = .OutOfGasError },
            .MemoryOOG => .{ .Halt = .OutOfGasError },
            .PrecompileOOG => .{ .Halt = .OutOfGasError },
            .InvalidOperandOOG => .{ .Halt = .OutOfGasError },
            .OpcodeNotFound => .{ .Halt = .OpcodeNotFound },
            .CallNotAllowedInsideStatic => .{ .Halt = .CallNotAllowedInsideStatic },
            .StateChangeDuringStaticCall => .{ .Halt = .StateChangeDuringStaticCall },
            .InvalidFEOpcode => .{ .Halt = .InvalidFEOpcode },
            .InvalidJump => .{ .Halt = .InvalidJump },
            .NotActivated => .{ .Halt = .NotActivated },
            .StackUnderflow => .{ .Halt = .StackUnderflow },
            .StackOverflow => .{ .Halt = .StackOverflow },
            .OutOfOffset => .{ .Halt = .OutOfOffset },
            .CreateCollision => .{ .Halt = .CreateCollision },
            .OverflowPayment => .{ .Halt = .OverflowPayment },
            .PrecompileError => .{ .Halt = .PrecompileError },
            .NonceOverflow => .{ .Halt = .NonceOverflow },
            .CreateContractSizeLimit => .{ .Halt = .CreateContractSizeLimit },
            .CreateContractStartingWithEF => .{ .Halt = .CreateContractSizeLimit },
            .CreateInitcodeSizeLimit => .{ .Halt = .CreateInitcodeSizeLimit },
            .FatalExternalError => .FatalExternalError,
        };
    }
};
