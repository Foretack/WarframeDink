const std = @import("std");

pub const Config = struct {
    username: ?[]const u8,
    profilePictureUrl: []const u8,
    warframeLogFile: []const u8,
    webhookUrl: []const u8,
    notifications: struct {
        login: NotifEntry = .{},
        logout: NotifEntry = .{},
        masteryRankUp: NotifEntry = .{},
        nightwaveChallengeComplete: NotifEntry = .{},
        acolyteDefeat: NotifEntry = .{},
        stalkerDefeat: NotifEntry = .{},
        lichSpawn: NotifEntry = .{},
        lichDefeat: NotifEntry = .{},
        eidolonCaptured: NotifEntry = .{},
        dailySortie: NotifEntry = .{},
        rivenSliverPickup: NotifEntry = .{},
        missionFailed: NotifEntry = .{},
        death: NotifEntry = .{},
        normalMission: NotifEntry = .{},
        steelPathMission: NotifEntry = .{},
        nightmareMission: NotifEntry = .{},
        kuvaSiphon: NotifEntry = .{},
        kuvaFlood: NotifEntry = .{},
        weeklyAyatanMission: NotifEntry = .{},
        eidolonHunt: NotifEntry = .{},
        voidFissure: NotifEntry = .{},
        arbitration: NotifEntry = .{},
        sanctuaryOnslaught: NotifEntry = .{},
        syndicateMission: NotifEntry = .{},
        lichTerritoryMission: NotifEntry = .{},
        grustragDefeat: NotifEntry = .{},
        profitTakerKill: NotifEntry = .{},
        voidAngelKill: NotifEntry = .{},
    },

    pub fn get(allocator: std.mem.Allocator) !Config {
        const file = try std.fs.cwd().openFile("config.json", .{});
        defer file.close();
        // deallocing this breaks shit
        const content = try file.readToEndAlloc(allocator, 8192);
        const json = try std.json.parseFromSlice(Config, allocator, content, .{ .ignore_unknown_fields = true });
        return json.value;
    }
};

pub const NotifEntry = struct {
    enabled: bool = true,
    minLevel: u16 = 0,
    showTime: bool = false,
};
