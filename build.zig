const std = @import("std");
const SemanticVersion = std.SemanticVersion;

const config = .{
    .app_name = "ssh-rdp",
    .app_version = "0.0.10",
    .app_publisher = "StorkKershaw",
    .app_url = "https://github.com/StorkKershaw/ssh-rdp",
};

pub fn build(b: *std.Build) void {
    const version = SemanticVersion.parse(config.app_version) catch @panic("Invalid semantic version.");

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const clap = b.dependency("clap", .{});
    const win32 = b.dependency("win32", .{});
    const executable = b.addExecutable(.{
        .name = config.app_name,
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    executable.subsystem = if (optimize == .Debug) .Console else .Windows;
    executable.addWin32ResourceFile(.{
        .file = b.path("resource.rc"),
        .flags = &.{
            b.fmt("/dAPP_NAME={s}", .{config.app_name}),
            b.fmt("/dVERSION_MAJOR={d}", .{version.major}),
            b.fmt("/dVERSION_MINOR={d}", .{version.minor}),
            b.fmt("/dVERSION_PATCH={d}", .{version.patch}),
            b.fmt("/dVERSION_BUILD={s}", .{version.build orelse "0"}),
            b.fmt("/dAPP_PUBLISHER={s}", .{config.app_publisher}),
        },
    });
    const option = b.addOptions();
    option.addOption([]const u8, "app_name", config.app_name);
    option.addOption([]const u8, "app_version", config.app_version);
    executable.root_module.addOptions("config", option);
    executable.root_module.addImport("clap", clap.module("clap"));
    executable.root_module.addImport("win32", win32.module("win32"));

    const install_executable = b.addInstallArtifact(executable, .{});

    const run_executable = b.addRunArtifact(executable);
    run_executable.step.dependOn(&install_executable.step);
    if (b.args) |args| {
        run_executable.addArgs(args);
    }

    const run = b.step("run", "Build and run `" ++ config.app_name ++ "`.");
    run.dependOn(&run_executable.step);

    const installer = b.addSystemCommand(
        &.{
            "ISCC.exe",
            "/Qp",
            b.fmt("/DAppName={s}", .{config.app_name}),
            b.fmt("/DAppVersion={s}", .{config.app_version}),
            b.fmt("/DAppPublisher={s}", .{config.app_publisher}),
            b.fmt("/DAppURL={s}", .{config.app_url}),
            b.fmt("/DOutputDir={s}\\bin", .{b.install_prefix}),
            "installer.iss",
        },
    );
    installer.step.dependOn(&install_executable.step);

    b.getInstallStep().dependOn(&installer.step);
}
