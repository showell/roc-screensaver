//! The headless harness: `png <out dir>` paints the app's first
//! `frames_written` frames, stepping the model once between each, and
//! writes them as `<out dir>/frame-NNN.png`. It is how the platform is
//! seen working without a window.
//!
//! `png <out dir> <step> ...` writes the frames at those steps instead, in
//! rising order, as `<out dir>/step-NNN.png`: the frame drawn after that many
//! steps from the first, as the page shows it at `?step=NNN`, so the two can
//! be laid side by side.

const std = @import("std");
const screensaver = @import("screensaver.zig");
const Screensaver = screensaver.Screensaver;
const png = @import("png.zig");

pub const frames_written = 8;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const a = init.arena.allocator();
    const args = try init.minimal.args.toSlice(a);
    if (args.len < 2) std.process.fatal("usage: png <out dir> [step ...]", .{});
    const dir = args[1];
    try std.Io.Dir.cwd().createDirPath(io, dir);

    const named = args.len > 2;
    var steps: std.ArrayList(u64) = .empty;
    if (named) {
        for (args[2..]) |word| try steps.append(a, std.fmt.parseInt(u64, word, 10) catch
            std.process.fatal("png: a step is a whole number, not {s}", .{word}));
        std.mem.sort(u64, steps.items, {}, std.sort.asc(u64));
    } else {
        for (0..frames_written) |k| try steps.append(a, k);
    }

    var s = try Screensaver.init(std.heap.smp_allocator);
    defer s.deinit();
    const row = 1 + s.width * 3;
    const raw = try a.alloc(u8, s.height * row);
    // Stored deflate blocks add five bytes per 65535, and zlib six in all.
    const zlib = try a.alloc(u8, raw.len + raw.len / 65535 * 5 + 64);
    const out = try a.alloc(u8, zlib.len + 1024);

    for (steps.items) |step| {
        while (s.frame_number < step) s.advance(.none);
        try s.paint();
        const bytes = png.encode(s.display, s.width, s.height, raw, zlib, out);
        const name = if (named) "step" else "frame";
        const path = try std.fmt.allocPrint(a, "{s}/{s}-{d:0>3}.png", .{ dir, name, step });
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = bytes });
    }
    std.debug.print("png: {d} frames of {d} by {d} in {s}; the last's checksum {x:0>16}\n", .{ steps.items.len, s.width, s.height, dir, screensaver.checksum(s.display) });
}
