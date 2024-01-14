const std = @import("std");

pub fn isObjectDumpStart(line: []const u8) bool {
    return line.len > 0 and line[0] != ' ' and std.mem.endsWith(u8, line, "={");
}

pub fn isObjectDumpEnd(line: []const u8) bool {
    return line.len == 1 and line[0] == '}';
}

pub fn objectStrField(line: []const u8) ?struct { name: []const u8, value: []const u8 } {
    const trimmed = std.mem.trim(u8, line, " ");
    const eql = std.mem.indexOf(u8, trimmed, "=") orelse return null;
    const name = trimmed[0..eql];
    const val = trimmed[eql + 1 ..];

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
