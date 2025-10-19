const std = @import("std");

pub fn parse(allocator: std.mem.Allocator, filepath: [:0]const u8) !void {
    var entries = try std.ArrayList([]u8).initCapacity(allocator, 100);
    defer entries.deinit();

    var buf: [1024]u8 = undefined;

    var r = std.fs.File.readerStreaming(try std.fs.cwd().openFile(filepath, .{}), &buf);
    defer r.deinit();

    var write_buf: [1024]u8 = undefined;

    var w = std.Io.Writer.fixed(&write_buf);
    defer w.deinit()

    while (r.interface.streamDelimiterEnding(&w, '\n')) |count| {
        try entries.append(allocator, w.buffer[0..count]);
        _ = w.consumeAll();
        std.debug.print("Entry is {s}\n", .{w.buffer[0..count]});
        _ = try r.interface.discardDelimiterInclusive('\n');
    } else |err| {
        std.debug.print("{any}", .{err});
        @panic("failed to read");
    }
}
