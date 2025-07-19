const std = @import("std");
const debug = std.debug;
const unicode = std.unicode;
const Allocator = std.mem.Allocator;
const win32 = @import("win32");
const windows_and_messaging = win32.ui.windows_and_messaging;
const config = @import("config");
const Buffer = std.ArrayList(u8);
const Self = @This();

allocator: Allocator,
buffer: Buffer,

pub fn init(allocator: Allocator) !Self {
    return .{
        .allocator = allocator,
        .buffer = try Buffer.initCapacity(allocator, 1024),
    };
}

pub fn writer(self: *Self) Buffer.Writer {
    return self.buffer.writer();
}

pub fn deinit(self: *Self) void {
    defer self.buffer.deinit();

    if (self.buffer.items.len == 0) {
        return;
    }

    const message = unicode.utf8ToUtf16LeAllocZ(self.allocator, self.buffer.items) catch |err| {
        debug.print("Failed to convert message to UTF-16: {}\n", .{err});
        return;
    };
    defer self.allocator.free(message);

    _ = windows_and_messaging.MessageBoxW(
        null,
        message.ptr,
        unicode.utf8ToUtf16LeStringLiteral(config.app_name),
        windows_and_messaging.MB_OK,
    );
}
