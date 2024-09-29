const std = @import("std");
const heap = std.heap;
const log = std.log;
const json = std.json;
const net = std.net;
const Action = @import("Action.zig");
const ProcessManager = @import("ProcessManager.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const address = try net.Address.parseIp4("127.0.0.1", 1999);
    var server = try address.listen(.{ .reuse_port = true });
    defer server.deinit();
    log.info("Listening on {}...", .{address});

    var processManager = try ProcessManager.init(allocator);
    defer processManager.deinit();

    while (server.accept()) |connection| {
        defer connection.stream.close();
        var reader = json.reader(allocator, connection.stream.reader());
        defer reader.deinit();

        const result = try json.parseFromTokenSource(Action, allocator, &reader, .{});
        defer result.deinit();

        try processManager.execute(result.value);
    } else |err| {
        return err;
    }
}
