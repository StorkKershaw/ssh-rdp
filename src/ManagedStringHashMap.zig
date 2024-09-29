const std = @import("std");
const mem = std.mem;

/// ManagedStringHashMap copies keys and values
/// before they go into the map and frees them when they get removed.
pub fn ManagedStringHashMap(comptime V: type) type {
    return struct {
        hash_map: std.StringHashMap(V),

        const Self = @This();

        /// Create a StringHashMap backed by a specific allocator.
        /// That allocator will be used for both backing allocations
        /// and string deduplication.
        pub fn init(allocator: mem.Allocator) Self {
            return .{ .hash_map = std.StringHashMap(V).init(allocator) };
        }

        /// Free the backing storage of the map, as well as all
        /// of the stored keys and values.
        pub fn deinit(self: *Self) void {
            var it = self.hash_map.iterator();
            while (it.next()) |entry| {
                self.free(entry.key_ptr.*);
                self.destroy(entry.value_ptr.*);
            }

            self.hash_map.deinit();
        }

        /// Same as `put` but the key and value become
        /// owned by the ManagedStringHashMap rather than being copied.
        /// If `putMove` fails, the ownership of key and value does not transfer.
        pub fn putMove(self: *Self, key: []u8, value: V) !void {
            if (try self.hash_map.fetchPut(key, value)) |pair| {
                self.free(pair.key);
                self.destroy(pair.value);
            }
        }

        /// Return the map's copy of the value associated with
        /// a key. The returned string is invalidated if this
        /// key is removed from the map.
        pub fn get(self: Self, key: []const u8) ?V {
            return self.hash_map.get(key);
        }

        /// Removes the item from the map and frees its value.
        /// This invalidates the value returned by get() for this key.
        pub fn remove(self: *Self, key: []const u8) void {
            if (self.hash_map.fetchRemove(key)) |pair| {
                self.free(pair.key);
                self.destroy(pair.value);
            }
        }

        /// Returns an iterator over entries in the map.
        pub fn iterator(self: *const Self) std.StringHashMap(V).Iterator {
            return self.hash_map.iterator();
        }

        fn free(self: Self, key: []const u8) void {
            self.hash_map.allocator.free(key);
        }

        fn destroy(self: Self, value: V) void {
            value.deinit();
            self.hash_map.allocator.destroy(value);
        }
    };
}
