//! The Windows window and the .scr screensaver for the platform. Each frame comes from the Roc
//! app through screensaver.zig, raster.zig fills it into pixels, and this file shows them in a
//! Win32 window and pumps the message queue. x11.zig is its Linux sibling.
//!
//! raster.zig's pixel, 0x00RRGGBB in a u32, is exactly a 32-bit BI_RGB DIB's DWORD, so the
//! buffer goes to GDI with no conversion. The DIB's height is negative so that row 0 is the top,
//! as in the buffer.
//!
//! GDI gets the supersampled render (the app's size times raster.SS) and scales it to the window
//! with the HALFTONE stretch mode, which keeps the anti-aliasing at any window size. It scales
//! into an off-screen bitmap and then copies that to the window in one BitBlt, because the
//! compositor otherwise catches a half-written frame and shows it as tearing.
//!
//! The frame is nearly all software raster, so it is split across threads. The main thread is
//! the only one that calls Roc: it steps the app, takes its frame's draw words and background
//! into a ring slot, and later shows finished slots in order at the app's frame rate. Two worker
//! threads each claim a queued slot and rasterize it into that slot's pixels. A slot belongs to
//! one thread at a time, so its atomic `state` is the only shared word: main publishes a slot as
//! queued, a worker claims it with a compare-and-swap, and publishes it as ready when its pixels
//! are done. Idle workers Sleep(1).
//!
//! Windows starts a .scr with a flag that picks its mode, which parseMode reads:
//!   /s          fullscreen: a borderless topmost popup over the primary monitor, the cursor
//!               hidden, and any key, click, wheel or real mouse move quits.
//!   /p <hwnd>   the preview inside the screen saver settings dialog, until that window closes.
//!   /c[:<hwnd>] the settings: there are none, so a message box says so.
//!   (no args)   a window at the app's size (Space pauses, Q or Esc quits), for development;
//!               the settings panel never starts a .scr without a flag.
//!   --headless=<N>  N frames with no window, then the last frame's checksum, for CI.
//! Fullscreen stretches the app's frame to the monitor's shape.
//!
//! std.os.windows has no user32 or gdi32, so those calls are declared below, which is what lets
//! `zig build -Dwindows` build this without a Windows SDK.
//!
//! This file was copied from angry-gopher's games/driving/native/ on 2026-11-15; angry-gopher's
//! copy draws the older zig Safari.

const std = @import("std");
const raster = @import("raster.zig");
const screensaver = @import("screensaver.zig");
const w = std.os.windows;

// --- base types (aliases into std.os.windows + the two the stdlib omits) ---
const BOOL = w.BOOL;
const HWND = w.HWND;
const HINSTANCE = w.HINSTANCE;
const HDC = w.HDC;
const HMENU = w.HMENU;
const HICON = w.HICON;
const HCURSOR = w.HCURSOR;
const HBRUSH = w.HBRUSH;
const UINT = w.UINT;
const DWORD = w.DWORD;
const WORD = w.WORD;
const LONG = w.LONG;
const ATOM = w.ATOM;
const LPVOID = w.LPVOID;
const WCHAR = w.WCHAR;
const WPARAM = usize; // UINT_PTR
const LPARAM = isize; // LONG_PTR
const LRESULT = isize; // LONG_PTR

const HBITMAP = *opaque {};
const HGDIOBJ = *anyopaque;

// --- Win32 structs (extern layout) ---
const POINT = extern struct { x: LONG, y: LONG };
const RECT = extern struct { left: LONG, top: LONG, right: LONG, bottom: LONG };

const WNDPROC = *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.winapi) LRESULT;
const WNDCLASSW = extern struct {
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: c_int = 0,
    cbWndExtra: c_int = 0,
    hInstance: ?HINSTANCE,
    hIcon: ?HICON = null,
    hCursor: ?HCURSOR = null,
    hbrBackground: ?HBRUSH = null,
    lpszMenuName: ?[*:0]const WCHAR = null,
    lpszClassName: [*:0]const WCHAR,
};

const MSG = extern struct {
    hwnd: ?HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
};

