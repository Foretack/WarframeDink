const std = @import("std");
const log_types = @import("../log_types.zig");
const game_types = @import("../game_types.zig");
const mission = @import("../current_mission.zig");

pub fn loginUsername(log: log_types.LogEntry) ?[]const u8 {
    if (!std.mem.startsWith(u8, log.message, ": Logged in")) {
        return null;
    }

    const next_space = std.mem.indexOf(u8, log.message[12..], " ").? + 12;
    return log.message[12..next_space];
}

pub fn missionEnd(log: log_types.LogEntry) bool {
    if (std.mem.startsWith(u8, log.message, ": EOM missionLocationUnlocked=")) {
        return true;
    }

    return false;
}

pub fn exitingGame(log: log_types.LogEntry) bool {
    return std.mem.eql(u8, log.message, ": Main Shutdown Initiated.");
}

pub fn rivenSliverPickup(log: log_types.LogEntry) bool {
    if (!std.mem.startsWith(u8, log.message, ": Resource load completed")) {
        return false;
    }

    return std.mem.indexOf(u8, log.message, "RivenFragment.png") != null;
}

pub fn nightwaveChallengeComplete(log: log_types.LogEntry) ?game_types.NightwaveChallenge {
    if (!std.mem.startsWith(u8, log.message, ": LotusProfileData::NotifyWorldStateChallengeCompleted")) {
        return null;
    }

    var tier: game_types.ChallengeTier = undefined;
    if (std.mem.indexOf(u8, log.message, "/WeeklyHard/") != null) {
        tier = .EliteWeekly;
    } else if (std.mem.indexOf(u8, log.message, "/Weekly/") != null) {
        tier = .Weekly;
    } else {
        tier = .Daily;
    }

    const last_slash_idx = std.mem.lastIndexOf(u8, log.message, "/") orelse return null;
    var challenge_name: []const u8 = undefined;
    @setEvalBranchQuota(3000);
    const last_char = log.message[log.message.len - 1];
    const end_at_idx = if (last_char >= '0' and last_char <= '9') log.message.len - 1 else log.message.len;
    const challenge = std.meta.stringToEnum(game_types.NightwaveChallenges, log.message[last_slash_idx + 1 .. end_at_idx]) orelse .UNKNOWN;
    challenge_name = switch (challenge) {
        .SeasonDailyPickUpMods => "Pick up 8 modules",
        .SeasonDailyVisitFeaturedDojo => "Visit a featured dojo",
        .SeasonDailyDeploySpecter => "Deploy a Specter",
        .SeasonDailyKillEnemiesWithMelee => "Kill 150 enemies with a melee weapon",
        .SeasonDailyKillEnemiesWithRadiation => "Kill 150 enemies with radiation damage",
        .SeasonDailyTwoForOne => "Pierce and kill 2 or more enemies in a single bow shot",
        .SeasonDailyCompleteMission => "Complete a mission",
        .SeasonDailyTransmuteMods => "Complete 3 transmutations",
        .SeasonDailyKillEnemiesWithHeadshots => "Kill 40 enemies with headshots",
        .SeasonDailySolveCiphers => "Hack 8 Consoles",
        .SeasonDailySlideKills => "Kill 20 enemies while sliding",
        .SeasonDailyPlayEmote => "Play 1 Emote",
        .SeasonDailyPlaceMarker => "Mark 5 mods or resources",
        .SeasonDailyPickUpEnergy => "Pick up 20 energy orbs",
        .SeasonDailyOpenLockers => "Open 20 lockers",
        .SeasonDailyKillEnemiesWithFire => "Kill 150 enemies with heat damage",
        .SeasonDailyKillEnemiesWithViral => "Kill 150 enemies with viral damage",
        .SeasonDailyKillEnemiesWithSecondary => "Kill 150 enemies with a Secondary Weapon",
        .SeasonDailyKillEnemiesWithPoison => "Kill 150 enemies with toxin damage",
        .SeasonDailyKillEnemiesWithPrimary => "Kill 150 enemies with a Primary Weapon",
        .SeasonDailyKillEnemiesWithMagnetic => "Kill 150 enemies with magnetic damage",
        .SeasonDailyKillEnemiesWithGas => "Kill 150 enemies with gas damage",
        .SeasonDailyKillEnemiesWithFreeze => "Kill 150 enemies with cold damage",
        .SeasonDailyKillEnemiesWithFinishers => "Kill 10 enemies with finishers",
        .SeasonDailyKillEnemiesWithElectricity => "Kill 150 enemies with electric damage",
        .SeasonDailyKillEnemiesWithCorrosive => "Kill 150 enemies with corrosive damage",
        .SeasonDailyKillEnemiesWithBlast => "Kill 150 enemies with blast damage",
        .SeasonDailyKillEnemiesWithAbilities => "Kill 150 enemies with abilities",
        .SeasonDailyPickUpMedallion => "Find 5 syndicate medallions",
        .SeasonDailyKillEnemies => "Kill 200 enemies",
        .SeasonDailyInteractWithPet => "Interact with your kubrow or kavat",
        .SeasonDailyDeployGlyph => "Deploy a glyph in a mission",
        .SeasonDailyDeployAirSupport => "Deploy an air support charge in a mission",
        .SeasonDailyCollectCredits => "Pick up 15000 credits",
        .SeasonDailyCodexScan => "Scan 25 objects or enemies",
        .SeasonDailyBulletJump => "Bullet jump 150 times",
        .SeasonDailyAimGlide => "Kill 20 enemies while aim gliding",

        .SeasonWeeklyLoyalty => "Interact with your Kubrow or Kavat",
        .SeasonWeeklyCompleteSpy => "Complete 3 spy missions",
        .SeasonWeeklyRailjackHijackDestroyThree => "While piloting a hijacked crewship, destroy 3 enemy fighters",
        .SeasonWeeklyVenusBounties => "Complete 5 different Bounties in Orb Vallis",
        .SeasonWeeklyPlainsBounties => "Complete 5 different Bounties in the Plains of Eidolon",
        .SeasonWeeklyUseForma => "Polarize a weapon, companion, or warframe",
        .SeasonWeeklyUnlockRelics => "Unlock 3 relics",
        .SeasonWeeklyUnlockDragonVaults => "Unlock 4 orokin vaults",
        .SeasonWeeklySimarisScan => "Complete 5 scans for cephalon simaris",
        .SeasonWeeklySanctuaryOnslaught => "Complete 8 waves of sanctuary onslaught",
        .SeasonWeeklySabotageCaches => "Find all caches in 3 sabotage missions",
        .SeasonWeeklyPickUpRareMods => "Pick up 8 Rare Mods",
        .SeasonWeeklyPerfectAnimalCapture => "Complete 6 different perfect animal captures in Orb Vallis",
        .SeasonWeeklyMineRareVenusResources => "Mine 6 rare gems in Orb Vallis",
        .SeasonWeeklyMineRarePlainsResources => "Mine 6 Rare Gems or Ore in the Plains of Eidolon",
        .SeasonWeeklyKillThumper => "Kill a Tusk Thumper in the Plains of Eidolon",
        .SeasonWeeklyKillEximus => "Kill 30 Eximus",
        .SeasonWeeklyKillEnemies => "Kill 500 enemies",
        .SeasonWeeklyGildModular => "Gild 1 modular item",
        .SeasonWeeklyCompleteVenusRace => "Complete 3 different K-Drive races in Orb Vallis",
        .SeasonWeeklyCompleteTreasures => "Fully socket 3 ayatan sculptures",
        .SeasonWeeklyCompleteSyndicateMissions => "Complete 10 syndicate missions",
        .SeasonWeeklyCompleteSortie => "Complete 1 Sortie",
        .SeasonWeeklyCompleteSabotage => "Complete 3 sabotage missions",
        .SeasonWeeklyCompleteRescue => "Complete 3 rescue missions",
        .SeasonWeeklyCompleteNightmareMissions => "Complete 3 nightmare missions of any type",
        .SeasonWeeklyCompleteMobileDefense => "Complete 3 mobile defense missions",
        .SeasonWeeklyCompleteKuva => "Complete 3 kuva siphon missions",
        .SeasonWeeklyCompleteInvasionMissions => "Complete 9 invasion missions of any type",
        .SeasonWeeklyCompleteExterminate => "Complete 3 exterminate missions",
        .SeasonWeeklyCompleteDisruptionConduits => "Complete 12 conduits in disruption",
        .SeasonWeeklyCompleteClemMission => "Help Clem with his weekly mission",
        .SeasonWeeklyCompleteCapture => "Complete 3 capture missions",
        .SeasonWeeklyCompleteAssassination => "Complete 3 Assassination missions",
        .SeasonWeeklyCatchRareVenusFish => "Catch 6 rare servofish in Orb Vallis",
        .SeasonWeeklyCatchRarePlainsFish => "Catch 6 rare fish in the Plains of Eidolon",

        .SeasonWeeklyPermanentCompleteMissions => "Complete any 15 missions",
        .SeasonWeeklyPermanentKillEnemies => "Kill 500 enemies",
        .SeasonWeeklyPermanentKillEximus => "Kill 30 eximus enemies",

        .SeasonWeeklyHardRailjackMissions => "Complete 8 Railjack missions",
        .SeasonWeeklyHardFriendsProfitTaker => "Kill the Profit-Taker in Orb Vallis",
        .SeasonWeeklyHardUnlockRelics => "Unlock 10 relics",
        .SeasonWeeklyHardLuaPuzzles => "Complete 4 halls of acension on Lua",
        .SeasonWeeklyHardKuvaSurvivalNoCapsules => "Survive for over 30 minutes in kuva survival",
        .SeasonWeeklyHardKillThumper => "Kill a Tusk Thumper Doma in the Plains of Eidolon",
        .SeasonWeeklyHardKillSilverGroveSpecters => "Kill 3 Silver Grove Specters",
        .SeasonWeeklyHardKillRopalyst => "Defeat the Ropalyst",
        .SeasonWeeklyHardKillEximus => " Kill 100 eximus",
        .SeasonWeeklyHardKillEnemies => "Kill 1500 enemies",
        .SeasonWeeklyHardIndexWinStreak => "Win 3 wagers in a row without letting the enemy score in one match of The Index",
        .SeasonWeeklyHardFriendsSurvival => "Complete a survival mission reaching at least 30 minutes",
        .SeasonWeeklyHardFriendsDefense => "Complete a defense mission reaching at least wave 20",
        .SeasonWeeklyHardExterminateNoAlarm => "Complete an Extermination Mission with level 30 or higher enemies without being detected",
        .SeasonWeeklyHardEliteSanctuaryOnslaught => "Complete 8 zones of Elite Sanctuary Onslaught",
        .SeasonWeeklyHardKillOrCaptureRainalyst => "Kill or Capture an Eidolon Hydrolyst",
        .SeasonWeeklyHardCompleteSortie => "Complete 3 sorties",
        .SeasonWeeklyHardCompleteNightmareMissions => "Complete 10 nightmare missions of any type",
        .SeasonWeeklyHardTheManyMadeWhole => "Exchange 10 riven slivers for a riven mod",

        else => log.message[last_slash_idx + 1 ..],
    };

    return game_types.NightwaveChallenge{
        .name = challenge_name,
        .tier = tier,
    };
}
