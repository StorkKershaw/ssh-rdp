const std = @import("std");
const fmt = std.fmt;
const fs = std.fs;
const heap = std.heap;
const log = std.log;
const mem = std.mem;
const time = std.time;
const windows = std.os.windows;
const Thread = std.Thread;
const Action = @import("Action.zig");
const ChildProcess = @import("ChildProcess.zig");
const credential = @import("credential.zig");
const rdp = @import("rdp.zig");
const Self = @This();
const ProcessHashMap = std.StringHashMap(ChildProcess);
const Entry = ProcessHashMap.Entry;
const Callback = fn (self: *const Self, entry: Entry) fmt.AllocPrintError!void;

allocator: mem.Allocator,
processes: ProcessHashMap,

pub fn init(allocator: mem.Allocator) !Self {
    return .{
        .allocator = allocator,
        .processes = ProcessHashMap.init(allocator),
    };
}

fn writeLog(comptime format: []const u8, entry: Entry) void {
    log.info(format, .{ entry.key_ptr.*, entry.value_ptr.pid });
}

fn remove(self: *Self, entry: Entry) void {
    entry.value_ptr.deinit();
    self.allocator.free(entry.key_ptr.*);
    self.processes.removeByPtr(entry.key_ptr);
}

pub fn deinit(self: *Self) void {
    var iterator = self.processes.iterator();
    while (iterator.next()) |entry| {
        entry.value_ptr.kill() catch {
            writeLog("Failed to terminate process '{s}' ({d}).", entry);
            continue;
        };
        writeLog("Terminated process '{s}' ({d}).", entry);

        writeLog("Removing process '{s}' ({d}).", entry);
        self.remove(entry);
    }
    self.processes.deinit();
}

fn runExitHandler(self: *Self, entry: Entry, comptime on_exit: ?Callback) !void {
    writeLog("Callback thread for process '{s}' ({d}) has started.", entry);

    try entry.value_ptr.wait();
    writeLog("Process '{s}' ({d}) has exited.", entry);

    if (on_exit) |callback| {
        writeLog("Running exit handler for process '{s}' ({d})...", entry);
        try callback(self, entry);
    }
    writeLog("Removing process '{s}' ({d}).", entry);
    self.remove(entry);
}

fn spawnManageThread(self: *Self, entry: Entry, comptime on_exit: ?Callback) !void {
    const thread = try Thread.spawn(.{}, runExitHandler, .{ self, entry, on_exit });
    thread.detach();
}

fn exitSSHTunnel(self: *const Self, rdp_entry: Entry) fmt.AllocPrintError!void {
    const ssh_key = try fmt.allocPrint(self.allocator, "ssh:{s}", .{rdp_entry.key_ptr.*[4..]});
    defer self.allocator.free(ssh_key);

    if (self.processes.getEntry(ssh_key)) |ssh_entry| {
        if (!ssh_entry.value_ptr.isAlive()) {
            writeLog("Process '{s}' ({d}) has exited.", ssh_entry);
            return;
        }
        ssh_entry.value_ptr.kill() catch {
            writeLog("Failed to terminate process '{s}' ({d}).", ssh_entry);
            return;
        };
        writeLog("Terminated process '{s}' ({d}).", ssh_entry);
    }
}

pub fn execute(self: *Self, action: *Action) !void {
    switch (action.type) {
        .ssh => {
            const key = try fmt.allocPrint(self.allocator, "ssh:{s}", .{action.host});

            const result = try self.processes.getOrPut(key);
            if (result.found_existing) {
                defer self.allocator.free(key);
                writeLog("Process '{s}' ({d}) is already running.", .{ .key_ptr = result.key_ptr, .value_ptr = result.value_ptr });
                return;
            }

            result.value_ptr.* = try ChildProcess.spawn(self.allocator, "ssh.exe {s}", .{action.host});
            const entry: Entry = .{ .key_ptr = result.key_ptr, .value_ptr = result.value_ptr };
            writeLog("Started process '{s}' ({d}).", entry);

            try self.spawnManageThread(entry, null);
        },
        .rdp => {
            const ssh_key = try fmt.allocPrint(self.allocator, "ssh:{s}", .{action.host});
            defer self.allocator.free(ssh_key);

            if (self.processes.getEntry(ssh_key)) |ssh_entry| {
                if (!ssh_entry.value_ptr.isAlive()) {
                    writeLog("Process '{s}' ({d}) has exited.", ssh_entry);
                    return;
                }
            } else {
                log.info("Process '{s}' is unavailable.", .{ssh_key});
                return;
            }

            const key = try fmt.allocPrint(self.allocator, "rdp:{s}", .{action.host});

            const result = try self.processes.getOrPut(key);
            if (result.found_existing) {
                defer self.allocator.free(key);
                writeLog("Process '{s}' ({d}) is already running.", .{ .key_ptr = result.key_ptr, .value_ptr = result.value_ptr });
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

            result.value_ptr.* = try ChildProcess.spawn(self.allocator, "mstsc.exe {s}", .{file_path});
            const entry: Entry = .{ .key_ptr = result.key_ptr, .value_ptr = result.value_ptr };
            writeLog("Started process '{s}' ({d}).", entry);

            try self.spawnManageThread(entry, exitSSHTunnel);
        },
    }
}
