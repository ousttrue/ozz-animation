pub const Sample = struct {
    name: []const u8,
    cfiles: []const []const u8,
    includes: []const []const u8 = &.{},
    sokol_shader: ?[]const u8 = null,
};

pub const samples = [_]Sample{
    .{
        .name = "playback",
        .cfiles = &.{"samples/playback/sample_playback.cc"},
    },
    .{
        .name = "attach",
        .cfiles = &.{"samples/attach/sample_attach.cc"},
    },
    .{
        .name = "blend",
        .cfiles = &.{"samples/blend/sample_blend.cc"},
    },
    .{
        .name = "partial_blend",
        .cfiles = &.{"samples/partial_blend/sample_partial_blend.cc"},
    },
    .{
        .name = "additive",
        .cfiles = &.{"samples/additive/sample_additive.cc"},
    },
    .{
        .name = "baked",
        .cfiles = &.{"samples/baked/sample_baked.cc"},
    },
    .{
        .name = "user_channel",
        .cfiles = &.{"samples/user_channel/sample_user_channel.cc"},
    },
    .{
        .name = "optimize",
        .cfiles = &.{"samples/optimize/sample_optimize.cc"},
    },
    .{
        .name = "millipede",
        .cfiles = &.{"samples/millipede/sample_millipede.cc"},
    },
    .{
        .name = "two_bone_ik",
        .cfiles = &.{"samples/two_bone_ik/sample_two_bone_ik.cc"},
    },
    .{
        .name = "look_at",
        .cfiles = &.{"samples/look_at/sample_look_at.cc"},
    },
    .{
        .name = "foot_ik",
        .cfiles = &.{"samples/foot_ik/sample_foot_ik.cc"},
    },
    .{
        .name = "skinning",
        .cfiles = &.{"samples/skinning/sample_skinning.cc"},
    },

    .{
        .name = "multithread",
        .cfiles = &.{"samples/multithread/sample_multithread.cc"},
    },

    // tool
    .{
        .name = "dump2ozz",
        .cfiles = &.{
            "src/animation/offline/tools/dump2ozz.cc",
            "src/animation/offline/tools/import2ozz.cc",
            "extern/jsoncpp/dist/jsoncpp.cpp",
            "src/animation/offline/tools/import2ozz_config.cc",
            "src/animation/offline/tools/import2ozz_skel.cc",
            "src/animation/offline/tools/import2ozz_anim.cc",
            "src/animation/offline/tools/import2ozz_track.cc",
        },
        .includes = &.{
            "extern/jsoncpp/dist",
            "src",
        },
    },
    .{
        .name = "gltf2ozz",
        .cfiles = &.{
            "src/animation/offline/gltf/gltf2ozz.cc",
            "src/animation/offline/tools/import2ozz.cc",
            "extern/jsoncpp/dist/jsoncpp.cpp",
            "src/animation/offline/tools/import2ozz_config.cc",
            "src/animation/offline/tools/import2ozz_skel.cc",
            "src/animation/offline/tools/import2ozz_anim.cc",
            "src/animation/offline/tools/import2ozz_track.cc",
        },
        .includes = &.{
            "extern/jsoncpp/dist",
            "src",
        },
    },

    // https://github.com/CU-Production/ozz_test.git
    .{
        .name = "ozz_anim",
        .cfiles = &.{
            "samples/ozz_anim/ozz_anim.cpp",
            "extern/imgui/imgui.cpp",
            "extern/imgui/imgui_demo.cpp",
            "extern/imgui/imgui_draw.cpp",
            "extern/imgui/imgui_widgets.cpp",
            "extern/imgui/imgui_tables.cpp",
        },
        .includes = &.{
            "extern/sokol",
            "extern/sokol/util",
            "extern/imgui",
        },
    },
    .{
        .name = "ozz_skin",
        .cfiles = &.{
            "samples/ozz_skin/ozz_skin.cpp",
            "extern/imgui/imgui.cpp",
            "extern/imgui/imgui_demo.cpp",
            "extern/imgui/imgui_draw.cpp",
            "extern/imgui/imgui_widgets.cpp",
            "extern/imgui/imgui_tables.cpp",
        },
        .includes = &.{
            "extern/sokol",
            "extern/sokol/util",
            "extern/imgui",
        },
        .sokol_shader = "samples/ozz_skin/ozz_skin.glsl",
    },
};
