const std = @import("std");
const debug = std.debug;
const heap = std.heap;
const json = std.json;
const log = std.log;
const net = std.net;
const Action = @import("Action.zig");
const ProcessManager = @import("ProcessManager.zig");

pub fn main() !void {
    var general_purpose_allocator = heap.GeneralPurposeAllocator(.{}){};
    defer debug.assert(general_purpose_allocator.deinit() == .ok);
    const allocator = general_purpose_allocator.allocator();

    const address = try net.Address.parseIp4("127.0.0.1", 1999);
    var server = try address.listen(.{ .reuse_port = true });
    defer server.deinit();
    log.info("Listening on {}.", .{address});

    var processManager = try ProcessManager.init(allocator);
    defer processManager.deinit();

    while (server.accept()) |connection| {
        defer connection.stream.close();

        var arena = heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        var reader = json.reader(arena_allocator, connection.stream.reader());
        var result = try json.parseFromTokenSource(Action, arena_allocator, &reader, .{});
        try processManager.execute(&result.value);
    } else |err| {
        return err;
    }
}
