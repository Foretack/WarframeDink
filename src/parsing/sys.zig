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

// TODO: Make this trigger for more rare items
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
    const first_num = std.mem.indexOfAny(u8, log.message, "1234567890");
    const end_at_idx = if (first_num != null) first_num.? else log.message.len;
    const challenge = std.meta.stringToEnum(game_types.NightwaveChallenges, log.message[last_slash_idx + 1 .. end_at_idx]) orelse .UNKNOWN;
    challenge_name = switch (challenge) {
        .SeasonDailyAimGlide => "Kill 15 Enemies while Aim Gliding",
        .SeasonDailyBulletJump => "Bullet Jump 150 times.",
        .SeasonDailyCodexScan => "Scan 15 Objects or Enemies.",
        .SeasonDailyCollectCredits => "Pick up 15000 Credits.",
        .SeasonDailyCompleteMission => "Complete a Mission.",
        .SeasonDailyDeployGlyph => "Deploy a Glyph while on a mission.",
        .SeasonDailyKillEnemies => "Kill 200 Enemies.",
        .SeasonDailyKillEnemiesWithAbilities => "Kill 150 Enemies with Abilities.",
        .SeasonDailyKillEnemiesWithBlast => "Kill 150 Enemies with Blast Damage.",
        .SeasonDailyKillEnemiesWithCorrosive => "Kill 150 Enemies with Corrosive Damage.",
        .SeasonDailyKillEnemiesWithElectricity => "Kill 150 Enemies with Electricity Damage.",
        .SeasonDailyKillEnemiesWithFinishers => "Kill 10 Enemies with Finishers.",
        .SeasonDailyKillEnemiesWithFire => "Kill 150 Enemies with Heat Damage.",
        .SeasonDailyKillEnemiesWithFreeze => "Kill 150 Enemies with Cold Damage.",
        .SeasonDailyKillEnemiesWithGas => "Kill 150 Enemies with Gas Damage.",
        .SeasonDailyKillEnemiesWithHeadshots => "Kill 40 Enemies with Headshots.",
        .SeasonDailyKillEnemiesWithMagnetic => "Kill 150 Enemies with Magnetic Damage.",
        .SeasonDailyKillEnemiesWithMelee => "Kill 150 Enemies with a Melee Weapon.",
        .SeasonDailyKillEnemiesWithPoison => "Kill 150 Enemies with Toxin Damage.",
        .SeasonDailyKillEnemiesWithPrimary => "Kill 150 Enemies with a Primary Weapon.",
        .SeasonDailyKillEnemiesWithRadiation => "Kill 150 Enemies with Radiation Damage.",
        .SeasonDailyKillEnemiesWithSecondary => "Kill 150 Enemies with a Secondary Weapon.",
        .SeasonDailyKillEnemiesWithViral => "Kill 150 Enemies with Viral Damage.",
        .SeasonDailyPickUpEnergy => "Pick up 20 Energy Orbs.",
        .SeasonDailyPickUpMods => "Pick up 8 Mods.",
        .SeasonDailyPlaceMarker => "Mark 5 Mods or Resources.",
        .SeasonDailyPlayEmote => "Play 1 Emote.",
        .SeasonDailySlideKills => "Kill 10 Enemies while Sliding.",
        .SeasonDailyKillEnemiesWhileOnKDrive => "Kill 20 enemies while riding a K-Drive, Kaithe, Velocipod, or Merulina.",
        .SeasonDailyLiquidation => "Sell any item in your Inventory for Credits.",
        .SeasonDailyTwoForOne => "Pierce and kill 2 or more enemies in a single Bow shot.",
        .SeasonDailySwatter => "Kill 3 Drones or Ospreys with your Melee Weapon.",
        .SeasonDailyToppingOffTheTank => "Successfully defend an Excavator without allowing it to run out of power.",
        .SeasonDailyThePersonalTouch => "Place 1 decoration in your Orbiter.",
        .SeasonDailyBuildersTouch => "Claim an item from your Foundry.",
        .SeasonDailyCompleteMissionMelee => "Complete a Mission with only a Melee Weapon equipped",
        .SeasonDailyCompleteMissionPrimary => "Complete a Mission with only a Primary Weapon equipped",
        .SeasonDailyCompleteMissionSecondary => "Complete a Mission with only a Secondary Weapon equipped",
        .SeasonDailyDeployAirSupport => "Deploy an Air Support Charge in a Mission",
        .SeasonDailyDeploySpecter => "Deploy a Specter",
        .SeasonDailyDonateLeverian => "Donate to the Leverian",
        .SeasonDailyInteractWithPet => "Interact with your Kubrow or Kavat",
        .SeasonDailyMercyKill => "Mercy Kill an Enemy",
        .SeasonDailyPickUpMedallion => "Find 5 Syndicate Medallions. You can search by yourself or with a squad.",
        .SeasonDailyHijackCrewship => "Hijack a Crewship from the enemy",
        .SeasonDailySuspendFiveEnemies => "Suspend 5 or more enemies in the air at once with a Heavy Slam Melee Attack",
        .SeasonDailyTransmuteMods => "Complete 1 Mod Transmutations",
        .SeasonDailyVisitFeaturedDojo => "Visit a Featured Dojo",
        .SeasonDailyFeedMeMore => "Feed the Maw in Duviri",
        .SeasonDailyHelpingHand => "Rescue an animal in Duviri",
        .SeasonDailySalutations => "Visit Acrithis in Duviri",
        .SeasonDailyYourMove => "Complete a game of Komi in Duviri",

        .SeasonWeeklyCatchRarePlainsFish => "Catch 3 Rare Fish in the Plains of Eidolon.",
        .SeasonWeeklyCatchRareVenusFish => "Catch 3 Rare Servofish in the Orb Vallis.",
        .SeasonWeeklyCompleteAssassination => "Complete 3 Assassination missions.",
        .SeasonWeeklyCompleteCapture => "Complete 3 Capture missions.",
        .SeasonWeeklyCompleteClemMission => "Help Clem with his weekly mission.",
        .SeasonWeeklyCompleteExterminate => "Complete 3 Exterminate missions.",
        .SeasonWeeklyCompleteInvasionMissions => "Complete 6 Invasion missions of any type.",
        .SeasonWeeklyCompleteMobileDefense => "Complete 3 Mobile Defense missions.",
        .SeasonWeeklyCompleteNightmareMissions => "Complete 3 Nightmare missions of any type.",
        .SeasonWeeklyCompleteRescue => "Complete 3 Rescue missions.",
        .SeasonWeeklyCompleteSabotage => "Complete 3 Sabotage missions.",
        .SeasonWeeklyCompleteSortie => "Complete 1 Sortie.",
        .SeasonWeeklyCompleteSpy => "Complete 3 Spy missions.",
        .SeasonWeeklyCompleteSyndicateMissions => "Complete 5 Syndicate missions.",
        .SeasonWeeklyCompleteTreasures => "Look for Ayatan Treasures for Maroo in Maroo's Bazaar.",
        .SeasonWeeklyKillEnemiesWithHeadshots => "Kill 100 Enemies with head shots.",
        .SeasonWeeklyMineRarePlainsResources => "Mine 3 Rare Gems or Ore in the Plains of Eidolon.",
        .SeasonWeeklyMineRareVenusResources => "Mine 3 Rare Gems or Ore in the Orb Vallis.",
        .SeasonWeeklyPerfectAnimalCapture => "Complete 3 different Perfect Animal Captures in Orb Vallis.",
        .SeasonWeeklyPlainsBounties => "Complete 3 different Bounties in the Plains of Eidolon.",
        .SeasonWeeklySabotageCaches => "Find 6 caches across any Sabotage mission.",
        .SeasonWeeklySanctuaryOnslaught => "Complete 8 Zones of Sanctuary Onslaught.",
        .SeasonWeeklySimarisScan => "Complete 3 Scans for Cephalon Simaris.",
        .SeasonWeeklyUnlockDragonVaults => "Unlock 4 Dragon Key vaults on Deimos.",
        .SeasonWeeklyUnlockRelics => "Unlock 3 Relics",
        .SeasonWeeklyUseForma => "Polarize a Weapon, Companion, or Warframe (not in Simulacrum).",
        .SeasonWeeklyVenusBounties => "Complete 3 different Bounties in the Orb Vallis.",
        .SeasonWeeklyNightAndDay => "Collect 10 Vome or Fass Residue in the Cambion Drift.",
        .SeasonWeeklyLoyalty => "Gain a total of 5000 Standing across all Syndicate factions.",
        .SeasonWeeklyTheOldWays => "Complete 1 mission with only a single pistol and a glaive equipped.",
        .SeasonWeeklyBloodthirsty => "Kill 20 enemies in 5 seconds.",
        .SeasonWeeklyIsolationBounties => "Complete an Isolation Vault Bounty Mission in the Cambion Drift on Deimos.",
        .SeasonWeeklyFeedHelminth => "Feed the Helminth any resource.",
        .SeasonWeeklyKillEnemiesInMech => "Kill 100 enemies with a Necramech.",
        .SeasonWeeklyCompleteDisruptionConduits => "Complete 12 Conduits in Disruption",
        .SeasonWeeklyEternalGuardian => "Complete 2 Void Armageddon missions.",
        .SeasonWeeklyHighGround => "Complete 3 Void Flood missions.",
        .SeasonWeeklyZarimanBountyHunter => "Complete 4 different Bounties in the Zariman.",
        .SeasonWeeklyCompleteKuva => "Complete 3 Kuva Siphon Missions",
        .SeasonWeeklyCompleteVenusRace => "Complete 3 different K-Drive races in Orb Vallis on Venus or in Cambion Drift on Deimos.",
        .SeasonWeeklyDestroyCrewshipArtillery => "Destroy a Crewship with Forward Artillery",
        .SeasonWeeklyKillArchgunEnemies => "Kill 500 enemies with an Archgun",
        .SeasonWeeklyKillThumper => "Kill a Tusk Thumper in the Plains of Eidolon",
        .SeasonWeeklyRailjackHijackDestroyThree => "While piloting a hijacked Crewship, destroy 3 enemy fighters",
        .SeasonWeeklyRailjackMissions => "Complete 3 Railjack Missions",
        .SeasonWeeklyBeastSlayer => "Defeat the Orowyrm",
        .SeasonWeeklyBoardingPartyNoDamage => "Clear a Railjack Boarding Party without your Warframe taking damage",
        .SeasonWeeklyCollector => "Collect 100 resources from Duviri",
        .SeasonWeeklyFinelyTuned => "Play 3 different Shawzin songs in Duviri",
        .SeasonWeeklyHorsingAround => "Fly your Kaithe for 1500 meters",
        .SeasonWeeklyIDecree => "Collect 15 Decrees in Duviri",
        .SeasonWeeklySkeletonsInTheCloset => "Kill 50 Dax enemies in Duviri",
        .SeasonWeeklyRequiemTotem => "Activate 3 Requiem Obelisks on Deimos.",
        .SeasonWeeklyCollectHundredResources => "Collect 4000 Resources",
        .SeasonWeeklySolveCiphers => "Hack 10 Consoles.",
        .SeasonWeeklyOpenLockers => "Open 30 Lockers.",

        .SeasonWeeklyPermanentCompleteMissions => "Complete 15 missions",
        .SeasonWeeklyPermanentKillEximus => "Kill 30 Eximus.",
        .SeasonWeeklyPermanentKillEnemies => "Kill 500 enemies.",

        .SeasonWeeklyHardLuaPuzzles => "Complete 4 Halls of Ascension on Lua.",
        .SeasonWeeklyHardCompleteNightmareMissions => "Complete 5 Nightmare missions of any type.",
        .SeasonWeeklyHardCompleteSortie => "Complete 3 Sorties.",
        .SeasonWeeklyHardEliteSanctuaryOnslaught => "Complete 8 Zones of Elite Sanctuary Onslaught.",
        .SeasonWeeklyHardFriendsDefense => "Complete a Defense mission reaching at least Wave 20.",
        .SeasonWeeklyHardFriendsProfitTaker => "Kill the Profit-Taker.",
        .SeasonWeeklyHardFriendsSurvival => "Complete a Survival mission reaching at least 20 minutes.",
        .SeasonWeeklyHardIndexWinStreak => "Win 3 wagers in a row without letting the enemy score in one match of The Index.",
        .SeasonWeeklyHardKillEnemies => "Kill 1500 Enemies.",
        .SeasonWeeklyHardKillEximus => "Kill 100 Eximus.",
        .SeasonWeeklyHardKillOrCaptureRainalyst => "Kill or Capture an Eidolon Hydrolyst.",
        .SeasonWeeklyHardKuvaSurvivalNoCapsules => "Survive for over 20 minutes in Kuva Survival.",
        .SeasonWeeklyHardUnlockRelics => "Unlock 10 Relics",
        .SeasonWeeklyHardKillEnemiesSteelPath => "Kill 1000 Enemies on The Steel Path.",
        .SeasonWeeklyHardCollectUniqueResources => "Collect 20 different types of resources.",
        .SeasonWeeklyHardCompleteSteelPathMissions => "Complete 5 different Steel Path Missions.",
        .SeasonWeeklyHardAntiquarian => "Open one of each era/tier of Relic (Lith, Meso, Neo, Axi) 4.",
        .SeasonWeeklyHardThePriceOfFreedom => "Free one Captured Solaris using a Granum Crown.",
        .SeasonWeeklyHardTheManyMadeWhole => "Exchange 10 Riven Slivers for a Riven Mod",
        .SeasonWeeklyHardTerminated => "Destroy 3 Necramech vault guardians.",
        .SeasonWeeklyHardRiseOfTheMachine => "Kill 300 enemies using a Necramech without getting destroyed.",
        .SeasonWeeklyHardFallenAngel => "Defeat 5 Void Angels in the Zariman. ",
        .SeasonWeeklyHardFastCapture => "Finish a Capture mission in less than 90 seconds",
        .SeasonWeeklyHardKillExploiterOrb => "Kill the Exploiter Orb",
        .SeasonWeeklyHardKillRopalolyst => "Defeat the Ropalolyst",
        .SeasonWeeklyHardKillThumper => "Kill a Tusk Thumper Doma in the Plains of Eidolon",
        .SeasonWeeklyHardRailjackMissions => "Complete 8 Railjack Missions",
        .SeasonWeeklyHardCompleteArchonHunt => "Complete an Archon Hunt.",
        .SeasonWeeklyHardFriendsMirrorDefense => "Complete 3 waves of Mirror Defense.",
        .SeasonWeeklyHardCeremonialEvolution => "Activate the Incarnon Form of any Incarnon weapon in-mission 5 times",
        .SeasonWeeklyHardEliteBeastSlayer => "Defeat the Orowyrm in Steel Path",
        .SeasonWeeklyHardPerplexed => "Complete 3 puzzles in Duviri",
        .SeasonWeeklyHardVitalArbiter => "Complete an Arbitration Mission",

        else => log.message[last_slash_idx + 1 ..],
    };

    return game_types.NightwaveChallenge{
        .name = challenge_name,
        .tier = tier,
    };
}
