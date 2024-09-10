const std = @import("std");
const CLib = @import("CLib.zig");

pub fn build(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root: std.Build.LazyPath,
    deps: []const *const CLib,
) CLib {
    const lib = b.addStaticLibrary(.{
        .name = "framework",
        .target = target,
        .optimize = optimize,
    });
    lib.addCSourceFiles(.{
        .root = root,
        .files = &.{
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
    lib.addIncludePath(root.path(b, "extern/glfw/include"));
    lib.addIncludePath(root.path(b, "samples"));
    for (deps) |dep| {
        dep.link(b, lib, root);
    }
    lib.linkLibCpp();
    return .{
        .include_directories = &.{
            "samples",
        },
        .lib = lib,
    };
}
