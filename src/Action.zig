const Self = @This();

type: enum { ssh, rdp },
host: []const u8,
user: ?[]const u8 = null,
password: ?[]const u8 = null,
address: ?[]const u8 = null,

pub fn init(host: []const u8, user: ?[]const u8, password: ?[]const u8, address: ?[]const u8) Self {
    return .{
        .type = if (user != null or password != null or address != null) .rdp else .ssh,
        .host = host,
        .user = user,
        .password = password,
        .address = address,
    };
}
