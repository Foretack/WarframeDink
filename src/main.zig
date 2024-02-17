const std = @import("std");
const cfg = @import("config.zig");
const sys = @import("parsing/sys.zig");
const game = @import("parsing/game.zig");
const script = @import("parsing/script.zig");
const discord = @import("utils/discord.zig");
const ss = @import("utils/string_switch.zig");
const try_extract = @import("parsing/try_extract.zig");
const NightwaveChallenge = @import("game_types.zig").NightwaveChallenge;
const CurrentMission = @import("current_mission.zig").Mission;
const Objective = @import("current_mission.zig").Objective;
const parseLog = @import("log_types.zig").parseLog;
const dbg = @import("builtin").mode == .Debug;
const fs = std.fs;
const fmt = std.fmt;
const mem = std.mem;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();
var config: cfg.Config = undefined;
var startTime: i64 = undefined;
var cfgUser: ?[]const u8 = null;
var user: []const u8 = undefined;
var loggedOut = false;
var checkMtime: i128 = 0;

pub fn main() !void {
    config = cfg.Config.init(allocator) catch |err| {
        std.log.err("Failed to load config file: {}\n", .{err});
        std.time.sleep(5_000_000_000);
        return;
    };

    cfgUser = config.username;
    while (true) {
        startTime = std.time.timestamp();
        const file = fs.openFileAbsolute(config.warframeLogFile, .{}) catch |err| {
            std.log.err("Failed to open log file: {}\n", .{err});
            std.time.sleep(5_000_000_000);
            // I think warframe deletes the file on startup which is not cool, so we should continue until we find it
            continue;
        };
        defer file.close();
        const stat = try file.stat();
        if (stat.mtime < checkMtime) {
            std.log.info("File has not changed since user logout. Waiting for change...\n", .{});
            std.time.sleep(30_000_000_000);
            continue;
        }

        const reader = file.reader();
        var buf: [8192]u8 = undefined;
        while (true) {
            if (loggedOut and stat.mtime < checkMtime) {
                std.log.info("User logged out. Closing file...\n", .{});
                break;
            }

            const read = reader.read(&buf) catch |err| {
                std.log.err("Failed to read log file: {}\n", .{err});
                std.time.sleep(5_000_000_000);
                return;
            };
            lineIterate(buf[0..read], if (read < buf.len) read else null) catch |err| {
                std.log.err("Failed to iterate over block: {s}\nblock:\n", .{ err, buf[0..read] });
                std.time.sleep(5_000_000_000);
                return;
            };
            if (read < buf.len) {
                std.time.sleep(1_000_000_000);
                continue;
            }
        }

        // 30s
        std.time.sleep(30_000_000_000);
    }
}

fn lineIterate(buffer: []u8, stopAt: ?usize) !void {
    var line_start_idx: usize = 0;
    var crlf_idx: ?usize = mem.indexOf(u8, buffer, "\r\n");
    while (crlf_idx) |line_end_idx| : (crlf_idx = mem.indexOf(u8, buffer[line_start_idx .. stopAt orelse buffer.len], "\r\n")) {
        const indexed_end = line_end_idx + line_start_idx;
        lineAction(buffer[line_start_idx..indexed_end]) catch |alloc_err| {
            std.log.err("Allocation error: {}\n", .{alloc_err});
            return;
        };

        line_start_idx = indexed_end + 2;
    }
}

var readingObject: bool = false;

