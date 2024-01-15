pub const NightwaveChallenge = struct {
    name: []const u8,
    tier: ChallengeTier,
};

pub const ChallengeTier = enum {
    Daily,
    Weekly,
    EliteWeekly,
};

pub const NightwaveChallenges = enum {
    SeasonWeeklyHardFriendsProfitTaker,
    SeasonWeeklyHardRailjackMissions,
    SeasonWeeklyCompleteSpy,
    SeasonWeeklyRailjackHijackDestroyThree,
    SeasonWeeklyPermanentKillEnemies7,
    SeasonWeeklyPermanentKillEximus7,
    SeasonWeeklyPermanentCompleteMissions7,
    SeasonDailyPickUpMods,
    SeasonDailyVisitFeaturedDojo,
    SeasonDailyDeploySpecter,
    SeasonDailyKillEnemiesWithMelee,
    SeasonWeeklyLoyalty,
    SeasonDailyKillEnemiesWithRadiation,
    SeasonDailyTwoForOne,
    SeasonDailyCompleteMission,
    UNKNOWN,
};

pub const Acolytes = enum {
    StrikerAcolyte,
    HeavyAcolyte,
    RogueAcolyte,
    AreaCasterAcolyte,
    ControlAcolyte,
    DuellistAcolyte,
};
