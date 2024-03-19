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
    pub var aborted: bool = false;

    pub var eidolonsCaputred: u5 = 0;
    pub var onslaughtWaves: u16 = 0;
    pub var circuitStages: u16 = 0;

    pub fn resetVars() void {
        aborted = false;
        eidolonsCaputred = 0;
        onslaughtWaves = 0;
        circuitStages = 0;
    }
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
    KahlMission,
    ArchonHunt,
};

pub const Objective = enum {
    UNKNOWN,
    MT_SURVIVAL,
    MT_DEFENSE,
    MT_MOBILE_DEFENSE,
    MT_RESCUE,
    MT_CAPTURE,
    MT_EXTERMINATION,
    MT_INTEL,
    MT_COUNTER_INTEL,
    MT_SABOTAGE,
    MT_SABOTAGE_2,
    MT_EXCAVATE,
    MT_HIVE,
    MT_TERRITORY,
    MT_RETRIEVAL,
    MT_EVACUATION,
    MT_ARENA,
    MT_ASSASSINATION,
    MT_PURSUIT,
    MT_RACE,
    MT_ASSAULT,
    MT_PURIFY,
    MT_RAID,
    MT_SALVAGE,
    MT_ARTIFACT,
    MT_SECTOR,
    MT_JUNCTION,
    MT_PVP,
    MT_GENERIC,
    MT_LANDSCAPE,
    MT_ENDLESS_EXTERMINATION,
    MT_RAILJACK,
    MT_RAILJACK_ORPHIX,
    MT_RAILJACK_VOLATILE,
    MT_RAILJACK_SPY,
    MT_RAILJACK_SURVIVAL,
    MT_ARMAGEDDON,
    MT_VOID_CASCADE,
    MT_CORRUPTION,
    MT_ENDLESS_DUVIRI,
};

pub fn missionKind(logMessage: []const u8, separator: usize) MissionKind {
    if (logMessage.len <= separator + 4) {
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
        case("Archon Hunt") => .ArchonHunt,
        else => .Normal,
    };
}
