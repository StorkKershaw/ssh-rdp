const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
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

    const zig_cli = b.addModule("zig-cli", .{
        .root_source_file = .{
            .src_path = .{
                .owner = b,
                .sub_path = "lib/zig-cli-last-zig-0.13/src/main.zig",
            },
        },
    });

    const server_exe = b.addExecutable(.{
        .name = "ssh-rdpd",
        .root_source_file = b.path("src/server.zig"),
        .target = target,
        .optimize = optimize,
    });
    server_exe.root_module.addImport("zig-cli", zig_cli);

    const client_exe = b.addExecutable(.{
        .name = "ssh-rdp",
        .root_source_file = b.path("src/client.zig"),
        .target = target,
        .optimize = optimize,
    });
    client_exe.root_module.addImport("zig-cli", zig_cli);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(server_exe);
    b.installArtifact(client_exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const server_run = b.addRunArtifact(server_exe);
    const client_run = b.addRunArtifact(client_exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    server_run.step.dependOn(b.getInstallStep());
    client_run.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        server_run.addArgs(args);
        client_run.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const server_step = b.step("server", "Run `ssh-rdpd`.");
    server_step.dependOn(&server_run.step);
    const client_step = b.step("client", "Run `ssh-rdp`.");
    client_step.dependOn(&client_run.step);
}