const BITMAPINFOHEADER = extern struct {
    biSize: DWORD,
    biWidth: LONG,
    biHeight: LONG,
    biPlanes: WORD,
    biBitCount: WORD,
    biCompression: DWORD,
    biSizeImage: DWORD,
    biXPelsPerMeter: LONG,
    biYPelsPerMeter: LONG,
    biClrUsed: DWORD,
    biClrImportant: DWORD,
};

// --- Win32 constants ---
const CS_VREDRAW: UINT = 0x0001;
const CS_HREDRAW: UINT = 0x0002;
const CS_OWNDC: UINT = 0x0020;
const WS_OVERLAPPEDWINDOW: DWORD = 0x00CF0000;
const WS_POPUP: DWORD = 0x80000000; // fullscreen: no border/caption
const WS_CHILD: DWORD = 0x40000000; // preview: hosted in the settings dialog's monitor
const WS_VISIBLE: DWORD = 0x10000000;
const WS_EX_TOPMOST: DWORD = 0x00000008; // fullscreen sits above everything
const CW_USEDEFAULT: c_int = @bitCast(@as(u32, 0x80000000));
const SW_SHOW: c_int = 5;
const SM_CXSCREEN: c_int = 0; // primary monitor width/height (GetSystemMetrics)
const SM_CYSCREEN: c_int = 1;
const MB_OK: UINT = 0;
const PM_REMOVE: UINT = 0x0001;
const WM_DESTROY: UINT = 0x0002;
const WM_CLOSE: UINT = 0x0010;
const WM_KEYDOWN: UINT = 0x0100;
const WM_SYSKEYDOWN: UINT = 0x0104; // Alt+key etc. — also quits in fullscreen
const WM_MOUSEMOVE: UINT = 0x0200;
const WM_LBUTTONDOWN: UINT = 0x0201;
const WM_RBUTTONDOWN: UINT = 0x0204;
const WM_MBUTTONDOWN: UINT = 0x0207;
const WM_MOUSEWHEEL: UINT = 0x020A;
const WM_QUIT: UINT = 0x0012;
const VK_ESCAPE: WPARAM = 0x1B;
const VK_SPACE: WPARAM = 0x20;
const VK_Q: WPARAM = 0x51;
const SRCCOPY: DWORD = 0x00CC0020;
const DIB_RGB_COLORS: UINT = 0;
const BI_RGB: DWORD = 0;
const HALFTONE: c_int = 4; // high-quality (bilinear-ish) stretch; needs SetBrushOrgEx after
const IDC_ARROW: usize = 32512;

