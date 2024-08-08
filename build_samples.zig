pub const Asset = struct {
    src: []const u8,
    dst: []const u8,
    fn make(comptime name: []const u8) Asset {
        return .{
            .src = "media/bin/" ++ name,
            .dst = "bin/media/" ++ name,
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
            Asset.make("pab_crossarms.ozz"),
        },
    },
    .{
        .name = "attach",
        .cfiles = &.{"samples/attach/sample_attach.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("pab_walk.ozz"),
        },
    },
    .{
        .name = "blend",
        .cfiles = &.{"samples/blend/sample_blend.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("pab_walk.ozz"),
            Asset.make("pab_jog.ozz"),
            Asset.make("pab_run.ozz"),
        },
    },
    .{
        .name = "partial_blend",
        .cfiles = &.{"samples/partial_blend/sample_partial_blend.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("pab_walk.ozz"),
            Asset.make("pab_crossarms.ozz"),
        },
    },
    .{
        .name = "additive",
        .cfiles = &.{"samples/additive/sample_additive.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("pab_walk.ozz"),
            Asset.make("pab_curl_additive.ozz"),
            Asset.make("pab_splay_additive.ozz"),
        },
    },
    // add_subdirectory(baked)
    .{
        .name = "baked",
        .cfiles = &.{"samples/baked/sample_baked.cc"},
        .assets = &.{
            Asset.make("baked_skeleton.ozz"),
            Asset.make("baked_animation.ozz"),
        },
    },
    // add_subdirectory(user_channel)
    .{
        .name = "user_channel",
        .cfiles = &.{"samples/user_channel/sample_user_channel.cc"},
        .assets = &.{
            Asset.make("robot_skeleton.ozz"),
            Asset.make("robot_animation.ozz"),
            Asset.make("robot_track_grasp.ozz"),
        },
    },

    // add_subdirectory(foot_ik)
    // add_subdirectory(look_at)
    // add_subdirectory(millipede)
    // add_subdirectory(multithread)
    // add_subdirectory(optimize)
    // add_subdirectory(skinning)
    // add_subdirectory(two_bone_ik)
};
