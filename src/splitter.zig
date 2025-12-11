const std = @import("std");

pub fn split(
    allocator: std.mem.Allocator,
    filepath: [:0]const u8,
    chunk_count: usize,
) !std.ArrayList([]u8) {
    std.debug.print("Opening file path {s} \n", .{filepath});
    const stats = try std.fs.cwd().statFile(filepath);
    std.debug.print("File is size {d}\n", .{stats.size});
    var f = try std.fs.cwd().openFile(filepath, .{});
    defer f.close();
    var start: u64 = 0;
    var end: u64 = 0;

    // Divide the file into equal-ish sized chunks (integer division)
    const chunk_size = stats.size / chunk_count;
    std.debug.print("Chunk size is {d}\n", .{chunk_size});
    // Allocate a chunk of memory to be used as a buffer.
    // We take a chunk_size bite of the file, find the last newline
    // in the buffer, then update the start and end positions based on the
    // location of that newline, then take another bite of the file.
    var rbuffers = try std.ArrayList([]u8).initCapacity(
        allocator,
        chunk_count,
    );
    var count: usize = 0;

    while (count < chunk_count) {
        var pos: usize = undefined;
        // micro optimization: Don't call seek for first iteration
        if (start > 0) {
            _ = try f.seekTo(start);
        }
        if (count == chunk_count - 1) {
            // last thread, set the end to be the remainder of the file
            end = stats.size;
            // Read the rest of the file
            const final = try f.readToEndAlloc(allocator, end - start);
            try rbuffers.append(allocator, final);
        } else {
            var rbuffer = try allocator.alloc(u8, chunk_size);
            // Read a chunk of the file into the buffer
            _ = try f.read(rbuffer);
            // look for a newline
            pos = std.mem.lastIndexOf(u8, rbuffer, "\n").?;
            end = start + pos;
            // Create a slice that ends at the last newline
            try rbuffers.append(allocator, rbuffer[0 .. pos + 1]);
        }
        var item = rbuffers.items[@as(usize, @intCast(count))];
        // Increment count before print so we get 1 based index
        // for pretty human readable format
        count += 1;
        std.debug.print(
            "Thread {d}, starting at {d} and ending at {d} - {d} bytes\n",
            .{ count, start, end, end - start },
        );
        // Update new start position
        start = end + 1;
        // Print first line of the chunk to make sure we're working
        // correctly
        std.debug.print(
            "First measurement: {s}\n",
            .{item[0..std.mem.indexOf(u8, item, "\n").?]},
        );
    }
    return rbuffers;
}