// --- extern Win32 functions (no SDK: declared against the system import libs) ---
extern "user32" fn RegisterClassW(*const WNDCLASSW) callconv(.winapi) ATOM;
extern "user32" fn CreateWindowExW(DWORD, [*:0]const WCHAR, [*:0]const WCHAR, DWORD, c_int, c_int, c_int, c_int, ?HWND, ?HMENU, ?HINSTANCE, ?LPVOID) callconv(.winapi) ?HWND;
extern "user32" fn DefWindowProcW(HWND, UINT, WPARAM, LPARAM) callconv(.winapi) LRESULT;
extern "user32" fn ShowWindow(HWND, c_int) callconv(.winapi) BOOL;
extern "user32" fn DestroyWindow(HWND) callconv(.winapi) BOOL;
extern "user32" fn PeekMessageW(*MSG, ?HWND, UINT, UINT, UINT) callconv(.winapi) BOOL;
extern "user32" fn TranslateMessage(*const MSG) callconv(.winapi) BOOL;
extern "user32" fn DispatchMessageW(*const MSG) callconv(.winapi) LRESULT;
extern "user32" fn PostQuitMessage(c_int) callconv(.winapi) void;
extern "user32" fn GetClientRect(HWND, *RECT) callconv(.winapi) BOOL;
extern "user32" fn AdjustWindowRect(*RECT, DWORD, BOOL) callconv(.winapi) BOOL;
extern "user32" fn GetDC(?HWND) callconv(.winapi) ?HDC;
extern "user32" fn LoadCursorW(?HINSTANCE, usize) callconv(.winapi) ?HCURSOR;
extern "user32" fn GetSystemMetrics(c_int) callconv(.winapi) c_int;
extern "user32" fn ShowCursor(BOOL) callconv(.winapi) c_int;
extern "user32" fn IsWindow(?HWND) callconv(.winapi) BOOL;
extern "user32" fn MessageBoxW(?HWND, [*:0]const WCHAR, [*:0]const WCHAR, UINT) callconv(.winapi) c_int;
extern "kernel32" fn GetModuleHandleW(?[*:0]const WCHAR) callconv(.winapi) ?HINSTANCE;
extern "kernel32" fn GetCommandLineW() callconv(.winapi) [*:0]const u16;
extern "kernel32" fn Sleep(DWORD) callconv(.winapi) void;
extern "kernel32" fn QueryPerformanceCounter(*i64) callconv(.winapi) BOOL;
extern "kernel32" fn QueryPerformanceFrequency(*i64) callconv(.winapi) BOOL;
extern "kernel32" fn GetStdHandle(DWORD) callconv(.winapi) ?w.HANDLE;
extern "kernel32" fn AttachConsole(DWORD) callconv(.winapi) BOOL;
extern "kernel32" fn WriteFile(w.HANDLE, [*]const u8, DWORD, ?*DWORD, ?*anyopaque) callconv(.winapi) BOOL;
extern "kernel32" fn ExitProcess(UINT) callconv(.winapi) noreturn;
extern "gdi32" fn StretchDIBits(HDC, c_int, c_int, c_int, c_int, c_int, c_int, c_int, c_int, *const anyopaque, *const BITMAPINFOHEADER, UINT, DWORD) callconv(.winapi) c_int;
extern "gdi32" fn SetStretchBltMode(HDC, c_int) callconv(.winapi) c_int;
extern "gdi32" fn SetBrushOrgEx(HDC, c_int, c_int, ?*POINT) callconv(.winapi) BOOL;
extern "gdi32" fn CreateCompatibleDC(?HDC) callconv(.winapi) ?HDC;
extern "gdi32" fn DeleteDC(HDC) callconv(.winapi) BOOL;
extern "gdi32" fn CreateCompatibleBitmap(HDC, c_int, c_int) callconv(.winapi) ?HBITMAP;
extern "gdi32" fn SelectObject(HDC, HGDIOBJ) callconv(.winapi) ?HGDIOBJ;
extern "gdi32" fn DeleteObject(HGDIOBJ) callconv(.winapi) BOOL;
extern "gdi32" fn BitBlt(HDC, c_int, c_int, c_int, c_int, HDC, c_int, c_int, DWORD) callconv(.winapi) BOOL;

// The frame's geometry is the app's `size`, read once from the Roc by `setUp`: the dev window's
// client area is that size, and each slot's render is that size times raster.SS, the
// supersampled image GDI resamples from.
var g_w: c_int = 0;
var g_h: c_int = 0;
var g_sw: usize = 0;
var g_sh: usize = 0;
var g_frame_ms: i64 = 0; // the app's fps as a display budget
var g_bmih: BITMAPINFOHEADER = undefined; // a top-down 32-bit BI_RGB DIB over a slot's render

// The Roc app, held and stepped on the main thread alone: the model is not shared across threads.
var g_saver: screensaver.Screensaver = undefined;
const gpa = std.heap.smp_allocator;

// --- the frame-parallel pipeline ---
const NUM_WORKERS = 2; // raster workers; 2 clears 60 fps and leaves cores for blit + OS (measured)
const RING = 4; // frame slots in flight: 2 rendering + 1 displaying + 1 free to produce into

// A slot moves empty → queued (main filled it) → rendering (a worker claimed it) → ready (worker
// done) → empty (main displayed it). `state` is the only word shared between threads; the atomic
// acquire/release on it publishes each phase's buffer writes to the next owner (see the header).
const SlotState = enum(u8) { empty, queued, rendering, ready };
const Slot = struct {
    px: []u32 = &.{}, // this frame's supersampled render (a worker fills it)
    words: std.ArrayList(u32) = .empty, // this frame's draw-command snapshot (main copies it in)
    tilt: f32 = 0,
    top: u32 = 0,
    horizon: u32 = 0,
    sun: raster.SunPos = .{ .visible = false, .x = 0, .y = 0, .scale = 0 },
    state: std.atomic.Value(SlotState) = .init(.empty),
};

