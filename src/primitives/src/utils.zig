pub fn Option(comptime T: type) type {
    return union(enum) { None: bool, Some: T };
}