fn lineAction(line: []const u8) !void {
    if (readingObject) {
        if (try_extract.isObjectDumpEnd(line)) {
            readingObject = false;
            return;
        } else if (!lineIsSeq(line)) {
            if (try_extract.objectNumField(line)) |field| {
                if (mem.eql(u8, field.name, "minEnemyLevel")) {
                    CurrentMission.minLevel = field.value;
                } else if (mem.eql(u8, field.name, "maxEnemyLevel")) {
                    CurrentMission.maxLevel = field.value;
                }

                return;
            } else if (try_extract.objectStrField(line)) |obj_field| {
                if (mem.eql(u8, obj_field.name, "missionType")) {
                    CurrentMission.objective = std.meta.stringToEnum(Objective, obj_field.value) orelse .UNKNOWN;
                } else if (mem.startsWith(u8, obj_field.name, "UpgradeFinger")) {
                    const compat_idx = mem.indexOf(u8, obj_field.value, "\\\"compat\\\":\\\"/Lotus/Weapons/");
                    if (compat_idx) |i| {
                        const wep_idx = i + 28;
                        const category = (mem.indexOf(u8, obj_field.value[wep_idx..], "/") orelse return) + wep_idx + 1;
                        const category_end = (mem.indexOf(u8, obj_field.value[category..], "/") orelse return) + category;
                        const name = obj_field.value[category..category_end];
                        std.log.info("unveiled riven for: {s}\n", .{rivenCategory(name)});
                        const message_str = try fmt.allocPrint(allocator, "Unveiled a {s} Riven!", .{rivenCategory(name)});
                        defer allocator.free(message_str);

                        sendDiscordMessage(message_str, null, 9442302, false);
                    }
                } else if (mem.eql(u8, obj_field.name, "goalTag") and mem.eql(u8, obj_field.value, "KahlMission")) {
                    CurrentMission.kind = .KahlMission;
                }

                return;
            }
        } else readingObject = false;
    } else if (try_extract.isObjectDumpStart(line)) {
        readingObject = true;
        return;
    }

    const log = parseLog(line) orelse return;
    if (log.level != .Info) return;
    var notif: struct { cfg.NotifEntry, Events } = .{ .{ .enabled = false }, .UNKNOWN };
    var desc: ?[]const u8 = null;
    var color: discord.EmbedColors = undefined;
    var arg: union {
        nwChallenge: NightwaveChallenge,
        killedBy: []const u8,
        acolyte: []const u8,
        masteryRank: u8,
    } = undefined;

    switch (log.category) {
        .Sys => {
            if (sys.loginUsername(log)) |username| {
                user = allocator.dupe(u8, username) catch unreachable;
                loggedOut = false;
                std.log.info("{s} logged in\n", .{user});
                notif = entryOf(.login);
                color = .darkGreen;
            } else if (sys.missionEnd(log)) {
                std.log.info("mission ended ({s}, {s})\n", .{ @tagName(CurrentMission.kind), @tagName(CurrentMission.objective) });
                try missionEnd();
                return;
            } else if (sys.nightwaveChallengeComplete(log)) |nw_challenge| {
                std.log.info("nightwave challenge complete: {s}\n", .{nw_challenge.name});
                notif = entryOf(.nightwaveChallengeComplete);
                color = .pink;
                arg = .{ .nwChallenge = nw_challenge };
            } else if (sys.exitingGame(log)) {
                std.log.info("{s} logged out\n", .{user});
                loggedOut = true;
                checkMtime = std.time.nanoTimestamp() + 10_000_000_000;
                notif = entryOf(.logout);
                color = .magenta;
            } else if (sys.rivenSliverPickup(log)) {
                std.log.info("Riven Sliver pickup\n", .{});
                notif = entryOf(.rivenSliverPickup);
                color = .purple;
            }
        },
        .Script => {
            if (script.missionInfo(log)) |mission_info| {
                allocator.free(CurrentMission.name);
                CurrentMission.name = allocator.dupe(u8, mission_info.name) catch unreachable;
                CurrentMission.startedAt = std.time.timestamp();
                CurrentMission.kind = mission_info.kind;
                CurrentMission.resetVars();
                std.log.debug("new mission set: {s}\n", .{CurrentMission.name});
                return;
            } else if (script.missionSuccess(log)) {
                CurrentMission.successCount += 1;
                std.log.debug("(success count increase)\n", .{});
                return;
            } else if (script.missionFailure(log)) {
                std.log.info("mission failed :(\n", .{});
                notif = entryOf(.missionFailed);
                color = .orange;
            } else if (script.acolyteDefeated(log)) |acolyte| {
                std.log.info("acolyte defeated: {s}\n", .{acolyte});
                notif = entryOf(.acolyteDefeat);
                color = .black;
                arg = .{ .acolyte = acolyte };
            } else if (script.eidolonCaptured(log)) {
                CurrentMission.kind = .EidolonHunt;
                std.log.info("eidolon captured\n", .{});
                CurrentMission.eidolonsCaputred += 1;
                notif = entryOf(.eidolonCaptured);
                color = .cyan;
            } else if (script.kuvaLichSpawn(log)) {
                std.log.info("lich spawned\n", .{});
                notif = entryOf(.lichSpawn);
                color = .darkRed;
            } else if (script.isMasteryRankUp(log)) |new_rank| {
                std.log.info("Mastery Rank {} reached\n", .{new_rank});
                notif = entryOf(.masteryRankUp);
                color = .blue;
                arg = .{ .masteryRank = new_rank };
            } else if (script.stalkerDefeated(log)) {
                std.log.info("stalker defeated\n", .{});
                notif = entryOf(.stalkerDefeat);
                color = .black;
            } else if (script.lichDefeated(log)) {
                std.log.info("lich defeated\n", .{});
                notif = entryOf(.lichDefeat);
                color = .white;
            } else if (script.grustragDefeated(log)) {
                std.log.info("grustrag three defeated\n", .{});
                notif = entryOf(.grustragDefeat);
                color = .brown;
            } else if (script.profitTakerDefeated(log)) {
                std.log.info("profit taker killed\n", .{});
                notif = entryOf(.profitTakerKill);
                color = .brown;
            } else if (script.exploiterOrbDefeated(log)) {
                std.log.info("exploiter orb killed\n", .{});
                notif = entryOf(.exploiterOrbKill);
                color = .cyan;
            } else if (script.voidAngelKilled(log)) {
                std.log.info("void angel killed\n", .{});
                notif = entryOf(.voidAngelKill);
                color = .cyan;
            } else if (script.onslaughtWaveFinished(log)) {
                CurrentMission.onslaughtWaves += 1;
                std.log.info("sanctuary onslaught wave complete ({d})\n", .{CurrentMission.onslaughtWaves});
                return;
            }
        },
        .Game => {
            if (game.hostMigration(log)) {
                std.log.debug("suffering host migration...\n", .{});
                return;
            } else if (game.userDeath(log, user)) |killed_by| {
                std.log.info("dead to a {s}\n", .{killed_by});
                notif = entryOf(.death);
                color = .red;
                arg = .{ .killedBy = killed_by };
            } else if (game.zanukaDefeat(log)) {
                std.log.info("zanuka hunter defeated\n", .{});
                notif = entryOf(.zanukaDefeat);
                color = .brown;
            }
        },
        else => return,
    }

    if (notif[1] == .UNKNOWN or !shouldPost(notif[0])) {
        return;
    }

    var arena = std.heap.ArenaAllocator.init(allocator);
    const a_alloc = arena.allocator();
    defer arena.deinit();

    const message = switch (notif[1]) {
        .login => "Logged in",
        .nightwaveChallengeComplete => try fmt.allocPrint(a_alloc, "Completed {s} Nightwave challenge!", .{challengeTier(arg.nwChallenge)}),
        .logout => "Logged out",
        .rivenSliverPickup => "Found a Riven Sliver!",
        .missionFailed => try fmt.allocPrint(a_alloc, "Failed {s} {s} mission!", .{ missionKindStr(), missionObjStr() }),
        .acolyteDefeat => try fmt.allocPrint(a_alloc, "Defeated an Acolyte! ({s})", .{arg.acolyte}),
        .eidolonCaptured => "Captured an Eidolon!",
        .lichSpawn => "Spawned a Lich!",
        .masteryRankUp => try fmt.allocPrint(a_alloc, "Reached Mastery Rank {}!", .{arg.masteryRank}),
        .stalkerDefeat => "Defeated the Stalker!",
        .lichDefeat => "Defeated their Lich!",
        .grustragDefeat => "Defeated the Grustrag Three!",
        .zanukaDefeat => "Defeated the Zanuka Hunter!",
        .profitTakerKill => "Killed the Profit Taker!",
        .exploiterOrbKill => "Killed the Exploiter Orb!",
        .voidAngelKill => try fmt.allocPrint(a_alloc, "Killed a dormant Void Angel! ({}-{})", .{ CurrentMission.minLevel, CurrentMission.maxLevel }),
        .death => try fmt.allocPrint(a_alloc, "Died to a {s}", .{arg.killedBy}),
        else => return,
    };
    defer if (notif[1] == .logout) allocator.free(user);

    desc = switch (notif[1]) {
        .nightwaveChallengeComplete => arg.nwChallenge.name,
        .missionFailed => CurrentMission.name,
        else => null,
    };

    sendDiscordMessage(message, desc, @intFromEnum(color), notif[0].showTime);
}

