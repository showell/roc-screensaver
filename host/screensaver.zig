//! Runs the app: it holds the model, steps it one frame at a time, and
//! paints each frame into a display buffer of the app's size. Painting asks
//! the Roc for the frame, writes its words (host/words.zig), hands the
//! frame back to Roc to free, and has host/raster.zig fill a supersampled
//! buffer, then box it down to the display.

const std = @import("std");
const abi = @import("abi.zig");
const words = @import("words.zig");
const raster = @import("raster.zig");

pub const Screensaver = struct {
    gpa: std.mem.Allocator,
    model: abi.Model,
    /// The number of the frame the model is drawn as; the first is 0.
    frame_number: u64 = 0,
    width: usize,
    height: usize,
    fps: u32,
    words: std.ArrayList(u32) = .empty,
    big: []u32,
    /// The last painted frame, `width` by `height`, each pixel 0x00RRGGBB.
    display: []u32,

    pub fn init(gpa: std.mem.Allocator) !Screensaver {
        const width: usize = abi.roc_width();
        const height: usize = abi.roc_height();
        if (width == 0 or height == 0) std.debug.panic("the app's size is {d} by {d}", .{ width, height });
        const big = try gpa.alloc(u32, width * raster.SS * height * raster.SS);
        errdefer gpa.free(big);
        const display = try gpa.alloc(u32, width * height);
        return .{
            .gpa = gpa,
            .model = abi.roc_init(),
            .width = width,
            .height = height,
            .fps = abi.roc_fps(),
            .big = big,
            .display = display,
        };
    }

    pub fn deinit(s: *Screensaver) void {
        abi.roc_release_model(s.model);
        s.words.deinit(s.gpa);
        s.gpa.free(s.big);
        s.gpa.free(s.display);
    }

    /// The model of the next frame, stepped with the keyboard as it is now.
    /// A host that passes no keys (the PNG harness, headless, the
    /// screensaver's own modes) passes `abi.Keys.none`.
    pub fn advance(s: *Screensaver, keys: abi.Keys) void {
        s.frame_number += 1;
        s.model = abi.roc_step(s.model, s.frame_number, keys);
    }

    /// The current model's frame as `raster.render` takes it. Its words are
    /// the screensaver's own buffer, good until the next call; the frame
    /// itself is already handed back to Roc. Only this part calls Roc, so a
    /// host that rasterizes on other threads (host/win32.zig) calls it on
    /// the one thread that holds the model.
    pub fn draw(s: *Screensaver) !Drawn {
        const frame = abi.roc_frame(abi.borrow(s.model));
        s.words.clearRetainingCapacity();
        try words.write(s.gpa, &s.words, frame.shapes.items());
        const bg = frame.background;
        const sun: raster.SunPos = switch (bg.sun.tag) {
            .hidden => .{ .visible = false, .x = 0, .y = 0, .scale = 0 },
            .shown => .{ .visible = true, .x = bg.sun.payload.shown.x, .y = bg.sun.payload.shown.y, .scale = bg.sun.payload.shown.scale },
        };
        abi.roc_release_frame(frame);
        return .{ .words = s.words.items, .roll = bg.roll, .sky_top = bg.sky_top, .sky_horizon = bg.sky_horizon, .sun = sun };
    }

    /// Paints the current model's frame into `display`.
    pub fn paint(s: *Screensaver) !void {
        const d = try s.draw();
        const big = raster.Fb{ .px = s.big, .w = s.width * raster.SS, .h = s.height * raster.SS };
        raster.render(big, d.words, d.roll, d.sky_top, d.sky_horizon, d.sun);
        raster.downsample(big, .{ .px = s.display, .w = s.width, .h = s.height });
    }
};

/// One frame, ready for `raster.render`.
pub const Drawn = struct {
    words: []const u32,
    roll: f32,
    sky_top: u32,
    sky_horizon: u32,
    sun: raster.SunPos,
};

/// The FNV-1a hash of a frame's pixels. The PNG harness and the Windows
/// headless run print it for their last frame, so the two builds can be
/// seen drawing the same picture.
pub fn checksum(px: []const u32) u64 {
    var h: u64 = 0xcbf29ce484222325;
    for (std.mem.sliceAsBytes(px)) |byte| {
        h ^= byte;
        h *%= 0x100000001b3;
    }
    return h;
}
