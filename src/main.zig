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
    if (args.inner.count > 2) {
        @panic("Invalid number of arguments");
    }

    // This is a bit overengineered, we could just call
    // _ = args.next() to skip over the first arg
    // or args.skip() but it's useful to practice using the
    // iterator
    var i: u2 = 0;
    var filepath: [:0]const u8 = undefined;
    while (args.next()) |arg| {
        // first arg is always the program name itself
        // second arg is what we want to pick up
        if (i == 1) {
            filepath = arg;
        }
        i += 1;
    }

    std.debug.print("Opening file path {s} \n", .{filepath});

    var map = try measurement_reader.parse(allocator, filepath);
    defer _ = map.deinit();

    std.debug.print("Total number of items {d}\n", .{map.count()});

    var it = map.iterator();
    while (it.next()) |entry| {
        std.debug.print(
            "{s}: {d}\n",
            .{ entry.key_ptr.*, entry.value_ptr.*.temperatureAvg },
        );
    }
}
