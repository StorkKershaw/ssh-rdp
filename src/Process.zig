const std = @import("std");
const fmt = std.fmt;
const log = std.log;
const mem = std.mem;
const unicode = std.unicode;
const windows = std.os.windows;
const Allocator = std.mem.Allocator;
const win32 = @import("win32");
const foundation = win32.foundation;
const threading = win32.system.threading;
const Self = @This();

allocator: Allocator,
command_line: []const u8,
process_handle: foundation.HANDLE,
thread_handle: foundation.HANDLE,
pid: u32,

pub fn format(self: Self, comptime _: []const u8, _: fmt.FormatOptions, writer: anytype) !void {
    _ = try writer.print(
        "command_line = '{s}', pid = {d}",
        .{ self.command_line, self.pid },
    );
}

pub fn init(allocator: Allocator, comptime command_format: []const u8, values: anytype) !Self {
    const command_line = try fmt.allocPrint(allocator, command_format, values);

    const command_line_utf16 = try unicode.utf8ToUtf16LeAllocZ(allocator, command_line);
    defer allocator.free(command_line_utf16);

    var startup_info = mem.zeroInit(threading.STARTUPINFOW, .{ .cb = @sizeOf(threading.STARTUPINFOW) });
    var process_info = mem.zeroInit(threading.PROCESS_INFORMATION, .{});

    _ = threading.CreateProcessW(
        null,
        command_line_utf16.ptr,
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

    const self = Self{
        .allocator = allocator,
        .command_line = command_line,
        .process_handle = process_info.hProcess.?,
        .thread_handle = process_info.hThread.?,
        .pid = pid,
    };

    log.info("[{s}.{s}] {s}", .{ @typeName(Self), @src().fn_name, self });

    return self;
}

pub fn deinit(self: Self) void {
    log.info("[{s}.{s}] {s}", .{ @typeName(Self), @src().fn_name, self });

    self.allocator.free(self.command_line);
    _ = foundation.CloseHandle(self.thread_handle);
    _ = foundation.CloseHandle(self.process_handle);
}

pub fn kill(self: *const Self) void {
    log.info("[{s}.{s}] {s}", .{ @typeName(Self), @src().fn_name, self });

    _ = threading.TerminateProcess(self.process_handle, 0);
}

pub fn wait(self: *const Self) void {
    log.info("[{s}.{s}] {s}", .{ @typeName(Self), @src().fn_name, self });

    _ = threading.WaitForSingleObject(self.process_handle, windows.INFINITE);
}
