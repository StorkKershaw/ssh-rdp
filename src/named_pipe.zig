const std = @import("std");
const fmt = std.fmt;
const log = std.log;
const mem = std.mem;
const windows = std.os.windows;
const unicode = std.unicode;
const Allocator = std.mem.Allocator;
const win32 = @import("win32");
const file_system = win32.storage.file_system;
const foundation = win32.foundation;
const pipes = win32.system.pipes;
const config = @import("config");

pub fn read(allocator: Allocator, hostname: []const u8) ![]const u8 {
    const pipe_name = try fmt.allocPrint(allocator, "\\\\.\\pipe\\{s}-{s}", .{ config.app_name, hostname });
    defer allocator.free(pipe_name);

    const pipe_name_utf16 = try unicode.utf8ToUtf16LeAllocZ(allocator, pipe_name);
    defer allocator.free(pipe_name_utf16);

    const pipe_handle = pipes.CreateNamedPipeW(
        pipe_name_utf16.ptr,
        file_system.PIPE_ACCESS_INBOUND,
        pipes.NAMED_PIPE_MODE{ .TYPE_MESSAGE = 1, .READMODE_MESSAGE = 1 },
        1,
        0,
        0,
        0,
        null,
    );

    if (pipe_handle == foundation.INVALID_HANDLE_VALUE) {
        return "";
    }
    defer _ = foundation.CloseHandle(pipe_handle);

    if (pipes.ConnectNamedPipe(pipe_handle, null) == windows.FALSE) {
        return "";
    }
    defer _ = pipes.DisconnectNamedPipe(pipe_handle);

    var buffer: [1024]u8 = undefined;
    var bytes_read: u32 = undefined;
    _ = file_system.ReadFile(
        pipe_handle,
        &buffer,
        buffer.len,
        &bytes_read,
        null,
    );

    var iterator = mem.tokenizeAny(u8, buffer[0..bytes_read], "\r\n");
    const message = iterator.next() orelse "";
    log.info("[{s}] message = '{s}'", .{ @src().fn_name, message });
    return allocator.dupe(u8, message);
}
