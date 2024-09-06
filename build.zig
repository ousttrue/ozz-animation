const std = @import("std");
const builtin = @import("builtin");
const zcc = @import("zcc.zig");
const shdc = @import("shdc.zig");
const ozz_wrap_samples = @import("ozz_wrap_samples/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    buildToWriteFile(b.default_step, b, target, optimize);

    if (if (b.option(bool, "samples", "build samples")) |enable_samples|
        enable_samples
    else
        false)
    {
        const build_samples = @import("build_samples.zig");
        const build_framework = @import("build_framework.zig");
        const build_ozz = @import("build_ozz.zig");
        const build_glfw = @import("build_glfw.zig");

        const ozz = build_ozz.build(b, target, optimize);
        const glfw = build_glfw.build(b, target, optimize);
        const framework = build_framework.build(
            b,
            target,
            optimize,
            &.{ &ozz, &glfw },
        );

        for (build_samples.samples) |sample| {
            const exe = b.addExecutable(.{
                .name = sample.name,
                .target = target,
                .optimize = optimize,
            });

            if (sample.sokol_shader) |sokol_shader| {
                exe.step.dependOn(shdc.sokolShdc(b, target, sokol_shader));
            }

            exe.addCSourceFiles(.{
                .files = sample.cfiles,
                .flags = &.{
                    "-std=c++20",
                },
            });
            for (sample.includes) |include| {
                exe.addIncludePath(b.path(include));
            }
            framework.link(b, exe);
            ozz.link(b, exe);
            glfw.link(b, exe);
            for (sample.windows_libs) |lib| {
                exe.linkSystemLibrary(lib);
            }
            b.installArtifact(exe);

            if (sample.use_gtest) {
                exe.addIncludePath(b.path("extern/gtest/fused-src"));
            }

            const install = b.addInstallArtifact(exe, .{});
            b.getInstallStep().dependOn(&install.step);

            // targets.append(exe) catch @panic("OOM");
            // add a step called "zcc" (Compile commands DataBase) for making
            // compile_commands.json. could be named anything. cdb is just quick to type
            install.step.dependOn(zcc.createStep(b, .{ .targets = &.{exe} }));

            const run = b.addRunArtifact(exe);
            run.step.dependOn(&install.step);
            // run.setCwd(b.path("zig-out/bin"));

            const step = b.step(
                b.fmt("run-{s}", .{sample.name}),
                b.fmt("Run {s}", .{sample.name}),
            );
            step.dependOn(&run.step);
        }

        if (!target.result.isWasm()) {
            ozz_wrap_samples.build(b, target, optimize);
        }
    }
}

const medias = [_][]const u8{
    "arnaud_mesh.ozz",
    "arnaud_mesh_4.ozz",
    "astro_max_animation.ozz",
    "astro_max_skeleton.ozz",
    "astro_maya_animation.ozz",
    "astro_maya_skeleton.ozz",
    "baked_animation.ozz",
    "baked_skeleton.ozz",
    "floor.ozz",
    "pab_atlas_raw.ozz",
    "pab_crackhead.ozz",
    "pab_crackhead_additive.ozz",
    "pab_crossarms.ozz",
    "pab_curl_additive.ozz",
    "pab_jog.ozz",
    "pab_run.ozz",
    "pab_skeleton.ozz",
    "pab_splay_additive.ozz",
    "pab_walk.ozz",
    "robot_animation.ozz",
    "robot_skeleton.ozz",
    "robot_track_grasp.ozz",
    "ruby_animation.ozz",
    "ruby_mesh.ozz",
    "ruby_skeleton.ozz",
    "seymour_animation.ozz",
    "seymour_skeleton.ozz",
};

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

    const dir = if (target.result.isWasm()) "web" else "bin";
    for (medias) |media| {
        _ = wf.addCopyFile(
            b.path(b.fmt("media/bin/{s}", .{media})),
            b.fmt("{s}/{s}", .{ dir, media }),
        );
    }
}

fn prefixFromMesonBuild(
    step: *std.Build.Step,
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) std.Build.LazyPath {
    const platform = if (target.result.isWasm()) "wasm" else "native";
    const buildtype = if (optimize == .Debug) "debug" else "release";

    const builddir = b.path(b.fmt("build_{s}_{s}", .{ platform, buildtype }));
    const prefix = b.path(b.fmt("prefix_{s}_{s}", .{ platform, buildtype }));
    const meson_install = b.addSystemCommand(&.{
        "meson",
        "install",
        "-C",
    });
    meson_install.addFileArg(builddir);
    step.dependOn(&meson_install.step);

    const setup_dir = builddir.getPath(b);
    // if (std.fs.openDirAbsolute(setup_dir, .{})) |*dir| {
    //     @constCast(dir).close();
    // } else |_| {
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
    // }

    return prefix;
}

pub fn writeCrossFile(
    step: *std.Build.Step,
    b: *std.Build,
) std.Build.LazyPath {
    const wf = b.addWriteFiles();
    step.dependOn(&wf.step);
    const emsdk_zig = b.dependency("emsdk-zig", .{});
    wf.step.dependOn(emsdk_zig.builder.default_step);
    const dep_emsdk = emsdk_zig.builder.dependency("emsdk", .{});
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
