const std = @import("std");
const zcc = @import("zcc.zig");
const shdc = @import("shdc.zig");
const sokol_build = @import("build_sokol_and_imgui.zig");

pub fn build(
    b: *std.Build,
) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // zig-0.13.0 wasm32-emscripten libcpp issue. buidl by meson using emsdk.
    // zig-0.13.0 x86_64-windows libcpp issue. build by meson using msvc etc.
    const sokol_lib = sokol_build.build(b, target, optimize);

    const utils = b.addModule("utils", .{
        .root_source_file = b.path("utils/utils.zig"),
    });
    const utils_shader_steps = [2]*std.Build.Step{
        shdc.shdc_zig(b, target, "utils/bone.glsl"),
        shdc.shdc_zig(b, target, "utils/joint.glsl"),
    };

    const rowmath_dep = b.dependency("rowmath", .{
        .target = target,
        .optimize = optimize,
    });
    const rowmath_module = rowmath_dep.module("rowmath");
    utils.addImport("rowmath", rowmath_module);
    utils.addImport("sokol", sokol_lib.sokol_mod);
    utils.addImport("cimgui", sokol_lib.cimgui_mod);

    const ozz_wrap_dep = b.dependency("ozz_wrap", .{
        .target = target,
        .optimize = optimize,
    });

    // const root = b.path("../..");
    for (samples) |sample| {
        sample.build(
            b,
            target,
            optimize,
            ozz_wrap_dep,
            sokol_lib,
            utils,
            &utils_shader_steps,
            rowmath_dep.module("rowmath"),
        );
    }
}

pub const Sample = struct {
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
        ozz_wrap_dep: *std.Build.Dependency,
        sokol: sokol_build.SokolLib,
        utils: *std.Build.Module,
        utils_shader_steps: []const *std.Build.Step,
        rowmath_module: *std.Build.Module,
    ) void {
        const exe = b.addExecutable(.{
            .target = target,
            .optimize = optimize,
            .name = self.name,
            .root_source_file = if (self.zig_root_source) |src| b.path(src) else null,
        });
        exe.linkLibC();
        exe.addIncludePath(b.path("ozz_wrap_samples"));
        exe.addCSourceFiles(.{
            .files = &.{
                "myalloc.cpp",
            },
        });
        exe.root_module.addImport("utils", utils);
        for (utils_shader_steps) |shader_step| {
            exe.step.dependOn(shader_step);
        }

        exe.addIncludePath(b.path(""));
        exe.addIncludePath(ozz_wrap_dep.path(""));
        sokol.inject_zig(exe);

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
        exe.addLibraryPath(ozz_wrap_dep.namedWriteFiles("build").getDirectory().path(b, "lib"));
        exe.linkSystemLibrary("ozz_wrap");

        // rowmath
        exe.root_module.addImport("rowmath", rowmath_module);

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

pub const samples = [_]Sample{
    .{
        .name = "playback",
        .zig_root_source = "playback/main.zig",
        .libs = &.{
            "gdi32",
        },
    },
    .{
        .name = "millipede",
        .zig_root_source = "millipede/main.zig",
        .libs = &.{
            "gdi32",
        },
    },
};