fn isFinalSortieMission() bool {
    return CurrentMission.kind == .Sortie and CurrentMission.minLevel == 80;
}

fn isFinalArchonMission() bool {
    return CurrentMission.kind == .ArchonHunt and CurrentMission.objective == .MT_ASSASSINATION;
}

fn lineIsSeq(line: []const u8) bool {
    if (line.len < 6) return false;
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        if (line[i] < '0' and '9' < line[i]) {
            return false;
        } else if (line[i] == '.') {
            return true;
        }
    }

    return false;
}

pub fn secSinceStart() i64 {
    return std.time.timestamp() - startTime;
}

fn missionEnd() !void {
    if (!dbg and std.time.timestamp() - CurrentMission.startedAt < 30) {
        return;
    }

    if (CurrentMission.successCount == 0) {
        std.log.info("Mission ended without success count increase\n", .{});
        return;
    }

    var arena = std.heap.ArenaAllocator.init(allocator);
    const a_alloc = arena.allocator();
    defer arena.deinit();

    var mission_str: []const u8 = undefined;
    var notif: struct { cfg.NotifEntry, Events } = switch (CurrentMission.kind) {
        .EidolonHunt => entryOf(.eidolonHunt),
        .Sortie => entryOf(.dailySortie),
        .Nightmare => entryOf(.nightmareMission),
        .Kuva => entryOf(.kuvaSiphon),
        .Syndicate => entryOf(.syndicateMission),
        .KuvaFlood => entryOf(.kuvaFlood),
        .SteelPath => entryOf(.steelPathMission),
        .ControlledTerritory => entryOf(.lichTerritoryMission),
        .Arbitration => entryOf(.arbitration),
        .T1Fissure, .T2Fissure, .T3Fissure, .T4Fissure, .T5Fissure => entryOf(.voidFissure),
        .TreasureHunt => entryOf(.weeklyAyatanMission),
        .KahlMission => entryOf(.kahlMission),
        .ArchonHunt => entryOf(.weeklyArchonHunt),
        else => entryOf(.normalMission),
    };

    if (CurrentMission.objective == .MT_ENDLESS_EXTERMINATION) {
        notif = entryOf(.sanctuaryOnslaught);
    } else if (CurrentMission.objective == .MT_RAILJACK) {
        return; // TODO: there is no setting for this in options
    }

    if (!shouldPost(notif[0])) {
        return;
    }

    switch (notif[1]) {
        .UNKNOWN => return,
        .dailySortie => {
            if (!isFinalSortieMission()) return;
            mission_str = "Completed today's Sortie!";
        },
        .sanctuaryOnslaught => {
            mission_str = try fmt.allocPrint(a_alloc, "Completed {d} waves of {s}!", .{ CurrentMission.onslaughtWaves, CurrentMission.name });
        },
        .weeklyAyatanMission => {
            mission_str = "Completed the weekly Ayatan hunt mission!";
        },
        .kahlMission => {
            mission_str = "Completed the weekly Kahl mission!";
        },
        .weeklyArchonHunt => {
            if (!isFinalArchonMission()) return;
            mission_str = "Completed the weekly Archon hunt mission!";
        },
        .eidolonHunt => {
            if (CurrentMission.eidolonsCaputred == 0) return;
            mission_str = try fmt.allocPrint(allocator, "Completed an Eidolon hunt! (x{d})", .{CurrentMission.eidolonsCaputred});
        },
        else => {
            mission_str = try fmt.allocPrint(allocator, "Completed {s} {s} mission: {s}! ({}-{})", .{
                missionKindStr(),
                missionObjStr(),
                CurrentMission.name,
                CurrentMission.minLevel,
                CurrentMission.maxLevel,
            });
        },
    }

    CurrentMission.successCount = 0;
    sendDiscordMessage(mission_str, null, @intFromEnum(discord.EmbedColors.lightGreen), notif[0].showTime);
}

