/// KZG Settings that allow us to specify a custom trusted setup.
/// or use hardcoded default settings.
pub const EnvKzgSettings = union(enum) {
    const Self = @This();

    /// Default mainnet trusted setup
    Default,
};
