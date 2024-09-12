project(
    'ozz-animation',
    'c',
    'cpp',
    version: '0.15.0',
    default_options: ['cpp_std=c++20'],
)

srcs = [
    'deps/cozz/cozz.cpp',

    'src/base/memory/allocator.cc',
    'src/base/platform.cc',
    'src/base/log.cc',
    'src/base/containers/string_archive.cc',
    'src/base/io/archive.cc',
    'src/base/io/stream.cc',
    'src/base/maths/box.cc',
    'src/base/maths/simd_math.cc',
    'src/base/maths/math_archive.cc',
    'src/base/maths/soa_math_archive.cc',
    'src/base/maths/simd_math_archive.cc',
    'src/base/encode/group_varint.cc',

    'src/animation/runtime/animation.cc',
    'src/animation/runtime/animation_utils.cc',
    'src/animation/runtime/blending_job.cc',
    'src/animation/runtime/ik_aim_job.cc',
    'src/animation/runtime/ik_two_bone_job.cc',
    'src/animation/runtime/local_to_model_job.cc',
    'src/animation/runtime/sampling_job.cc',
    'src/animation/runtime/skeleton.cc',
    'src/animation/runtime/skeleton_utils.cc',
    'src/animation/runtime/track.cc',
    'src/animation/runtime/track_sampling_job.cc',
    'src/animation/runtime/track_triggering_job.cc',

    'src/animation/offline/raw_animation.cc',
    'src/animation/offline/raw_animation_archive.cc',
    'src/animation/offline/raw_animation_utils.cc',
    'src/animation/offline/animation_builder.cc',
    'src/animation/offline/animation_optimizer.cc',
    'src/animation/offline/additive_animation_builder.cc',
    'src/animation/offline/raw_skeleton.cc',
    'src/animation/offline/raw_skeleton_archive.cc',
    'src/animation/offline/skeleton_builder.cc',
    'src/animation/offline/raw_track.cc',
    'src/animation/offline/track_builder.cc',
    'src/animation/offline/track_optimizer.cc',

    'samples/framework/mesh.cc',
]
ozz_inc = include_directories('include')

cxx = meson.get_compiler('cpp')
if cxx.get_id() == 'emscripten'
    # wasm
    executable(
        'cozz',
        srcs,
        include_directories: [ozz_inc, include_directories('src', 'samples')],
        cpp_args: [
            '-DEMSCRIPTEN=1',
            '-sSIDE_MODULE=1',
            '-fPIC',
            '-g',
        ],
        link_args: [
            '-sEXPORT_ALL=1',
            '-sWASM=1',
            '-sSIDE_MODULE=1',
            '-g',
        ],
        # pic: true,
        install: true,
        name_suffix: 'wasm',
        install_dir: 'web',
        # => prefix/lib/ozz-animation.js
        # => prefix/lib/ozz-animation.wasm
    )
else
    # native
    ozz_lib = shared_library(
        'cozz',
        srcs,
        include_directories: [ozz_inc, include_directories('src', 'samples')],
        cpp_args: [
            '-DDLL_EXPORTS',
        ],
        install: true,
        # => prefix/bin/ozz-animation.dll
        # => prefix/lib/ozz-animation.lib
    )

    if get_option('examples')
        subdir('extern/glfw')

        gl_dep = dependency('opengl')

        ozz_dep = declare_dependency(
            include_directories: ozz_inc,
            link_with: ozz_lib,
        )

        subdir('samples/framework')

        executable(
            'playback',
            'samples/playback/sample_playback.cc',
            dependencies: [
                ozz_dep,
                framework_dep,
                gl_dep,
            ],
            install: true,
        )

        install_data(
            sources: [
                'media/bin/pab_skeleton.ozz',
                'media/bin/pab_crossarms.ozz',
            ],
            rename: [
                'media/skeleton.ozz',
                'media/animation.ozz',
            ],
            install_dir: 'bin',
        )
    endif
endif
