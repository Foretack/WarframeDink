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

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();
var machineUsername: ?[]const u8 = null;
const startTime = std.time.timestamp() + 30;
var user: []u8 = undefined;
var loggedOut = false;
var checkMtime: i128 = 0;
const webhookUrl = "I will probably leak this by accident";

pub fn main() !void {
    std.debug.print("(Starting in 30s)\n", .{});
    while (true) {
        // 30s
        std.time.sleep(30_000_000_000);
        const logFilePath = try getWarframeLogFile();
        defer allocator.free(logFilePath);
        const file = try fs.openFileAbsolute(logFilePath, .{});

        defer file.close();
        const stat = try file.stat();
        if (stat.mtime < checkMtime) {
            std.debug.print("File has not changed since user logout. Waiting for changes...\n", .{});
            continue;
        }

        const reader = file.reader();
        var buf: [8192]u8 = undefined;
        while (true) {
            if (loggedOut and stat.mtime < checkMtime) {
                std.debug.print("User logged out. Closing file...\n", .{});
                break;
            }

            const read = try reader.read(&buf);
            try lineIterate(buf[0..read], if (read < buf.len) read else null);
            if (read < buf.len) {
                // 3s
                std.time.sleep(3_000_000_000);
                continue;
            }
        }
    }
}

