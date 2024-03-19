const std = @import("std");
const mem = std.mem;
const log_types = @import("../log_types.zig");
const game_types = @import("../game_types.zig");
const mission = @import("../current_mission.zig");

pub fn missionAbort(log: log_types.LogEntry) bool {
    return mem.eql(u8, log.message, ": GameRulesImpl - changing state from SS_STARTED to SS_ENDING");
}
