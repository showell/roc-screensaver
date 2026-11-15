const std = @import("std");

/// The screensaver's build. The pinned Roc (roc-version) builds the app on
/// platform/ into one archive, which is linked into each of the host's
/// programs.
///
///   zig build png -- <out dir>   the headless harness: the first frames as PNGs
///   zig build test               the host's tests: the seam against roc glue,
///                                and the example's frames painted and freed
///
/// `-Dapp=<path>` names another app; the example is the default.
///
/// `-Dwindows` builds the Windows screensaver instead (host/win32.zig, on
/// Roc's x64win archive), from any host:
///
///   zig build -Dwindows            zig-out/bin/screensaver.exe and a
///                                  byte-identical screensaver.scr
///   zig build -Dwindows headless   runs the .exe with no window, where the
///                                  host runs Windows programs
pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const app_root = b.option([]const u8, "app", "The app's main.roc (examples/basic/main.roc)") orelse "examples/basic/main.roc";
    const windows = b.option(bool, "windows", "Build the Windows screensaver (x86_64-windows) in place of the Linux programs") orelse false;
    const roc = rocCompiler(b);

    if (windows) {
        const win_target = b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu });
        buildWindows(b, rocArchive(b, roc, app_root, "x64win", "app-x64win.lib"), win_target, optimize);
        return;
    }

    const target = b.standardTargetOptions(.{});
    const app = rocArchive(b, roc, app_root, "x64musl", "app-x64musl.a");

    const png_exe = withApp(b, "png", "host/png_main.zig", app, target, optimize);
    b.installArtifact(png_exe);
    const png = b.addRunArtifact(png_exe);
    png.addPassthruArgs();
    png.stdio = .inherit;
    b.step("png", "The headless harness: -- <out dir>, the app's first frames as PNGs").dependOn(&png.step);

    const tests = b.step("test", "The host's tests: the seam against roc glue, and the example's frames painted and freed");
    const abi_test = b.createModule(.{ .root_source_file = b.path("host/abi_test.zig"), .target = target, .optimize = optimize });
    abi_test.addObjectFile(app);
    tests.dependOn(&testRun(b, abi_test).step);
    const app_test = b.createModule(.{ .root_source_file = b.path("host/screensaver_test.zig"), .target = target, .optimize = optimize });
    app_test.addObjectFile(app);
    tests.dependOn(&testRun(b, app_test).step);
}

/// The app on platform/, built by the pinned Roc for one of the platform's
/// targets into an archive, on Roc's dev backend.
fn rocArchive(b: *std.Build, roc: []const u8, app_root: []const u8, roc_target: []const u8, name: []const u8) std.Build.LazyPath {
    const archive = b.addSystemCommand(&.{ roc, "build", app_root, b.fmt("--target={s}", .{roc_target}), "--opt=dev" });
    archive.setCwd(b.path("."));
    rocInputs(b, archive, "platform");
    rocInputs(b, archive, std.fs.path.dirname(app_root) orelse ".");
    archive.addFileInput(.{ .cwd_relative = roc });
    return archive.addPrefixedOutputFileArg("--output=", name);
}

/// The Windows screensaver: one GUI-subsystem program, installed twice,
/// as the .exe and as the .scr Windows takes for a screensaver. The same
/// bytes serve both because Windows picks the mode by the command line
/// (host/win32.zig). It needs no SDK: zig's own import libraries cover
/// user32, gdi32 and kernel32.
fn buildWindows(b: *std.Build, app: std.Build.LazyPath, target: std.Build.ResolvedTarget, optimize: std.lang.Optimize) void {
    const exe = withApp(b, "screensaver", "host/win32.zig", app, target, optimize);
    exe.subsystem = .windows;
    exe.root_module.linkSystemLibrary("user32", .{});
    exe.root_module.linkSystemLibrary("gdi32", .{});
    b.installArtifact(exe);
    b.getInstallStep().dependOn(&b.addInstallFileWithDir(exe.getEmittedBin(), .bin, "screensaver.scr").step);

    const run = b.addRunArtifact(exe);
    run.addArg(b.fmt("--headless={d}", .{headless_frames}));
    run.stdio = .inherit;
    run.has_side_effects = true;
    b.step("headless", "Run the .exe with no window: the PNG harness's frames, the last one's checksum printed").dependOn(&run.step);
}

