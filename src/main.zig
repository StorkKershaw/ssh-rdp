const std = @import("std");
const debug = std.debug;
const Allocator = std.mem.Allocator;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const config = @import("config");
const clap = @import("clap");
const MessageBox = @import("MessageBox.zig");
const Process = @import("Process.zig");
const named_pipe = @import("named_pipe.zig");

pub fn main() !void {
    var general_purpose_allocator = GeneralPurposeAllocator(.{}){};
    defer debug.assert(general_purpose_allocator.deinit() == .ok);
    const allocator = general_purpose_allocator.allocator();

    const parameters = comptime clap.parseParamsComptime(
        \\-h, --help           Display this help and exit.
        \\<str>                The ssh host to connect.
    );

    var message_box = try MessageBox.init(allocator);
    defer message_box.deinit();
    const writer = message_box.writer();

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
        try diagnostic.report(writer, err);
        return err;
    };
    defer response.deinit();

    if (response.args.help != 0) {
        try help(writer, &parameters);
        return;
    }

    if (response.positionals[0]) |hostname| {
        try connect(allocator, hostname);
    } else {
        try help(writer, &parameters);
    }
}

fn help(writer: anytype, parameters: []const clap.Param(clap.Help)) !void {
    try writer.print(
        \\{s} v{s}
        \\$ {s} [options] [hostname]
        \\
        \\
    ,
        .{ config.app_name, config.app_version, config.app_name },
    );
    try clap.help(writer, clap.Help, parameters, .{});
}

fn connect(allocator: Allocator, hostname: []const u8) !void {
    var ssh_process = try Process.init(allocator, "ssh.exe {s}", .{hostname});
    defer ssh_process.deinit();

    const credential = try named_pipe.parse(allocator, hostname);
    defer credential.deinit();
    try credential.storePassword();
    try credential.writeConfig();

    var tsc_process = try Process.init(allocator, "mstsc.exe {s}", .{credential.config_path});
    defer tsc_process.deinit();
    tsc_process.wait();

    ssh_process.kill();
}
