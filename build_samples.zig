pub const Asset = struct {
    src: []const u8,
    dst: []const u8,
    fn make(comptime name: []const u8) Asset {
        return .{
            .src = "media/bin/pab_" ++ name ++ ".ozz",
            .dst = "bin/media/" ++ name ++ ".ozz",
        };
    }
};
const SKELETON = Asset{
    .src = "media/bin/pab_skeleton.ozz",
    .dst = "bin/media/skeleton.ozz",
};
pub const Sample = struct {
    name: []const u8,
    cfiles: []const []const u8,
    assets: []const Asset = &.{},
};

pub const samples = [_]Sample{
    .{
        .name = "playback",
        .cfiles = &.{"samples/playback/sample_playback.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("crossarms"),
        },
    },
    .{
        .name = "attach",
        .cfiles = &.{"samples/attach/sample_attach.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("walk"),
        },
    },
    .{
        .name = "blend",
        .cfiles = &.{"samples/blend/sample_blend.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("walk"),
            Asset.make("jog"),
            Asset.make("run"),
        },
    },
    // add_subdirectory(blend)

    // add_subdirectory(additive)
    // add_subdirectory(baked)
    // add_subdirectory(foot_ik)
    // add_subdirectory(look_at)
    // add_subdirectory(millipede)
    // add_subdirectory(multithread)
    // add_subdirectory(optimize)
    // add_subdirectory(partial_blend)
    // add_subdirectory(skinning)
    // add_subdirectory(two_bone_ik)
    // add_subdirectory(user_channel)
};
