const std = @import("std");
const build_samples = @import("build_samples.zig");
const build_framework = @import("build_framework.zig");
const build_ozz = @import("build_ozz.zig");
const build_glfw = @import("build_glfw.zig");
const CLib = @import("CLib.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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
        exe.addCSourceFiles(.{
            .files = sample.cfiles,
        });
        framework.link(b, exe);
        ozz.link(b, exe);
        glfw.link(b, exe);
        exe.linkSystemLibrary("OpenGL32");
        b.installArtifact(exe);

        for (sample.assets) |asset| {
            b.installFile(asset.src, asset.dst);
        }
    }
}
