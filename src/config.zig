const std = @import("std");

pub const Config = struct {
    profilePictureUrl: []const u8,
    warframeLogFile: []const u8,
    webhookUrl: []const u8,
    notifications: struct {
        login: NotifEntry,
        logout: NotifEntry,
        masteryRankUp: NotifEntry,
        nightwaveChallengeComplete: NotifEntry,
        acolyteDefeat: NotifEntry,
        stalkerDefeat: NotifEntry,
        lichSpawn: NotifEntry,
        lichDefeat: NotifEntry,
        eidolonCaptured: NotifEntry,
        dailySortie: NotifEntry,
        rivenSliverPickup: NotifEntry,
        missionFailed: NotifEntry,
        death: NotifEntry,
        normalMission: NotifEntry,
        steelPathMission: NotifEntry,
        nightmareMission: NotifEntry,
        kuvaSiphon: NotifEntry,
        kuvaFlood: NotifEntry,
        weeklyAyatanMission: NotifEntry,
        eidolonHunt: NotifEntry,
        voidFissure: NotifEntry,
        arbitration: NotifEntry,
        sanctuaryOnslaught: NotifEntry,
        syndicateMission: NotifEntry,
        lichTerritoryMission: NotifEntry,
    },

    pub fn get(allocator: std.mem.Allocator) !Config {
        const file = try std.fs.cwd().openFile("config.json", .{});
        defer file.close();
        const content = try file.readToEndAlloc(allocator, 8192);
        defer allocator.free(content);
        const json = try std.json.parseFromSlice(Config, allocator, content, .{ .ignore_unknown_fields = true });
        std.debug.print("Config loaded\n {s}\n {s}\n {s}\n", .{ json.value.profilePictureUrl, json.value.warframeLogFile, json.value.webhookUrl });
        return json.value;
    }
};

pub const NotifEntry = struct {
    enabled: bool = true,
    minLevel: u16 = 0,
};
