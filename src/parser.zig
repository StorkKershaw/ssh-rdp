const std = @import("std");
const unicode = std.unicode;
const windows = std.os.windows;
const Allocator = std.mem.Allocator;
const ArgIteratorWindows = std.process.ArgIteratorWindows;
const Writer = std.Io.Writer;
const clap = @import("clap");
const Diagnostic = clap.Diagnostic;
const Help = clap.Help;
const config = @import("config");
const MessageBox = @import("MessageBox.zig");
const named_pipe = @import("named_pipe.zig");
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

const Source = union(enum) {
    command,
    pipe: []const u8,

    const Self = @This();

    fn usage(self: Self, writer: *Writer) !void {
        switch (self) {
            .command => {
                try writer.print(
                    \\Usage: $ {s} [options] <hostname>
                    \\
                    \\
                ,
                    .{config.app_name},
                );
                try clap.help(writer, Help, &command_params, .{});
            },
            .pipe => {
                try writer.print(
                    \\Usage: $ echo [options] > \\.\pipe\{s}-<hostname>
                    \\
                    \\
                ,
                    .{config.app_name},
                );
                try clap.help(writer, Help, &pipe_params, .{});
            },
        }
    }

    fn parse(self: Self, allocator: Allocator, writer: *Writer) !?ParseResult {
        switch (self) {
            .command => {
                const commandline = windows.peb().ProcessParameters.CommandLine;
                const commandline_utf16 = commandline.Buffer.?[0 .. commandline.Length / 2];

                var iterator = try ArgIteratorWindows.init(allocator, commandline_utf16);
                defer iterator.deinit();

                var diagnostic: Diagnostic = .{};
                var result = clap.parseEx(
                    Help,
                    &command_params,
                    clap.parsers.default,
                    &iterator,
                    .{
                        .allocator = allocator,
                        .diagnostic = &diagnostic,
                    },
                ) catch |err| {
                    try diagnostic.report(writer, err);
                    try writer.writeByte('\n');
                    return null;
                };
                defer result.deinit();

                if (result.args.help != 0) {
                    return null;
                }

                if (result.positionals[0]) |hostname| {
                    return try ParseResult.init(allocator, .{
                        .hostname = hostname,
                        .username = result.args.user,
                        .password = result.args.password,
                        .address = result.args.address,
                        .silent = result.args.silent != 0,
                        .windowed = result.args.windowed != 0,
                        .width = result.args.width,
                        .height = result.args.height,
                    });
                } else {
                    return null;
                }
            },
            .pipe => |hostname| {
                const message = try named_pipe.read(allocator, hostname);
                defer allocator.free(message);

                const message_utf16 = try unicode.utf8ToUtf16LeAlloc(allocator, message);
                defer allocator.free(message_utf16);

                var iterator = try ArgIteratorWindows.init(allocator, message_utf16);
                defer iterator.deinit();

                var diagnostic: Diagnostic = .{};
                var result = clap.parseEx(
                    Help,
                    &pipe_params,
                    clap.parsers.default,
                    &iterator,
                    .{
                        .allocator = allocator,
                        .diagnostic = &diagnostic,
                    },
                ) catch |err| {
                    try diagnostic.report(writer, err);
                    try writer.writeByte('\n');
                    return null;
                };
                defer result.deinit();

                return try ParseResult.init(allocator, .{
                    .hostname = "",
                    .username = result.args.user,
                    .password = result.args.password,
                    .address = result.args.address,
                    .silent = result.args.silent != 0,
                    .windowed = result.args.windowed != 0,
                    .width = result.args.width,
                    .height = result.args.height,
                });
            },
        }
    }
};

pub fn parse(allocator: Allocator, source: Source) !?ParseResult {
    var message_box = MessageBox.init(allocator);
    defer message_box.deinit();
    const writer = message_box.writer();

    return try source.parse(allocator, writer) orelse blk: {
        try source.usage(writer);
        break :blk null;
    };
}
