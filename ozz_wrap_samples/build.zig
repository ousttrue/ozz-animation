const std = @import("std");
const Sample = struct {
    name: []const u8,
    srcs: []const []const u8 = &.{},
    cflags: []const []const u8 = &.{},
    fn build(
        self: @This(),
        b: *std.Build,
        target: std.Build.ResolvedTarget,
        optimize: std.builtin.OptimizeMode,
    ) void {
        const exe = b.addExecutable(.{
            .target = target,
            .optimize = optimize,
            .name = self.name,
        });

        exe.addCSourceFiles(.{
            .files = self.srcs,
        });
        const sokol_dep = b.dependency("sokol", .{});
        exe.addIncludePath(sokol_dep.path(""));

        const install = b.addInstallArtifact(exe, .{});
        b.getInstallStep().dependOn(&install.step);

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
) void {
    for (samples) |sample| {
        sample.build(b, target, optimize);
    }
}

const samples = [_]Sample{
    .{
        .name = "ozz_wrap_playback",
        .srcs = &.{
            "ozz_wrap_samples/sample_playback.cc",
        },
        .cflags = &.{
            "-std=c99",
        },
    },
};
