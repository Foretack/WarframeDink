const std = @import("std");
const http = @import("std").http;

pub const Message = struct {
    avatar_url: ?[]const u8 = null,
    username: ?[]const u8 = null,
    content: ?[]const u8 = null,
    embeds: ?[]Embed = null,

    pub fn SendWebhook(self: Message, allocator: std.mem.Allocator, webhookUrl: []const u8) !http.Status {
        const uri = try std.Uri.parse(webhookUrl);

        const json = try std.json.stringifyAlloc(allocator, self, .{ .emit_null_optional_fields = false });
        defer allocator.free(json);

        var client = http.Client{ .allocator = allocator };
        defer client.deinit();

        var headers = http.Headers{ .allocator = allocator };
        defer headers.deinit();
        try headers.append("accept", "*/*");
        try headers.append("Content-Type", "application/json");

        var request = try client.request(.POST, uri, headers, .{});
        defer request.deinit();
        request.transfer_encoding = .{ .content_length = json.len };
        try request.start();
        try request.writeAll(json);
        try request.finish();
        try request.wait();
        return request.response.status;
    }
};

pub const Embed = struct {
    title: []const u8,
    description: ?[]const u8 = null,
    color: i32,
};
