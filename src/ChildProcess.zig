const std = @import("std");
const fmt = std.fmt;
const log = std.log;
const mem = std.mem;
const Child = std.process.Child;
const windows = std.os.windows;
const ArrayList = std.ArrayList;
const win32 = @import("win32");
const foundation = win32.foundation;
const threading = win32.system.threading;
const Self = @This();

allocator: mem.Allocator,
command_line: []const u8,
arguments: [][]const u8,
process: Child,
pid: u32,

fn init(allocator: mem.Allocator, comptime format: []const u8, values: anytype) !Self {
    const command_line = try fmt.allocPrint(allocator, format, values);
    errdefer allocator.free(command_line);

    var list = ArrayList([]const u8).init(allocator);
    defer list.deinit();

    var iterator = mem.tokenizeScalar(u8, command_line, ' ');
    while (iterator.next()) |item| {
        try list.append(item);
    }
    const arguments = try list.toOwnedSlice();
    errdefer allocator.free(arguments);

    var child_process = Child.init(arguments, allocator);
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

pub fn spawn(allocator: mem.Allocator, comptime format: []const u8, values: anytype) !Self {
    var child_process = try Self.init(allocator, format, values);
    errdefer child_process.deinit();

    try child_process.process.spawn();
    errdefer child_process.kill();

    child_process.pid = threading.GetProcessId(child_process.process.id);
    return child_process;
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.arguments);
    self.allocator.free(self.command_line);
}

pub fn wait(self: *Self) !void {
    try windows.WaitForSingleObject(self.process.id, windows.INFINITE);
}

pub fn kill(self: *Self) !void {
    try windows.TerminateProcess(self.process.id, 0);
}

pub fn isAlive(self: *const Self) bool {
    var exit_code: windows.DWORD = undefined;
    if (threading.GetExitCodeProcess(self.process.id, &exit_code) == 0) {
        return false;
    }

    return exit_code == foundation.STILL_ACTIVE;
}
