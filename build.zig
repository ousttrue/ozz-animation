const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    buildToWriteFile(b.default_step, b, target, optimize);
}

fn buildToWriteFile(
    step: *std.Build.Step,
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const wf = b.addNamedWriteFiles("meson_build");
    step.dependOn(&wf.step);
    const prefix = prefixFromMesonBuild(&wf.step, b, target, optimize);
    if (target.result.isWasm()) {
        _ = wf.addCopyFile(prefix.path(b, "web/ozz-animation.wasm"), "web/ozz-animation.wasm");
    } else {
        _ = wf.addCopyFile(prefix.path(b, "bin/ozz-animation.dll"), "bin/ozz-animation.dll");
        _ = wf.addCopyFile(prefix.path(b, "lib/ozz-animation.lib"), "lib/ozz-animation.lib");
    }
}

fn prefixFromMesonBuild(
    step: *std.Build.Step,
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) std.Build.LazyPath {
    const buildtype = if (optimize == .Debug) "debug" else "release";
    const platform = if (target.result.isWasm()) "wasm" else "native";

    const builddir = b.path(b.fmt("build_{s}_{s}", .{ platform, buildtype }));
    const setup_dir = builddir.getPath(b);
    const prefix = b.path(b.fmt("prefix_{s}_{s}", .{ platform, buildtype }));
    const meson_install = b.addSystemCommand(&.{
        "meson",
        "install",
        "-C",
        setup_dir,
    });
    step.dependOn(&meson_install.step);

    if (std.fs.openDirAbsolute(setup_dir, .{})) |*dir| {
        @constCast(dir).close();
    } else |_| {
        const meson_setup = b.addSystemCommand(&.{
            "meson",
            "setup",
            setup_dir,
            "--buildtype",
            if (optimize == .Debug) "debug" else "release",
            "--prefix",
        });
        meson_setup.addFileArg(prefix);
        meson_install.step.dependOn(&meson_setup.step);

        if (target.result.isWasm()) {
            // cross-file
            const ini = writeCrossFile(&meson_setup.step, b);
            meson_setup.addArg("--cross-file");
            meson_setup.addFileArg(ini);
        }
    }

    return prefix;
}

pub fn writeCrossFile(
    step: *std.Build.Step,
    b: *std.Build,
) std.Build.LazyPath {
    const wf = b.addWriteFiles();
    step.dependOn(&wf.step);
    const dep_emsdk = b.dependency("emsdk-zig", .{}).builder.dependency("emsdk", .{});
    const ext: []const u8 = if (builtin.os.tag == .windows) ".bat" else "";
    return wf.add("emsdk.ini", b.fmt(
        \\# wasm.ini
        \\[constants]
        \\args = []
        \\
        \\[binaries]
        \\c = '{s}'
        \\cpp = '{s}'
        \\ar = '{s}'
        \\strip = '{s}'
        \\
        \\[built-in options]
        \\c_args = []
        \\c_link_args = args
        \\cpp_args = []
        \\cpp_link_args = args
        \\default_library = 'static'
        \\
        \\[host_machine]
        \\system = 'emscripten'
        \\cpu_family = 'wasm'
        \\cpu = 'wasm'
        \\endian = 'little'
    , .{
        dep_emsdk.path(b.fmt("upstream/emscripten/emcc{s}", .{ext})).getPath(b),
        dep_emsdk.path(b.fmt("upstream/emscripten/em++{s}", .{ext})).getPath(b),
        dep_emsdk.path(b.fmt("upstream/emscripten/emar{s}", .{ext})).getPath(b),
        dep_emsdk.path(b.fmt("upstream/emscripten/emstrip{s}", .{ext})).getPath(b),
    }));
}
