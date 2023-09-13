pub const PrecompileError = error{
    OutOfGas,
    Blake2WrongLength,
    Blake2WrongFinalIndicatorFlag,
    ModexpExpOverflow,
    ModexpBaseOverflow,
    ModexpModOverflow,
    Bn128FieldPointNotAMember,
    Bn128AffineGFailedToCreate,
    Bn128PairLength,
};
