const std = @import("std");

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
};

const SuccessConds = union {
    excavationsComplete: u16,
    stagesCleared: u16,
};

pub fn missionKind(logMessage: []const u8) MissionKind {
    if (std.mem.endsWith(u8, logMessage, "THE STEEL PATH")) {
        return .SteelPath;
    } else if (std.mem.endsWith(u8, logMessage, "Kuva Siphon")) {
        return .Kuva;
    } else if (std.mem.endsWith(u8, logMessage, "Kuva Flood")) {
        return .KuvaFlood;
    } else if (std.mem.endsWith(u8, logMessage, "SORTIE")) {
        return .Sortie;
    } else if (std.mem.endsWith(u8, logMessage, "EIDOLON CULL")) {
        return .EidolonHunt;
    } else if (std.mem.endsWith(u8, logMessage, "Nightmare")) {
        return .Nightmare;
    } else if (std.mem.endsWith(u8, logMessage, "Arbitration")) {
        return .Arbitration;
    } else if (std.mem.endsWith(u8, logMessage, "T1 FISSURE")) {
        return .T1Fissure;
    } else if (std.mem.endsWith(u8, logMessage, "T2 FISSURE")) {
        return .T2Fissure;
    } else if (std.mem.endsWith(u8, logMessage, "T3 FISSURE")) {
        return .T3Fissure;
    } else if (std.mem.endsWith(u8, logMessage, "T4 FISSURE")) {
        return .T4Fissure;
    } else if (std.mem.endsWith(u8, logMessage, "T5 FISSURE")) {
        return .T5Fissure;
    } else if (std.mem.endsWith(u8, logMessage, "SYNDICATE")) {
        return .Syndicate;
    } else if (std.mem.endsWith(u8, logMessage, "Controlled Territory")) {
        return .ControlledTerritory;
    }

    return .Normal;
}
