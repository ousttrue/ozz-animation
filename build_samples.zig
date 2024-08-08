pub const Asset = struct {
    src: []const u8,
    dst: []const u8,
    fn make(comptime name: []const u8) Asset {
        return .{
            .src = "media/bin/" ++ name ++ ".ozz",
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
            Asset.make("pab_crossarms"),
        },
    },
    .{
        .name = "attach",
        .cfiles = &.{"samples/attach/sample_attach.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("pab_walk"),
        },
    },
    .{
        .name = "blend",
        .cfiles = &.{"samples/blend/sample_blend.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("pab_walk"),
            Asset.make("pab_jog"),
            Asset.make("pab_run"),
        },
    },
    .{
        .name = "partial_blend",
        .cfiles = &.{"samples/partial_blend/sample_partial_blend.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("pab_walk"),
            Asset.make("pab_crossarms"),
        },
    },

    // add_subdirectory(additive)
    // add_subdirectory(baked)
    // add_subdirectory(foot_ik)
    // add_subdirectory(look_at)
    // add_subdirectory(millipede)
    // add_subdirectory(multithread)
    // add_subdirectory(optimize)
    // add_subdirectory(skinning)
    // add_subdirectory(two_bone_ik)
    // add_subdirectory(user_channel)
};
