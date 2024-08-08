const std = @import("std");

pub const CLib = struct {
    lib: *std.Build.Step.Compile,
    include_directories: []const []const u8,
};

pub fn buildOzzAnimation(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) CLib {
    const lib = b.addStaticLibrary(.{
        .name = "ozz",
        .target = target,
        .optimize = optimize,
    });
    lib.addCSourceFiles(.{
        .files = &.{
            "src/base/platform.cc",
            "src/base/log.cc",
            "src/base/memory/allocator.cc",
            "src/base/containers/string_archive.cc",
            "src/base/io/archive.cc",
            "src/base/io/stream.cc",
            "src/base/maths/box.cc",
            "src/base/maths/simd_math.cc",
            "src/base/maths/math_archive.cc",
            "src/base/maths/soa_math_archive.cc",
            "src/base/maths/simd_math_archive.cc",
            "src/animation/runtime/animation.cc",
            "src/animation/runtime/animation_utils.cc",
            "src/animation/runtime/blending_job.cc",
            "src/animation/runtime/ik_aim_job.cc",
            "src/animation/runtime/ik_two_bone_job.cc",
            "src/animation/runtime/local_to_model_job.cc",
            "src/animation/runtime/sampling_job.cc",
            "src/animation/runtime/skeleton.cc",
            "src/animation/runtime/skeleton_utils.cc",
            "src/animation/runtime/track.cc",
            "src/animation/runtime/track_sampling_job.cc",
            "src/animation/runtime/track_triggering_job.cc",
            "src/animation/offline/raw_animation.cc",
            "src/animation/offline/raw_animation_archive.cc",
            "src/animation/offline/raw_animation_utils.cc",
            "src/animation/offline/animation_builder.cc",
            "src/animation/offline/animation_optimizer.cc",
            "src/animation/offline/additive_animation_builder.cc",
            "src/animation/offline/raw_skeleton.cc",
            "src/animation/offline/raw_skeleton_archive.cc",
            "src/animation/offline/skeleton_builder.cc",
            "src/animation/offline/raw_track.cc",
            "src/animation/offline/track_builder.cc",
            "src/animation/offline/track_optimizer.cc",
            "src/options/options.cc",
            "src/geometry/runtime/skinning_job.cc",
        },
    });
    lib.addIncludePath(b.path("include"));
    lib.addIncludePath(b.path("src"));
    lib.linkLibCpp();
    return .{
        .include_directories = &.{
            "include",
        },
        .lib = lib,
    };
}
