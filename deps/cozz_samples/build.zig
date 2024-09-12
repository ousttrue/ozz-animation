const std = @import("std");
const builtin = @import("builtin");
const zcc = @import("zcc.zig");
const sokol_build = @import("build_sokol_and_imgui.zig");
const emsdk_zig = @import("emsdk-zig");

const debug_flags = [_][]const u8{
    "-sASSERTIONS",
    "-g4",
};

const release_flags = [_][]const u8{};

const emcc_extra_args = [_][]const u8{
    "-sTOTAL_MEMORY=512MB",
    "-sSTACK_SIZE=256MB",
    "-sALLOW_MEMORY_GROWTH=0",
    "-sUSE_OFFSET_CONVERTER=1",
} ++ (if (builtin.mode == .Debug) debug_flags else release_flags);

pub fn build(
    b: *std.Build,
) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // zig-0.13.0 wasm32-emscripten libcpp issue. buidl by meson using emsdk.
    // zig-0.13.0 x86_64-windows libcpp issue. build by meson using msvc etc.
    const sokol_lib = sokol_build.build(b, target, optimize);
    if (target.result.isWasm()) {
        const emsdk_zig_dep = b.dependency("emsdk-zig", .{});
        const emsdk_dep = emsdk_zig_dep.builder.dependency("emsdk", .{});
        const emsdk_incl_path = emsdk_dep.path("upstream/emscripten/cache/sysroot/include");
        sokol_lib.sokol_lib.addSystemIncludePath(emsdk_incl_path);
    }

    const rowmath_dep = b.dependency("rowmath", .{
        .target = target,
        .optimize = optimize,
    });

    const cozz_dep = b.dependency("cozz", .{
        .target = target,
        .optimize = optimize,
    });
    const cozz = cozz_dep.artifact("cozz");
    cozz.root_module.addImport("sokol", sokol_lib.sokol_mod);
    cozz.root_module.addImport("cimgui", sokol_lib.cimgui_mod);
    cozz.root_module.addImport("rowmath", rowmath_dep.module("rowmath"));

    // const root = b.path("../..");
    if (target.result.isWasm()) {
        const wf = b.addNamedWriteFiles("build");
        for (samples) |sample| {
            sample.buildWasm(
                b,
                target,
                optimize,
                cozz_dep,
                sokol_lib,
                rowmath_dep.module("rowmath"),
                wf,
            );
        }
    } else {
        for (samples) |sample| {
            sample.buildNative(
                b,
                target,
                optimize,
                cozz_dep,
                sokol_lib,
                rowmath_dep.module("rowmath"),
            );
        }
    }
}

