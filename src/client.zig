const std = @import("std");
const debug = std.debug;
const heap = std.heap;
const io = std.io;
const json = std.json;
const net = std.net;
const clap = @import("clap");
const Action = @import("action.zig");

const app_name = "ssh-rdp";

pub fn main() !void {
    var general_purpose_allocator = heap.GeneralPurposeAllocator(.{}){};
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
        return clap.help(io.getStdErr().writer(), clap.Help, &parameters, .{});
    }

    if (response.args.user == null and response.args.password == null and response.args.address == null) {
        try send(
            .{
                .type = .ssh,
                .host = response.positionals[0].?,
            },
        );
    } else {
        try send(
            .{
                .type = .rdp,
                .host = response.positionals[0].?,
                .user = response.args.user,
                .password = response.args.password,
                .address = response.args.address,
            },
        );
    }
}

fn send(action: Action) !void {
    const address = try net.Address.parseIp4("127.0.0.1", 1999);
    var stream = net.tcpConnectToAddress(address) catch |err| {
        io.getStdErr().writer().print("{s}: Failed to connect to {}.", .{ @errorName(err), address }) catch {};
        return;
    };
    defer stream.close();
    try json.stringify(action, .{ .emit_null_optional_fields = false }, stream.writer());
}
