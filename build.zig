const std = @import("std");
const build_ozz = @import("build_ozz.zig");
const build_glfw = @import("build_glfw.zig");
const build_framework = @import("build_framework.zig");
const CLib = @import("CLib.zig");

const Asset = struct {
    src: []const u8,
    dst: []const u8,
};
const Sample = struct {
    name: []const u8,
    cfiles: []const []const u8,
    assets: []const Asset = &.{},
};
const samples = [_]Sample{
    .{
        .name = "playback",
        .cfiles = &.{"samples/playback/sample_playback.cc"},
        .assets = &.{
            .{
                .src = "media/bin/pab_skeleton.ozz",
                .dst = "bin/media/skeleton.ozz",
            },
            .{
                .src = "media/bin/pab_crossarms.ozz",
                .dst = "bin/media/animation.ozz",
            },
        },
    },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ozz = build_ozz.build(b, target, optimize);
    const glfw = build_glfw.build(b, target, optimize);
    var libs = [2]*const CLib{ &ozz, &glfw };
    const framework = build_framework.build(
        b,
        target,
        optimize,
        &libs,
    );

    for (samples) |sample| {
        // sample.build(b, target, optimize);
        const exe = b.addExecutable(.{
            .target = target,
            .optimize = optimize,
            .name = sample.name,
        });
        ozz.link(b, exe);
        glfw.link(b, exe);
        framework.link(b, exe);
        exe.addCSourceFiles(.{ .files = sample.cfiles });
        exe.linkLibCpp();
        exe.linkSystemLibrary("OpenGL32");
        b.installArtifact(exe);
        for (sample.assets) |asset| {
            b.installFile(asset.src, asset.dst);
        }

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.cwd = b.path("zig-out/bin");
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step(
            b.fmt("run-{s}", .{sample.name}),
            b.fmt("Run: {s}", .{sample.name}),
        );
        run_step.dependOn(&run_cmd.step);
    }

    // const exe_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("src/main.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_exe_unit_tests.step);
}