var slots: [RING]Slot = @splat(.{});
var g_quit = std.atomic.Value(bool).init(false); // tells the workers to exit
var g_running: bool = true; // main loop (main thread only; set by the WndProc)
var g_auto: bool = true; // SPACE pause: main stops producing + displaying (freeze)

// which .scr mode we're in — set once by parseMode() before the window is created (main thread only).
// `headless` is no .scr mode: `--headless=<N>` draws N frames through the pipeline with no window
// and prints the last one's checksum, so CI can see the .exe link, load and draw.
const Mode = enum { windowed, fullscreen, preview, config, headless };
var g_mode: Mode = .windowed;
var g_headless_frames: usize = 0;
var g_preview_parent: ?HWND = null; // /p mode: the settings-dialog monitor we're a child of
// fullscreen exit-on-mouse-move: ignore the spurious first move; quit once it travels past this.
var g_mouse_seen: bool = false;
var g_mouse_x: LONG = 0;
var g_mouse_y: LONG = 0;
const MOUSE_EXIT_PX: LONG = 8;

// double-buffer state (main thread only): an off-screen DC we scale into, its client-sized
// bitmap, and the size that bitmap is built for (rebuilt on resize). See PRESENTATION above.
var g_memdc: ?HDC = null;
var g_bmp: ?HBITMAP = null;
var g_bmp_w: c_int = 0;
var g_bmp_h: c_int = 0;

// a worker: claim any queued slot (CAS, so two workers never take the same one), rasterize it into
// its own buffer, mark it ready. When there's nothing queued, briefly poll. Repeat until quit.
fn worker() void {
    while (!g_quit.load(.acquire)) {
        const claimed: ?usize = blk: {
            for (&slots, 0..) |*s, i| {
                if (s.state.cmpxchgStrong(.queued, .rendering, .acquire, .monotonic) == null) break :blk i;
            }
            break :blk null;
        };
        if (claimed) |i| {
            const s = &slots[i]; // sole owner of this slot's buffers until we publish .ready
            raster.render(.{ .px = s.px, .w = g_sw, .h = g_sh }, s.words.items, s.tilt, s.top, s.horizon, s.sun);
            s.state.store(.ready, .release);
        } else {
            Sleep(1); // ring full or drained — negligible against the 60 fps budget
        }
    }
}

// fullscreen only: any key/click/wheel quits, and a real mouse move (past the first spurious one,
// far enough to be intentional) quits. Windowed/preview never call this.
fn exitOnInput(hwnd: HWND, msg: UINT, lParam: LPARAM) void {
    if (msg == WM_MOUSEMOVE) {
        const lp: usize = @bitCast(lParam);
        const x: LONG = @intCast(@as(i16, @bitCast(@as(u16, @truncate(lp))))); // GET_X_LPARAM (signed)
        const y: LONG = @intCast(@as(i16, @bitCast(@as(u16, @truncate(lp >> 16)))));
        if (!g_mouse_seen) {
            g_mouse_x = x;
            g_mouse_y = y;
            g_mouse_seen = true;
            return; // the first move is the OS positioning the cursor — not the user
        }
        if (@abs(x - g_mouse_x) > MOUSE_EXIT_PX or @abs(y - g_mouse_y) > MOUSE_EXIT_PX) _ = DestroyWindow(hwnd);
        return;
    }
    _ = DestroyWindow(hwnd); // any click or wheel
}

