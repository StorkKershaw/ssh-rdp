const std = @import("std");
const fmt = std.fmt;
const heap = std.heap;
const log = std.log;
const mem = std.mem;
const windows = std.os.windows;
const Action = @import("Action.zig");
const ChildProcess = @import("ChildProcess.zig");
const ManagedStringHashMap = @import("ManagedStringHashMap.zig").ManagedStringHashMap;
const ProcessManager = @This();

arena: *heap.ArenaAllocator,
allocator: mem.Allocator,
processes: *ManagedStringHashMap(*ChildProcess),

fn spawn(self: *const ProcessManager, comptime format: []const u8, values: anytype) !*ChildProcess {
    const child_process = try self.allocator.create(ChildProcess);
    errdefer self.allocator.destroy(child_process);

    child_process.* = try ChildProcess.spawn(self.arena.child_allocator, format, values);
    return child_process;
}

fn spawnAndWait(self: *const ProcessManager, comptime format: []const u8, values: anytype) !void {
    try ChildProcess.spawnAndWait(self.arena.child_allocator, format, values);
}

pub fn init(child_allocator: mem.Allocator) !ProcessManager {
    var arena = try child_allocator.create(heap.ArenaAllocator);
    errdefer child_allocator.destroy(arena);

    arena.* = heap.ArenaAllocator.init(child_allocator);
    const allocator = arena.allocator();

    const processes = try allocator.create(ManagedStringHashMap(*ChildProcess));
    errdefer allocator.destroy(processes);

    processes.* = ManagedStringHashMap(*ChildProcess).init(allocator);

    return .{
        .arena = arena,
        .allocator = allocator,
        .processes = processes,
    };
}

pub fn deinit(self: *ProcessManager) void {
    self.processes.deinit();
    self.allocator.destroy(self.processes);

    self.arena.deinit();
    self.arena.child_allocator.destroy(self.arena);
}

fn collectExitedProcesses(self: *const ProcessManager) void {
    var iterator = self.processes.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const value = entry.value_ptr.*;

        if (!value.isAlive()) {
            log.info("Removing exited process '{s}' ({d}).", .{ key, value.pid });
            self.processes.remove(key);
        }
    }
}

pub fn execute(self: *const ProcessManager, action: Action) !void {
    defer self.collectExitedProcesses();

    switch (action.type) {
        .SSH => {
            // `key` is temporal; it will be freed at the end of the block.
            const key = try fmt.allocPrint(self.allocator, "ssh:{s}", .{action.host});
            defer self.allocator.free(key);

            if (self.processes.get(key)) |ssh_process| {
                if (ssh_process.isAlive()) {
                    log.info("Process '{s}' ({d}) is running.", .{ key, ssh_process.pid });
                    return;
                }
            }

            const ssh_process = try self.spawn("ssh.exe {s}", .{action.host});
            log.info("Started process '{s}' ({d}).", .{ key, ssh_process.pid });

            const persist_key = try self.allocator.dupe(u8, key);
            errdefer self.allocator.free(persist_key);
            try self.processes.putMove(persist_key, ssh_process);
        },
        .RDP => {
            const other_key = try fmt.allocPrint(self.allocator, "ssh:{s}", .{action.host});
            defer self.allocator.free(other_key);

            if (self.processes.get(other_key)) |ssh_process| {
                if (!ssh_process.isAlive()) {
                    log.warn("Process '{s}' ({d}) has exited.", .{ other_key, ssh_process.pid });

                    self.processes.remove(other_key);
                    return;
                }
            } else {
                log.warn("Process '{s}' is unavailable.", .{other_key});
                return;
            }

            // `key` is temporal; it will be freed at the end of the block.
            const key = try fmt.allocPrint(self.allocator, "rdp:{s}", .{action.host});
            defer self.allocator.free(key);

            if (self.processes.get(key)) |rdp_process| {
                if (rdp_process.isAlive()) {
                    log.info("Process '{s}' ({d}) is running.", .{ key, rdp_process.pid });
                    return;
                }
            }

            try self.spawnAndWait("cmdkey.exe /add:TERMSRV/localhost /user:{s} /pass:{s}", .{ action.user.?, action.password.? });

            const rdp_process = try self.spawn("mstsc.exe {s}", .{action.file.?});
            log.info("Started process '{s}' ({d}).", .{ key, rdp_process.pid });

            const persist_key = try self.allocator.dupe(u8, key);
            errdefer self.allocator.free(persist_key);
            try self.processes.putMove(persist_key, rdp_process);

            const thread = try std.Thread.spawn(.{}, synchronize, .{ self, action.host });
            thread.detach();
        },
    }
}

pub fn synchronize(self: *const ProcessManager, host: []const u8) !void {
    defer self.collectExitedProcesses();

    const rdp_key = try fmt.allocPrint(self.allocator, "rdp:{s}", .{host});
    defer self.allocator.free(rdp_key);

    const rdp_process = self.processes.get(rdp_key).?;
    try rdp_process.wait();
    log.info("Process '{s}' ({d}) has exited.", .{ rdp_key, rdp_process.pid });

    const ssh_key = try fmt.allocPrint(self.allocator, "ssh:{s}", .{host});
    defer self.allocator.free(ssh_key);

    const ssh_process = self.processes.get(ssh_key).?;
    try ssh_process.kill();
    log.info("Terminated process '{s}' ({d}).", .{ ssh_key, ssh_process.pid });
}
