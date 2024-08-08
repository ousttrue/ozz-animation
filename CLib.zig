const std = @import("std");

lib: *std.Build.Step.Compile,
include_directories: []const []const u8 = &.{},

pub fn link(self: @This(), b: *std.Build, lib: *std.Build.Step.Compile) void {
    for (self.include_directories) |include| {
        lib.addIncludePath(b.path(include));
    }
    lib.linkLibrary(self.lib);
}
