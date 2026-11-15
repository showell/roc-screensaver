//! The frame-time bench: `bench` runs the app through one whole cycle and
//! says how long each frame takes, phase by phase, against the budget of
//! the app's frame rate. It answers whether the Windows screensaver keeps
//! up, measured on Linux, where it can be run.
//!
//! Each step is timed in the order host/win32.zig's `produce` and `worker`
//! do the work, and at the size win32.zig rasterizes in every mode: the
//! app's size times raster.SS, which GDI then stretches to the window or
//! the monitor. That stretch, and GDI's copy to the screen, are Windows'
//! own and are not timed here. The phases:
//!   roc     the Roc: the step to the next model (`roc_step`), and the
//!           frame of a model (`roc_frame`, then `roc_release_frame`)
//!   convert the frame's shapes written as draw words (host/words.zig), and
//!           those words copied into a ring slot, as `produce` copies them
//!   raster  raster.render into the supersampled buffer, on one thread,
//!           in its three parts: the sky and grass, the sun, and the shapes
//!
//! Then the pipeline: win32.zig's own split, the main thread doing the Roc
//! and the conversion for a ring of four slots while two worker threads
//! each rasterize whole frames, unpaced. Its numbers are the time between
//! one frame finishing and the next, in order, which is what holds or
//! drops the frame rate on Windows. An idle worker yields here where
//! win32.zig's sleeps a millisecond.
//!
//! Both passes step through the whole cycle and draw every sixth step
//! (`stride`). `bench` takes no arguments. The cycle's length is lanterns',
//! 1350 steps (screensavers/lanterns/README.md, "The cycle"); another app is
//! timed over the same count of steps.

const std = @import("std");
const abi = @import("abi.zig");
const words = @import("words.zig");
const raster = @import("raster.zig");
const screensaver = @import("screensaver.zig");

const cycle_steps = 1350;
/// Every step is stepped, and every `stride`th drawn and rasterized: a
/// frame here is about 0.1 s of raster on one thread, so the whole cycle's
/// would take minutes. Neighbouring frames differ little.
const stride = 6;
const sampled = cycle_steps / stride;
const ring = 4;
/// A shape's fill by its first word, as host/words.zig writes it.
const fill_names = [_][]const u8{ "solid", "round", "(none)", "disc", "radial", "linear", "elliptical" };
const workers_count = 2;

