const std = @import("std");
const fs = std.fs;
const builtin = @import("builtin");
const log_types = @import("log_types.zig");
const try_extract = @import("try_extract.zig");
const mission_types = @import("current_mission.zig");
const CurrentMission = mission_types.Mission;
const sys = @import("parsing/sys.zig");
const script = @import("parsing/script.zig");
const game = @import("parsing/game.zig");
const discord = @import("discord.zig");
const cfg = @import("config.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();
var config: cfg.Config = undefined;
var startTime: i64 = undefined;
var user: []const u8 = undefined;
var loggedOut = false;
var checkMtime: i128 = 0;

pub fn main() !void {
    config = cfg.Config.get(allocator) catch |err| {
        std.log.err("Failed to load config file: {}\n", .{err});
        std.time.sleep(5_000_000_000);
        return;
    };

    user = config.username orelse undefined;
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
            std.debug.print("File has not changed since user logout. Waiting for change...\n", .{});
            std.time.sleep(30_000_000_000);
            continue;
        }

        const reader = file.reader();
        var buf: [8192]u8 = undefined;
        while (true) {
            if (loggedOut and stat.mtime < checkMtime) {
                std.debug.print("User logged out. Closing file...\n", .{});
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
                // 3s
                std.time.sleep(3_000_000_000);
                continue;
            }
        }

        // 30s
        std.time.sleep(30_000_000_000);
    }
}

fn lineIterate(buffer: []u8, stopAt: ?usize) !void {
    var line_start_idx: usize = 0;
    var crlf_idx: ?usize = std.mem.indexOf(u8, buffer, "\r\n");
    while (crlf_idx) |line_end_idx| : (crlf_idx = std.mem.indexOf(u8, buffer[line_start_idx .. stopAt orelse buffer.len], "\r\n")) {
        const indexed_end = line_end_idx + line_start_idx;
        lineAction(buffer[line_start_idx..indexed_end]);
        line_start_idx = indexed_end + 2;
    }
}

var readingObject: bool = false;

