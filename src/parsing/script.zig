const std = @import("std");
const log_types = @import("../log_types.zig");
const game_types = @import("../game_types.zig");
const mission = @import("../current_mission.zig");

pub fn missionInfo(log: log_types.LogEntry) ?struct { name: []const u8, kind: mission.MissionKind } {
    if (!std.mem.eql(u8, log.luaFile orelse return null, "ThemedSquadOverlay.lua")) {
        return null;
    }

    if (std.mem.startsWith(u8, log.message, ": Mission name:")) {
        const kind_separator = std.mem.lastIndexOf(u8, log.message, " - ");
        if (kind_separator != null) {
            return .{
                .name = log.message[16..kind_separator.?],
                .kind = mission.missionKind(log.message),
            };
        }

        return .{
            .name = log.message[16..],
            .kind = .Normal,
        };
    } else if (std.mem.startsWith(u8, log.message, ": Cached mission name=")) {
        const try_idx = std.mem.lastIndexOf(u8, log.message, " (SolNode");
        const r_idx = try_idx orelse std.mem.lastIndexOf(u8, log.message, " ()") orelse return null;
        const message = log.message[22..r_idx];
        const kind_separator = std.mem.lastIndexOf(u8, message, " - ");
        if (kind_separator != null) {
            return .{
                .name = message[0..kind_separator.?],
                .kind = mission.missionKind(message),
            };
        }

        return .{
            .name = message,
            .kind = .Normal,
        };
    }

    return null;
}

pub fn missionSuccess(log: log_types.LogEntry) bool {
    if (!std.mem.eql(u8, log.luaFile orelse return false, "EndOfMatch.lua")) {
        return false;
    }

    if (!std.mem.eql(u8, log.message, ": Mission Succeeded")) {
        return false;
    }

    return true;
}

pub fn missionFailure(log: log_types.LogEntry) bool {
    if (!std.mem.eql(u8, log.luaFile orelse return false, "EndOfMatch.lua")) {
        return false;
    }

    if (!std.mem.eql(u8, log.message, ": Mission Failed")) {
        return false;
    }

    return true;
}

pub fn acolyteDefeated(log: log_types.LogEntry) ?[]const u8 {
    if (!std.mem.eql(u8, log.luaFile orelse "", "Transmission.lua")) {
        return null;
    }

    const last_idx = std.mem.lastIndexOf(u8, log.message, "/") orelse return null;
    const acolyteString = log.message[last_idx + 1 .. log.message.len - 6];
    const acolyte = std.meta.stringToEnum(game_types.Acolytes, acolyteString) orelse return null;
    return switch (acolyte) {
        .StrikerAcolyte => "Angst",
        .HeavyAcolyte => "Malice",
        .RogueAcolyte => "Mania",
        .AreaCasterAcolyte => "Misery",
        .ControlAcolyte => "Torment",
        .DuellistAcolyte => "Violence",
    };
}

pub fn stalkerDefeated(log: log_types.LogEntry) bool {
    if (!std.mem.eql(u8, log.luaFile orelse "", "Transmission.lua")) {
        return false;
    }

    return std.mem.endsWith(u8, log.message, "Stalker/SentientTauntDeath");
}

pub fn eidolonCaptured(log: log_types.LogEntry) bool {
    if (!std.mem.eql(u8, log.luaFile orelse return false, "TeralystAvatarScript.lua")) {
        return false;
    }

    if (!std.mem.eql(u8, log.message, ": Teralyst Captured")) {
        return false;
    }

    return true;
}

pub fn kuvaLichSpan(log: log_types.LogEntry) bool {
    if (!std.mem.eql(u8, log.luaFile orelse return false, "KuvaLichFinisher.lua")) {
        return false;
    }

    if (!std.mem.startsWith(u8, log.message, ": creating kuva lich")) {
        return false;
    }

    return true;
}

pub fn isMasteryRankUp(log: log_types.LogEntry) ?u8 {
    if (!std.mem.eql(u8, log.luaFile orelse return null, "WaveChallenge.lua")) {
        return null;
    }

    if (!std.mem.startsWith(u8, log.message, ": Dojo: OnTrainingResultUploaded result=true")) {
        return null;
    }

    const idx1 = (std.mem.indexOf(u8, log.message, "\"NewLevel\":") orelse return null) + 11;
    const idx2 = (std.mem.indexOf(u8, log.message[idx1..], ",") orelse return null) + idx1;
    var rank: u8 = 0;
    for (log.message[idx1..idx2]) |n| {
        if (n > '9' or n < '0') return null;
        rank *= 10;
        rank += n - '0';
    }

    return rank;
}

pub fn lichDefeated(log: log_types.LogEntry) bool {
    if (!std.mem.eql(u8, log.luaFile orelse return false, "NemesisAssassinate.lua")) {
        return false;
    }

    if (!std.mem.eql(u8, log.message, ": Lich killed, unlocking door")) {
        return false;
    }

    return true;
}

pub fn grustragDefeated(log: log_types.LogEntry) bool {
    if (!std.mem.eql(u8, log.luaFile orelse return false, "HudRedux.lua")) {
        return false;
    }

    return std.mem.endsWith(u8, log.message, "GrineerDeathSquad/DeathSquadDefeatedTransmission");
}
