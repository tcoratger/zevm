pub const Opcodes = struct {
    // Stop and Arithmetic Operations
    /// Halts execution
    pub const STOP: u8 = 0x00;
    /// Addition operation
    pub const ADD: u8 = 0x01;
    /// Multiplication operation
    pub const MUL: u8 = 0x02;
    /// Subtraction operation
    pub const SUB: u8 = 0x03;
    /// Integer division operation
    pub const DIV: u8 = 0x04;
    /// Signed integer division operation (truncated)
    pub const SDIV: u8 = 0x05;
    /// Modulo remainder operation
    pub const MOD: u8 = 0x06;
    /// Signed modulo remainder operation
    pub const SMOD: u8 = 0x07;
    /// Modulo addition operation
    pub const ADDMOD: u8 = 0x08;
    /// Modulo multiplication operation
    pub const MULMOD: u8 = 0x09;
    /// Exponential operation
    pub const EXP: u8 = 0x0a;
    /// Extend length of two’s complement signed integer
    pub const SIGNEXTEND: u8 = 0x0b;

    // Comparison & Bitwise Logic Operations
    /// Less-than comparison
    pub const LT: u8 = 0x10;
    /// Greater-than comparison
    pub const GT: u8 = 0x11;
    /// Signed less-than comparison
    pub const SLT: u8 = 0x12;
    /// Signed greater-than comparison
    pub const SGT: u8 = 0x13;
    /// Equality comparison
    pub const EQ: u8 = 0x14;
    /// Simple not operator
    pub const ISZERO: u8 = 0x15;
    /// Bitwise AND operation
    pub const AND: u8 = 0x16;
    /// Bitwise OR operation
    pub const OR: u8 = 0x17;
    /// Bitwise XOR operation
    pub const XOR: u8 = 0x18;
    /// Bitwise NOT operation
    pub const NOT: u8 = 0x19;
    /// Retrieve single byte from word
    pub const BYTE: u8 = 0x1a;
    /// Left shift operation
    pub const SHL: u8 = 0x1b;
    /// Logical right shift operation
    pub const SHR: u8 = 0x1c;
    /// Arithmetic (signed) right shift operation
    pub const SAR: u8 = 0x1d;

    // SHA3
    /// Compute Keccak-256 hash
    pub const SHA3: u8 = 0x20;

    // Environmental Information
    /// Get address of currently executing account
    pub const ADDRESS: u8 = 0x30;
    /// Get balance of the given account
    pub const BALANCE: u8 = 0x31;
    /// Get execution origination address
    pub const ORIGIN: u8 = 0x32;
    /// Get caller address
    pub const CALLER: u8 = 0x33;
    /// Get deposited value by the instruction/transaction
    /// responsible for this execution
    pub const CALLVALUE: u8 = 0x34;
    /// Get input data of current environment
    pub const CALLDATALOAD: u8 = 0x35;
    /// Get size of input data in current environment
    pub const CALLDATASIZE: u8 = 0x36;
    /// Copy input data in current environment to memory
    pub const CALLDATACOPY: u8 = 0x37;
    /// Get size of code running in current environment
    pub const CODESIZE: u8 = 0x38;
    /// Copy code running in current environment to memory
    pub const CODECOPY: u8 = 0x39;
    /// Get price of gas in current environment
    pub const GASPRICE: u8 = 0x3a;
    /// Get size of an account’s code
    pub const EXTCODESIZE: u8 = 0x3b;
    /// Copy an account’s code to memory
    pub const EXTCODECOPY: u8 = 0x3c;
    /// Get size of output data from the previous call
    /// from the current environment
    pub const RETURNDATASIZE: u8 = 0x3d;
    /// Copy output data from the previous call to memory
    pub const RETURNDATACOPY: u8 = 0x3e;
    /// Get hash of an account’s code
    pub const EXTCODEHASH: u8 = 0x3f;

    // Block information
    /// Get the hash of one of the 256 most recent complete blocks
    pub const BLOCKHASH: u8 = 0x40;
    /// Get the block’s beneficiary address
    pub const COINBASE: u8 = 0x41;
    /// Get the block’s timestamp
    pub const TIMESTAMP: u8 = 0x42;
    /// Get the block’s number
    pub const NUMBER: u8 = 0x43;
    /// Get the block’s difficulty
    pub const DIFFICULTY: u8 = 0x44;
    /// Get the block’s gas limit
    pub const GASLIMIT: u8 = 0x45;
    /// Get the chain ID
    pub const CHAINID: u8 = 0x46;
    /// Get balance of currently executing account
    pub const SELFBALANCE: u8 = 0x47;
    /// Get the base fee
    pub const BASEFEE: u8 = 0x48;

    // Stack Memory Storage and Flow Operations
    /// Remove item from stack
    pub const POP: u8 = 0x50;
    /// Load word from memory
    pub const MLOAD: u8 = 0x51;
    /// Save word to memory
    pub const MSTORE: u8 = 0x52;
    /// Save byte to memory
    pub const MSTORE8: u8 = 0x53;
    /// Load word from storage
    pub const SLOAD: u8 = 0x54;
    /// Save word to storage
    pub const SSTORE: u8 = 0x55;
    /// Alter the program counter
    pub const JUMP: u8 = 0x56;
    /// Conditionally alter the program counter
    pub const JUMPI: u8 = 0x57;
    /// Get the value of the program counter prior
    /// to the increment corresponding to this instruction
    pub const PC: u8 = 0x58;
    /// Get the size of active memory in bytes
    pub const MSIZE: u8 = 0x59;
    /// Get the amount of available gas,
    /// including the corresponding reduction for the cost of this instruction
    pub const GAS: u8 = 0x5a;
    /// Mark a valid destination for jumps
    pub const JUMPDEST: u8 = 0x5b;

    // Push operations
    /// Place value 0 on stack
    pub const PUSH0: u8 = 0x5f;
    /// Place 1 byte item on stack
    pub const PUSH1: u8 = 0x60;
    /// Place 2 byte item on stack
    pub const PUSH2: u8 = 0x61;
    /// Place 3 byte item on stack
    pub const PUSH3: u8 = 0x62;
    /// Place 4 byte item on stack
    pub const PUSH4: u8 = 0x63;
    /// Place 5 byte item on stack
    pub const PUSH5: u8 = 0x64;
    /// Place 6 byte item on stack
    pub const PUSH6: u8 = 0x65;
    /// Place 7 byte item on stack
    pub const PUSH7: u8 = 0x66;
    /// Place 8 byte item on stack
    pub const PUSH8: u8 = 0x67;
    /// Place 9 byte item on stack
    pub const PUSH9: u8 = 0x68;
    /// Place 10 byte item on stack
    pub const PUSH10: u8 = 0x69;
    /// Place 11 byte item on stack
    pub const PUSH11: u8 = 0x6a;
    /// Place 12 byte item on stack
    pub const PUSH12: u8 = 0x6b;
    /// Place 13 byte item on stack
    pub const PUSH13: u8 = 0x6c;
    /// Place 14 byte item on stack
    pub const PUSH14: u8 = 0x6d;
    /// Place 15 byte item on stack
    pub const PUSH15: u8 = 0x6e;
    /// Place 16 byte item on stack
    pub const PUSH16: u8 = 0x6f;
    /// Place 17 byte item on stack
    pub const PUSH17: u8 = 0x70;
    /// Place 18 byte item on stack
    pub const PUSH18: u8 = 0x71;
    /// Place 19 byte item on stack
    pub const PUSH19: u8 = 0x72;
    /// Place 20 byte item on stack
    pub const PUSH20: u8 = 0x73;
    /// Place 21 byte item on stack
    pub const PUSH21: u8 = 0x74;
    /// Place 22 byte item on stack
    pub const PUSH22: u8 = 0x75;
    /// Place 23 byte item on stack
    pub const PUSH23: u8 = 0x76;
    /// Place 24 byte item on stack
    pub const PUSH24: u8 = 0x77;
    /// Place 25 byte item on stack
    pub const PUSH25: u8 = 0x78;
    /// Place 26 byte item on stack
    pub const PUSH26: u8 = 0x79;
    /// Place 27 byte item on stack
    pub const PUSH27: u8 = 0x7a;
    /// Place 28 byte item on stack
    pub const PUSH28: u8 = 0x7b;
    /// Place 29 byte item on stack
    pub const PUSH29: u8 = 0x7c;
    /// Place 30 byte item on stack
    pub const PUSH30: u8 = 0x7d;
    /// Place 31 byte item on stack
    pub const PUSH31: u8 = 0x7e;
    /// Place 32 byte item on stack
    pub const PUSH32: u8 = 0x7f;

    // Duplication Operations
    /// Duplicate 1st stack item
    pub const DUP1: u8 = 0x80;
    /// Duplicate 2nd stack item
    pub const DUP2: u8 = 0x81;
    /// Duplicate 3rd stack item
    pub const DUP3: u8 = 0x82;
    /// Duplicate 4th stack item
    pub const DUP4: u8 = 0x83;
    /// Duplicate 5th stack item
    pub const DUP5: u8 = 0x84;
    /// Duplicate 6th stack item
    pub const DUP6: u8 = 0x85;
    /// Duplicate 7th stack item
    pub const DUP7: u8 = 0x86;
    /// Duplicate 8th stack item
    pub const DUP8: u8 = 0x87;
    /// Duplicate 9th stack item
    pub const DUP9: u8 = 0x88;
    /// Duplicate 10th stack item
    pub const DUP10: u8 = 0x89;
    /// Duplicate 11th stack item
    pub const DUP11: u8 = 0x8a;
    /// Duplicate 12th stack item
    pub const DUP12: u8 = 0x8b;
    /// Duplicate 13th stack item
    pub const DUP13: u8 = 0x8c;
    /// Duplicate 14th stack item
    pub const DUP14: u8 = 0x8d;
    /// Duplicate 15th stack item
    pub const DUP15: u8 = 0x8e;
    /// Duplicate 16th stack item
    pub const DUP16: u8 = 0x8f;

    // Exchange Operations
    /// Exchange 1st and 2nd stack items
    pub const SWAP1: u8 = 0x90;
    /// Exchange 1st and 3rd stack items
    pub const SWAP2: u8 = 0x91;
    /// Exchange 1st and 4th stack items
    pub const SWAP3: u8 = 0x92;
    /// Exchange 1st and 5th stack items
    pub const SWAP4: u8 = 0x93;
    /// Exchange 1st and 6th stack items
    pub const SWAP5: u8 = 0x94;
    /// Exchange 1st and 7th stack items
    pub const SWAP6: u8 = 0x95;
    /// Exchange 1st and 8th stack items
    pub const SWAP7: u8 = 0x96;
    /// Exchange 1st and 9th stack items
    pub const SWAP8: u8 = 0x97;
    /// Exchange 1st and 10th stack items
    pub const SWAP9: u8 = 0x98;
    /// Exchange 1st and 11th stack items
    pub const SWAP10: u8 = 0x99;
    /// Exchange 1st and 12th stack items
    pub const SWAP11: u8 = 0x9a;
    /// Exchange 1st and 13th stack items
    pub const SWAP12: u8 = 0x9b;
    /// Exchange 1st and 14th stack items
    pub const SWAP13: u8 = 0x9c;
    /// Exchange 1st and 15th stack items
    pub const SWAP14: u8 = 0x9d;
    /// Exchange 1st and 16th stack items
    pub const SWAP15: u8 = 0x9e;
    /// Exchange 1st and 17th stack items
    pub const SWAP16: u8 = 0x9f;

    // Logging Operations
    /// Append log record with no topics
    pub const LOG0: u8 = 0xa0;
    /// Append log record with one topic
    pub const LOG1: u8 = 0xa1;
    /// Append log record with two topics
    pub const LOG2: u8 = 0xa2;
    /// Append log record with three topics
    pub const LOG3: u8 = 0xa3;
    /// Append log record with four topics
    pub const LOG4: u8 = 0xa4;

    // System operations
    /// Create a new account with associated code
    pub const CREATE: u8 = 0xf0;
    /// Message-call into an account
    pub const CALL: u8 = 0xf1;
    /// Message-call into this account with alternative account’s code
    pub const CALLCODE: u8 = 0xf2;
    /// Halt execution returning output data
    pub const RETURN: u8 = 0xf3;
    /// Message-call into this account with an alternative account’s code,
    /// but persisting the current values for sender and value
    pub const DELEGATECALL: u8 = 0xf4;
    /// Create a new account with associated code at a predictable address
    pub const CREATE2: u8 = 0xf5;
    /// Static message-call into an account
    pub const STATICCALL: u8 = 0xfa;
    /// Halt execution reverting state changes but returning data and remaining gas
    pub const REVERT: u8 = 0xfd;
    /// Designated invalid instruction
    pub const INVALID: u8 = 0xfe;
    /// Halt execution and register account for later deletion
    pub const SELFDESTRUCT: u8 = 0xff;
};