fn sendDiscordMessage(title: []const u8, description: ?[]const u8, color: i32, includeTime: bool) void {
    if (!dbg and secSinceStart() < 3) {
        return;
    }

    var arena = std.heap.ArenaAllocator.init(allocator);
    const a_alloc = arena.allocator();
    defer arena.deinit();

    var footer: ?discord.Footer = null;
    if (includeTime) {
        const time_str: ?[]const u8 = timeStr() catch null;
        if (time_str) |time| {
            footer = discord.Footer{ .text = time };
        }
    }

    const embed = discord.Embed{
        .title = title,
        .description = description,
        .color = color,
        .footer = footer,
    };

    const embed_arr: []discord.Embed = a_alloc.alloc(discord.Embed, 1) catch |err| {
        std.log.err("Failed to allocate embed array: {}\n", .{err});
        return;
    };

    embed_arr[0] = embed;
    const message = discord.Message{
        .avatar_url = config.profilePictureUrl,
        .username = cfgUser orelse user,
        .embeds = embed_arr,
    };

    const status = message.SendWebhook(a_alloc, config.webhookUrl) catch |send_err| {
        std.log.err("Failed to send webhook: {}\n", .{send_err});
        return;
    };

    if (status != .no_content) {
        std.log.err("Webhook not sent: HTTP Status: {s}\n", .{@tagName(status)});
    }
}