fn wndProc(hwnd: HWND, msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT {
    switch (msg) {
        WM_CLOSE => {
            _ = DestroyWindow(hwnd);
            return 0;
        },
        WM_DESTROY => {
            g_running = false;
            PostQuitMessage(0);
            return 0;
        },
        WM_KEYDOWN, WM_SYSKEYDOWN => {
            switch (g_mode) {
                .fullscreen => _ = DestroyWindow(hwnd), // any key ends the screensaver
                .windowed => switch (wParam) {
                    VK_SPACE => g_auto = !g_auto,
                    VK_ESCAPE, VK_Q => _ = DestroyWindow(hwnd),
                    else => {},
                },
                .preview, .config, .headless => {}, // preview ignores input; config and headless have no window
            }
            return 0;
        },
        WM_MOUSEMOVE, WM_LBUTTONDOWN, WM_RBUTTONDOWN, WM_MBUTTONDOWN, WM_MOUSEWHEEL => {
            if (g_mode == .fullscreen) {
                exitOnInput(hwnd, msg, lParam);
                return 0;
            }
            return DefWindowProcW(hwnd, msg, wParam, lParam);
        },
        else => return DefWindowProcW(hwnd, msg, wParam, lParam),
    }
}

fn isSpaceW(c: u16) bool {
    return c == ' ' or c == '\t';
}

fn startsWithW(s: [*:0]const u16, ascii: []const u8) bool {
    for (ascii, 0..) |c, k| if (s[k] != c) return false;
    return true;
}

// Writes to the console or pipe that launched us. A GUI-subsystem program has standard handles
// only when its parent passed them (a shell's redirect does), so with none it attaches to the
// parent's console, and with neither the text is dropped: headless mode's verdict is its exit code.
fn say(comptime fmt: []const u8, args: anytype) void {
    var buf: [512]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, fmt, args) catch return;
    const STD_OUTPUT_HANDLE: DWORD = @bitCast(@as(i32, -11));
    const ATTACH_PARENT_PROCESS: DWORD = @bitCast(@as(i32, -1));
    var h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == null or h == w.INVALID_HANDLE_VALUE) {
        _ = AttachConsole(ATTACH_PARENT_PROCESS);
        h = GetStdHandle(STD_OUTPUT_HANDLE);
    }
    const out = h orelse return;
    if (out == w.INVALID_HANDLE_VALUE) return;
    _ = WriteFile(out, text.ptr, @intCast(text.len), null, null);
}

fn fail(msg: []const u8) noreturn {
    say("screensaver: {s}\n", .{msg});
    ExitProcess(2);
}

// read the .scr command-line flag and set g_mode (+ g_preview_parent for /p). We parse the raw
// UTF-16 command line (GetCommandLineW) rather than std.process, whose Args API needs an OS handle
// threaded in — this shell has no libc and the flags are trivial ASCII. No args → windowed dev
// view; an unrecognized flag → windowed too (harmless). Case-insensitive (/S == /s).
fn parseMode() void {
    const cl = GetCommandLineW();
    var i: usize = 0;
    if (cl[0] == '"') { // skip the (possibly quoted) program path = argv[0]
        i = 1;
        while (cl[i] != 0 and cl[i] != '"') : (i += 1) {}
        if (cl[i] == '"') i += 1;
    } else {
        while (cl[i] != 0 and !isSpaceW(cl[i])) : (i += 1) {}
    }
    while (cl[i] != 0 and isSpaceW(cl[i])) : (i += 1) {} // skip to the flag
    if (cl[i] == 0 or (cl[i] != '/' and cl[i] != '-')) return; // no flag → windowed

    const headless_flag = "--headless=";
    if (startsWithW(cl[i..], headless_flag)) {
        var j = i + headless_flag.len;
        var n: usize = 0;
        while (cl[j] >= '0' and cl[j] <= '9') : (j += 1) n = n * 10 + @as(usize, cl[j] - '0');
        if (n == 0 or cl[j] != 0 and !isSpaceW(cl[j])) fail("--headless=<N> takes a count of frames, 1 or more");
        g_headless_frames = n;
        g_mode = .headless;
        return;
    }

    const flag: u16 = if (cl[i + 1] >= 'A' and cl[i + 1] <= 'Z') cl[i + 1] + 32 else cl[i + 1];
    switch (flag) {
        's' => g_mode = .fullscreen,
        'c' => g_mode = .config,
        'p' => {
            // the preview HWND is glued on (/p:1234 or /p1234) or is the next token (/p 1234).
            var j = i + 2;
            if (cl[j] == ':') j += 1;
            if (cl[j] < '0' or cl[j] > '9') // not glued on — advance to the next token
                while (cl[j] != 0 and isSpaceW(cl[j])) : (j += 1) {};
            var h: usize = 0;
            var any = false;
            while (cl[j] >= '0' and cl[j] <= '9') : (j += 1) {
                h = h * 10 + @as(usize, cl[j] - '0');
                any = true;
            }
            if (!any or h == 0) return; // no valid handle → nothing to preview into; windowed
            g_preview_parent = @ptrFromInt(h);
            g_mode = .preview;
        },
        else => {},
    }
}

