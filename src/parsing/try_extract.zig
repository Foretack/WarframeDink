const std = @import("std");

pub fn isObjectDumpStart(line: []const u8) bool {
    return line.len > 0 and line[0] != ' ' and (line[line.len - 1] == '{' or line[0] == '{');
}

pub fn isObjectDumpEnd(line: []const u8) bool {
    return line.len == 1 and line[0] == '}';
}

pub fn objectStrField(line: []const u8) ?struct { name: []const u8, value: []const u8 } {
    const trimmed = std.mem.trim(u8, line, " ");
    var name: []const u8 = undefined;
    var val: []const u8 = undefined;
    if (trimmed.len < 1) {
        return null;
    }

    // JSON mode
    if (trimmed[0] == '"') {
        const colon = std.mem.indexOf(u8, trimmed, ":") orelse return null;
        if (colon - 2 <= 1) {
            return null;
        }

        name = trimmed[1 .. colon - 2];
        if (trimmed.len > colon + 5 and trimmed[colon + 2] == '"') {
            val = trimmed[colon + 3 .. trimmed.len - 2];
        } else {
            val = trimmed[colon + 2 .. trimmed.len - 1];
        }
    } else {
        const eql = std.mem.indexOf(u8, trimmed, "=") orelse return null;
        name = trimmed[0..eql];
        val = trimmed[eql + 1 ..];
    }

    return .{ .name = name, .value = val };
}

pub fn objectNumField(line: []const u8) ?struct { name: []const u8, value: usize } {
    const s = objectStrField(line) orelse return null;
    var num: usize = 0;
    for (s.value) |c| {
        if (c > '9' or c < '0') return null;
        num *= 10;
        num += c - '0';
    }

    return .{ .name = s.name, .value = num };
}
