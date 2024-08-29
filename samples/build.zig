const std = @import("std");
const build_samples = @import("build_samples.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    for (build_samples.samples) |sample| {
        const exe = b.addExecutable(.{
            .name = sample.name,
            .target = target,
            .optimize = optimize,
        });
        b.installArtifact(exe);
    }
}
