const std = @import("std");
const fs = std.fs;
const mem = std.mem;

const file_name = "ssh-rdp.rdp";

pub fn writeConfig(allocator: mem.Allocator, address: []const u8, user: []const u8) ![]const u8 {
    const directory_path = try fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(directory_path);

    const file_path = try fs.path.join(allocator, &.{ directory_path, file_name });

    const file = try fs.createFileAbsolute(file_path, .{});
    defer file.close();

    const writer = file.writer();
    try writer.print(
        \\full address:s:{s}
        \\username:s:{s}
        \\desktopwidth:i:1920
        \\desktopheight:i:1080
        \\screen mode id:i:2
        \\authentication level:i:0
        \\
    ,
        .{ address, user },
    );

    return file_path;
}
