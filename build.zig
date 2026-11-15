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
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const app_root = b.option([]const u8, "app", "The app's main.roc (examples/basic/main.roc)") orelse "examples/basic/main.roc";
    const roc = rocCompiler(b);

    const archive = b.addSystemCommand(&.{ roc, "build", app_root, "--target=x64musl", "--opt=dev" });
    archive.setCwd(b.path("."));
    rocInputs(b, archive, "platform");
    rocInputs(b, archive, std.fs.path.dirname(app_root) orelse ".");
    archive.addFileInput(.{ .cwd_relative = roc });
    const app = archive.addPrefixedOutputFileArg("--output=", "app-x64musl.a");

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
/// `~/tools/roc-<pin>/roc`. Either is refused unless `roc version` names
/// the pin, because another nightly lays the seam out its own way.
fn rocCompiler(b: *std.Build) []const u8 {
    const roc = b.option([]const u8, "roc", "The Roc compiler; it must be the pin in roc-version") orelse blk: {
        const home = b.graph.environ_map.get("HOME") orelse std.process.fatal("no HOME to find ~/tools/roc-{s}/roc", .{roc_pin});
        break :blk b.fmt("{s}/tools/roc-{s}/roc", .{ home, roc_pin });
    };
    var code: u8 = undefined;
    const said = b.runAllowFail(&.{ roc, "version" }, &code, .ignore) catch |e|
        std.process.fatal("the Roc: `{s} version` did not run ({t}); install the pin {s} there", .{ roc, e, roc_pin });
    if (std.mem.indexOf(u8, said, roc_pin) == null)
        std.process.fatal("the Roc: {s} is not the pin {s} (roc-version); it says: {s}", .{ roc, roc_pin, std.mem.trim(u8, said, " \n") });
    return roc;
}
