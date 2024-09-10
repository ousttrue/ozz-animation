const std = @import("std");

pub const SokolLib = struct {
    sokol_lib: *std.Build.Step.Compile,
    sokol_mod: *std.Build.Module,
    cimgui_mod: *std.Build.Module,
    sokol_includes: std.ArrayList([]const u8),

    pub fn inject_zig(self: @This(), compile: *std.Build.Step.Compile) void {
        compile.root_module.addImport("sokol", self.sokol_mod);
        compile.root_module.addImport("cimgui", self.cimgui_mod);
    }

    pub fn inject_lib(
        self: @This(),
        compile: *std.Build.Step.Compile,
    ) void {
        compile.linkLibrary(self.sokol_lib);
        for (self.sokol_includes.items) |include| {
            // std.debug.print("=> {s}\n", .{include});
            compile.addIncludePath(.{ .cwd_relative = include });
        }
    }
};

pub fn build(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) SokolLib {
    // create file tree for cimgui and imgui
    const cimgui_dep = b.dependency("cimgui", .{});
    const imgui_dep = b.dependency("imgui", .{});
    const wf = b.addNamedWriteFiles("cimgui");
    _ = wf.addCopyDirectory(cimgui_dep.path(""), "", .{});
    _ = wf.addCopyDirectory(imgui_dep.path(""), "imgui", .{});
    const root = wf.getDirectory();

    // sokol
    const sokol_dep = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
        .with_sokol_imgui = true,
    });
    const sokol_lib = sokol_dep.artifact("sokol_clib");
    sokol_lib.step.dependOn(&wf.step);
    sokol_lib.addIncludePath(root);

    // lib
    sokol_lib.addCSourceFiles(.{
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
    sokol_lib.addCSourceFile(.{
        .file = b.path("custom_button_behaviour.cpp"),
    });

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
    translateC.step.dependOn(&wf.step);
    const entrypoint = translateC.getOutput();
    // build cimgui as a module with the header file as the entrypoint
    const mod_cimgui = b.addModule("cimgui", .{
        .root_source_file = entrypoint,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    mod_cimgui.linkLibrary(sokol_lib);

    var list = std.ArrayList([]const u8).init(b.allocator);
    list.append(sokol_dep.path("src/sokol/c").getPath(b)) catch unreachable;
    list.append(imgui_dep.path("").getPath(b)) catch unreachable;

    return .{
        .sokol_lib = sokol_lib,
        .sokol_mod = sokol_dep.module("sokol"),
        .cimgui_mod = mod_cimgui,
        .sokol_includes = list,
    };
}
