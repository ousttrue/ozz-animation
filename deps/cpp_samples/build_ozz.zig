const std = @import("std");
const CLib = @import("CLib.zig");

pub fn build(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root: std.Build.LazyPath,
) CLib {
    const lib = b.addStaticLibrary(.{
        .name = "ozz",
        .target = target,
        .optimize = optimize,
    });
    lib.addCSourceFiles(.{
        .root = root,
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
            "src/base/encode/group_varint.cc",
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
            "src/animation/runtime/motion_blending_job.cc",
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
            "src/animation/offline/raw_track_utils.cc",
            "src/animation/offline/track_builder.cc",
            "src/animation/offline/track_optimizer.cc",
            "src/animation/offline/motion_extractor.cc",
            "src/options/options.cc",
            "src/geometry/runtime/skinning_job.cc",

            "samples/framework/mesh.cc",
        },
    });
    lib.addIncludePath(root.path(b, "include"));
    lib.addIncludePath(root.path(b, "src"));
    lib.linkLibCpp();
    return .{
        .include_directories = &.{
            "include",
            "src",
        },
        .lib = lib,
    };
}
