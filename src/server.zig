const std = @import("std");
const debug = std.debug;
const json = std.json;
const log = std.log;
const Address = std.net.Address;
const ArenaAllocator = std.heap.ArenaAllocator;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const config = @import("config");
const Action = @import("Action.zig");
const ProcessManager = @import("ProcessManager.zig");

pub fn main() !void {
    var general_purpose_allocator = GeneralPurposeAllocator(.{}){};
    defer debug.assert(general_purpose_allocator.deinit() == .ok);
    const allocator = general_purpose_allocator.allocator();

    const address = try Address.parseIp4(config.app_host, config.app_port);
    var server = try address.listen(.{ .reuse_port = true });
    defer server.deinit();
    log.info("Listening on {}.", .{address});

    var processManager = try ProcessManager.init(allocator);
    defer processManager.deinit();

    while (server.accept()) |connection| {
        defer connection.stream.close();

        var arena = ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        var reader = json.reader(arena_allocator, connection.stream.reader());
        var result = json.parseFromTokenSource(Action, arena_allocator, &reader, .{}) catch |err| {
            log.warn("{s}: Failed to parse JSON.", .{@errorName(err)});
            continue;
        };
        try processManager.execute(&result.value);
    } else |err| {
        return err;
    }
}
