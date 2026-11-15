//! The seam between the host and the Roc archive (an app built on
//! platform/). It declares the app's entries, which platform/main.roc
//! provides, mirrors the frame they answer (platform/Frame.roc) as extern
//! structs, and exports the runtime functions the archive calls: the
//! allocator, `roc_crashed`, `roc_dbg` and `roc_expect_failed`.
//!
//! Roc lays a record out by alignment, then by field name, so the fields
//! below are in that order, not the source's. A tag union is its payload,
//! then a one-byte tag at the end, its tags numbered alphabetically.
//! host/abi_test.zig holds every type here to what `roc glue` makes of the
//! platform (host/glue/platform_abi.zig), field by field and tag by tag.
//!
//! Every allocation goes through `allocator`, a real allocator, because the
//! model lives across frames and Roc frees what it no longer holds. `live`
//! counts what is allocated and not yet freed, so a test can show that a
//! released frame and model leave nothing behind.

const std = @import("std");

/// A Roc list as glue lays one out: the elements' pointer, the length, then
/// the capacity (or, for a slice, the allocation's pointer).
pub fn List(comptime T: type) type {
    return extern struct {
        elements: ?[*]const T,
        length: usize,
        capacity_or_alloc_ptr: usize,

        pub fn items(l: @This()) []const T {
            const p = l.elements orelse return &.{};
            return p[0..l.length];
        }
    };
}

pub const Point = extern struct { x: f32, y: f32 };

pub const Stop = extern struct { at: f32, color: u32 };

pub const SunShown = extern struct { scale: f32, x: f32, y: f32 };

pub const SunTag = enum(u8) { hidden, shown };

pub const Sun = extern struct {
    payload: extern union { hidden: [0]u8, shown: SunShown },
    tag: SunTag,
};

pub const Background = extern struct {
    roll: f32,
    sky_horizon: u32,
    sky_top: u32,
    sun: Sun,
};

pub const Disc = extern struct { alpha: f32, center: Point, color: u32, radius: f32 };

pub const Round = extern struct { color: u32, strength: f32 };

pub const Radial = extern struct { center: Point, inner: u32, outer: u32, radius: f32 };

pub const Linear = extern struct { end: Stop, from: Point, start: Stop, to: Point };

pub const Elliptical = extern struct { center: Point, end: Stop, start: Stop, u: Point, v: Point };

pub const FillTag = enum(u8) { elliptical, linear, radial, round, solid };

pub const Fill = extern struct {
    payload: extern union {
        elliptical: Elliptical,
        linear: Linear,
        radial: Radial,
        round: Round,
        solid: u32,
    },
    tag: FillTag,
};

pub const Polygon = extern struct { points: List(Point), fill: Fill };

pub const ShapeTag = enum(u8) { disc, polygon };

pub const Shape = extern struct {
    payload: extern union { disc: Disc, polygon: Polygon },
    tag: ShapeTag,
};

pub const Frame = extern struct { shapes: List(Shape), background: Background };

/// The app's model, boxed: a pointer to the value, its refcount the word
/// before it.
pub const Model = ?*anyopaque;

pub extern fn roc_init() callconv(.c) Model;
pub extern fn roc_step(model: Model, frame_number: u64) callconv(.c) Model;
pub extern fn roc_frame(model: Model) callconv(.c) Frame;
pub extern fn roc_release_frame(frame: Frame) callconv(.c) void;
pub extern fn roc_release_model(model: Model) callconv(.c) void;
pub extern fn roc_width() callconv(.c) u32;
pub extern fn roc_height() callconv(.c) u32;
pub extern fn roc_fps() callconv(.c) u32;

/// Adds a reference to the boxed model, for a call that keeps nothing:
/// Roc's drop at the end of the call takes it away. A refcount of zero
/// marks static data, which is never counted.
pub fn borrow(model: Model) Model {
    const data: [*]u8 = @ptrCast(model orelse @panic("borrow: the model is a null box"));
    const rc: *isize = @ptrCast(@alignCast(data - @sizeOf(isize)));
    if (rc.* != 0) rc.* += 1;
    return model;
}

// The runtime.

pub var allocator: std.mem.Allocator = std.heap.smp_allocator;

/// How many allocations Roc holds now.
pub var live: usize = 0;

comptime {
    @export(&roc_alloc, .{ .name = "roc_alloc" });
    @export(&roc_realloc, .{ .name = "roc_realloc" });
    @export(&roc_dealloc, .{ .name = "roc_dealloc" });
    @export(&roc_crashed, .{ .name = "roc_crashed" });
    @export(&roc_dbg, .{ .name = "roc_dbg" });
    @export(&roc_expect_failed, .{ .name = "roc_expect_failed" });
}

/// Each allocation's length sits in a header before what Roc is given, so
/// `roc_realloc` and `roc_dealloc`, which are not told it, can find it. The
/// header is 16 bytes because Roc asks for at most 16's alignment.
const header = 16;

fn whole(ptr: *anyopaque) []align(header) u8 {
    const base: [*]align(header) u8 = @alignCast(@as([*]u8, @ptrCast(ptr)) - header);
    const len = std.mem.readInt(usize, base[0..@sizeOf(usize)], .little);
    return base[0 .. header + len];
}

fn roc_alloc(len: usize, alignment: usize) callconv(.c) *anyopaque {
    if (alignment > header) std.debug.panic("roc_alloc: an alignment of {d}, past the header's {d}", .{ alignment, header });
    const got = allocator.alignedAlloc(u8, .fromByteUnits(header), header + len) catch
        std.debug.panic("roc_alloc: out of memory ({d} bytes)", .{len});
    std.mem.writeInt(usize, got[0..@sizeOf(usize)], len, .little);
    live += 1;
    return got.ptr + header;
}

fn roc_realloc(ptr: *anyopaque, len: usize, alignment: usize) callconv(.c) *anyopaque {
    const old = whole(ptr);
    const new: [*]u8 = @ptrCast(roc_alloc(len, alignment));
    const kept = @min(old.len - header, len);
    @memcpy(new[0..kept], old[header..][0..kept]);
    roc_dealloc(ptr, alignment);
    return new;
}

fn roc_dealloc(ptr: *anyopaque, alignment: usize) callconv(.c) void {
    _ = alignment;
    allocator.free(whole(ptr));
    live -= 1;
}

fn roc_crashed(bytes: [*]const u8, len: usize) callconv(.c) void {
    std.debug.panic("roc crashed: {s}", .{bytes[0..len]});
}

fn roc_dbg(bytes: [*]const u8, len: usize) callconv(.c) void {
    std.debug.print("roc dbg: {s}\n", .{bytes[0..len]});
}

fn roc_expect_failed(bytes: [*]const u8, len: usize) callconv(.c) void {
    std.debug.panic("roc: an inline expect failed: {s}", .{bytes[0..len]});
}
