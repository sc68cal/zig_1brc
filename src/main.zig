const std = @import("std");
const measurement_reader = @import("measurement_reader.zig");

pub fn main() !void {
    // Use the arena allocator because this is a CLI program and we
    // can just throw everything out at the end of the run
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var f: std.fs.File = undefined;
    defer f.close();

    const allocator = arena.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    if (args.inner.count > 3) {
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

    var start: u64 = 0;
    var end: u64 = 0;
    var chunk_size: u64 = stats.size / threads;
    if (threads > 1) {
        std.debug.print("Chunk size is {d}\n", .{chunk_size});
        const rbuffer = try allocator.alloc(u8, chunk_size);
        // open the file, seek to chunk size
        f = try std.fs.cwd().openFile(filepath, .{});
        var count: i8 = 0;

        while (count < threads) {
            // Set up for the next iteration
            // Send this chunk to a thread
            if (count == threads - 1) {
                // last thread, give the remainder
                end = stats.size;
            } else {
                _ = try f.seekTo(start);
                _ = try f.read(rbuffer);
                end = start + std.mem.lastIndexOf(u8, rbuffer, "\n").?;
            }
            std.debug.print(
                "Thread {d}, starting at {d} and ending at {d}\n",
                .{ count + 1, start, end },
            );
            count += 1;
            start = end + 1;
        }
    } else {
        // no chopping, process the whole file in one thread
        chunk_size = stats.size;
        end = stats.size;
    }
}
