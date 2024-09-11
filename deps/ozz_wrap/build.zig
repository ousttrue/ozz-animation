const std = @import("std");
const builtin = @import("builtin");
pub const emsdk_zig = @import("emsdk-zig");

//
// ozz-animation wrapper for zig using
//
// build ozz_wrap.dll or ozz_wrap.wasm
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root = b.path("../..");
    const meson_arg = b.option(
        []const u8,
        "meson_arg",
        "add meson setup. '--wipe' ...etc",
    );

    const wf = buildToWriteFile(
        b,
        target,
        optimize,
        root,
        meson_arg,
    );
    b.default_step.dependOn(wf);
}

fn buildToWriteFile(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root: std.Build.LazyPath,
    meson_arg: ?[]const u8,
) *std.Build.Step {
    const wf = b.addNamedWriteFiles("build");
    const prefix = prefixFromMesonBuild(
        &wf.step,
        b,
        target,
        optimize,
        root,
        meson_arg,
    );
    _ = wf.addCopyFile(b.path("ozz_wrap.h"), "include/ozz_wrap.h");
    if (target.result.isWasm()) {
        _ = wf.addCopyFile(prefix.path(b, "web/ozz_wrap.wasm"), "web/ozz_wrap.wasm");
    } else {
        _ = wf.addCopyFile(prefix.path(b, "bin/ozz_wrap.dll"), "bin/ozz_wrap.dll");
        _ = wf.addCopyFile(prefix.path(b, "lib/ozz_wrap.lib"), "lib/ozz_wrap.lib");
    }

    return &wf.step;
}

fn prefixFromMesonBuild(
    step: *std.Build.Step,
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root: std.Build.LazyPath,
    meson_arg: ?[]const u8,
) std.Build.LazyPath {
    const platform = if (target.result.isWasm()) "wasm" else "native";
    const buildtype = if (optimize == .Debug) "debug" else "release";

    const builddir = root.path(
        b,
        b.fmt("build_{s}_{s}", .{ platform, buildtype }),
    );
    const prefix = root.path(b, b.fmt(
        "prefix_{s}_{s}",
        .{ platform, buildtype },
    ));
    const meson_install = b.addSystemCommand(&.{
        "meson",
        "install",
        "-C",
    });
    meson_install.setCwd(root);
    meson_install.addFileArg(builddir);
    step.dependOn(&meson_install.step);

    const meson_setup = b.addSystemCommand(&.{
        "meson",
        "setup",
    });
    meson_setup.setCwd(root);
    meson_setup.addFileArg(builddir);
    meson_setup.addArgs(&.{
        "--buildtype",
        buildtype,
        "--prefix",
    });
    meson_setup.addFileArg(prefix);
    if (meson_arg) |meson_opt| {
        meson_setup.addArg(meson_opt);
    }
    meson_install.step.dependOn(&meson_setup.step);

    if (target.result.isWasm()) {
        // cross-file
        const ini = writeCrossFile(&meson_setup.step, b);
        meson_setup.addArg("--cross-file");
        meson_setup.addFileArg(ini);
    }

    return prefix;
}

pub fn writeCrossFile(
    step: *std.Build.Step,
    b: *std.Build,
) std.Build.LazyPath {
    const wf = b.addWriteFiles();
    step.dependOn(&wf.step);
    const emsdk_zig_dep = b.dependency("emsdk-zig", .{});
    wf.step.dependOn(emsdk_zig_dep.builder.default_step);
    const dep_emsdk = emsdk_zig_dep.builder.dependency("emsdk", .{});
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
