const std = @import("std");
const ss = @import("utils/string_switch.zig");
const stringSwitch = ss.stringSwitch;
const case = ss.case;

pub const Mission = struct {
    pub var name: []const u8 = undefined;
    pub var kind: MissionKind = undefined;
    pub var objective: Objective = undefined;
    pub var minLevel: usize = 0;
    pub var maxLevel: usize = 0;
    pub var startedAt: i64 = 0;
    pub var successCount: u16 = 0;
};

pub const MissionKind = enum {
    Normal,
    Nightmare,
    Kuva,
    KuvaFlood,
    SteelPath,
    TreasureHunt,
    Sortie,
    EidolonHunt,
    Arbitration,
    T1Fissure,
    T2Fissure,
    T3Fissure,
    T4Fissure,
    T5Fissure,
    Syndicate,
    ControlledTerritory,
};

pub const Objective = enum {
    UNKNOWN,
    MT_DEFENSE,
    MT_ENDLESS_EXTERMINATION,
    MT_CAPTURE,
    MT_LANDSCAPE,
    MT_PVP,
    MT_SURVIVAL,
    MT_RESCUE,
    MT_SABOTAGE,
    MT_EXTERMINATION,
    MT_INTEL,
    MT_RAILJACK,
    MT_MOBILE_DEFENSE,
    MT_TERRITORY,
    MT_EXCAVATE,
    MT_ARTIFACT,
    MT_ASSASSINATION,
};

const SuccessConds = union {
    excavationsComplete: u16,
    stagesCleared: u16,
};

pub fn missionKind(logMessage: []const u8, separator: usize) MissionKind {
    if (std.mem.indexOf(u8, logMessage, "Weekly Ayatan") != null) {
        return .TreasureHunt;
    } else if (logMessage.len <= separator + 4) {
        return .Normal;
    }

    return switch (stringSwitch(logMessage[(separator + 3)..])) {
        case("THE STEEL PATH") => .SteelPath,
        case("Kuva Siphon") => .Kuva,
        case("Kuva Flood") => .KuvaFlood,
        case("SORTIE") => .Sortie,
        case("EIDOLON CULL") => .EidolonHunt,
        case("Nightmare") => .Nightmare,
        case("Arbitration") => .Arbitration,
        case("T1 FISSURE") => .T1Fissure,
        case("T2 FISSURE") => .T2Fissure,
        case("T3 FISSURE") => .T3Fissure,
        case("T4 FISSURE") => .T4Fissure,
        case("T5 FISSURE") => .T5Fissure,
        case("SYNDICATE") => .Syndicate,
        case("Controlled Territory") => .ControlledTerritory,
        else => .Normal,
    };
}