pub fn main() !void {
    parseMode();

    const hinstance = GetModuleHandleW(null);
    if (g_mode == .config) {
        // no settings — say so and exit (the /c contract still expects the process to end).
        _ = MessageBoxW(null, std.unicode.utf8ToUtf16LeStringLiteral("The screensaver has no options to configure."), std.unicode.utf8ToUtf16LeStringLiteral("Roc Screensaver"), MB_OK);
        return;
    }

    try setUp();
    defer tearDown();
    if (g_mode == .headless) return headless(g_headless_frames);

    const class_name = std.unicode.utf8ToUtf16LeStringLiteral("RocScreensaverWindow");
    const title = std.unicode.utf8ToUtf16LeStringLiteral("Roc Screensaver");
    const wc = WNDCLASSW{
        .style = CS_OWNDC | CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc = &wndProc,
        .hInstance = hinstance,
        .hCursor = LoadCursorW(null, IDC_ARROW),
        .lpszClassName = class_name,
    };
    if (RegisterClassW(&wc) == 0) return error.RegisterClass;

    const hwnd = switch (g_mode) {
        .fullscreen => makeFullscreen(hinstance, class_name, title),
        .preview => makePreview(hinstance, class_name, title),
        .windowed => makeWindowed(hinstance, class_name, title),
        .config, .headless => unreachable,
    } orelse return error.CreateWindow;

    if (g_mode == .fullscreen) _ = ShowCursor(BOOL.fromBool(false)); // hide the pointer over the saver
    try run(hwnd);
    if (g_mode == .fullscreen) _ = ShowCursor(BOOL.fromBool(true));
}

// Loads the app and sizes everything by it: the slots' renders, the DIB that describes them, and
// the display budget. The Screensaver's own buffers go unused here; the slots hold the renders.
fn setUp() !void {
    g_saver = try screensaver.Screensaver.init(gpa);
    g_w = @intCast(g_saver.width);
    g_h = @intCast(g_saver.height);
    g_sw = g_saver.width * raster.SS;
    g_sh = g_saver.height * raster.SS;
    g_frame_ms = @divTrunc(1000, @max(1, g_saver.fps));
    g_bmih = .{
        .biSize = @sizeOf(BITMAPINFOHEADER),
        .biWidth = @intCast(g_sw),
        .biHeight = -@as(LONG, @intCast(g_sh)), // negative: row 0 is the top
        .biPlanes = 1,
        .biBitCount = 32,
        .biCompression = BI_RGB,
        .biSizeImage = 0,
        .biXPelsPerMeter = 0,
        .biYPelsPerMeter = 0,
        .biClrUsed = 0,
        .biClrImportant = 0,
    };
    for (&slots) |*s| s.px = try gpa.alloc(u32, g_sw * g_sh);
}

fn tearDown() void {
    for (&slots) |*s| {
        gpa.free(s.px);
        s.words.deinit(gpa);
    }
    g_saver.deinit();
}

// `--headless=<N>`: the windowed pipeline with no window. Main produces N frames and takes each
// back in order as the workers finish it; the last is boxed down to the app's size and its
// checksum printed, the same as the PNG harness prints for its last frame on Linux.
fn headless(frames: usize) !void {
    var workers: [NUM_WORKERS]std.Thread = undefined;
    for (&workers) |*t| t.* = try std.Thread.spawn(.{}, worker, .{});
    var produce_seq: usize = 0;
    var display_seq: usize = 0;
    while (display_seq < frames) {
        produce(&produce_seq, frames);
        const s = &slots[display_seq % RING];
        if (s.state.load(.acquire) != .ready) {
            Sleep(0);
            continue;
        }
        if (display_seq + 1 == frames) {
            raster.downsample(.{ .px = s.px, .w = g_sw, .h = g_sh }, .{ .px = g_saver.display, .w = g_saver.width, .h = g_saver.height });
        }
        s.state.store(.empty, .release);
        display_seq += 1;
    }
    g_quit.store(true, .release);
    for (&workers) |*t| t.join();
    say("headless: {d} frames of {d} by {d}; the last's checksum {x:0>16}\n", .{ frames, g_saver.width, g_saver.height, screensaver.checksum(g_saver.display) });
}