/// The headless run draws as many frames as the PNG harness writes, so the
/// checksum each prints for its last frame is of the same picture.
const headless_frames = @import("host/png_main.zig").frames_written;

/// One root's tests, run on every `zig build test`. Zig otherwise replays a
/// run whose inputs are unchanged and leaves its tests out of the summary.
fn testRun(b: *std.Build, module: *std.Build.Module) *std.Build.Step.Run {
    const run = b.addRunArtifact(b.addTest(.{ .root_module = module }));
    run.has_side_effects = true;
    return run;
}

/// The program `name`, from `root`, with the app's archive linked.
fn withApp(b: *std.Build, name: []const u8, root: []const u8, app: std.Build.LazyPath, target: std.Build.ResolvedTarget, optimize: std.lang.Optimize) *std.Build.Step.Compile {
    const mod = b.createModule(.{ .root_source_file = b.path(root), .target = target, .optimize = optimize });
    mod.addObjectFile(app);
    return b.addExecutable(.{ .name = name, .root_module = mod });
}

/// Every file in `folder` is an input of the archive, found rather than
/// listed, so a change to any module builds it again. The listing is a
/// dependency of the configure step too, so a module added after the first
/// build is found.
fn rocInputs(b: *std.Build, run: *std.Build.Step.Run, folder: []const u8) void {
    b.dependOnDirectoryContents(b.path(folder));
    const io = b.graph.io;
    var dir = b.root.root_dir.handle.openDir(io, folder, .{ .iterate = true }) catch |e|
        std.process.fatal("the Roc: cannot open {s} ({t})", .{ folder, e });
    defer dir.close(io);
    var it = dir.iterate();
    while (it.next(io) catch |e| std.process.fatal("the Roc: cannot list {s} ({t})", .{ folder, e })) |entry| {
        if (entry.kind != .file) continue;
        run.addFileInput(b.path(b.fmt("{s}/{s}", .{ folder, entry.name })));
    }
}

const roc_pin = std.mem.trim(u8, @embedFile("roc-version"), " \n");

/// The Roc is pinned (roc-version): `-Droc=<path>`, else
/// `~/tools/roc-<pin>/roc`, else `roc` on the PATH, which is where CI's
/// setup-roc puts it. Any of them is refused unless `roc version` names the
/// pin, because another nightly lays the seam out its own way.
fn rocCompiler(b: *std.Build) []const u8 {
    const roc = b.option([]const u8, "roc", "The Roc compiler; it must be the pin in roc-version") orelse blk: {
        if (b.graph.environ_map.get("HOME")) |home| {
            const installed = b.fmt("{s}/tools/roc-{s}/roc", .{ home, roc_pin });
            if (std.Io.Dir.cwd().access(b.graph.io, installed, .{})) break :blk installed else |_| {}
        }
        break :blk b.findProgram(.{ .names = &.{"roc"} }) orelse
            std.process.fatal("the Roc: no ~/tools/roc-{s}/roc and no roc on the PATH; install the pin or name it with -Droc", .{roc_pin});
    };
    var code: u8 = undefined;
    const said = b.runAllowFail(&.{ roc, "version" }, &code, .ignore) catch |e|
        std.process.fatal("the Roc: `{s} version` did not run ({t}); install the pin {s} there", .{ roc, e, roc_pin });
    if (std.mem.indexOf(u8, said, roc_pin) == null)
        std.process.fatal("the Roc: {s} is not the pin {s} (roc-version); it says: {s}", .{ roc, roc_pin, std.mem.trim(u8, said, " \n") });
    return roc;
}
