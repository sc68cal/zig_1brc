const std = @import("std");
const measurement_reader = @import("measurement_reader.zig");

pub fn main() !void {
    // Use the arena allocator because this is a CLI program and we
    // can just throw everything out at the end of the run
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

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
    const contents = try std.fs.Dir.readFileAlloc(
        std.fs.cwd(),
        filepath,
        allocator,
        .unlimited,
    );
    std.debug.print("File is size {d}\n", .{contents.len});

    var start: usize = 0;
    var end: usize = 0;
    var chunk_size: usize = contents.len / threads;
    std.debug.print("Chunk size is {d}\n", .{chunk_size});
    if (threads > 1) {
        // find first newline, after chunk_size
        end = std.mem.findPos(u8, contents, chunk_size, "\n").?;
    } else {
        // no chopping, process the whole file in one thread
        chunk_size = contents.len;
        end = contents.len;
    }
    var count: i8 = 0;
    while (count < threads) {
        // Send this chunk to a thread
        std.debug.print(
            "Found newline for thread {d}, starting at {d} and ending at {d}\n",
            .{ count + 1, start, end },
        );
        // Set up for the next iteration
        start = end + 1;
        // Jump ahead in the file by chunk_size, unless there is
        // not enough file left
        if (end + chunk_size <= contents.len) {
            end = std.mem.findPos(u8, contents, end + chunk_size, "\n").?;
        } else {
            end = contents.len;
        }
        count += 1;
    }
}
