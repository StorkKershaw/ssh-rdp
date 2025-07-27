const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const clap = @import("clap");
const config = @import("config");
const MessageBox = @import("MessageBox.zig");
const ParseResult = @import("ParseResult.zig");

const command_params = clap.parseParamsComptime(
    \\--user <string>      The username to use for the RDP connection.
    \\--password <string>  The password to use for the RDP connection.
    \\--address <string>   The address the RDP server is listening on.
    \\--silent             Connect without warning even if server certificate is invalid.
    \\--windowed           Connect in a window instead of full screen.
    \\--width <i32>        The width of the window.
    \\--height <i32>       The height of the window.
    \\--help               Display the help and exit.
    \\<string>             The ssh host to connect.
);

const pipe_params = clap.parseParamsComptime(
    \\--user <string>      The username to use for the RDP connection.
    \\--password <string>  The password to use for the RDP connection.
    \\--address <string>   The address the RDP server is listening on.
    \\--silent             Connect without warning even if server certificate is invalid.
    \\--windowed           Connect in a window instead of full screen.
    \\--width <i32>        The width of the window.
    \\--height <i32>       The height of the window.
);

const HelpType = union(enum) {
    command,
    pipe,
};

fn help(writer: anytype, help_type: HelpType) !void {
    switch (help_type) {
        .command => {
            try writer.print("$ {s} [options] [hostname]\n\n", .{config.app_name});
            try clap.help(writer, clap.Help, &command_params, .{});
        },
        .pipe => {
            try writer.print("$ echo [options] > \\\\.\\pipe\\{s}-<hostname>\n\n", .{config.app_name});
            try clap.help(writer, clap.Help, &pipe_params, .{});
        },
    }
}

pub fn parseCommandline(allocator: Allocator) !?ParseResult {
    var arena = ArenaAllocator.init(allocator);
    defer arena.deinit();

    var message_box = try MessageBox.init(arena.allocator());
    defer message_box.deinit();
    const writer = message_box.writer();

    var diagnostic: clap.Diagnostic = .{};
    var response = clap.parse(
        clap.Help,
        &command_params,
        clap.parsers.default,
        .{
            .diagnostic = &diagnostic,
            .allocator = arena.allocator(),
        },
    ) catch |err| {
        try diagnostic.report(writer, err);
        try help(writer, .command);
        return err;
    };
    defer response.deinit();

    if (response.args.help != 0) {
        try help(writer, .command);
        return null;
    }

    if (response.positionals[0]) |hostname| {
        return try ParseResult.init(allocator, .{
            .hostname = hostname,
            .username = response.args.user,
            .password = response.args.password,
            .address = response.args.address,
            .silent = response.args.silent != 0,
            .windowed = response.args.windowed != 0,
            .width = response.args.width,
            .height = response.args.height,
        });
    } else {
        try help(writer, .command);
        return null;
    }
}

pub fn parseMessage(allocator: Allocator, message: []const u8) !ParseResult {
    var arena = ArenaAllocator.init(allocator);
    defer arena.deinit();

    var message_box = try MessageBox.init(arena.allocator());
    defer message_box.deinit();
    const writer = message_box.writer();

    var diagnostic: clap.Diagnostic = .{};
    var iterator = mem.tokenizeScalar(u8, message, ' ');
    var response = clap.parseEx(
        clap.Help,
        &pipe_params,
        clap.parsers.default,
        &iterator,
        .{
            .diagnostic = &diagnostic,
            .allocator = arena.allocator(),
        },
    ) catch |err| {
        try diagnostic.report(writer, err);
        try help(writer, .pipe);
        return err;
    };
    defer response.deinit();

    return try ParseResult.init(allocator, .{
        .hostname = "",
        .username = response.args.user,
        .password = response.args.password,
        .address = response.args.address,
        .silent = response.args.silent != 0,
        .windowed = response.args.windowed != 0,
        .width = response.args.width,
        .height = response.args.height,
    });
}