fn shouldPost(entry: cfg.NotifEntry) bool {
    if (!entry.enabled) return false;
    if (entry.minLevel > CurrentMission.minLevel) return false;
    if (entry.minTime > @divFloor(std.time.timestamp() - CurrentMission.startedAt, 60)) return false;
    return true;
}

fn entryOf(comptime event: Events) struct { cfg.NotifEntry, Events } {
    inline for (comptime std.meta.fieldNames(cfg)) |field| {
        if (comptime !mem.eql(u8, field, @tagName(event))) continue;
        return .{ @field(config, field), event };
    }

    std.log.err("Notification entry of event {s} is not present in notifications config\n", .{@tagName(event)});
    unreachable;
}

fn missionKindStr() []const u8 {
    return switch (CurrentMission.kind) {
        .Nightmare => "a Nightmare",
        .Kuva => "a Kuva",
        .KuvaFlood => "a Kuva Flood",
        .SteelPath => "a Steel Path",
        .EidolonHunt => "an Eidolon hunt",
        .Arbitration => "an Arbitration",
        .T1Fissure => "a Lith Fissure",
        .T2Fissure => "a Meso Fissure",
        .T3Fissure => "a Neo Fissure",
        .T4Fissure => "an Axi Fissure",
        .T5Fissure => "a Requiem Fissure",
        .Syndicate => "a Syndicate",
        .ControlledTerritory => "a Lich controlled territory",
        .Sortie => "a Sortie",
        else => "the",
    };
}

