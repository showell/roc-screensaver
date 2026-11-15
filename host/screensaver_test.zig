//! Runs the basic example (examples/basic/) through the host. Its first
//! frame is read back field by field and its words held to what
//! raster.zig's `walk` reads, then several frames are painted and every
//! allocation Roc made is shown freed: each frame handed back to
//! `roc_release_frame`, and the last model to `roc_release_model`.

const std = @import("std");
const abi = @import("abi.zig");
const words = @import("words.zig");
const Screensaver = @import("screensaver.zig").Screensaver;

fn bits(x: f32) u32 {
    return @bitCast(x);
}

test "the example's first frame, read field by field and written word by word" {
    abi.allocator = std.testing.allocator;
    const model = abi.roc_init();
    const frame = abi.roc_frame(abi.borrow(model));

    try std.testing.expect(abi.live > 0);

    const bg = frame.background;
    try std.testing.expectEqual(0x2a3f7a, bg.sky_top);
    try std.testing.expectEqual(0xf2a65a, bg.sky_horizon);
    try std.testing.expectEqual(0.0, bg.roll);
    try std.testing.expectEqual(abi.SunTag.shown, bg.sun.tag);
    try std.testing.expectEqual(abi.SunShown{ .scale = 0.4, .x = 330.0, .y = 90.0 }, bg.sun.payload.shown);

    const shapes = frame.shapes.items();
    try std.testing.expectEqual(6, shapes.len);
    const fills = [_]abi.FillTag{ .round, .solid, .linear, .elliptical, .radial };
    for (fills, shapes[0..5]) |want, shape| {
        try std.testing.expectEqual(abi.ShapeTag.polygon, shape.tag);
        try std.testing.expectEqual(want, shape.payload.polygon.fill.tag);
    }
    try std.testing.expectEqual(abi.ShapeTag.disc, shapes[5].tag);

    var out: std.ArrayList(u32) = .empty;
    defer out.deinit(std.testing.allocator);
    // The road: solid, four points.
    try words.write(std.testing.allocator, &out, shapes[1..2]);
    try std.testing.expectEqualSlices(u32, &.{
        0,         0x55504a,  4,
        bits(225), bits(150), bits(255),
        bits(150), bits(400), bits(300),
        bits(80),  bits(300),
    }, out.items);
    // The panel: linear, its stops and its line, then four points.
    out.clearRetainingCapacity();
    try words.write(std.testing.allocator, &out, shapes[2..3]);
    try std.testing.expectEqualSlices(u32, &.{ 5, 0xffd04a3a, 0xff3a1e6e, bits(0.1), bits(0.9), bits(40), bits(190), bits(100), bits(250), 4 }, out.items[0..10]);
    // The lamp: radial.
    out.clearRetainingCapacity();
    try words.write(std.testing.allocator, &out, shapes[4..5]);
    try std.testing.expectEqualSlices(u32, &.{ 4, 0xe0fff6b0, 0x00fff6b0, bits(240), bits(200), bits(30), 4 }, out.items[0..7]);
    // The beacon: a disc, at full strength less its pulse at time 0.
    out.clearRetainingCapacity();
    try words.write(std.testing.allocator, &out, shapes[5..6]);
    try std.testing.expectEqualSlices(u32, &.{ 3, 0xff3030, bits(260), bits(76), bits(5), bits(0.55) }, out.items);
    // The hills: round, at a strength of 0.8, eight points.
    out.clearRetainingCapacity();
    try words.write(std.testing.allocator, &out, shapes[0..1]);
    try std.testing.expectEqualSlices(u32, &.{ 1, 0x5c6b4a, bits(0.8), 8 }, out.items[0..4]);
    // The blob: elliptical.
    out.clearRetainingCapacity();
    try words.write(std.testing.allocator, &out, shapes[3..4]);
    try std.testing.expectEqualSlices(u32, &.{ 6, 0xfff0e0c0, 0xff7a5030, bits(0), bits(1), bits(350), bits(210), bits(50), bits(0), bits(0), bits(40), 8 }, out.items[0..12]);

    abi.roc_release_frame(frame);
    abi.roc_release_model(model);
    try std.testing.expectEqual(0, abi.live);
}

test "frames move, and every allocation Roc made is freed" {
    abi.allocator = std.testing.allocator;
    var s = try Screensaver.init(std.testing.allocator);
    try std.testing.expectEqual(480, s.width);
    try std.testing.expectEqual(300, s.height);
    try std.testing.expectEqual(30, s.fps);
    try s.paint();
    const first = try std.testing.allocator.dupe(u32, s.display);
    defer std.testing.allocator.free(first);
    for (0..4) |_| {
        s.advance(.none);
        try s.paint();
    }
    try std.testing.expectEqual(4, s.frame_number);
    try std.testing.expect(!std.mem.eql(u32, first, s.display));
    s.deinit();
    try std.testing.expectEqual(0, abi.live);
}
