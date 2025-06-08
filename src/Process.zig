const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const unicode = std.unicode;
const windows = std.os.windows;
const Allocator = std.mem.Allocator;
const win32 = @import("win32");
const foundation = win32.foundation;
const threading = win32.system.threading;
const Self = @This();

allocator: Allocator,
process_handle: foundation.HANDLE,
thread_handle: foundation.HANDLE,
pid: u32,

pub fn init(allocator: Allocator, comptime format: []const u8, values: anytype) !Self {
    const command_line_utf8 = try fmt.allocPrint(allocator, format, values);
    defer allocator.free(command_line_utf8);

    const command_line = try unicode.utf8ToUtf16LeAllocZ(allocator, command_line_utf8);
    defer allocator.free(command_line);

    var startup_info = mem.zeroInit(threading.STARTUPINFOW, .{ .cb = @sizeOf(threading.STARTUPINFOW) });
    var process_info = mem.zeroInit(threading.PROCESS_INFORMATION, .{});

    _ = threading.CreateProcessW(
        null,
        command_line.ptr,
        null,
        null,
        windows.FALSE,
        threading.CREATE_NO_WINDOW,
        null,
        null,
        &startup_info,
        &process_info,
    );

    const pid = threading.GetProcessId(process_info.hProcess);

    return .{
        .allocator = allocator,
        .process_handle = process_info.hProcess.?,
        .thread_handle = process_info.hThread.?,
        .pid = pid,
    };
}

pub fn deinit(self: *Self) void {
    _ = foundation.CloseHandle(self.process_handle);
    _ = foundation.CloseHandle(self.thread_handle);
}

pub fn isAlive(self: *const Self) bool {
    var exit_code: u32 = undefined;
    if (threading.GetExitCodeProcess(self.process_handle, &exit_code) == 0) {
        return false;
    }

    return exit_code == foundation.STILL_ACTIVE;
}

pub fn wait(self: *const Self) void {
    _ = threading.WaitForSingleObject(self.process_handle, windows.INFINITE);
}

pub fn waitWith(self: *const Self, other: *const Self) void {
    _ = threading.WaitForMultipleObjects(2, &.{ self.process_handle, other.process_handle }, windows.FALSE, windows.INFINITE);
}

pub fn kill(self: *const Self) void {
    _ = threading.TerminateProcess(self.process_handle, 0);
}
