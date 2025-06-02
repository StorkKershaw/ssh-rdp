const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const unicode = std.unicode;
const windows = std.os.windows;
const win32 = @import("win32");
const foundation = win32.foundation;
const threading = win32.system.threading;
const Self = @This();

allocator: mem.Allocator,
command_line: [:0]const u16,
startup_info: threading.STARTUPINFOW,
process_info: threading.PROCESS_INFORMATION,
pid: u32,

pub fn init(allocator: mem.Allocator, comptime format: []const u8, values: anytype) !Self {
    const command_line_utf8 = try fmt.allocPrint(allocator, format, values);
    defer allocator.free(command_line_utf8);

    const command_line = try unicode.utf8ToUtf16LeAllocZ(allocator, command_line_utf8);
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
        .command_line = command_line,
        .startup_info = startup_info,
        .process_info = process_info,
        .pid = pid,
    };
}

pub fn deinit(self: *Self) void {
    _ = foundation.CloseHandle(self.process_info.hProcess);
    _ = foundation.CloseHandle(self.process_info.hThread);
    self.allocator.free(self.command_line);
}

pub fn isAlive(self: *const Self) bool {
    var exit_code: u32 = undefined;
    if (threading.GetExitCodeProcess(self.process_info.hProcess, &exit_code) == 0) {
        return false;
    }

    return exit_code == foundation.STILL_ACTIVE;
}

pub fn wait(self: *const Self) void {
    _ = threading.WaitForSingleObject(self.process_info.hProcess, windows.INFINITE);
}

pub fn kill(self: *const Self) void {
    _ = threading.TerminateProcess(self.process_info.hProcess, 0);
}
