//! Writes a frame's shapes as the draw-command words host/raster.zig walks:
//! for each shape a tag word, its colours and parameters, then, for a
//! polygon, its point count and each point's x and y. A float travels as
//! its bits in a u32. The words for each fill are those of raster.zig's
//! `walk`: 0 solid, 1 round, 3 disc, 4 radial, 5 linear, 6 elliptical.

const std = @import("std");
const abi = @import("abi.zig");

/// The most points raster.zig fills in one polygon. It would draw only the
/// first this many of a longer one, so a longer one stops the host instead.
pub const most_points = 1024;

pub fn write(gpa: std.mem.Allocator, out: *std.ArrayList(u32), shapes: []const abi.Shape) !void {
    for (shapes) |shape| switch (shape.tag) {
        .disc => {
            const d = shape.payload.disc;
            try out.appendSlice(gpa, &.{ 3, d.color, bits(d.center.x), bits(d.center.y), bits(d.radius), bits(d.alpha) });
        },
        .polygon => {
            const p = shape.payload.polygon;
            const points = p.points.items();
            if (points.len > most_points) std.debug.panic("a polygon of {d} points; the rasterizer fills at most {d}", .{ points.len, most_points });
            const n: u32 = @intCast(points.len);
            const fill = p.fill.payload;
            switch (p.fill.tag) {
                .solid => try out.appendSlice(gpa, &.{ 0, fill.solid, n }),
                .round => try out.appendSlice(gpa, &.{ 1, fill.round.color, bits(fill.round.strength), n }),
                .radial => {
                    const r = fill.radial;
                    try out.appendSlice(gpa, &.{ 4, r.inner, r.outer, bits(r.center.x), bits(r.center.y), bits(r.radius), n });
                },
                .linear => {
                    const l = fill.linear;
                    try out.appendSlice(gpa, &.{ 5, l.start.color, l.end.color, bits(l.start.at), bits(l.end.at), bits(l.from.x), bits(l.from.y), bits(l.to.x), bits(l.to.y), n });
                },
                .elliptical => {
                    const e = fill.elliptical;
                    try out.appendSlice(gpa, &.{ 6, e.start.color, e.end.color, bits(e.start.at), bits(e.end.at), bits(e.center.x), bits(e.center.y), bits(e.u.x), bits(e.u.y), bits(e.v.x), bits(e.v.y), n });
                },
            }
            for (points) |pt| try out.appendSlice(gpa, &.{ bits(pt.x), bits(pt.y) });
        },
    };
}

fn bits(x: f32) u32 {
    return @bitCast(x);
}
