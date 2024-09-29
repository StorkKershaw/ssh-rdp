const Action = @This();

type: enum { SSH, RDP },
host: []const u8,
user: ?[]const u8 = null,
password: ?[]const u8 = null,
file: ?[]const u8 = null,