pub const Sample = struct {
    name: []const u8,
    c_files: []const []const u8 = &.{},
    c_flags: []const []const u8 = &.{},
    cpp_files: []const []const u8 = &.{},
    cpp_flags: []const []const u8 = &.{},
    zig_root_source: ?[]const u8 = null,
    shader: ?[]const u8 = null,

    fn buildNative(
        self: @This(),
        b: *std.Build,
        target: std.Build.ResolvedTarget,
        optimize: std.builtin.OptimizeMode,
        cozz_dep: *std.Build.Dependency,
        sokol: sokol_build.SokolLib,
        rowmath_module: *std.Build.Module,
    ) void {
        const exe = b.addExecutable(.{
            .target = target,
            .optimize = optimize,
            .name = self.name,
            .root_source_file = if (self.zig_root_source) |src| b.path(src) else null,
        });
        exe.addIncludePath(b.path("cozz_samples"));
        exe.addIncludePath(b.path(""));
        exe.addIncludePath(cozz_dep.path(""));
        exe.root_module.addImport("cozz", &cozz_dep.artifact("cozz").root_module);
        exe.step.dependOn(&cozz_dep.artifact("cozz").step);
        sokol.inject_zig(exe);

        // c
        exe.addCSourceFiles(.{
            .files = self.c_files,
            .flags = self.c_flags,
        });
        // cpp
        exe.addCSourceFiles(.{
            .files = self.cpp_files,
            .flags = self.cpp_flags,
        });

        // rowmath
        exe.root_module.addImport("rowmath", rowmath_module);

        // ozz
        exe.addIncludePath(b.path("include"));

        // libs
        exe.addLibraryPath(cozz_dep.namedWriteFiles(
            "build",
        ).getDirectory().path(b, "lib"));
        exe.linkSystemLibrary("gdi32");
        exe.linkSystemLibrary("cozz");

        // install exe & run
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

    fn buildWasm(
        self: @This(),
        b: *std.Build,
        target: std.Build.ResolvedTarget,
        optimize: std.builtin.OptimizeMode,
        cozz_dep: *std.Build.Dependency,
        sokol: sokol_build.SokolLib,
        rowmath_module: *std.Build.Module,
        wf: *std.Build.Step.WriteFile,
    ) void {
        const lib =
            b.addStaticLibrary(.{
            .target = target,
            .optimize = optimize,
            .name = self.name,
            .root_source_file = if (self.zig_root_source) |src| b.path(src) else null,
            // required
            .pic = true,
        });
        lib.addIncludePath(b.path("cozz_samples"));
        lib.addIncludePath(b.path(""));
        lib.addIncludePath(cozz_dep.path(""));
        sokol.inject_zig(lib);

        const cozz = cozz_dep.artifact("cozz");
        lib.root_module.addImport("cozz", &cozz.root_module);
        lib.step.dependOn(&cozz.step);

        // c
        lib.addCSourceFiles(.{
            .files = self.c_files,
            .flags = self.c_flags,
        });
        // cpp
        lib.addCSourceFiles(.{
            .files = self.cpp_files,
            .flags = self.cpp_flags,
        });

        // rowmath
        lib.root_module.addImport("rowmath", rowmath_module);

        // ozz
        lib.addIncludePath(b.path("include"));

        const emsdk_zig_dep = b.dependency("emsdk-zig", .{});
        const emsdk_dep = emsdk_zig_dep.builder.dependency("emsdk", .{});

        // fix sysroot
        const emsdk_incl_path = emsdk_dep.path(
            "upstream/emscripten/cache/sysroot/include",
        );
        lib.addSystemIncludePath(emsdk_incl_path);

        // create a build step which invokes the Emscripten linker
        const emcc = try emsdk_zig.emLinkCommand(b, emsdk_dep, .{
            .lib_main = lib,
            .target = target,
            .optimize = optimize,
            .use_webgl2 = true,
            .use_emmalloc = true,
            .use_filesystem = true,
            .shell_file_path = sokol.sokol_dep.path(
                "src/sokol/web/shell.html",
            ).getPath(b),
            .release_use_closure = false,
            .extra_before = &emcc_extra_args,
        });

        emcc.addArg("-o");
        const out_file = emcc.addOutputFileArg(b.fmt("{s}.html", .{self.name}));

        // link cozz as sidemodule
        emcc.addArg("-sMAIN_MODULE=1");
        const cozz_wf = cozz_dep.namedWriteFiles("build");
        emcc.addFileArg(cozz_wf.getDirectory().path(b, "web/cozz.wasm"));
        emcc.addArg("-sERROR_ON_UNDEFINED_SYMBOLS=0");

        // the emcc linker creates 3 output files (.html, .wasm and .js)
        _ = wf.addCopyDirectory(out_file.dirname(), "web", .{});
        wf.step.dependOn(&emcc.step);
    }
};

pub const samples = [_]Sample{
    .{
        .name = "playback",
        .zig_root_source = "playback/main.zig",
    },
    .{
        .name = "attach",
        .zig_root_source = "attach/main.zig",
    },
    .{
        .name = "millipede",
        .zig_root_source = "millipede/main.zig",
    },
};
