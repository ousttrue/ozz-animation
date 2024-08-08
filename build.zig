const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .target = target,
        .optimize = optimize,
        .name = "ozz-animation",
        // .root_source_file = b.path(),
    });
    exe.addCSourceFiles(.{
        .files = &.{
            "samples/playback/sample_playback.cc",
            //
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
            "samples/framework/application.cc",
            "samples/framework/image.cc",
            "samples/framework/profile.cc",
            "samples/framework/utils.cc",
            "samples/framework/mesh.cc",
            "samples/framework/internal/camera.cc",
            "samples/framework/internal/immediate.cc",
            "samples/framework/internal/imgui_impl.cc",
            "samples/framework/internal/renderer_impl.cc",
            "samples/framework/internal/shader.cc",
            "samples/framework/internal/shooter.cc",
            "extern/glfw/lib/win32/win32_dllmain.c",
            "extern/glfw/lib/win32/win32_enable.c",
            "extern/glfw/lib/win32/win32_fullscreen.c",
            "extern/glfw/lib/win32/win32_glext.c",
            "extern/glfw/lib/win32/win32_init.c",
            "extern/glfw/lib/win32/win32_joystick.c",
            "extern/glfw/lib/win32/win32_thread.c",
            "extern/glfw/lib/win32/win32_time.c",
            "extern/glfw/lib/win32/win32_window.c",
            "extern/glfw/lib/enable.c",
            "extern/glfw/lib/fullscreen.c",
            "extern/glfw/lib/glext.c",
            "extern/glfw/lib/image.c",
            "extern/glfw/lib/init.c",
            "extern/glfw/lib/input.c",
            "extern/glfw/lib/joystick.c",
            "extern/glfw/lib/stream.c",
            "extern/glfw/lib/tga.c",
            "extern/glfw/lib/thread.c",
            "extern/glfw/lib/time.c",
            "extern/glfw/lib/window.c",
        },
    });
    exe.addIncludePath(b.path("include"));
    exe.addIncludePath(b.path("src"));
    exe.addIncludePath(b.path("samples"));
    exe.addIncludePath(b.path("extern/glfw/include"));
    exe.addIncludePath(b.path("extern/glfw/lib"));
    exe.linkLibCpp();
    exe.linkSystemLibrary("OpenGL32");
    b.installArtifact(exe);

    b.installFile("media/bin/pab_skeleton.ozz", "bin/media/skeleton.ozz");
    b.installFile("media/bin/pab_crossarms.ozz", "bin/media/animation.ozz");

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.cwd = b.path("zig-out/bin");
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