fn missionObjStr() []const u8 {
    return switch (CurrentMission.objective) {
        .MT_SURVIVAL => "survival",
        .MT_DEFENSE => "defense",
        .MT_MOBILE_DEFENSE => "mobile defense",
        .MT_RESCUE => "rescue",
        .MT_CAPTURE => "capture",
        .MT_EXTERMINATION => "exterminate",
        .MT_INTEL => "spy",
        .MT_COUNTER_INTEL => "deception",
        .MT_SABOTAGE => "sabotage",
        .MT_SABOTAGE_2 => "caches",
        .MT_EXCAVATE => "excavation",
        .MT_HIVE => "hive",
        .MT_TERRITORY => "interception",
        .MT_RETRIEVAL => "hijack",
        .MT_EVACUATION => "defection",
        .MT_ARENA => "arena",
        .MT_ASSASSINATION => "assassination",
        .MT_PURSUIT => "pursuit",
        .MT_RACE => "rush",
        .MT_ASSAULT => "assault",
        .MT_PURIFY => "infested salvage",
        .MT_RAID => "raid",
        .MT_SALVAGE => "recovery",
        .MT_ARTIFACT => "disruption",
        .MT_SECTOR => "dark sector",
        .MT_JUNCTION => "junction",
        .MT_PVP => "conclave",
        .MT_GENERIC => "quest",
        .MT_LANDSCAPE => "free roam",
        .MT_ENDLESS_EXTERMINATION => "sanctuary onslaught",
        .MT_RAILJACK => "skirmish  (Railjack)",
        .MT_RAILJACK_ORPHIX => "orphix  (Railjack)",
        .MT_RAILJACK_VOLATILE => "volatile  (Railjack)",
        .MT_RAILJACK_SPY => "spy  (Railjack)",
        .MT_RAILJACK_SURVIVAL => "survival  (Railjack)",
        .MT_ARMAGEDDON => "void armageddon",
        .MT_VOID_CASCADE => "void cascade",
        .MT_CORRUPTION => "void flood",
        else => "",
    };
}

fn timeStr() ![]const u8 {
    const sec_diff: u64 = @intCast(std.time.timestamp() - CurrentMission.startedAt);
    const hours = @divFloor(sec_diff, 3600);
    var secs_remaining = @mod(sec_diff, 3600);
    const minutes = @divFloor(secs_remaining, 60);
    secs_remaining = @mod(secs_remaining, 60);
    if (hours > 0) {
        return fmt.allocPrint(allocator, "[{d}:{d:0>2}:{d:0>2}]", .{ hours, minutes, secs_remaining });
    }

    if (minutes > 0) {
        return fmt.allocPrint(allocator, "[{d:0>2}:{d:0>2}]", .{ minutes, secs_remaining });
    }

    return fmt.allocPrint(allocator, "[{d:0>2}s]", .{secs_remaining});
}

fn challengeTier(challenge: NightwaveChallenge) []const u8 {
    return switch (challenge.tier) {
        .EliteWeekly => "an elite weekly",
        .Weekly => "a weekly",
        .Daily => "a daily",
    };
}

fn rivenCategory(string: []const u8) []const u8 {
    return switch (ss.stringSwitch(string)) {
        ss.case("LongGuns") => "Shotguns",
        else => string,
    };
}

const Events = enum {
    UNKNOWN,
    login,
    logout,
    masteryRankUp,
    nightwaveChallengeComplete,
    acolyteDefeat,
    stalkerDefeat,
    lichSpawn,
    lichDefeat,
    eidolonCaptured,
    dailySortie,
    rivenSliverPickup,
    missionFailed,
    death,
    normalMission,
    steelPathMission,
    nightmareMission,
    kuvaSiphon,
    kuvaFlood,
    weeklyAyatanMission,
    eidolonHunt,
    voidFissure,
    arbitration,
    sanctuaryOnslaught,
    syndicateMission,
    lichTerritoryMission,
    grustragDefeat,
    zanukaDefeat,
    profitTakerKill,
    exploiterOrbKill,
    voidAngelKill,
    kahlMission,
    weeklyArchonHunt,
};
