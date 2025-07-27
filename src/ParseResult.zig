const std = @import("std");
const Allocator = std.mem.Allocator;
const Self = @This();

allocator: Allocator,
hostname: []const u8,
username: ?[]const u8,
password: ?[]const u8,
address: ?[]const u8,
silent: bool,
windowed: bool,
width: ?i32,
height: ?i32,

const InitOptions = struct {
    hostname: []const u8,
    username: ?[]const u8,
    password: ?[]const u8,
    address: ?[]const u8,
    silent: bool,
    windowed: bool,
    width: ?i32,
    height: ?i32,
};

pub fn init(allocator: Allocator, options: InitOptions) !Self {
    return Self{
        .allocator = allocator,
        .hostname = try allocator.dupe(u8, options.hostname),
        .username = if (options.username) |username| try allocator.dupe(u8, username) else null,
        .password = if (options.password) |password| try allocator.dupe(u8, password) else null,
        .address = if (options.address) |address| try allocator.dupe(u8, address) else null,
        .silent = options.silent,
        .windowed = options.windowed,
        .width = options.width,
        .height = options.height,
    };
}

pub fn deinit(self: *Self) void {
    if (self.address) |address| self.allocator.free(address);
    if (self.password) |password| self.allocator.free(password);
    if (self.username) |username| self.allocator.free(username);
    self.allocator.free(self.hostname);
}
