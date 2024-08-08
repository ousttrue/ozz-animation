const std = @import("std");
const CLib = @import("CLib.zig");

pub fn build(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) CLib {
    const lib = b.addStaticLibrary(.{
        .name = "glfw",
        .target = target,
        .optimize = optimize,
    });
    lib.addCSourceFiles(.{
        .files = &.{
            "extern/glfw/lib/win32/win32_dllmain.c",
            "extern/glfw/lib/win32/win32_enable.c",
            "extern/glfw/lib/win32/win32_fullscreen.c",
            "extern/glfw/lib/win32/win32_glext.c",
            "extern/glfw/lib/win32/win32_init.c",
            "extern/glfw/lib/win32/win32_joystick.c",
            "extern/glfw/lib/win32/win32_thread.c",
            "extern/glfw/lib/win32/win32_time.c",
            "extern/glfw/lib/win32/win32_window.c",
            "extern/glfw/lib/enable.c",
            "extern/glfw/lib/fullscreen.c",
            "extern/glfw/lib/glext.c",
            "extern/glfw/lib/image.c",
            "extern/glfw/lib/init.c",
            "extern/glfw/lib/input.c",
            "extern/glfw/lib/joystick.c",
            "extern/glfw/lib/stream.c",
            "extern/glfw/lib/tga.c",
            "extern/glfw/lib/thread.c",
            "extern/glfw/lib/time.c",
            "extern/glfw/lib/window.c",
        },
    });
    lib.linkLibC();
    lib.addIncludePath(b.path("extern/glfw/include"));
    lib.addIncludePath(b.path("extern/glfw/lib"));
    return .{
        .include_directories = &.{
            "extern/glfw/include",
        },
        .lib = lib,
    };
}
