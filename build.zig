const std = @import("std");
const build_ozz = @import("build_ozz.zig");
const build_glfw = @import("build_glfw.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ozz = build_ozz.build(b, target, optimize);
    const glfw = build_glfw.build(b, target, optimize);

    const exe = b.addExecutable(.{
        .target = target,
        .optimize = optimize,
        .name = "ozz-animation",
        // .root_source_file = b.path(),
    });
    exe.linkLibrary(ozz.lib);
    exe.linkLibrary(glfw.lib);
    exe.addCSourceFiles(.{
        .files = &.{
            "samples/playback/sample_playback.cc",
            //
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
        },
    });
    for (ozz.include_directories) |include| {
        exe.addIncludePath(b.path(include));
    }
    for (glfw.include_directories) |include| {
        exe.addIncludePath(b.path(include));
    }

    exe.addIncludePath(b.path("samples"));
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
