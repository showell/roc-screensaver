//! The Lanterns page's wasm host: the canvas apps' host (web/platform/host.zig,
//! the `canvas_host` module), every export of it, and one export more,
//! computeCode, which web/lanterns_platform/code_pane.js calls after each step
//! to learn what the code pane shows.
//!
//! The answer is a Roc box, which the host keeps until the next call and then
//! hands back to Roc to drop (`roc_release_code`), since the string inside is
//! Roc's to free. computeCode answers where the box's pointer is kept, and the
//! page's glue reads the answer through it, as it reads the dressing.

const canvas_host = @import("canvas_host");

// The canvas apps' exports are this module's too.
comptime {
    _ = canvas_host;
}

pub const panic = canvas_host.panic;

extern fn roc_code(model: ?[*]u8) callconv(.c) ?[*]u8;
extern fn roc_release_code(code: ?[*]u8) callconv(.c) void;

// The last answer, owned until the next call replaces it.
var code_box: ?[*]u8 = null;

pub export fn computeCode() u32 {
    if (code_box != null) roc_release_code(code_box);
    code_box = roc_code(canvas_host.borrowed());
    return @intCast(@intFromPtr(&code_box));
}
