const std = @import("std");
const measurement_reader = @import("measurement_reader.zig");

pub fn main() !void {
    // Use the arena allocator because this is a CLI program and we
    // can just throw everything out at the end of the run
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // Wrap the arena with threadsafe so multiple threads can use
    var ts_arena: std.heap.ThreadSafeAllocator = .{ .child_allocator = arena.allocator() };
    const allocator = ts_arena.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    if (args.inner.count < 2) {
        @panic("Invalid number of arguments");
    }

    // This is a bit overengineered, we could just call
    // _ = args.next() to skip over the first arg
    // or args.skip() but it's useful to practice using the
    // iterator
    var i: u2 = 0;
    var filepath: [:0]const u8 = undefined;
    // Assume a max of 256 threads, and start with a default of 2
    var threads: u8 = 2;
    while (args.next()) |arg| {
        switch (i) {
            // first arg is always the program name itself
            // second arg is what we want to pick up
            1 => {
                filepath = arg;
            },
            2 => {
                threads = try std.fmt.parseUnsigned(u8, arg, 10);
                if (threads < 1) {
                    @panic("Invalid input for threads");
                }
            },
            else => {},
        }
        i += 1;
    }

    std.debug.print("Opening file path {s} \n", .{filepath});
    const stats = try std.fs.cwd().statFile(filepath);
    std.debug.print("File is size {d}\n", .{stats.size});
    var f = try std.fs.cwd().openFile(filepath, .{});
    defer f.close();

    if (threads > 1) {
        var start: u64 = 0;
        var end: u64 = 0;
        // Divide the file into equal-ish sized chunks (integer division)
        const chunk_size: u64 = stats.size / threads;
        std.debug.print("Chunk size is {d}\n", .{chunk_size});
        // Allocate a chunk of memory to be used as a buffer.
        // We take a chunk_size bite of the file, find the last newline
        // in the buffer, then update the start and end positions based on the
        // location of that newline, then take another bite of the file.
        var rbuffers = try std.ArrayList(*const []u8).initCapacity(
            allocator,
            threads,
        );
        var count: i8 = 0;

        while (count < threads) {
            var pos: usize = undefined;
            // micro optimization: Don't call seek for first iteration
            if (start > 0) {
                _ = try f.seekTo(start);
            }
            if (count == threads - 1) {
                // last thread, set the end to be the remainder of the file
                end = stats.size;
                // Read the rest of the file
                const final = try f.readToEndAlloc(allocator, end - start);
                try rbuffers.append(allocator, &final);
            } else {
                var rbuffer = try allocator.alloc(u8, chunk_size);
                // Read a chunk of the file into the buffer
                _ = try f.read(rbuffer);
                // look for a newline
                pos = std.mem.lastIndexOf(u8, rbuffer, "\n").?;
                end = start + pos;
                // Create a slice that ends at the last newline
                try rbuffers.append(allocator, &rbuffer[0..pos]);
            }
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
            var item = rbuffers.items[@as(usize, @intCast(count - 1))].*;
            std.debug.print(
                "First measurement: {s}\n",
                .{item[0..std.mem.indexOf(u8, item, "\n").?]},
            );
        }
    } else {
        // no chopping, process the whole file in one thread
    }
}