// windowed dev view: the CLIENT area is the app's size (borders/caption sit outside).
fn makeWindowed(hinstance: ?HINSTANCE, class_name: [*:0]const WCHAR, title: [*:0]const WCHAR) ?HWND {
    var wr = RECT{ .left = 0, .top = 0, .right = g_w, .bottom = g_h };
    _ = AdjustWindowRect(&wr, WS_OVERLAPPEDWINDOW, .FALSE);
    const hwnd = CreateWindowExW(0, class_name, title, WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, wr.right - wr.left, wr.bottom - wr.top, null, null, hinstance, null);
    if (hwnd) |h| _ = ShowWindow(h, SW_SHOW);
    return hwnd;
}

// fullscreen saver: a borderless topmost popup covering the primary monitor.
fn makeFullscreen(hinstance: ?HINSTANCE, class_name: [*:0]const WCHAR, title: [*:0]const WCHAR) ?HWND {
    const sw = GetSystemMetrics(SM_CXSCREEN);
    const sh = GetSystemMetrics(SM_CYSCREEN);
    const hwnd = CreateWindowExW(WS_EX_TOPMOST, class_name, title, WS_POPUP | WS_VISIBLE, 0, 0, sw, sh, null, null, hinstance, null);
    if (hwnd) |h| _ = ShowWindow(h, SW_SHOW);
    return hwnd;
}

// preview: a child window filling the settings dialog's little monitor (g_preview_parent).
fn makePreview(hinstance: ?HINSTANCE, class_name: [*:0]const WCHAR, title: [*:0]const WCHAR) ?HWND {
    const parent = g_preview_parent orelse return null;
    var prc: RECT = undefined;
    if (!GetClientRect(parent, &prc).toBool()) return null;
    const hwnd = CreateWindowExW(0, class_name, title, WS_CHILD | WS_VISIBLE, 0, 0, prc.right, prc.bottom, parent, null, hinstance, null);
    if (hwnd) |h| _ = ShowWindow(h, SW_SHOW);
    return hwnd;
}

// the shared render loop: set up the double buffer + workers, pump messages, produce/display at 60 fps,
// then tear the workers down cleanly. Mode-independent except the preview parent-liveness check.
fn run(hwnd: HWND) !void {
    const hdc = GetDC(hwnd) orelse return error.NoDC; // CS_OWNDC → valid for the window's life
    // off-screen DC we scale into (then BitBlt to the window) — the double buffer that kills tearing.
    g_memdc = CreateCompatibleDC(hdc) orelse return error.NoMemDC;
    _ = SetStretchBltMode(g_memdc.?, HALFTONE);
    _ = SetBrushOrgEx(g_memdc.?, 0, 0, null); // HALFTONE requires this or the brush origin misaligns

    for (&slots) |*s| s.state = .init(.empty);
    var workers: [NUM_WORKERS]std.Thread = undefined;
    for (&workers) |*t| t.* = try std.Thread.spawn(.{}, worker, .{});

    var freq: i64 = 1;
    _ = QueryPerformanceFrequency(&freq);

    var produce_seq: usize = 0; // next frame to run geometry for
    var display_seq: usize = 0; // next frame to blit (strict order)

    while (g_running) {
        var start: i64 = 0;
        _ = QueryPerformanceCounter(&start);

        var msg: MSG = undefined;
        while (PeekMessageW(&msg, null, 0, 0, PM_REMOVE).toBool()) {
            if (msg.message == WM_QUIT) {
                g_running = false;
                break;
            }
            _ = TranslateMessage(&msg);
            _ = DispatchMessageW(&msg);
        }
        if (!g_running) break;

        // preview: the settings dialog owns our parent — when it closes, our host is gone, so exit.
        if (g_mode == .preview) {
            if (g_preview_parent) |p| if (!IsWindow(p).toBool()) break;
        }

        if (g_auto) {
            displayNext(hdc, hwnd, &display_seq);
            produce(&produce_seq, std.math.maxInt(usize)); // refill the ring after freeing a slot
        }

        // pace to the display budget: sleep only the time LEFT after the tick's work.
        var now: i64 = 0;
        _ = QueryPerformanceCounter(&now);
        const elapsed_ms = @divTrunc((now - start) * 1000, freq);
        if (elapsed_ms < g_frame_ms) Sleep(@intCast(g_frame_ms - elapsed_ms));
    }

    // tear down the workers cleanly before the window/DC go away. They poll g_quit at the top of
    // their loop (waking within the Sleep(1) at worst), so no wakeup signal is needed.
    g_quit.store(true, .release);
    for (&workers) |*t| t.join();

    if (g_bmp) |b| _ = DeleteObject(@ptrCast(b));
    if (g_memdc) |m| _ = DeleteDC(m);
}

