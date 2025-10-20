const std = @import("std");

const temperatureReading = struct {
    location: []const u8,
    temperature: f16,
};

pub fn parse(allocator: std.mem.Allocator, filepath: [:0]const u8) !void {
    var entries = try std.ArrayList(temperatureReading).initCapacity(allocator, 100);
    defer entries.deinit(allocator);

    var buf: [8196]u8 = undefined;
    // assume a single line is less than 256 chars
    var write_buf: [256]u8 = undefined;

    var r = std.fs.File.readerStreaming(try std.fs.cwd().openFile(filepath, .{}), &buf);

    var w = std.Io.Writer.fixed(&write_buf);

    while (r.interface.streamDelimiterEnding(&w, '\n')) |count| {
        const entryItem = try splitData(w.buffer[0..count]);
        try entries.append(
            allocator,
            entryItem,
        );
        std.debug.print(
            "Entry count is {d}\n",
            .{entries.items.len},
        );
        std.debug.print(
            "location: {s} temp: {d}\n",
            .{ entryItem.location, entryItem.temperature },
        );
        _ = w.consumeAll();
        _ = try r.interface.discardDelimiterInclusive('\n');
    } else |err| {
        std.debug.print("{any}", .{err});
        @panic("failed to read");
    }
}

fn splitData(temperatureEntry: []const u8) !temperatureReading {
    // split the string based on the ; and convert the temperatore to f16
    var location: []const u8 = undefined;
    var temp: f16 = undefined;
    const sep = std.mem.indexOf(u8, temperatureEntry, ";").?;
    location = temperatureEntry[0..sep];
    temp = try std.fmt.parseFloat(f16, temperatureEntry[sep + 1 .. temperatureEntry.len]);
    return temperatureReading{ .location = location, .temperature = temp };
}
