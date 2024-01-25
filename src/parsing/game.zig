const std = @import("std");
const log_types = @import("../log_types.zig");
const game_types = @import("../game_types.zig");
const mission = @import("../current_mission.zig");

pub fn hostMigration(log: log_types.LogEntry) bool {
    return std.mem.startsWith(u8, log.message, ": HOST MIGRATION: local client");
}

pub fn userDeath(log: log_types.LogEntry, playerName: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, log.message[2..], playerName)) {
        return null;
    }

    const from_level_idx = std.mem.indexOf(u8, log.message, "from a level") orelse return null;
    const using_a_idx = std.mem.indexOf(u8, log.message, "using a ") orelse return null;
    return log.message[from_level_idx + 7 .. using_a_idx];
}

pub fn zanukaDefeat(log: log_types.LogEntry) bool {
    return std.mem.endsWith(u8, log.message, "CorpusHarvesterDeathAladV");
}
