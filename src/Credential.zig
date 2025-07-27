const std = @import("std");
const fmt = std.fmt;
const fs = std.fs;
const log = std.log;
const mem = std.mem;
const path = std.fs.path;
const unicode = std.unicode;
const Allocator = std.mem.Allocator;
const win32 = @import("win32");
const credentials = win32.security.credentials;
const config = @import("config");
const Self = @This();

allocator: Allocator,
username: []const u8,
password: ?[]const u8,
address: []const u8,
config_path: []const u8,
silent: bool,
windowed: bool,
width: ?i32,
height: ?i32,

pub fn format(self: Self, comptime _: []const u8, _: fmt.FormatOptions, writer: anytype) !void {
    _ = try writer.print(
        "username = '{s}', address = '{s}', config_path = '{s}', silent = {}, windowed = {}, width = {?}, height = {?}",
        .{ self.username, self.address, self.config_path, self.silent, self.windowed, self.width, self.height },
    );
}

const InitOptions = struct {
    hostname: []const u8,
    username: []const u8,
    password: ?[]const u8,
    address: []const u8,
    silent: bool,
    windowed: bool,
    width: ?i32,
    height: ?i32,
};

pub fn init(allocator: Allocator, options: InitOptions) !Self {
    const directory_path = try fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(directory_path);

    const file_name = try fmt.allocPrint(allocator, "{s}-{s}.rdp", .{ config.app_name, options.hostname });
    defer allocator.free(file_name);

    const config_path = try path.join(allocator, &.{ directory_path, file_name });

    return Self{
        .allocator = allocator,
        .username = try allocator.dupe(u8, options.username),
        .password = if (options.password) |password| try allocator.dupe(u8, password) else null,
        .address = try allocator.dupe(u8, options.address),
        .config_path = config_path,
        .silent = options.silent,
        .windowed = options.windowed,
        .width = options.width,
        .height = options.height,
    };
}

pub fn deinit(self: Self) void {
    log.info("[{s}.{s}] {s}", .{ @typeName(Self), @src().fn_name, self });

    fs.deleteFileAbsolute(self.config_path) catch |err| {
        log.warn("[{s}.{s}] Failed to delete config file: {}", .{ @typeName(Self), @src().fn_name, err });
    };
    self.allocator.free(self.config_path);
    self.allocator.free(self.address);
    if (self.password) |password| {
        self.allocator.free(password);
    }
    self.allocator.free(self.username);
}

pub fn storePassword(self: Self) !void {
    if (self.password) |password| {
        log.info("[{s}.{s}] {s}", .{ @typeName(Self), @src().fn_name, self });

        const target_utf16 = try unicode.utf8ToUtf16LeAllocZ(self.allocator, "TERMSRV/localhost");
        defer self.allocator.free(target_utf16);

        const username_utf16 = try unicode.utf8ToUtf16LeAllocZ(self.allocator, self.username);
        defer self.allocator.free(username_utf16);

        // `CredentialBlob` field does not need to be null-terminated.
        const password_utf16 = try unicode.utf8ToUtf16LeAlloc(self.allocator, password);
        defer self.allocator.free(password_utf16);

        var credential = mem.zeroInit(credentials.CREDENTIALW, .{ .Type = credentials.CRED_TYPE_DOMAIN_PASSWORD });
        credential.TargetName = target_utf16.ptr;
        credential.CredentialBlobSize = @intCast(password_utf16.len * @sizeOf(u16));
        credential.CredentialBlob = @ptrCast(password_utf16.ptr);
        credential.Persist = credentials.CRED_PERSIST_SESSION;
        credential.UserName = username_utf16.ptr;

        _ = credentials.CredWriteW(&credential, 0);
    }
}

pub fn writeConfig(self: Self) !void {
    log.info("[{s}.{s}] {s}", .{ @typeName(Self), @src().fn_name, self });

    const file = try fs.createFileAbsolute(self.config_path, .{});
    defer file.close();

    const writer = file.writer();
    try writer.print(
        \\full address:s:{s}
        \\username:s:{s}
        \\
    ,
        .{ self.address, self.username },
    );

    if (self.silent) {
        _ = try writer.write("authentication level:i:0\n");
    }

    if (self.windowed) {
        _ = try writer.write("screen mode id:i:1\n");
    }

    if (self.width) |width| {
        try writer.print("desktopwidth:i:{d}\n", .{width});
    }

    if (self.height) |height| {
        try writer.print("desktopheight:i:{d}\n", .{height});
    }
}
