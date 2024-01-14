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
