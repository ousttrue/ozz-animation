const std = @import("std");
const zcc = @import("../zcc.zig");
const shdc = @import("../shdc.zig");
const SokolLib = @import("../build_sokol_and_imgui.zig").SokolLib;

const Sample = struct {
    name: []const u8,
    c_files: []const []const u8 = &.{},
    c_flags: []const []const u8 = &.{},
    cpp_files: []const []const u8 = &.{},
    cpp_flags: []const []const u8 = &.{},
    zig_root_source: ?[]const u8 = null,
    libs: []const []const u8 = &.{},
    shader: ?[]const u8 = null,

    fn build(
        self: @This(),
        b: *std.Build,
        target: std.Build.ResolvedTarget,
        optimize: std.builtin.OptimizeMode,
        ozz_lib: *std.Build.Step.Compile,
        sokol: SokolLib,
    ) void {
        const exe = b.addExecutable(.{
            .target = target,
            .optimize = optimize,
            .name = self.name,
            .root_source_file = if (self.zig_root_source) |src| b.path(src) else null,
        });
        exe.addIncludePath(b.path(""));
        if (self.shader) |shader| {
            exe.step.dependOn(shdc.shdc_zig(b, target, shader));
            sokol.inject_zig(exe);
        }

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
        exe.linkLibrary(ozz_lib);

        // rowmath
        const rowmath_dep = b.dependency("rowmath", .{});
        exe.root_module.addImport("rowmath", rowmath_dep.module("rowmath"));

        // ozz
        exe.addIncludePath(b.path("include"));

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
    ozz: *std.Build.Step.Compile,
    sokol: SokolLib,
) void {
    for (samples) |sample| {
        sample.build(b, target, optimize, ozz, sokol);
    }
}

const samples = [_]Sample{
    .{
        .name = "ozz_wrap_playback",
        .zig_root_source = "ozz_wrap_samples/playback/main.zig",
        .libs = &.{
            "gdi32",
        },
        .shader = "ozz_wrap_samples/playback/bone.glsl",
    },
};
