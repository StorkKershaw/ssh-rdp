const std = @import("std");
const debug = std.debug;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const Credential = @import("Credential.zig");
const Process = @import("Process.zig");
const named_pipe = @import("named_pipe.zig");
const parser = @import("parser.zig");

pub fn main() !void {
    var general_purpose_allocator = GeneralPurposeAllocator(.{}){};
    defer debug.assert(general_purpose_allocator.deinit() == .ok);
    const allocator = general_purpose_allocator.allocator();

    var command_result = try parser.parseCommandline(allocator) orelse return;
    defer command_result.deinit();

    var ssh_process = try Process.init(allocator, "ssh.exe {s}", .{command_result.hostname});
    defer ssh_process.deinit();

    const message = try named_pipe.read(allocator, command_result.hostname);
    defer allocator.free(message);

    var pipe_result = try parser.parseMessage(allocator, message);
    defer pipe_result.deinit();
    var credential = try Credential.init(allocator, .{
        .hostname = command_result.hostname,
        .username = command_result.username orelse pipe_result.username orelse "",
        .password = command_result.password orelse pipe_result.password,
        .address = command_result.address orelse pipe_result.address orelse "",
        .silent = command_result.silent or pipe_result.silent,
        .windowed = command_result.windowed or pipe_result.windowed,
        .width = command_result.width orelse pipe_result.width,
        .height = command_result.height orelse pipe_result.height,
    });
    defer credential.deinit();
    try credential.storePassword();
    try credential.writeConfig();

    var tsc_process = try Process.init(allocator, "mstsc.exe {s}", .{credential.config_path});
    defer tsc_process.deinit();
    tsc_process.wait();

    ssh_process.kill();
}