fn lineAction(line: []const u8) void {
    if (readingObject) {
        if (try_extract.isObjectDumpEnd(line)) {
            readingObject = false;
            return;
        } else if (!lineIsSeq(line)) {
            if (try_extract.objectNumField(line)) |field| {
                if (std.mem.eql(u8, field.name, "minEnemyLevel")) {
                    CurrentMission.minLevel = field.value;
                } else if (std.mem.eql(u8, field.name, "maxEnemyLevel")) {
                    CurrentMission.maxLevel = field.value;
                }
            } else if (try_extract.objectStrField(line)) |obj_field| {
                if (std.mem.eql(u8, obj_field.name, "missionType")) {
                    CurrentMission.objective = std.meta.stringToEnum(mission_types.Objective, obj_field.value) orelse .UNKNOWN;
                }
            }
        } else readingObject = false;
    } else if (!lineIsSeq(line) and try_extract.isObjectDumpStart(line)) {
        readingObject = true;
        return;
    }

    const log = log_types.parseLog(line) orelse return;
    if (log.level != .Info) return;
    switch (log.category) {
        .Sys => {
            if (sys.loginUsername(log)) |username| {
                if (config.username == null) {
                    user = allocator.dupe(u8, username) catch unreachable;
                }

                loggedOut = false;
                std.debug.print("{s} logged in\n", .{user});
                if (!config.notifications.login.enabled) {
                    return;
                }

                const message_str = std.fmt.allocPrint(allocator, "Logged in", .{}) catch |err| {
                    std.log.err("Allocation error: {}\n", .{err});
                    return;
                };
                defer allocator.free(message_str);

                sendDiscordMessage(message_str, null, 1155897);
            } else if (sys.missionEnd(log)) {
                missionEnd() catch |alloc_err| {
                    std.log.err("Allocation error: {}\n", .{alloc_err});
                    return;
                };
            } else if (sys.nightwaveChallengeComplete(log)) |nw_challenge| {
                if (!config.notifications.nightwaveChallengeComplete.enabled) {
                    return;
                }

                const challenge_str = switch (nw_challenge.tier) {
                    .Daily => "a daily",
                    .Weekly => "a weekly",
                    .EliteWeekly => "an elite weekly",
                };

                const message_str = std.fmt.allocPrint(allocator, "Completed {s} Nightwave challenge!", .{
                    challenge_str,
                }) catch |err| {
                    std.log.err("Allocation error: {}\n", .{err});
                    return;
                };
                defer allocator.free(message_str);

                sendDiscordMessage(message_str, nw_challenge.name, 16449791);
            } else if (sys.exitingGame(log)) {
                std.debug.print("{s} logged out\n", .{user});
                loggedOut = true;
                checkMtime = std.time.nanoTimestamp() + 10_000_000_000;
                if (!config.notifications.logout.enabled) {
                    return;
                }

                const message_str = std.fmt.allocPrint(allocator, "Logged out", .{}) catch |err| {
                    std.log.err("Allocation error: {}\n", .{err});
                    return;
                };
                defer allocator.free(message_str);

                sendDiscordMessage(message_str, null, 13699683);
            } else if (sys.rivenSliverPickup(log)) {
                if (!config.notifications.rivenSliverPickup.enabled) {
                    return;
                }

                std.debug.print("Found a Riven Sliver!\n", .{});
                const message_str = std.fmt.allocPrint(allocator, "Found a Riven Sliver!", .{}) catch |err| {
                    std.log.err("Allocation error: {}\n", .{err});
                    return;
                };
                defer allocator.free(message_str);

                sendDiscordMessage(message_str, null, 9442302);
            }
        },
        .Script => {
            if (script.missionInfo(log)) |mission_info| {
                allocator.free(CurrentMission.name);
                CurrentMission.name = allocator.dupe(u8, mission_info.name) catch unreachable;
                CurrentMission.startedAt = std.time.timestamp();
                CurrentMission.kind = mission_info.kind;
            } else if (script.missionSuccess(log)) {
                CurrentMission.successCount += 1;
            } else if (script.missionFailure(log)) {
                if (!config.notifications.missionFailed.enabled) {
                    return;
                }

                const message_str = std.fmt.allocPrint(allocator, "Failed a mission: {s}", .{CurrentMission.name}) catch |err| {
                    std.log.err("Allocation error: {}\n", .{err});
                    return;
                };
                defer allocator.free(message_str);

                sendDiscordMessage(message_str, CurrentMission.name, 15036416);
            } else if (script.acolyteDefeated(log)) |acolyte| {
                if (!config.notifications.acolyteDefeat.enabled) {
                    return;
                }

                std.debug.print("{s} defeated an Acolyte! ({s})\n", .{ user, acolyte });
                const message_str = std.fmt.allocPrint(allocator, "Defeated an Acolyte! ({s})", .{acolyte}) catch |err| {
                    std.log.err("Allocation error: {}\n", .{err});
                    return;
                };
                defer allocator.free(message_str);

                sendDiscordMessage(message_str, null, 1);
            } else if (script.eidolonCaptured(log)) {
                CurrentMission.kind = .EidolonHunt;
                if (!config.notifications.eidolonCaptured.enabled) {
                    return;
                }

                const message_str = std.fmt.allocPrint(allocator, "Captured an Eidolon!", .{}) catch |err| {
                    std.log.err("Allocation error: {}\n", .{err});
                    return;
                };
                defer allocator.free(message_str);

                sendDiscordMessage(message_str, null, 65535);
            } else if (script.kuvaLichSpan(log)) {
                if (!config.notifications.lichSpawn.enabled) {
                    return;
                }

                const message_str = std.fmt.allocPrint(allocator, "Spawned a Lich!", .{}) catch |err| {
                    std.log.err("Allocation error: {}\n", .{err});
                    return;
                };
                defer allocator.free(message_str);

                sendDiscordMessage(message_str, null, 5776672);
            } else if (script.isMasteryRankUp(log)) |new_rank| {
                if (!config.notifications.masteryRankUp.enabled) {
                    return;
                }

                std.debug.print("{s} reached MR {}\n", .{ user, new_rank });
                const message_str = std.fmt.allocPrint(allocator, "Reached Mastery Rank {}!", .{new_rank}) catch |err| {
                    std.log.err("Allocation error: {}\n", .{err});
                    return;
                };
                defer allocator.free(message_str);

                sendDiscordMessage(message_str, null, 30940);
            } else if (script.stalkerDefeated(log)) {
                if (!config.notifications.stalkerDefeat.enabled) {
                    return;
                }

                const message_str = std.fmt.allocPrint(allocator, "Defeated the stalker!", .{}) catch |err| {
                    std.log.err("Allocation error: {}\n", .{err});
                    return;
                };
                defer allocator.free(message_str);

                sendDiscordMessage(message_str, null, 1);
            } else if (script.lichDefeated(log)) {
                if (!config.notifications.lichDefeat.enabled) {
                    return;
                }

                const message_str = std.fmt.allocPrint(allocator, "Defeated their Lich!", .{}) catch |err| {
                    std.log.err("Allocation error: {}\n", .{err});
                    return;
                };
                defer allocator.free(message_str);

                sendDiscordMessage(message_str, null, 16777215);
            } else if (script.grustragDefeated(log)) {
                const message_str = std.fmt.allocPrint(allocator, "Defeated the Grustrag Three!", .{}) catch |err| {
                    std.log.err("Allocation error: {}\n", .{err});
                    return;
                };
                defer allocator.free(message_str);

                sendDiscordMessage(message_str, null, 12158478);
            } else if (script.profitTakerDefeated(log)) {
                if (!config.notifications.profitTakerKill.enabled) {
                    return;
                }

                const message_str = std.fmt.allocPrint(allocator, "Killed the Profit Taker!", .{}) catch |err| {
                    std.log.err("Allocation error: {}\n", .{err});
                    return;
                };
                defer allocator.free(message_str);

                sendDiscordMessage(message_str, null, 12158478);
            }
        },
        .Game => {
            if (game.hostMigration(log)) {
                std.debug.print("{s} is suffering host migration\n", .{user});
            } else if (game.userDeath(log, user)) |killed_by| {
                if (!config.notifications.death.enabled) {
                    return;
                }

                const message_str = std.fmt.allocPrint(allocator, "Died to a {s}", .{killed_by}) catch |err| {
                    std.log.err("Allocation error: {}\n", .{err});
                    return;
                };
                defer allocator.free(message_str);

                sendDiscordMessage(message_str, null, 16725760);
            }
        },
        else => {},
    }
}