const Phases = struct {
    /// roc_frame and roc_release_frame of the sampled step's model.
    frame: u64,
    convert: u64,
    background: u64,
    sun: u64,
    shapes: u64,

    fn rasterized(p: Phases) u64 {
        return p.background + p.sun + p.shapes;
    }
    fn all(p: Phases) u64 {
        return p.frame + p.convert + p.rasterized();
    }
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = std.heap.smp_allocator;
    var s = try screensaver.Screensaver.init(gpa);
    defer s.deinit();
    const sw = s.width * raster.SS;
    const sh = s.height * raster.SS;
    const budget_ns: u64 = 1_000_000_000 / @max(1, s.fps);

    var phases: [sampled]Phases = undefined;
    var steps: [cycle_steps]u64 = undefined;
    var slot_words: std.ArrayList(u32) = .empty;
    defer slot_words.deinit(gpa);
    const big = raster.Fb{ .px = s.big, .w = sw, .h = sh };
    var one: std.ArrayList(u32) = .empty;
    defer one.deinit(gpa);
    var by_fill: [fill_names.len]struct { ns: u64 = 0, count: u64 = 0 } = @splat(.{});

    for (&phases, 0..) |*p, k| {
        // A line every 30 frames, so a slow run says where it is.
        if (k % 30 == 0 and k > 0) {
            const q = phases[k - 1];
            std.debug.print("bench: step {d}, its frame {d:.1} ms: roc {d:.1}, convert {d:.1}, raster {d:.1}\n", .{ (k - 1) * stride, ms(q.all()), ms(q.frame), ms(q.convert), ms(q.rasterized()) });
        }
        const t0 = now(io);
        // Screensaver.draw, cut where the Roc ends and the conversion begins.
        const frame = abi.roc_frame(abi.borrow(s.model));
        const t1 = now(io);
        s.words.clearRetainingCapacity();
        try words.write(gpa, &s.words, frame.shapes.items());
        slot_words.clearRetainingCapacity();
        try slot_words.appendSlice(gpa, s.words.items);
        const t2 = now(io);
        const bg = frame.background;
        const sun: raster.SunPos = switch (bg.sun.tag) {
            .hidden => .{ .visible = false, .x = 0, .y = 0, .scale = 0 },
            .shown => .{ .visible = true, .x = bg.sun.payload.shown.x, .y = bg.sun.payload.shown.y, .scale = bg.sun.payload.shown.scale },
        };
        const t3 = now(io);
        // raster.render's three parts, each timed. The shapes are walked
        // one at a time, in order as render walks them, so each one's time
        // is charged to its fill.
        const roll = raster.rollFor(big, bg.roll);
        raster.drawBackground(big, roll, bg.sky_top, bg.sky_horizon);
        const t4 = now(io);
        if (sun.visible) raster.drawSun(big, roll, sun);
        const t5 = now(io);
        var shapes_ns: u64 = 0;
        for (0..frame.shapes.items().len) |i| {
            one.clearRetainingCapacity();
            try words.write(gpa, &one, frame.shapes.items()[i .. i + 1]);
            const a = now(io);
            raster.walk(big, roll, one.items);
            const took = now(io) - a;
            shapes_ns += took;
            by_fill[one.items[0]].ns += took;
            by_fill[one.items[0]].count += 1;
        }
        const t6 = now(io);
        abi.roc_release_frame(frame);
        const t7 = now(io);
        p.* = .{ .frame = (t1 - t0) + (t7 - t6), .convert = t2 - t1, .background = t4 - t3, .sun = t5 - t4, .shapes = shapes_ns };
        for (0..stride) |j| {
            const a = now(io);
            s.advance(.none);
            steps[k * stride + j] = now(io) - a;
        }
    }

    std.debug.print("bench: {d} steps of {d} by {d}, every {d}th of them drawn, rasterized at {d} by {d}; the budget {d:.1} ms a frame ({d} fps)\n", .{ cycle_steps, s.width, s.height, stride, sw, sh, ms(budget_ns), s.fps });
    report("roc step, every step", &steps, budget_ns);
    var column: [sampled]u64 = undefined;
    inline for (.{
        .{ "frame", "roc frame" },
        .{ "convert", "convert" },
        .{ "background", "raster, the sky and grass" },
        .{ "sun", "raster, the sun" },
        .{ "shapes", "raster, the shapes" },
    }) |field| {
        for (phases, 0..) |p, i| column[i] = @field(p, field[0]);
        report(field[1], &column, budget_ns);
    }
    for (phases, 0..) |p, i| column[i] = p.rasterized();
    report("raster, all three", &column, budget_ns);
    // A frame's whole cost on one thread: its frame, its conversion, its raster and one step.
    for (phases, 0..) |p, i| column[i] = p.all() + steps[i * stride];
    report("one thread, the whole frame", &column, budget_ns);

    var shapes_all: u64 = 0;
    for (by_fill) |f| shapes_all += f.ns;
    std.debug.print("bench: the shapes' raster by fill, over the {d} frames:", .{sampled});
    for (by_fill, fill_names) |f, name| {
        if (f.count == 0) continue;
        std.debug.print(" {s} {d}% ({d:.1} ms a frame, {d} shapes a frame);", .{ name, f.ns * 100 / @max(1, shapes_all), ms(f.ns / sampled), f.count / sampled });
    }
    std.debug.print("\n", .{});

    var order: [sampled]usize = undefined;
    for (&order, 0..) |*o, i| o.* = i;
    std.mem.sort(usize, &order, &column, struct {
        fn slower(c: *const [sampled]u64, a: usize, b: usize) bool {
            return c[a] > c[b];
        }
    }.slower);
    std.debug.print("bench: the slowest frames:\n", .{});
    for (order[0..6]) |i| {
        const p = phases[i];
        std.debug.print("bench:   step {d}: {d:.1} ms; roc {d:.1}, convert {d:.1}, background {d:.1}, sun {d:.1}, shapes {d:.1}\n", .{ i * stride, ms(column[i]), ms(p.frame + steps[i * stride]), ms(p.convert), ms(p.background), ms(p.sun), ms(p.shapes) });
    }
    for (spans) |span| {
        var worst: u64 = 0;
        var at: usize = 0;
        var sum: u64 = 0;
        var n: u64 = 0;
        for (column, 0..) |c, i| {
            const step = i * stride;
            if (step < span.from or step >= span.to) continue;
            sum += c;
            n += 1;
            if (c > worst) {
                worst = c;
                at = step;
            }
        }
        std.debug.print("bench: {s} (steps {d} to {d}): mean {d:.1} ms, worst {d:.1} ms at step {d}\n", .{ span.name, span.from, span.to - 1, ms(sum / @max(1, n)), ms(worst), at });
    }

    try pipeline(io, gpa, &s, sw, sh, budget_ns);
}

