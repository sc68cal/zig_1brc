const std = @import("std");
const measurement_reader = @import("measurement_reader.zig");
const splitter = @import("splitter.zig");

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

    if (threads > 1) {
        const chunks = try splitter.split(allocator, filepath, threads);
        std.debug.print("chunks count: {d}\n", .{chunks.items.len});
        const readings = try measurement_reader.parse(allocator, chunks.items[0]);
        std.debug.print("Readings count: {d}\n", .{readings.count()});
    } else {
        // no chopping, process the whole file in one thread
        const stats = try std.fs.cwd().statFile(filepath);
        const data = try std.fs.cwd().readFileAlloc(allocator, filepath, stats.size);
        const readings = try measurement_reader.parse(allocator, data);
        std.debug.print("Readings count: {d}\n", .{readings.count()});
    }
}
