const std = @import("std");
const CLib = @import("CLib.zig");

pub fn build(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    deps: []const *const CLib,
) CLib {
    const lib = b.addStaticLibrary(.{
        .name = "framework",
        .target = target,
        .optimize = optimize,
    });
    lib.addCSourceFiles(.{
        .files = &.{
            "framework/application.cc",
            "framework/image.cc",
            "framework/profile.cc",
            "framework/utils.cc",
            "framework/mesh.cc",
            "framework/internal/camera.cc",
            "framework/internal/immediate.cc",
            "framework/internal/imgui_impl.cc",
            "framework/internal/renderer_impl.cc",
            "framework/internal/shader.cc",
            "framework/internal/shooter.cc",
        },
    });
    lib.addIncludePath(b.path("../samples"));
    for (deps) |dep| {
        dep.link(b, lib);
    }
    lib.linkLibCpp();
    return .{
        .include_directories = &.{
            "../samples",
        },
        .lib = lib,
    };
}
