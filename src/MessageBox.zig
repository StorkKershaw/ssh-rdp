const std = @import("std");
const debug = std.debug;
const unicode = std.unicode;
const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;
const Allocating = std.Io.Writer.Allocating;
const win32 = @import("win32");
const windows_and_messaging = win32.ui.windows_and_messaging;
const config = @import("config");
const Buffer = std.ArrayList(u8);
const Self = @This();

allocator: Allocator,
buffer: Allocating,

pub fn init(allocator: Allocator) !Self {
    return .{
        .allocator = allocator,
        .buffer = try Allocating.initCapacity(allocator, 1024),
    };
}

pub fn writer(self: *Self) *Writer {
    return &self.buffer.writer;
}

pub fn deinit(self: *Self) void {
    defer self.buffer.deinit();

    const message = self.buffer.written();
    if (message.len == 0) {
        return;
    }

    const message_utf16 = unicode.utf8ToUtf16LeAllocZ(self.allocator, message) catch |err| {
        debug.print("Failed to convert message to UTF-16: {}\n", .{err});
        return;
    };
    defer self.allocator.free(message_utf16);

    _ = windows_and_messaging.MessageBoxW(
        null,
        message_utf16.ptr,
        unicode.utf8ToUtf16LeStringLiteral(config.app_name ++ " v" ++ config.app_version),
        windows_and_messaging.MB_OK,
    );
}
