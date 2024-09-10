const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (b.option(bool, "cpp_samples", "build cpp samples") orelse false) {
        // ozz cpp samples. build by zig cc
        const cpp_sample_build = @import("cpp_samples");
        const cpp_sample_dep = b.dependency("cpp_samples", .{
            .target = target,
            .optimize = optimize,
        });
        for (cpp_sample_build.samples) |sample| {
            const artifact = cpp_sample_dep.artifact(sample.name);
            const install = b.addInstallArtifact(artifact, .{});
            b.getInstallStep().dependOn(&install.step);

            const run = b.addRunArtifact(artifact);
            run.step.dependOn(&install.step);

            b.step(b.fmt("run-cpp-{s}", .{sample.name}), b.fmt(
                "Run cpp sample {s}",
                .{sample.name},
            )).dependOn(&run.step);
        }
    } else {
        const meson_arg = b.option([]const u8, "meson", "additional meson arg. --wipe etc");
        // default.build dll or wasm.
        const wf = b.addNamedWriteFiles("build");
        b.default_step.dependOn(&wf.step);

        // zig-0.13.0 wasm32-emscripten libcpp issue. buidl by meson using emsdk.
        // zig-0.13.0 x86_64-windows libcpp issue. build by meson using msvc etc.
        const ozz_dep = if (meson_arg) |arg|
            b.dependency("ozz_wrap", .{
                .target = target,
                .optimize = optimize,
                .meson_arg = arg,
            })
        else
            b.dependency("ozz_wrap", .{
                .target = target,
                .optimize = optimize,
            });

        // meson build is not artifact.
        // so use namedWriteFiles.
        const ozz_wrap_wf = ozz_dep.namedWriteFiles("build");
        _ = wf.addCopyDirectory(ozz_wrap_wf.getDirectory(), "", .{});

        // copy media/bin/* to web/*
        for (medias) |media| {
            _ = wf.addCopyFile(
                b.path(b.fmt("media/bin/{s}", .{media})),
                b.fmt("{s}/{s}", .{ "web", media }),
            );
        }

        // copy to zig-out
        b.installDirectory(.{
            .source_dir = wf.getDirectory(),
            .install_dir = .{ .prefix = void{} },
            .install_subdir = "",
        });

        if (b.option(
            bool,
            "ozz_wrap_samples",
            "build ozz_wrap sample",
        ) orelse false) {
            const ozz_wrap_sample_build = @import("ozz_wrap_samples");
            const ozz_wrap_sample_dep = b.dependency("ozz_wrap_samples", .{
                .target = target,
                .optimize = optimize,
            });
            for (ozz_wrap_sample_build.samples) |sample| {
                const artifact = ozz_wrap_sample_dep.artifact(sample.name);
                const install = b.addInstallArtifact(artifact, .{});
                b.getInstallStep().dependOn(&install.step);

                const run = b.addRunArtifact(artifact);
                run.step.dependOn(&install.step);

                b.step(b.fmt("run-ozz_wrap-{s}", .{sample.name}), b.fmt(
                    "Run ozz_wrap sample {s}",
                    .{sample.name},
                )).dependOn(&run.step);
            }
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
