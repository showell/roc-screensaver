//! Runs the keys example (examples/keys/), a canvas app on NativeApp, through
//! the host's step with keys from host/keyboard.zig, as win32.zig's window
//! passes them, and reads the counts back from its frame: a first disc whose
//! radius is one more than the steps the right arrow was held at, then a disc
//! for each Space struck. So a key struck in the host reaches the app's step
//! under lib/Keys.roc's names, and a held or repeated key is not struck again.

const std = @import("std");
const abi = @import("abi.zig");
const keyboard = @import("keyboard.zig");
const Screensaver = @import("screensaver.zig").Screensaver;

const space = keyboard.bitOfVirtualKey(0x20);
const right = keyboard.bitOfVirtualKey(0x27);

/// The keys example's two counts, read from its current frame.
fn counts(s: *Screensaver) struct { spaces_struck: usize, steps_right_held: f32 } {
    const frame = abi.roc_frame(abi.borrow(s.model));
    defer abi.roc_release_frame(frame);
    const shapes = frame.shapes.items();
    for (shapes) |shape| std.debug.assert(shape.tag == .disc);
    return .{ .spaces_struck = shapes.len - 1, .steps_right_held = shapes[0].payload.disc.radius - 1 };
}

test "keys struck and held in the host reach the app's step, and nothing else does" {
    abi.allocator = std.testing.allocator;
    var s = try Screensaver.init(std.testing.allocator);
    var k: keyboard.Keyboard = .{};
    try std.testing.expectEqual(0, counts(&s).spaces_struck);

    // Space struck: pressed at this step only, however long it stays down.
    k.press(space, false);
    s.advance(k.take());
    try std.testing.expectEqual(1, counts(&s).spaces_struck);
    k.press(space, true);
    s.advance(k.take());
    try std.testing.expectEqual(1, counts(&s).spaces_struck);
    try std.testing.expectEqual(0, counts(&s).steps_right_held);

    // The right arrow held over two steps counts at each.
    k.release(space);
    k.press(right, false);
    s.advance(k.take());
    s.advance(k.take());
    try std.testing.expectEqual(2, counts(&s).steps_right_held);
    try std.testing.expectEqual(1, counts(&s).spaces_struck);

    // A tap of Space between two steps is struck all the same, and R, a key
    // the app ignores, counts nothing.
    k.press(keyboard.bitOfVirtualKey('R'), false);
    k.press(space, false);
    k.release(space);
    s.advance(k.take());
    try std.testing.expectEqual(2, counts(&s).spaces_struck);
    try std.testing.expectEqual(3, counts(&s).steps_right_held);

    // A lost focus lets every key go, and Q never reaches the app.
    k.clear();
    k.press(keyboard.bitOfVirtualKey('Q'), false);
    s.advance(k.take());
    s.advance(.none);
    try std.testing.expectEqual(2, counts(&s).spaces_struck);
    try std.testing.expectEqual(3, counts(&s).steps_right_held);

    s.deinit();
    try std.testing.expectEqual(0, abi.live);
}

test "the keyboard: a step's take spends the struck keys, and the window's keys are no app's" {
    var k: keyboard.Keyboard = .{};
    k.press(space, false);
    try std.testing.expectEqual(abi.Keys{ .held = 256, .struck = 256 }, k.take());
    try std.testing.expectEqual(abi.Keys{ .held = 256, .struck = 0 }, k.take());
    k.release(space);
    try std.testing.expectEqual(abi.Keys.none, k.take());
    // Escape and Q close the window; Space and the arrows are Keys.roc's.
    try std.testing.expectEqual(0, keyboard.bitOfVirtualKey(0x1B));
    try std.testing.expectEqual(0, keyboard.bitOfVirtualKey('Q'));
    try std.testing.expectEqual(8, right);
    try std.testing.expectEqual(1, keyboard.bitOfVirtualKey(0x26));
    try std.testing.expectEqual(524288, keyboard.bitOfVirtualKey('J'));
}
