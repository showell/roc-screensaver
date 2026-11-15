//! Holds raster.zig's fast paths to its plain per-pixel rule. Each test
//! paints one polygon over the same noisy background twice, through
//! `walkWith(.fast)` and `walkWith(.per_pixel)`, and wants the same pixels.
//! Each also wants the polygon to have changed the background, so a fill
//! that painted nothing both ways cannot pass. The pentagon's rows are of
//! every length, so a `lanes` run's last few pixels, painted one by one,
//! are covered too.

const std = @import("std");
const raster = @import("raster.zig");

/// A small supersampled buffer: 32 by 24 design pixels.
const w = 64;
const h = 48;

fn bits(x: f32) u32 {
    return @bitCast(x);
}

/// A background whose every pixel differs from its neighbours, so a blend
/// over it shows any difference in how it was worked out.
fn noise(px: []u32) void {
    for (px, 0..) |*p, i| p.* = @as(u32, @truncate(i *% 2654435761)) & 0xffffff;
}

/// A polygon's corners, as the words take them: a pentagon that fills most
/// of the frame, with no edge upright or level.
const pentagon = [_]f32{ 2, 3, 29, 1, 31, 15, 16, 23, 1, 18 };

fn withPoints(comptime n: usize, head: [n]u32) [n + pentagon.len]u32 {
    var out: [n + pentagon.len]u32 = undefined;
    for (head, 0..) |x, i| out[i] = x;
    for (pentagon, 0..) |x, i| out[n + i] = bits(x);
    return out;
}

/// The pixels `words` paint over the noise at `tilt`, both ways, and how many
/// of them the fill changed.
fn paintBoth(words: []const u32, tilt: f32) !usize {
    var fast: [w * h]u32 = undefined;
    var slow: [w * h]u32 = undefined;
    var bare: [w * h]u32 = undefined;
    noise(&fast);
    noise(&slow);
    noise(&bare);
    const fb_fast = raster.Fb{ .px = &fast, .w = w, .h = h };
    const fb_slow = raster.Fb{ .px = &slow, .w = w, .h = h };
    raster.walkWith(fb_fast, raster.rollFor(fb_fast, tilt), words, .fast);
    raster.walkWith(fb_slow, raster.rollFor(fb_slow, tilt), words, .per_pixel);
    try std.testing.expectEqualSlices(u32, &slow, &fast);
    var changed: usize = 0;
    for (fast, bare) |a, b| {
        if (a != b) changed += 1;
    }
    return changed;
}

/// A linear gradient's words over the pentagon.
fn linear(c0: u32, c1: u32, o0: f32, o1: f32, ax: f32, ay: f32, bx: f32, by: f32) [10 + pentagon.len]u32 {
    var out: [10 + pentagon.len]u32 = undefined;
    const head = [_]u32{ 5, c0, c1, bits(o0), bits(o1), bits(ax), bits(ay), bits(bx), bits(by), pentagon.len / 2 };
    @memcpy(out[0..head.len], &head);
    for (pentagon, 0..) |x, i| out[head.len + i] = bits(x);
    return out;
}

test "a vertical gradient, worked out once a row, paints as the per-pixel rule does" {
    // Translucent stops, the stop offsets inside the line, and opaque ones.
    const translucent = linear(0x80ff8020, 0x2010a0f0, 0.2, 0.8, 5, 2, 5, 20);
    try std.testing.expect(try paintBoth(&translucent, 0) > 500);
    const opaque_stops = linear(0xff2a3f7a, 0xfff2a65a, 0.0, 1.0, 0, 0, 0, 24);
    try std.testing.expect(try paintBoth(&opaque_stops, 0) > 500);
}

test "a translucent flat brush, one colour at both stops, paints as the per-pixel rule does" {
    // The adapter's flat brush runs left to right; this one runs on a slant,
    // since a one-colour gradient is one colour whatever its direction.
    const flat = linear(0x66d0a040, 0x66d0a040, 0.0, 1.0, 0, 0, 7, 3);
    try std.testing.expect(try paintBoth(&flat, 0) > 500);
    // A gradient too short to have a direction is its first stop's colour.
    const point = linear(0x90103050, 0xff00ff00, 0.0, 1.0, 4, 4, 4, 4);
    try std.testing.expect(try paintBoth(&point, 0) > 500);
    // An unseen colour changes nothing, both ways.
    const unseen = linear(0x00ffffff, 0x00ffffff, 0.0, 1.0, 0, 0, 1, 0);
    try std.testing.expectEqual(0, try paintBoth(&unseen, 0));
}

