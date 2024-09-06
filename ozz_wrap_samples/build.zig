const std = @import("std");
const zcc = @import("../zcc.zig");

const Sample = struct {
    name: []const u8,
    c_files: []const []const u8 = &.{},
    c_flags: []const []const u8 = &.{},
    cpp_files: []const []const u8 = &.{},
    cpp_flags: []const []const u8 = &.{},
    libs: []const []const u8 = &.{},
    fn build(
        self: @This(),
        b: *std.Build,
        target: std.Build.ResolvedTarget,
        optimize: std.builtin.OptimizeMode,
    ) void {
        const exe = b.addExecutable(.{
            .target = target,
            .optimize = optimize,
            .name = self.name,
        });

        // c
        exe.linkLibC();
        exe.addCSourceFiles(.{
            .files = self.c_files,
            .flags = self.c_flags,
        });
        // cpp
        exe.linkLibCpp();
        exe.addCSourceFiles(.{
            .files = self.cpp_files,
            .flags = self.cpp_flags,
        });
        // libs
        for (self.libs) |lib| {
            exe.linkSystemLibrary(lib);
        }

        const sokol_dep = b.dependency("sokol", .{});
        exe.addIncludePath(sokol_dep.path(""));

        const install = b.addInstallArtifact(exe, .{});
        b.getInstallStep().dependOn(&install.step);
        install.step.dependOn(zcc.createStep(b, .{ .targets = &.{exe} }));

        const run = b.addRunArtifact(exe);
        run.step.dependOn(&install.step);

        const step = b.step(
            b.fmt("run-{s}", .{self.name}),
            b.fmt("Run {s}", .{self.name}),
        );
        step.dependOn(&run.step);
    }
};

pub fn build(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    for (samples) |sample| {
        sample.build(b, target, optimize);
    }
}

const samples = [_]Sample{
    .{
        .name = "ozz_wrap_playback",
        .c_files = &.{
            "ozz_wrap_samples/playback/main.c",
        },
        .c_flags = &.{
            "-std=c99",
        },
        .cpp_files = &.{
            "ozz_wrap_samples/playback/sample_playback.cc",
        },
        .cpp_flags = &.{
            "-std=c++20",
        },
        .libs = &.{
            "gdi32",
        },
    },
};
