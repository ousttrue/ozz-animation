const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    if (target.result.isWasm()) {
        @panic("todo: wasm not implemented");
    } else {
        dllToWriteFile(b.default_step, b, optimize);
    }
}

fn dllToWriteFile(
    step: *std.Build.Step,
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
) void {
    const wf = b.addNamedWriteFiles("meson_build");
    step.dependOn(&wf.step);
    const prefix = prefixFromMesonBuild(&wf.step, b, optimize);
    _ = wf.addCopyFile(prefix.path(b, "bin/ozz-animation.dll"), "bin/ozz-animation.dll");
    _ = wf.addCopyFile(prefix.path(b, "lib/ozz-animation.lib"), "lib/ozz-animation.lib");
}

fn prefixFromMesonBuild(
    step: *std.Build.Step,
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
) std.Build.LazyPath {
    const builddir = b.path(if (optimize == .Debug) "build_native_debug" else "build_native_release");
    const setup_dir = builddir.getPath(b);
    const prefix = b.path(if (optimize == .Debug) "prefix_debug" else "prefix_release");
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
    }

    return prefix;
}
