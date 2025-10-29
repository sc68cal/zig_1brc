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
) !std.StringHashMap(temperatureEntry) {
    // Create a StringHashMap that stores the temperatures
    var entries = std.StringHashMap(temperatureEntry).init(allocator);

    // Use a fixed 8k chunk - might align with storage size
    // TODO: check if this is a good value that fits the OS expectations
    var reader_buffer: [8196]u8 = undefined;
    // Use a dynamically allocated buffer to store lines from the file
    // so that we don't have to worry about a line being too long
    var writer_buffer = try std.Io.Writer.Allocating.initCapacity(allocator, 255);
    defer writer_buffer.deinit();

    var r = std.fs.File.readerStreaming(
        try std.fs.cwd().openFile(filepath, .{}),
        &reader_buffer,
    );
    var w = writer_buffer.writer;

    while (r.interface.streamDelimiterEnding(&w, '\n')) |count| {
        if (count == 0) {
            // Hit the end of the file which is a single newline and no content
            break;
        }
        const entryItem = try splitData(w.buffer[0..count]);
        if (entries.contains(entryItem.location)) {
            var entry = entries.getPtr(entryItem.location).?;
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
            try entries.put(key, .{
                .count = 1,
                .temperatureAvg = entryItem.temperature,
            });
        }
        // Mark the number of bytes read as consumed
        _ = w.consume(count);
        // Advance the reader
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
