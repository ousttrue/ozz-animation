const std = @import("std");

lib: *std.Build.Step.Compile,
include_directories: []const []const u8 = &.{},

pub fn link(
    self: @This(),
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    root: std.Build.LazyPath,
) void {
    for (self.include_directories) |include| {
        lib.addIncludePath(root.path(b, include));
    }
    lib.linkLibrary(self.lib);
}
