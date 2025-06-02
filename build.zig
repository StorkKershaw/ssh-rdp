const std = @import("std");

const config = .{
    .app_name = "ssh-rdp",
    .app_version = "0.0.4",
    .app_publisher = "StorkKershaw",
    .app_url = "https://github.com/StorkKershaw/ssh-rdp",
};

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const win32 = b.dependency("win32", .{});
    const server_exe = b.addExecutable(.{
        .name = config.app_name ++ "d",
        .root_source_file = b.path("src/server.zig"),
        .target = target,
        .optimize = optimize,
    });
    server_exe.subsystem = if (optimize == .Debug) .Console else .Windows;
    server_exe.root_module.addImport("win32", win32.module("win32"));

    const clap = b.dependency("clap", .{});
    const client_exe = b.addExecutable(.{
        .name = config.app_name,
        .root_source_file = b.path("src/client.zig"),
        .target = target,
        .optimize = optimize,
    });
    client_exe.root_module.addImport("clap", clap.module("clap"));

    const server_install = b.addInstallArtifact(server_exe, .{});
    const client_install = b.addInstallArtifact(client_exe, .{});

    const server_run = b.addRunArtifact(server_exe);
    const client_run = b.addRunArtifact(client_exe);

    server_run.step.dependOn(b.getInstallStep());
    client_run.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        server_run.addArgs(args);
        client_run.addArgs(args);
    }

    const server_step = b.step("server", "Build and run `" ++ config.app_name ++ "d`.");
    server_step.dependOn(&server_run.step);
    const client_step = b.step("client", "Build and run `" ++ config.app_name ++ "`.");
    client_step.dependOn(&client_run.step);

    const arguments: []const []const u8 = &.{
        "ISCC.exe",
        "/Qp",
        b.fmt("/DAppName={s}", .{config.app_name}),
        b.fmt("/DAppVersion={s}", .{config.app_version}),
        b.fmt("/DAppPublisher={s}", .{config.app_publisher}),
        b.fmt("/DAppURL={s}", .{config.app_url}),
        b.fmt("/DOutputDir={s}\\bin", .{b.install_prefix}),
        "installer.iss",
    };
    const installer = b.addSystemCommand(arguments);
    installer.step.dependOn(&server_install.step);
    installer.step.dependOn(&client_install.step);

    b.getInstallStep().dependOn(&installer.step);
}
