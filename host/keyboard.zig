//! The keyboard as a windowed host keeps it between two steps: the keys down
//! now, and those struck since the last step, in lib/Keys.roc's bits, as the
//! page's canvas_app_runner.js keeps them. Each step takes one snapshot, which
//! consumes the struck keys, so a key struck once is pressed at one step only.
//!
//! The Win32 virtual-key codes are mapped here rather than in win32.zig so the
//! mapping is a plain function that the Linux tests run (host/keys_test.zig).

const abi = @import("abi.zig");

pub const Keyboard = struct {
    held: u32 = 0,
    struck: u32 = 0,

    /// A key went down. A repeat, the OS's autorepeat of a key still down,
    /// keeps it held without striking it again. A key the app has no bit
    /// for (a bit of 0) changes nothing.
    pub fn press(k: *Keyboard, bit: u32, repeat: bool) void {
        if (!repeat) k.struck |= bit;
        k.held |= bit;
    }

    /// A key went up. A key struck and let go before the next step stays
    /// struck, so a quick tap is not lost.
    pub fn release(k: *Keyboard, bit: u32) void {
        k.held &= ~bit;
    }

    /// The window lost the focus, and its keys with it, so no key sticks
    /// down that the window will never hear go up.
    pub fn clear(k: *Keyboard) void {
        k.* = .{};
    }

    /// The keys for one step; the struck keys are spent.
    pub fn take(k: *Keyboard) abi.Keys {
        const keys: abi.Keys = .{ .held = k.held, .struck = k.struck };
        k.struck = 0;
        return keys;
    }
};

/// The Keys.roc bit of a Win32 virtual-key code, or 0 for a key the app is
/// never given. Q and Escape are 0: they close the window, so the host keeps
/// them, as roc-apps' native runner keeps Escape out of an app's input.
pub fn bitOfVirtualKey(vk: usize) u32 {
    return switch (vk) {
        0x26 => 1, // VK_UP
        0x28 => 2, // VK_DOWN
        0x25 => 4, // VK_LEFT
        0x27 => 8, // VK_RIGHT
        'W' => 16,
        'A' => 32,
        'S' => 64,
        'D' => 128,
        0x20 => 256, // VK_SPACE
        0x0D => 512, // VK_RETURN
        'P' => 1024,
        'R' => 2048,
        'E' => 8192,
        'C' => 16384,
        '1' => 32768,
        '2' => 65536,
        '3' => 131072,
        '4' => 262144,
        'J' => 524288,
        else => 0,
    };
}
