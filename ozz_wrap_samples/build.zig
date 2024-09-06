const std = @import("std");
const zcc = @import("../zcc.zig");
const shdc = @import("../shdc.zig");

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
        exe.addCSourceFile(.{
            .file = b.path("custom_button_behaviour.cpp"),
        });
        // libs
        for (self.libs) |lib| {
            exe.linkSystemLibrary(lib);
        }
        exe.linkLibrary(ozz_lib);

        // create file tree for cimgui and imgui
        const cimgui_dep = b.dependency("cimgui", .{});
        const imgui_dep = b.dependency("imgui", .{});
        const wf = b.addNamedWriteFiles("cimgui");
        _ = wf.addCopyDirectory(cimgui_dep.path(""), "", .{});
        _ = wf.addCopyDirectory(imgui_dep.path(""), "imgui", .{});
        const root = wf.getDirectory();
        exe.addIncludePath(root);
        exe.addCSourceFiles(.{
            .root = root,
            .files = &.{
                b.pathJoin(&.{"cimgui.cpp"}),
                b.pathJoin(&.{ "imgui", "imgui.cpp" }),
                b.pathJoin(&.{ "imgui", "imgui_widgets.cpp" }),
                b.pathJoin(&.{ "imgui", "imgui_draw.cpp" }),
                b.pathJoin(&.{ "imgui", "imgui_tables.cpp" }),
                b.pathJoin(&.{ "imgui", "imgui_demo.cpp" }),
            },
        });

        // sokol
        const sokol_dep = b.dependency("sokol", .{
            .target = target,
            .optimize = optimize,
            .with_sokol_imgui = true,
        });
        exe.root_module.addImport("sokol", sokol_dep.module("sokol"));
        sokol_dep.artifact("sokol_clib").addIncludePath(root);

        // translate-c the cimgui.h file
        // NOTE: always run this with the host target, that way we don't need to inject
        // the Emscripten SDK include path into the translate-C step when building for WASM
        const cimgui_h = cimgui_dep.path("cimgui.h");
        const translateC = b.addTranslateC(.{
            .root_source_file = cimgui_h,
            .target = b.host,
            .optimize = optimize,
        });
        translateC.defineCMacroRaw("CIMGUI_DEFINE_ENUMS_AND_STRUCTS=\"\"");
        const entrypoint = translateC.getOutput();
        // build cimgui as a module with the header file as the entrypoint
        const mod_cimgui = b.addModule("cimgui", .{
            .root_source_file = entrypoint,
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addImport("cimgui", mod_cimgui);

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
) void {
    for (samples) |sample| {
        sample.build(b, target, optimize, ozz);
    }
}

const samples = [_]Sample{
    .{
        .name = "ozz_wrap_playback",
        .c_files = &.{},
        .c_flags = &.{
            "-std=c99",
        },
        .cpp_files = &.{
            // "ozz_wrap_samples/playback/main.cpp",
            "ozz_wrap_samples/playback/sample_playback.cc",
        },
        .cpp_flags = &.{
            "-std=c++20",
        },
        .zig_root_source = "ozz_wrap_samples/playback/main.zig",
        .libs = &.{
            "gdi32",
        },
        .shader = "ozz_wrap_samples/playback/bone.glsl",
    },
};
