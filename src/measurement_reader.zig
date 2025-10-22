const std = @import("std");

// Contains a single measurement
const temperatureReading = struct {
    location: []const u8,
    temperature: f64,
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
    filepath: [:0]const u8,
) !std.StringHashMap(*temperatureEntry) {
    // Create a StringHashMap that stores the temperatures
    var entries = std.StringHashMap(*temperatureEntry).init(allocator);

    // Use a fixed 8k chunk - might align with storage size
    // TODO: check if this is a good value that fits the OS expectations
    var buf: [8196]u8 = undefined;
    // assume a single line is less than 256 chars
    var write_buf: [256]u8 = undefined;

    var r = std.fs.File.readerStreaming(try std.fs.cwd().openFile(filepath, .{}), &buf);

    var w = std.Io.Writer.fixed(&write_buf);

    while (r.interface.streamDelimiterEnding(&w, '\n')) |count| {
        if (count == 0) {
            // Hit the end of the file which is a single newline and no content
            break;
        }
        const entryItem = try splitData(w.buffer[0..count]);
        if (entries.contains(entryItem.location)) {
            var entry = entries.getPtr(entryItem.location).?.*;
            entry.count += 1;
            const converted_count = @as(f64, @floatFromInt(entry.count));
            // constant average algorithm
            // new_average = (old_average * (n-1) + new_value) / n
            const new_temp =
                (entry.temperatureAvg *
                    (converted_count - 1) +
                    entryItem.temperature) / converted_count;
            entry.temperatureAvg = new_temp;
        } else {
            const key = try allocator.dupe(u8, entryItem.location);
            const val = try allocator.create(temperatureEntry);
            val.* = .{
                .count = 1,
                .temperatureAvg = entryItem.temperature,
            };
            try entries.put(key, val);
        }
        _ = w.consumeAll();
        _ = try r.interface.discardDelimiterInclusive('\n');
    } else |err| {
        std.debug.print("{any}", .{err});
        @panic("failed to read");
    }

    return entries;
}

fn splitData(temperatureRecord: []const u8) !temperatureReading {
    // split the string based on the ; and convert the temperatore to f16
    var location: []const u8 = undefined;
    var temp: f16 = undefined;
    const sep = std.mem.indexOf(u8, temperatureRecord, ";").?;
    location = temperatureRecord[0..sep];
    temp = try std.fmt.parseFloat(f16, temperatureRecord[sep + 1 .. temperatureRecord.len]);
    return temperatureReading{ .location = location, .temperature = temp };
}
