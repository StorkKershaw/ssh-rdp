const std = @import("std");
const fmt = std.fmt;
const log = std.log;
const mem = std.mem;
const process = std.process;
const windows = std.os.windows;
const ChildProcess = @This();

const STILL_ACTIVE = 259;

extern "kernel32" fn GetExitCodeProcess(windows.HANDLE, *windows.DWORD) callconv(windows.WINAPI) windows.BOOL;
extern "kernel32" fn GetProcessId(windows.HANDLE) callconv(windows.WINAPI) windows.DWORD;

allocator: mem.Allocator,
command_line: []const u8,
arguments: [][]const u8,
process: process.Child,
pid: u32,

fn init(allocator: mem.Allocator, comptime format: []const u8, values: anytype) !ChildProcess {
    const command_line = try fmt.allocPrint(allocator, format, values);
    errdefer allocator.free(command_line);

    var list = std.ArrayList([]const u8).init(allocator);
    defer list.deinit();

    var iterator = mem.tokenizeScalar(u8, command_line, ' ');
    while (iterator.next()) |item| {
        try list.append(item);
    }
    const arguments = try list.toOwnedSlice();
    errdefer allocator.free(arguments);

    var child_process = process.Child.init(arguments, allocator);
    child_process.stdin_behavior = .Ignore;
    child_process.stdout_behavior = .Ignore;
    child_process.stderr_behavior = .Ignore;

    return .{
        .allocator = allocator,
        .command_line = command_line,
        .arguments = arguments,
        .process = child_process,
        .pid = 0,
    };
}

pub fn spawn(allocator: mem.Allocator, comptime format: []const u8, values: anytype) !ChildProcess {
    var child_process = try ChildProcess.init(allocator, format, values);
    errdefer child_process.deinit();

    try child_process.process.spawn();
    errdefer child_process.kill();

    child_process.pid = GetProcessId(child_process.process.id);
    return child_process;
}

pub fn wait(self: *ChildProcess) !void {
    _ = try self.process.wait();
}

pub fn kill(self: *ChildProcess) !void {
    _ = try self.process.kill();
}

pub fn spawnAndWait(allocator: mem.Allocator, comptime format: []const u8, values: anytype) !void {
    var child_process = try ChildProcess.init(allocator, format, values);
    errdefer child_process.deinit();

    _ = try child_process.process.spawnAndWait();
    errdefer child_process.kill();
}

pub fn deinit(self: *ChildProcess) void {
    self.allocator.free(self.arguments);
    self.allocator.free(self.command_line);
}

pub fn isAlive(self: *const ChildProcess) bool {
    var exit_code: windows.DWORD = undefined;
    if (GetExitCodeProcess(self.process.id, &exit_code) == 0) {
        return false;
    }

    return exit_code == STILL_ACTIVE;
}
