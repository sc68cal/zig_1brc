const std = @import("std");

// Contains a single measurement
const temperatureReading = struct {
    location: []const u8,
    temperature: f64,
};

pub const ThreadSafeHashMap = struct {
    mutex: std.Thread.Mutex,
    map: std.StringHashMap(temperatureEntry),

    pub fn init(allocator: std.mem.Allocator) ThreadSafeHashMap {
        return .{
            .mutex = std.Thread.Mutex{},
            .map = std.StringHashMap(temperatureEntry).init(allocator),
        };
    }

    pub fn deinit(self: *ThreadSafeHashMap) void {
        self.map.deinit();
    }

    pub fn put(self: *ThreadSafeHashMap, key: []const u8, value: temperatureEntry) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.map.put(key, value);
    }

    pub fn get(self: *ThreadSafeHashMap, key: []const u8) ?[]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.map.get(key);
    }

    pub fn remove(self: *ThreadSafeHashMap, key: []const u8) ?[]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.map.remove(key);
    }

    pub fn contains(self: *ThreadSafeHashMap, key: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.map.contains(key);
    }
    pub fn getPtr(self: *ThreadSafeHashMap, key: []const u8) ?*temperatureEntry {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.map.getPtr(key);
    }
    pub fn count(self: *ThreadSafeHashMap) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.map.count();
    }
};

// Used with StringHashMap to track data for a location.
// Location name is the key in the Hashmap and this is the value.
// This is used to calculate the cumulative average sum
// without storing each measurement
const temperatureEntry = struct {
    temperatureAvg: f64,
    // Worst case assume 1 billion row file of just one city
    count: u30,
};

pub fn parse(
    allocator: std.mem.Allocator,
    measurements: []const u8,
    entries: *ThreadSafeHashMap,
) !void {
    // Assume that no individual temperature reading is longer than 255 chars
    var writer_buffer = try std.Io.Writer.Allocating.initCapacity(allocator, 255);
    defer writer_buffer.deinit();

    var r = std.Io.Reader.fixed(measurements);
    var w = writer_buffer.writer;

    while (r.streamDelimiterEnding(&w, '\n')) |count| {
        if (count == 0) {
            // Hit the end of the file which is a single newline and no content
            break;
        }
        const entryItem = try splitData(w.buffer[0..count]);
        if (entries.contains(entryItem.location)) {
            const entry = entries.getPtr(entryItem.location).?;
            entry.*.count += 1;
            const converted_count = @as(f64, @floatFromInt(entry.count));
            // constant average algorithm
            // new_average = (old_average * (n-1) + new_value) / n
            const new_temp =
                (entry.temperatureAvg *
                    (converted_count - 1) +
                    entryItem.temperature) / converted_count;
            entry.*.temperatureAvg = new_temp;
        } else {
            // Copy the location name into a dynamically allocated u8
            // since entryItem is stack-allocated and StringHashMap
            // requires you to manage keys yourself
            const key = try allocator.dupe(u8, entryItem.location);
            try entries.put(
                key,
                .{
                    .count = 1,
                    .temperatureAvg = entryItem.temperature,
                },
            );
        }
        // Mark the number of bytes read as consumed
        _ = w.consume(count);
        // Advance the reader
        _ = try r.discardDelimiterInclusive('\n');
    } else |err| {
        std.debug.print("{any}", .{err});
        @panic("failed to read");
    }
}

fn splitData(temperatureRecord: []const u8) !temperatureReading {
    // split the string based on the ; and convert the temperatore to f16
    var location: []const u8 = undefined;
    var temp: f16 = undefined;
    const sep = std.mem.indexOf(u8, temperatureRecord, ";").?;
    location = temperatureRecord[0..sep];
    temp = try std.fmt.parseFloat(
        f16,
        temperatureRecord[sep + 1 .. temperatureRecord.len],
    );
    return temperatureReading{
        .location = location,
        .temperature = temp,
    };
}