fn getWarframeLogFile() ![]const u8 {
    if (builtin.os.tag == .windows) {
        if (machineUsername == null) {
            machineUsername = try std.process.getEnvVarOwned(allocator, "USERNAME");
        }

        return std.fmt.allocPrint(allocator,
            \\C:\Users\{s}\AppData\Local\Warframe\EE.log
        , .{machineUsername.?});
    }

    if (builtin.os.tag == .linux) {
        if (machineUsername == null) {
            machineUsername = try std.process.getEnvVarOwned(allocator, "USER");
        }

        // TODO
        return std.fmt.allocPrint(allocator,
            \\/home/{s}/.local/share/Steam/steamapps/compatdata/230410/pfx/drive_c/users/steamuser/Saved Games/
        , .{machineUsername.?});
    }

    return anyerror.PlatformUnsupported;
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
                user = allocator.dupe(u8, username) catch unreachable;
                loggedOut = false;
                std.debug.print("{s} logged in\n", .{user});
            } else if (sys.missionEnd(log)) {
                missionEnd();
            } else if (sys.nightwaveChallengeComplete(log)) |nw_challenge| {
                const message_str = std.fmt.allocPrint(allocator, "{s} completed a {s} Nightwave challenge: {s}!\n", .{
                    user,
                    @tagName(nw_challenge.tier),
                    nw_challenge.name,
                }) catch |err| {
                    std.log.err("Allocation error: {}\n", .{err});
                    return;
                };
                defer allocator.free(message_str);

                sendDiscordMessage(message_str, null, 16711680);
            } else if (sys.exitingGame(log)) {
                std.debug.print("{s} logged out\n", .{user});
                loggedOut = true;
                checkMtime = std.time.nanoTimestamp() + 10_000_000_000;
            } else if (sys.rivenSliverPickup(log)) {
                std.debug.print("{s} found a Riven Sliver!\n", .{user});
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
                std.debug.print("{s} failed the mission: {s}\n", .{ user, CurrentMission.name });
            } else if (script.acolyteDefeated(log)) |acolyte| {
                std.debug.print("{s} defeated an Acolyte! ({s})\n", .{ user, acolyte });
            } else if (script.eidolonCaptured(log)) {
                CurrentMission.kind = .EidolonHunt;
                std.debug.print("{s} captured an Eidolon!\n", .{user});
            } else if (script.kuvaLichSpan(log)) {
                std.debug.print("{s} spawned a Kuva Lich!\n", .{user});
            } else if (script.isMasteryRankUp(log)) |new_rank| {
                std.debug.print("{s} reached MR {}\n", .{ user, new_rank });
            } else if (script.stalkerDefeated(log)) {
                const message_str = std.fmt.allocPrint(allocator, "{s} defeated the stalker!", .{user}) catch |err| {
                    std.log.err("Allocation error: {}\n", .{err});
                    return;
                };
                defer allocator.free(message_str);

                sendDiscordMessage(message_str, null, 1);
            } else if (script.lichDefeated(log)) {
                const message_str = std.fmt.allocPrint(allocator, "{s} defeated their Kuva Lich!", .{user}) catch |err| {
                    std.log.err("Allocation error: {}\n", .{err});
                    return;
                };
                defer allocator.free(message_str);

                sendDiscordMessage(message_str, null, 16777215);
            }
        },
        .Game => {
            if (game.hostMigration(log)) {
                std.debug.print("{s} is suffering host migration\n", .{user});
            } else if (game.userDeath(log, user)) |killed_by| {
                std.debug.print("{s} died to a {s}\n", .{ user, killed_by });
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

fn missionEnd() void {
    switch (CurrentMission.objective) {
        .MT_DEFENSE => {
            std.debug.print("{s} completed {} waves of defense in {s}! ({}-{})\n", .{
                user,
                CurrentMission.successCount,
                CurrentMission.name,
                CurrentMission.minLevel,
                CurrentMission.maxLevel,
            });
        },
        .MT_ENDLESS_EXTERMINATION => {
            std.debug.print("{s} cleared {} stages of {s}! ({}-{})\n", .{
                user,
                CurrentMission.successCount,
                CurrentMission.name,
                CurrentMission.minLevel,
                CurrentMission.maxLevel,
            });
        },
        .MT_LANDSCAPE => {
            std.debug.print("{s} finished {} bounties in {s}! ({}-{})\n", .{
                user,
                CurrentMission.successCount,
                CurrentMission.name,
                CurrentMission.minLevel,
                CurrentMission.maxLevel,
            });
        },
        .MT_SURVIVAL => {
            std.debug.print("{s} Survived {} minutes in {s}! ({}-{})\n", .{
                user,
                @divTrunc(std.time.timestamp() - CurrentMission.startedAt, 60),
                CurrentMission.name,
                CurrentMission.minLevel,
                CurrentMission.maxLevel,
            });
        },
        else => {
            switch (CurrentMission.kind) {
                .EidolonHunt => {
                    std.debug.print("{s} completed an Eidolon hunt!\n", .{
                        user,
                    });
                },
                else => {
                    if (CurrentMission.kind == .Normal) {
                        std.debug.print("{s} completed the mission: {s}! ({}-{})\n", .{
                            user,
                            CurrentMission.name,
                            CurrentMission.minLevel,
                            CurrentMission.maxLevel,
                        });

                        return;
                    } else if (CurrentMission.kind == .Sortie) {
                        if (!isFinalSortieMission()) {
                            return;
                        }

                        std.debug.print("{s} completed today's sortie!\n", .{user});
                        return;
                    }

                    std.debug.print("{s} completed the mission: {s}! ({}-{}, {s})\n", .{
                        user,
                        CurrentMission.name,
                        CurrentMission.minLevel,
                        CurrentMission.maxLevel,
                        @tagName(CurrentMission.kind),
                    });
                },
            }
        },
    }

    CurrentMission.successCount = 0;
}

fn sendDiscordMessage(title: []const u8, description: ?[]const u8, color: i32) void {
    const embed = discord.Embed{
        .title = title,
        .description = description,
        .color = color,
    };

    const embed_arr: []discord.Embed = allocator.alloc(discord.Embed, 1) catch |err| {
        std.log.err("Failed to allocate embed array: {}\n", .{err});
        return;
    };

    embed_arr[0] = embed;
    const message = discord.Message{
        .embeds = embed_arr,
    };

    const status = message.SendWebhook(allocator, webhookUrl) catch |send_err| {
        std.log.err("Failed to send webhook: {}\n", .{send_err});
        return;
    };

    if (status != .no_content) {
        std.log.err("Webhook not sent: HTTP Status: {s}\n", .{@tagName(status)});
    }
}

test "warframe log file exists" {
    if (builtin.os.tag == .windows) {
        const username = try std.process.getEnvVarOwned(std.testing.allocator, "USERNAME");
        defer std.testing.allocator.free(username);
        std.debug.print("\nUSER IS {s}\n", .{username});
        std.debug.print("MACHINE {}\n", .{builtin.os.tag});
        const path = try std.fmt.allocPrint(
            \\C:\Users\{s}\AppData\Local\Warframe\EE.log
        , .{username});
        defer std.testing.allocator.free(path);
        _ = try fs.openFileAbsolute(path, .{});
    }
}