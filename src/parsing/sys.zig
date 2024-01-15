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
    if (std.mem.startsWith(u8, log.message, ": LotusProfileData::NotifyWorldStateChallengeCompleted")) {
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
        const challenge = std.meta.stringToEnum(game_types.NightwaveChallenges, log.message[last_slash_idx + 1 ..]) orelse .UNKNOWN;
        challenge_name = switch (challenge) {
            .SeasonWeeklyHardFriendsProfitTaker => "Kill the Profit-Taker in Orb Vallis",
            .SeasonWeeklyHardRailjackMissions => "Complete 8 Railjack missions",
            .SeasonWeeklyCompleteSpy => "Complete 3 spy missions",
            .SeasonWeeklyRailjackHijackDestroyThree => "While piloting a hijacked crewship, destroy 3 enemy fighters",
            .SeasonWeeklyPermanentKillEnemies7 => "Kill 500 enemies",
            .SeasonWeeklyPermanentKillEximus7 => "Kill 30 eximus enemies",
            .SeasonWeeklyPermanentCompleteMissions7 => "Complete any 15 missions",
            .SeasonDailyPickUpMods => "Pick up 8 modules",
            .SeasonDailyVisitFeaturedDojo => "Visit a featured dojo",
            .SeasonDailyKillEnemiesWithMelee => "Kill 150 enemies with a melee weapon",
            .SeasonWeeklyLoyalty => "Interact with your Kubrow or Kavat",
            .SeasonDailyKillEnemiesWithRadiation => "Kill 150 enemies with radiation damage",
            .SeasonDailyDeploySpecter => "Deploy a Specter",
            .SeasonDailyTwoForOne => "Pierce and kill 2 or more enemies in a single bow shot",
            .SeasonDailyCompleteMission => "Complete a mission",
            else => log.message[last_slash_idx + 1 ..],
        };

        return game_types.NightwaveChallenge{
            .name = challenge_name,
            .tier = tier,
        };
    }

    return null;
}
