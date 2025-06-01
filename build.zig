const std = @import("std");

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
        .name = "ssh-rdpd",
        .root_source_file = b.path("src/server.zig"),
        .target = target,
        .optimize = optimize,
    });
    server_exe.root_module.addImport("win32", win32.module("win32"));

    const clap = b.dependency("clap", .{});
    const client_exe = b.addExecutable(.{
        .name = "ssh-rdp",
        .root_source_file = b.path("src/client.zig"),
        .target = target,
        .optimize = optimize,
    });
    client_exe.root_module.addImport("clap", clap.module("clap"));

    b.installArtifact(server_exe);
    b.installArtifact(client_exe);

    const server_run = b.addRunArtifact(server_exe);
    const client_run = b.addRunArtifact(client_exe);

    server_run.step.dependOn(b.getInstallStep());
    client_run.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        server_run.addArgs(args);
        client_run.addArgs(args);
    }

    const server_step = b.step("server", "Build and run `ssh-rdpd`.");
    server_step.dependOn(&server_run.step);
    const client_step = b.step("client", "Build and run `ssh-rdp`.");
    client_step.dependOn(&client_run.step);
}