test "a horizontal gradient, worked out once a column, paints as the per-pixel rule does" {
    // A span's half: translucent at one end, as the adapter makes them, and
    // opaque, with the line running right to left.
    const half = linear(0xc0804020, 0x40f0e0d0, 0.0, 1.0, 3, 0, 20, 0);
    try std.testing.expect(try paintBoth(&half, 0) > 500);
    const opaque_stops = linear(0xff336699, 0xff996633, 0.1, 0.7, 28, 9, 4, 9);
    try std.testing.expect(try paintBoth(&opaque_stops, 0) > 500);
}

test "a round fill, worked out once a column, paints as the per-pixel rule does" {
    const round = withPoints(4, .{ 1, 0x5c6b4a, bits(0.8), pentagon.len / 2 });
    try std.testing.expect(try paintBoth(&round, 0) > 500);
}

/// A radial gradient's words over the pentagon.
fn radial(c0: u32, c1: u32, cx: f32, cy: f32, r: f32) [7 + pentagon.len]u32 {
    return withPoints(7, .{ 4, c0, c1, bits(cx), bits(cy), bits(r), pentagon.len / 2 });
}

/// An elliptical gradient's words over the pentagon.
fn elliptical(c0: u32, c1: u32, o0: f32, o1: f32, u: [2]f32, v: [2]f32) [12 + pentagon.len]u32 {
    return withPoints(12, .{ 6, c0, c1, bits(o0), bits(o1), bits(15), bits(11), bits(u[0]), bits(u[1]), bits(v[0]), bits(v[1]), pentagon.len / 2 });
}

test "a radial gradient, eight pixels at a time, paints as the per-pixel rule does" {
    // A halo as the lamps' are: translucent inside and unseen at its edge,
    // which falls inside the pentagon, so some pixels are past it.
    const halo = radial(0xe0fff6b0, 0x00fff6b0, 16, 12, 10);
    try std.testing.expect(try paintBoth(&halo, 0) > 300);
    // Opaque stops of different colours, as the sun's disc is.
    const disc = radial(0xffffe6a3, 0xffff9d5c, 12, 10, 14);
    try std.testing.expect(try paintBoth(&disc, 0) > 500);
}

test "an elliptical gradient, eight pixels at a time, paints as the per-pixel rule does" {
    const tilted = elliptical(0xf0f0e0c0, 0x307a5030, 0.2, 0.9, .{ 12, 3 }, .{ -2, 8 });
    try std.testing.expect(try paintBoth(&tilted, 0) > 500);
    // Stops out of order take the per-pixel rule, and still paint.
    const reversed = elliptical(0xf0f0e0c0, 0x907a5030, 0.8, 0.3, .{ 12, 3 }, .{ -2, 8 });
    try std.testing.expect(try paintBoth(&reversed, 0) > 500);
    // Axes with no area are one translucent colour, worked out once a row.
    const flat = elliptical(0x80204060, 0xff000000, 0.0, 1.0, .{ 4, 2 }, .{ 8, 4 });
    try std.testing.expect(try paintBoth(&flat, 0) > 500);
}

test "a slanted gradient, eight pixels at a time, and every fill under a roll, paint as the per-pixel rule does" {
    // A slanted gradient's colour changes along a row and down a column.
    const slanted = linear(0xa0ff0000, 0xff0000ff, 0.0, 1.0, 0, 0, 30, 20);
    try std.testing.expect(try paintBoth(&slanted, 0) > 500);
    // A roll turns each row's design coordinates, so no fill is planned.
    const vertical = linear(0x80ff8020, 0x2010a0f0, 0.2, 0.8, 5, 2, 5, 20);
    try std.testing.expect(try paintBoth(&vertical, 0.1) > 500);
    const round = withPoints(4, .{ 1, 0x5c6b4a, bits(0.8), pentagon.len / 2 });
    try std.testing.expect(try paintBoth(&round, -0.1) > 500);
}
