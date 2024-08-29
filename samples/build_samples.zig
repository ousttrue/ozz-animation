pub const Asset = struct {
    src: []const u8,
    dst: []const u8,
    fn make(comptime name: []const u8) Asset {
        return .{
            .src = "../media/bin/" ++ name,
            .dst = "bin/media/" ++ name,
        };
    }
};
const SKELETON = Asset{
    .src = "../media/bin/pab_skeleton.ozz",
    .dst = "bin/media/pab_skeleton.ozz",
};
pub const Sample = struct {
    name: []const u8,
    cfiles: []const []const u8,
    assets: []const Asset = &.{},
};

pub const samples = [_]Sample{
    .{
        .name = "playback",
        .cfiles = &.{"playback/sample_playback.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("pab_crossarms.ozz"),
        },
    },
    .{
        .name = "attach",
        .cfiles = &.{"attach/sample_attach.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("pab_walk.ozz"),
        },
    },
    .{
        .name = "blend",
        .cfiles = &.{"blend/sample_blend.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("pab_walk.ozz"),
            Asset.make("pab_jog.ozz"),
            Asset.make("pab_run.ozz"),
        },
    },
    .{
        .name = "partial_blend",
        .cfiles = &.{"partial_blend/sample_partial_blend.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("pab_walk.ozz"),
            Asset.make("pab_crossarms.ozz"),
        },
    },
    .{
        .name = "additive",
        .cfiles = &.{"additive/sample_additive.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("pab_walk.ozz"),
            Asset.make("pab_curl_additive.ozz"),
            Asset.make("pab_splay_additive.ozz"),
        },
    },
    .{
        .name = "baked",
        .cfiles = &.{"baked/sample_baked.cc"},
        .assets = &.{
            Asset.make("baked_skeleton.ozz"),
            Asset.make("baked_animation.ozz"),
        },
    },
    .{
        .name = "user_channel",
        .cfiles = &.{"user_channel/sample_user_channel.cc"},
        .assets = &.{
            Asset.make("robot_skeleton.ozz"),
            Asset.make("robot_animation.ozz"),
            Asset.make("robot_track_grasp.ozz"),
        },
    },
    .{
        .name = "optimize",
        .cfiles = &.{"optimize/sample_optimize.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("pab_atlas_raw.ozz"),
        },
    },
    .{
        .name = "millipede",
        .cfiles = &.{"millipede/sample_millipede.cc"},
        .assets = &.{},
    },
    .{
        .name = "two_bone_ik",
        .cfiles = &.{"two_bone_ik/sample_two_bone_ik.cc"},
        .assets = &.{
            Asset.make("robot_skeleton.ozz"),
        },
    },
    .{
        .name = "look_at",
        .cfiles = &.{"look_at/sample_look_at.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("pab_crossarms.ozz"),
            Asset.make("arnaud_mesh.ozz"),
        },
    },
    .{
        .name = "foot_ik",
        .cfiles = &.{"foot_ik/sample_foot_ik.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("pab_crossarms.ozz"),
            Asset.make("arnaud_mesh.ozz"),
            Asset.make("floor.ozz"),
        },
    },
    .{
        .name = "skinning",
        .cfiles = &.{"skinning/sample_skinning.cc"},
        .assets = &.{
            Asset.make("ruby_mesh.ozz"),
            Asset.make("ruby_skeleton.ozz"),
            Asset.make("ruby_animation.ozz"),
        },
    },

    .{
        .name = "multithread",
        .cfiles = &.{"multithread/sample_multithread.cc"},
        .assets = &.{
            SKELETON,
            Asset.make("pab_walk.ozz"),
        },
    },
};
