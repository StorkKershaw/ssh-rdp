const std = @import("std");
const heap = std.heap;
const json = std.json;
const net = std.net;
const cli = @import("zig-cli");
const Action = @import("action.zig");

const app_name = "ssh-rdp";

var config = struct {
    host: []const u8 = undefined,
    user: ?[]const u8 = null,
    password: ?[]const u8 = null,
    file: ?[]const u8 = null,
}{};

pub fn main() !void {
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var runner = try cli.AppRunner.init(allocator);
    defer runner.deinit();

    const app: cli.App = .{
        .command = .{
            .name = app_name,
            .options = &.{
                .{
                    .long_name = "user",
                    .short_alias = 'u',
                    .help = "The user to sign in as.",
                    .value_ref = runner.mkRef(&config.user),
                    .value_name = "USER",
                },
                .{
                    .long_name = "password",
                    .short_alias = 'p',
                    .help = "The password for the user.",
                    .value_ref = runner.mkRef(&config.password),
                    .value_name = "PASSWORD",
                },
                .{
                    .long_name = "file",
                    .short_alias = 'f',
                    .help = "The .rdp file to use.",
                    .value_ref = runner.mkRef(&config.file),
                    .value_name = "FILE",
                },
            },
            .target = .{
                .action = .{
                    .positional_args = .{
                        .required = try runner.mkSlice(cli.PositionalArg, &.{
                            .{
                                .name = "host",
                                .help = "The ssh host to connect.",
                                .value_ref = runner.mkRef(&config.host),
                            },
                        }),
                    },
                    .exec = send,
                },
            },
        },
        .version = "0.0.1",
        .author = "Stork Kershaw",
    };

    return runner.run(&app);
}

fn send() !void {
    const address = try net.Address.parseIp4("127.0.0.1", 1999);
    var stream = try net.tcpConnectToAddress(address);
    defer stream.close();

    const action: Action = if (config.user == null or config.password == null or config.file == null)
        .{
            .type = .SSH,
            .host = config.host,
        }
    else
        .{
            .type = .RDP,
            .host = config.host,
            .user = config.user,
            .password = config.password,
            .file = config.file,
        };

    try json.stringify(action, .{ .emit_null_optional_fields = false }, stream.writer());
}