// ask the Roc for the current model's frame and step the model (main-thread-only: the model is
// not shared) for as many EMPTY ring slots as we can, up to `limit` frames in all, snapshotting
// each frame's words into its slot and handing it to the workers. Stops when the ring is full
// (workers/display haven't caught up). The first frame is the app's `init`, as in the PNG harness.
fn produce(produce_seq: *usize, limit: usize) void {
    while (produce_seq.* < limit) {
        const s = &slots[produce_seq.* % RING];
        if (s.state.load(.acquire) != .empty) return; // ring full — nothing to produce into

        const d = g_saver.draw() catch fail("out of memory for a frame's words");
        // the slot is .empty → no worker looks at it, so fill its buffers before publishing .queued.
        s.words.clearRetainingCapacity();
        s.words.appendSlice(gpa, d.words) catch fail("out of memory for a frame's words");
        s.tilt = d.roll;
        s.top = d.sky_top;
        s.horizon = d.sky_horizon;
        s.sun = d.sun;
        g_saver.advance();

        s.state.store(.queued, .release); // publish: a worker's claim CAS acquires the writes above
        produce_seq.* += 1;
    }
}

// if the next frame (in strict produced order) is rasterized, blit it and free its slot. At most one
// frame per tick, so the display paces at 60 fps even though the workers run well ahead.
fn displayNext(hdc: HDC, hwnd: HWND, display_seq: *usize) void {
    const s = &slots[display_seq.* % RING];
    if (s.state.load(.acquire) != .ready) return; // workers haven't finished it — hold the current frame

    var rc: RECT = undefined;
    _ = GetClientRect(hwnd, &rc);
    const cw = rc.right - rc.left;
    const ch = rc.bottom - rc.top;
    if (cw <= 0 or ch <= 0) return; // minimised — nothing to show (don't free the slot; keep it for later)

    // (re)build the off-screen bitmap when the client size changes. It's screen-COMPATIBLE (created
    // against the window DC, not the mem DC — else it'd be 1-bpp monochrome).
    if (g_bmp == null or cw != g_bmp_w or ch != g_bmp_h) {
        if (g_bmp) |b| _ = DeleteObject(@ptrCast(b));
        g_bmp = CreateCompatibleBitmap(hdc, cw, ch) orelse return;
        _ = SelectObject(g_memdc.?, @ptrCast(g_bmp.?));
        g_bmp_w = cw;
        g_bmp_h = ch;
    }

    // scale the supersampled frame into the off-screen buffer (HALFTONE), then present it in one
    // fast 1:1 BitBlt — so the on-screen write is too brief for the compositor to catch half-done.
    _ = StretchDIBits(g_memdc.?, 0, 0, cw, ch, 0, 0, @intCast(g_sw), @intCast(g_sh), s.px.ptr, &g_bmih, DIB_RGB_COLORS, SRCCOPY);
    _ = BitBlt(hdc, 0, 0, cw, ch, g_memdc.?, 0, 0, SRCCOPY);

    s.state.store(.empty, .release); // freed for produce() to reuse
    display_seq.* += 1;
}
