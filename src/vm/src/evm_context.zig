const Env = @import("../../primitives/primitives.zig").Env;
const Database = @import("./db/db.zig").Database;
const JournaledState = @import("./journaled_state.zig").JournaledState;

pub const EvmContext = struct {
    env: Env,
    journaled_state: JournaledState,
    db: Database,
};
