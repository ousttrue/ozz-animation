pub const Sample = struct {
    name: []const u8,
    cfiles: []const []const u8,
    includes: []const []const u8 = &.{},
    windows_libs: []const []const u8 = &.{},
    sokol_shader: ?[]const u8 = null,
    use_gtest: bool = false,
};

pub const samples = [_]Sample{
    .{
        .name = "playback",
        .cfiles = &.{"samples/playback/sample_playback.cc"},
        .windows_libs = &.{
            "OpenGL32",
            "Gdi32",
        },
    },
    .{
        .name = "attach",
        .cfiles = &.{"samples/attach/sample_attach.cc"},
        .windows_libs = &.{
            "OpenGL32",
            "Gdi32",
        },
    },
    .{
        .name = "blend",
        .cfiles = &.{"samples/blend/sample_blend.cc"},
        .windows_libs = &.{
            "OpenGL32",
            "Gdi32",
        },
    },
    .{
        .name = "partial_blend",
        .cfiles = &.{"samples/partial_blend/sample_partial_blend.cc"},
        .windows_libs = &.{
            "OpenGL32",
            "Gdi32",
        },
    },
    .{
        .name = "additive",
        .cfiles = &.{"samples/additive/sample_additive.cc"},
        .windows_libs = &.{
            "OpenGL32",
            "Gdi32",
        },
    },
    .{
        .name = "baked",
        .cfiles = &.{"samples/baked/sample_baked.cc"},
        .windows_libs = &.{
            "OpenGL32",
            "Gdi32",
        },
    },
    .{
        .name = "user_channel",
        .cfiles = &.{"samples/user_channel/sample_user_channel.cc"},
        .windows_libs = &.{
            "OpenGL32",
            "Gdi32",
        },
    },
    .{
        .name = "optimize",
        .cfiles = &.{"samples/optimize/sample_optimize.cc"},
        .windows_libs = &.{
            "OpenGL32",
            "Gdi32",
        },
    },
    .{
        .name = "millipede",
        .cfiles = &.{"samples/millipede/sample_millipede.cc"},
        .windows_libs = &.{
            "OpenGL32",
            "Gdi32",
        },
    },
    .{
        .name = "two_bone_ik",
        .cfiles = &.{"samples/two_bone_ik/sample_two_bone_ik.cc"},
        .windows_libs = &.{
            "OpenGL32",
            "Gdi32",
        },
    },
    .{
        .name = "look_at",
        .cfiles = &.{"samples/look_at/sample_look_at.cc"},
        .windows_libs = &.{
            "OpenGL32",
            "Gdi32",
        },
    },
    .{
        .name = "foot_ik",
        .cfiles = &.{"samples/foot_ik/sample_foot_ik.cc"},
        .windows_libs = &.{
            "OpenGL32",
            "Gdi32",
        },
    },
    .{
        .name = "skinning",
        .cfiles = &.{"samples/skinning/sample_skinning.cc"},
        .windows_libs = &.{
            "OpenGL32",
            "Gdi32",
        },
    },

    .{
        .name = "multithread",
        .cfiles = &.{"samples/multithread/sample_multithread.cc"},
        .windows_libs = &.{
            "OpenGL32",
            "Gdi32",
        },
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
    // howto
    .{
        .name = "custom_animation_importer",
        .cfiles = &.{"howtos/custom_animation_importer.cc"},
    },
    .{
        .name = "custom_skeleton_importer",
        .cfiles = &.{"howtos/custom_skeleton_importer.cc"},
    },
    .{
        .name = "load_from_file",
        .cfiles = &.{"howtos/load_from_file.cc"},
    },
    // tests
    .{
        .name = "test_base_maths",
        .cfiles = &.{
            "extern/gtest/fused-src/gtest/gtest-all.cc",
            "extern/gtest/fused-src/gtest/gtest_main.cc",
            "test/base/maths/box_tests.cc",
            "test/base/maths/math_archive_tests.cc",
            "test/base/maths/math_ex_tests.cc",
            "test/base/maths/quaternion_tests.cc",
            "test/base/maths/rect_tests.cc",
            "test/base/maths/simd_float4x4_tests.cc",
            "test/base/maths/simd_float_math_tests.cc",
            "test/base/maths/simd_int_math_tests.cc",
            "test/base/maths/simd_math_archive_tests.cc",
            "test/base/maths/simd_math_transpose_tests.cc",
            "test/base/maths/simd_quaternion_math_tests.cc",
            "test/base/maths/soa_float4x4_tests.cc",
            "test/base/maths/soa_float_tests.cc",
            "test/base/maths/soa_math_archive_tests.cc",
            "test/base/maths/soa_quaternion_tests.cc",
            "test/base/maths/soa_transform_tests.cc",
            "test/base/maths/transform_tests.cc",
            "test/base/maths/vec_float_tests.cc",
        },
        .use_gtest = true,
    },
};