pub fn isFinalSortieMission() bool {
    return CurrentMission.kind == .Sortie and CurrentMission.minLevel == 80;
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
    var mission_str: []const u8 = "NOTSET";
    defer {
        if (!std.mem.eql(u8, mission_str, "NOTSET")) allocator.free(mission_str);
    }
    var desc: ?[]const u8 = null;
    var color: i32 = 65400;
    switch (CurrentMission.kind) {
        .EidolonHunt => {
            if (!config.notifications.eidolonHunt.enabled) {
                return;
            }

            mission_str = try std.fmt.allocPrint(allocator, "Completed an Eidolon hunt!\n", .{});
        },
        .Normal => {
            if (CurrentMission.objective == .MT_ENDLESS_EXTERMINATION) {
                if (!config.notifications.sanctuaryOnslaught.enabled or config.notifications.sanctuaryOnslaught.minLevel > CurrentMission.minLevel) {
                    return;
                }

                mission_str = try std.fmt.allocPrint(allocator, "Completed {s}!", .{CurrentMission.name});
            } else if (CurrentMission.objective == .MT_RAILJACK) {
                mission_str = try std.fmt.allocPrint(allocator, "Completed a Railjack mission!", .{});
                return;
            } else if (!config.notifications.normalMission.enabled or config.notifications.normalMission.minLevel > CurrentMission.minLevel) {
                return;
            }

            mission_str = try std.fmt.allocPrint(allocator, "Completed a {s} mission: {s}! ({}-{})", .{
                missionObjStr(),
                CurrentMission.name,
                CurrentMission.minLevel,
                CurrentMission.maxLevel,
            });
        },
        .Sortie => {
            if (!config.notifications.dailySortie.enabled) {
                return;
            }

            if (!isFinalSortieMission()) {
                return;
            }

            mission_str = try std.fmt.allocPrint(allocator, "Completed the sortie of today!", .{});
        },
        .Nightmare => {
            if (!config.notifications.nightmareMission.enabled or config.notifications.nightmareMission.minLevel > CurrentMission.minLevel) {
                return;
            }

            mission_str = try std.fmt.allocPrint(allocator, "Completed a Nightmare {s} mission: {s}! ({}-{})", .{
                missionObjStr(),
                CurrentMission.name,
                CurrentMission.minLevel,
                CurrentMission.maxLevel,
            });
        },
        .Kuva => {
            if (!config.notifications.kuvaSiphon.enabled or config.notifications.kuvaSiphon.minLevel > CurrentMission.minLevel) {
                return;
            }

            mission_str = try std.fmt.allocPrint(allocator, "Completed a Kuva {s} mission: {s}! ({}-{})", .{
                missionObjStr(),
                CurrentMission.name,
                CurrentMission.minLevel,
                CurrentMission.maxLevel,
            });
        },
        .Syndicate => {
            if (!config.notifications.syndicateMission.enabled or config.notifications.syndicateMission.minLevel > CurrentMission.minLevel) {
                return;
            }

            mission_str = try std.fmt.allocPrint(allocator, "Completed a syndicate {s} mission: {s}! ({}-{})", .{
                missionObjStr(),
                CurrentMission.name,
                CurrentMission.minLevel,
                CurrentMission.maxLevel,
            });
        },
        .KuvaFlood => {
            if (!config.notifications.kuvaFlood.enabled or config.notifications.kuvaFlood.minLevel > CurrentMission.minLevel) {
                return;
            }

            mission_str = try std.fmt.allocPrint(allocator, "Completed a Kuva Flood {s} mission: {s}! ({}-{})", .{
                missionObjStr(),
                CurrentMission.name,
                CurrentMission.minLevel,
                CurrentMission.maxLevel,
            });
        },
        .SteelPath => {
            if (!config.notifications.steelPathMission.enabled or config.notifications.steelPathMission.minLevel > CurrentMission.minLevel) {
                return;
            }

            mission_str = try std.fmt.allocPrint(allocator, "Completed a Steel Path {s} mission: {s}! ({}-{})", .{
                missionObjStr(),
                CurrentMission.name,
                CurrentMission.minLevel,
                CurrentMission.maxLevel,
            });
        },
        .ControlledTerritory => {
            if (!config.notifications.lichTerritoryMission.enabled or config.notifications.lichTerritoryMission.minLevel > CurrentMission.minLevel) {
                return;
            }

            mission_str = try std.fmt.allocPrint(allocator, "Completed a Lich territory {s} mission: {s}! ({}-{})", .{
                missionObjStr(),
                CurrentMission.name,
                CurrentMission.minLevel,
                CurrentMission.maxLevel,
            });
        },
        .Arbitration => {
            if (!config.notifications.arbitration.enabled or config.notifications.arbitration.minLevel > CurrentMission.minLevel) {
                return;
            }

            mission_str = try std.fmt.allocPrint(allocator, "Completed an Arbitration {s} mission: {s}! ({}-{})", .{
                missionObjStr(),
                CurrentMission.name,
                CurrentMission.minLevel,
                CurrentMission.maxLevel,
            });
        },
        .T1Fissure, .T2Fissure, .T3Fissure, .T4Fissure, .T5Fissure => {
            if (!config.notifications.voidFissure.enabled or config.notifications.voidFissure.minLevel > CurrentMission.minLevel) {
                return;
            }

            const relic_str = switch (CurrentMission.kind) {
                .T1Fissure => "Lith",
                .T2Fissure => "Meso",
                .T3Fissure => "Neo",
                .T4Fissure => "Axi",
                .T5Fissure => "Requiem",
                else => "???",
            };

            mission_str = try std.fmt.allocPrint(allocator, "Completed a {s} fissure {s} mission: {s}! ({}-{})", .{
                relic_str,
                missionObjStr(),
                CurrentMission.name,
                CurrentMission.minLevel,
                CurrentMission.maxLevel,
            });
        },
        .TreasureHunt => {
            if (!config.notifications.weeklyAyatanMission.enabled) {
                return;
            }

            mission_str = try std.fmt.allocPrint(allocator, "Completed the weekly Ayatan hunt mission!", .{});
        },
    }

    CurrentMission.successCount = 0;
    sendDiscordMessage(mission_str, desc, color);
}

