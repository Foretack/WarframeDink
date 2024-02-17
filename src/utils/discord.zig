const std = @import("std");
const http = @import("std").http;

pub const Message = struct {
    avatar_url: ?[]const u8 = null,
    username: ?[]const u8 = null,
    content: ?[]const u8 = null,
    embeds: ?[]Embed = null,

    pub fn SendWebhook(self: Message, allocator: std.mem.Allocator, webhookUrl: []const u8) !http.Status {
        const uri = try std.Uri.parse(webhookUrl);

        const json = try std.json.stringifyAlloc(allocator, self, .{
            .emit_null_optional_fields = false,
            .emit_strings_as_arrays = false,
        });
        defer allocator.free(json);
        var client = http.Client{ .allocator = allocator };
        defer client.deinit();

        var headers = http.Headers{ .allocator = allocator };
        defer headers.deinit();
        try headers.append("accept", "*/*");
        try headers.append("Content-Type", "application/json");

        var request = client.request(.POST, uri, headers, .{}) catch |err| {
            std.log.err("Error ({any}) sending request ({s}) to {s}", .{ err, json, webhookUrl });
            return err;
        };
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
    footer: ?Footer = null,
};

pub const Footer = struct {
    text: []const u8,
};

pub const EmbedColors = enum(i32) {
    lightGreen = 65400,
    darkGreen = 1155897,
    pink = 16449791,
    magenta = 13699683,
    orange = 15036416,
    cyan = 65535,
    darkRed = 5776672,
    black = 1,
    white = 16777215,
    brown = 12158478,
    red = 16725760,
    purple = 9442302,
    blue = 30940,
};
