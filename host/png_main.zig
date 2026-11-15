//! The headless harness: `png <out dir>` paints the app's first
//! `frames_written` frames, stepping the model once between each, and
//! writes them as `<out dir>/frame-NNN.png`. It is how the platform is
//! seen working without a window.

const std = @import("std");
const screensaver = @import("screensaver.zig");
const Screensaver = screensaver.Screensaver;
const png = @import("png.zig");

pub const frames_written = 8;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const a = init.arena.allocator();
    const args = try init.minimal.args.toSlice(a);
    if (args.len != 2) std.process.fatal("usage: png <out dir>", .{});
    const dir = args[1];
    try std.Io.Dir.cwd().createDirPath(io, dir);

    var s = try Screensaver.init(std.heap.smp_allocator);
    defer s.deinit();
    const row = 1 + s.width * 3;
    const raw = try a.alloc(u8, s.height * row);
    // Stored deflate blocks add five bytes per 65535, and zlib six in all.
    const zlib = try a.alloc(u8, raw.len + raw.len / 65535 * 5 + 64);
    const out = try a.alloc(u8, zlib.len + 1024);

    for (0..frames_written) |k| {
        if (k > 0) s.advance();
        try s.paint();
        const bytes = png.encode(s.display, s.width, s.height, raw, zlib, out);
        const path = try std.fmt.allocPrint(a, "{s}/frame-{d:0>3}.png", .{ dir, k });
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = bytes });
    }
    std.debug.print("png: {d} frames of {d} by {d} in {s}; the last's checksum {x:0>16}\n", .{ frames_written, s.width, s.height, dir, screensaver.checksum(s.display) });
}
