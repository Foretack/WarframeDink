const std = @import("std");

pub const LogEntry = struct {
    category: LogCategory,
    level: LogLevel,
    luaFile: ?[]const u8,
    message: []const u8,
};

pub const LogCategory = enum {
    Sys,
    AI,
    Net,
    Phys,
    Script,
    Gfx,
    Snd,
    Input,
    Game,
    Anim,
    UNKNOWN,
};

pub const LogLevel = enum {
    Error,
    Info,
    Diag,
    Warning,
    UNKNOWN,
};

pub fn parseLog(line: []const u8) ?LogEntry {
    const first_space = (std.mem.indexOf(u8, line, " ") orelse return null) + 1;
    const second_space = (std.mem.indexOf(u8, line[first_space..], " ") orelse return null) + first_space;
    const category = std.meta.stringToEnum(LogCategory, line[first_space..second_space]) orelse .UNKNOWN;
    var level: LogLevel = undefined;
    var lua_file: ?[]const u8 = null;
    var message: []const u8 = undefined;
    if (category == .UNKNOWN) {
        level = .UNKNOWN;
        message = line[second_space..];
    } else {
        const third_space = (std.mem.indexOf(u8, line[second_space + 1 ..], " ") orelse return null) + second_space;
        level = std.meta.stringToEnum(LogLevel, line[second_space + 2 .. third_space - 1]) orelse .UNKNOWN;
        const lua_file_end = std.mem.indexOf(u8, line[third_space..], ".lua");
        if (lua_file_end) |end_idx| {
            lua_file = line[third_space + 2 .. third_space + end_idx + 4];
            message = line[third_space + end_idx + 4 ..];
        } else {
            message = line[third_space..];
        }
    }

    return LogEntry{
        .category = category,
        .level = level,
        .luaFile = lua_file,
        .message = message,
    };
}