fn sendDiscordMessage(title: []const u8, description: ?[]const u8, color: i32) void {
    if (secSinceStart() < 3) {
        return;
    }

    const embed = discord.Embed{
        .title = title,
        .description = description,
        .color = color,
    };

    const embed_arr: []discord.Embed = allocator.alloc(discord.Embed, 1) catch |err| {
        std.log.err("Failed to allocate embed array: {}\n", .{err});
        return;
    };
    defer allocator.free(embed_arr);

    embed_arr[0] = embed;
    const message = discord.Message{
        .avatar_url = config.profilePictureUrl,
        .username = user,
        .embeds = embed_arr,
    };

    const status = message.SendWebhook(allocator, config.webhookUrl) catch |send_err| {
        std.log.err("Failed to send webhook: {}\n", .{send_err});
        return;
    };

    if (status != .no_content) {
        std.log.err("Webhook not sent: HTTP Status: {s}\n", .{@tagName(status)});
    }
}

fn missionObjStr() []const u8 {
    return switch (CurrentMission.objective) {
        .MT_CAPTURE => "capture",
        .MT_DEFENSE => "defense",
        .MT_EXCAVATE => "excavation",
        .MT_EXTERMINATION => "extermination",
        .MT_INTEL => "spy",
        .MT_LANDSCAPE => "open world",
        .MT_MOBILE_DEFENSE => "mobile defense",
        .MT_RAILJACK => "Railjack",
        .MT_TERRITORY => "interception",
        else => "",
    };
}