/// The stretches of lanterns' cycle, by its README: dawn until the plane
/// comes in, the plane's crossing, the empty sky, and the jets' pass.
const Span = struct { name: []const u8, from: usize, to: usize };
const spans = [_]Span{
    .{ .name = "dawn", .from = 0, .to = 400 },
    .{ .name = "the plane", .from = 400, .to = 1175 },
    .{ .name = "the empty sky", .from = 1175, .to = 1276 },
    .{ .name = "the jets", .from = 1276, .to = 1340 },
    .{ .name = "the closing perch", .from = 1340, .to = cycle_steps },
};

const Slot = struct {
    px: []u32,
    words: std.ArrayList(u32) = .empty,
    drawn: screensaver.Drawn = undefined,
    state: std.atomic.Value(enum(u8) { empty, queued, rendering, ready }) = .init(.empty),
};

const Pipeline = struct {
    slots: [ring]Slot,
    quit: std.atomic.Value(bool) = .init(false),
    sw: usize,
    sh: usize,
};

fn worker(p: *Pipeline) void {
    while (!p.quit.load(.acquire)) {
        var claimed = false;
        for (&p.slots) |*s| {
            if (s.state.cmpxchgStrong(.queued, .rendering, .acquire, .monotonic) == null) {
                const d = s.drawn;
                raster.render(.{ .px = s.px, .w = p.sw, .h = p.sh }, s.words.items, d.roll, d.sky_top, d.sky_horizon, d.sun);
                s.state.store(.ready, .release);
                claimed = true;
                break;
            }
        }
        if (!claimed) std.Thread.yield() catch {};
    }
}

/// win32.zig's split, from a fresh model: the main thread fills the ring
/// and takes each frame back in order, two workers rasterize.
fn pipeline(io: std.Io, gpa: std.mem.Allocator, s: *screensaver.Screensaver, sw: usize, sh: usize, budget_ns: u64) !void {
    abi.roc_release_model(s.model);
    s.model = abi.roc_init();
    s.frame_number = 0;
    var p: Pipeline = .{ .slots = undefined, .sw = sw, .sh = sh };
    for (&p.slots) |*slot| slot.* = .{ .px = try gpa.alloc(u32, sw * sh) };
    defer for (&p.slots) |*slot| {
        gpa.free(slot.px);
        slot.words.deinit(gpa);
    };
    var threads: [workers_count]std.Thread = undefined;
    for (&threads) |*t| t.* = try std.Thread.spawn(.{}, worker, .{&p});

    var gaps: [sampled]u64 = undefined;
    var produced: usize = 0;
    var shown: usize = 0;
    const start = now(io);
    var last = start;
    while (shown < sampled) {
        while (produced < sampled) {
            const slot = &p.slots[produced % ring];
            if (slot.state.load(.acquire) != .empty) break;
            const d = try s.draw();
            slot.words.clearRetainingCapacity();
            try slot.words.appendSlice(gpa, d.words);
            slot.drawn = d;
            for (0..stride) |_| s.advance(.none);
            slot.state.store(.queued, .release);
            produced += 1;
        }
        const slot = &p.slots[shown % ring];
        if (slot.state.load(.acquire) != .ready) {
            std.Thread.yield() catch {};
            continue;
        }
        const t = now(io);
        gaps[shown] = t - last;
        last = t;
        slot.state.store(.empty, .release);
        shown += 1;
    }
    p.quit.store(true, .release);
    for (&threads) |*t| t.join();

    const total = last - start;
    std.debug.print("bench: the pipeline, {d} workers and {d} slots: {d} frames in {d:.0} ms, {d:.1} frames a second unpaced, a frame every {d:.1} ms\n", .{ workers_count, ring, sampled, ms(total), @as(f64, sampled) * 1000.0 / ms(total), ms(total / sampled) });
    // The first frame waits on a cold ring, so the gaps are the frames after it.
    // Two workers finish frames in pairs, so the gaps come short and long by
    // turns: the frame rate is the mean above, and the worst gap the stall.
    report("the pipeline, frame to frame", gaps[1..], budget_ns);
}

fn report(name: []const u8, column: []const u64, budget_ns: u64) void {
    var sorted: [cycle_steps]u64 = undefined;
    const v = sorted[0..column.len];
    @memcpy(v, column);
    std.mem.sort(u64, v, {}, std.sort.asc(u64));
    var over: usize = 0;
    for (v) |x| {
        if (x > budget_ns) over += 1;
    }
    std.debug.print("bench: {s}: median {d:.2} ms, p95 {d:.2} ms, worst {d:.2} ms; {d} of {d} over the budget\n", .{ name, ms(v[v.len / 2]), ms(v[v.len * 95 / 100]), ms(v[v.len - 1]), over, v.len });
}

fn now(io: std.Io) u64 {
    return @intCast(std.Io.Timestamp.now(io, .awake).nanoseconds);
}

fn ms(ns: u64) f64 {
    return @as(f64, @floatFromInt(ns)) / 1_000_000.0;
}
