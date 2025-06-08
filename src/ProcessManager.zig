const std = @import("std");
const log = std.log;
const Allocator = std.mem.Allocator;
const Thread = std.Thread;
const Action = @import("Action.zig");
const Process = @import("Process.zig");
const credential = @import("credential.zig");
const rdp = @import("rdp.zig");
const Self = @This();
const ProcessPair = struct {
    ssh: Process,
    rdp: ?Process,
};
const ProcessHashMap = std.StringHashMap(ProcessPair);
const Entry = ProcessHashMap.Entry;

allocator: Allocator,
processes: ProcessHashMap,

pub fn init(allocator: Allocator) !Self {
    return .{
        .allocator = allocator,
        .processes = ProcessHashMap.init(allocator),
    };
}

fn remove(self: *Self, entry: Entry) void {
    self.allocator.free(entry.key_ptr.*);
    self.processes.removeByPtr(entry.key_ptr);
}

pub fn deinit(self: *Self) void {
    var iterator = self.processes.iterator();
    while (iterator.next()) |entry| {
        if (entry.value_ptr.rdp) |rdp_process| {
            log.info("Terminating RDP process '{s}' ({d}).", .{ entry.key_ptr.*, rdp_process.pid });
            rdp_process.kill();
        } else {
            log.info("Terminating SSH process '{s}' ({d}).", .{ entry.key_ptr.*, entry.value_ptr.ssh.pid });
            entry.value_ptr.ssh.kill();
        }

        self.remove(entry);
    }
    self.processes.deinit();
}

fn runExitHandler(self: *Self, entry: Entry) !void {
    if (entry.value_ptr.rdp) |rdp_process| {
        log.info("Callback thread for RDP process '{s}' ({d}) has started.", .{ entry.key_ptr.*, rdp_process.pid });

        rdp_process.waitWith(&entry.value_ptr.ssh);
        if (rdp_process.isAlive()) {
            log.info("Terminating RDP process '{s}' ({d}).", .{ entry.key_ptr.*, rdp_process.pid });
            rdp_process.kill();
        } else {
            log.info("RDP process '{s}' ({d}) has exited.", .{ entry.key_ptr.*, rdp_process.pid });
        }
        entry.value_ptr.rdp.?.deinit();
        entry.value_ptr.rdp = null;

        if (entry.value_ptr.ssh.isAlive()) {
            log.info("Terminating SSH process '{s}' ({d}).", .{ entry.key_ptr.*, entry.value_ptr.ssh.pid });
            entry.value_ptr.ssh.kill();
        }
    } else {
        log.info("Callback thread for SSH process '{s}' ({d}) has started.", .{ entry.key_ptr.*, entry.value_ptr.ssh.pid });

        entry.value_ptr.ssh.wait();
        log.info("SSH process '{s}' ({d}) has exited.", .{ entry.key_ptr.*, entry.value_ptr.ssh.pid });
        entry.value_ptr.ssh.deinit();

        self.remove(entry);
    }
}

fn spawnManageThread(self: *Self, entry: Entry) !void {
    const thread = try Thread.spawn(.{}, runExitHandler, .{ self, entry });
    thread.detach();
}

pub fn execute(self: *Self, action: *Action) !void {
    switch (action.type) {
        .ssh => {
            const result = try self.processes.getOrPut(action.host);
            if (result.found_existing) {
                log.info("SSH Process '{s}' ({d}) is already running.", .{ action.host, result.value_ptr.ssh.pid });
                return;
            }

            result.key_ptr.* = try self.allocator.dupe(u8, action.host);
            result.value_ptr.* = .{
                .ssh = try Process.init(self.allocator, "ssh.exe {s}", .{action.host}),
                .rdp = null,
            };
            log.info("SSH Process '{s}' ({d}) has started.", .{ action.host, result.value_ptr.ssh.pid });

            try self.spawnManageThread(.{ .key_ptr = result.key_ptr, .value_ptr = result.value_ptr });
        },
        .rdp => {
            const result = try self.processes.getOrPut(action.host);
            if (!result.found_existing) {
                log.info("SSH process '{s}' is unavailable.", .{action.host});
                return;
            }

            if (result.value_ptr.rdp) |rdp_process| {
                log.info("RDP Process '{s}' ({d}) is already running.", .{ action.host, rdp_process.pid });
                return;
            }

            const user = action.user orelse return;
            const address = action.address orelse return;

            if (action.password) |password| {
                try credential.writeCredential(self.allocator, user, password);
                log.info("Saved credential for user '{s}'.", .{user});
            }

            const file_path = try rdp.writeConfig(self.allocator, address, user);
            defer self.allocator.free(file_path);
            log.info("Created RDP config file '{s}'.", .{file_path});

            result.value_ptr.*.rdp = try Process.init(self.allocator, "mstsc.exe {s}", .{file_path});
            log.info("RDP Process '{s}' ({d}) has started.", .{ action.host, result.value_ptr.rdp.?.pid });

            try self.spawnManageThread(.{ .key_ptr = result.key_ptr, .value_ptr = result.value_ptr });
        },
    }
}
