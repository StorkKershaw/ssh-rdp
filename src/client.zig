const std = @import("std");
const debug = std.debug;
const io = std.io;
const json = std.json;
const net = std.net;
const Address = std.net.Address;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const config = @import("config");
const clap = @import("clap");
const Action = @import("Action.zig");

pub fn main() !void {
    var general_purpose_allocator = GeneralPurposeAllocator(.{}){};
    defer debug.assert(general_purpose_allocator.deinit() == .ok);
    const allocator = general_purpose_allocator.allocator();

    const parameters = comptime clap.parseParamsComptime(
        \\-h, --help           Display this help and exit.
        \\-u, --user <str>     The user to sign in as.
        \\-p, --password <str> The password for the user.
        \\-a, --address <str>  The address of the forwarded RDP server.
        \\<str>                The ssh host to connect.
    );

    var diagnostic: clap.Diagnostic = .{};
    const response = clap.parse(
        clap.Help,
        &parameters,
        clap.parsers.default,
        .{
            .diagnostic = &diagnostic,
            .allocator = allocator,
        },
    ) catch |err| {
        try diagnostic.report(io.getStdErr().writer(), err);
        return err;
    };
    defer response.deinit();

    if (response.args.help != 0 or response.positionals.len == 0) {
        const writer = io.getStdErr().writer();
        try writer.print(
            \\{s} v{s}
            \\$ {s} [options] [host]
            \\
            \\
        ,
            .{ config.app_name, config.app_version, config.app_name },
        );
        try clap.help(writer, clap.Help, &parameters, .{});
        return;
    }

    const action = Action.init(response.positionals[0].?, response.args.user, response.args.password, response.args.address);
    try send(action);
}

fn send(action: Action) !void {
    const address = try Address.parseIp4(config.app_host, config.app_port);
    var stream = net.tcpConnectToAddress(address) catch |err| {
        io.getStdErr().writer().print("{s}: Failed to connect to {}.", .{ @errorName(err), address }) catch {};
        return;
    };
    defer stream.close();
    try json.stringify(action, .{ .emit_null_optional_fields = false }, stream.writer());
}
