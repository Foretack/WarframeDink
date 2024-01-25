pub fn stringSwitch(string: []const u8) usize {
    var i: usize = 0;
    for (string) |char| {
        i += char;
    }

    return i;
}

pub fn case(comptime string: []const u8) usize {
    var i: usize = 0;
    inline for (string) |char| {
        i += char;
    }

    if (!@inComptime()) unreachable;
    return i;
}
