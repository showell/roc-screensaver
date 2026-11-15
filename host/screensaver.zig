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

    /// The model of the next frame.
    pub fn advance(s: *Screensaver) void {
        s.frame_number += 1;
        s.model = abi.roc_step(s.model, s.frame_number);
    }

    /// Paints the current model's frame into `display`.
    pub fn paint(s: *Screensaver) !void {
        const frame = abi.roc_frame(abi.borrow(s.model));
        s.words.clearRetainingCapacity();
        try words.write(s.gpa, &s.words, frame.shapes.items());
        const bg = frame.background;
        const sun: raster.SunPos = switch (bg.sun.tag) {
            .hidden => .{ .visible = false, .x = 0, .y = 0, .scale = 0 },
            .shown => .{ .visible = true, .x = bg.sun.payload.shown.x, .y = bg.sun.payload.shown.y, .scale = bg.sun.payload.shown.scale },
        };
        abi.roc_release_frame(frame);
        const big = raster.Fb{ .px = s.big, .w = s.width * raster.SS, .h = s.height * raster.SS };
        raster.render(big, s.words.items, bg.roll, bg.sky_top, bg.sky_horizon, sun);
        raster.downsample(big, .{ .px = s.display, .w = s.width, .h = s.height });
    }
};
