const std = @import("std");
const measurement_reader = @import("measurement_reader.zig");

pub fn main() !void {
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
        std.debug.print("arg is {s} \n", .{arg});
    }

    std.debug.print("Opening file path {s} \n", .{filepath});

    try measurement_reader.parse(allocator, filepath);
}
