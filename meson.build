project(
    'ozz-animation',
    'cpp',
    version: '0.15.0',
    default_options: ['cpp_std=c++14'],
)

srcs = [
    'ozz_wrap.cpp',

    # 'src/ozz_base.cc',
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

    # 'src/ozz_animation.cc',
    'src/animation/runtime/animation.cc',
    # 'src/animation/runtime/animation_utils.cc',
    # 'src/animation/runtime/blending_job.cc',
    # 'src/animation/runtime/ik_aim_job.cc',
    # 'src/animation/runtime/ik_two_bone_job.cc',
    'src/animation/runtime/local_to_model_job.cc',
    'src/animation/runtime/sampling_job.cc',
    'src/animation/runtime/skeleton.cc',
    'src/animation/runtime/skeleton_utils.cc',
    # 'src/animation/runtime/track.cc',
    # 'src/animation/runtime/track_sampling_job.cc',
    # 'src/animation/runtime/track_triggering_job.cc',

    'samples/framework/mesh.cc',
    'samples/framework/internal/renderer_impl.cc',
]
ozz_inc = include_directories('include')

cxx = meson.get_compiler('cpp')
if cxx.get_id() == 'emscripten'
    # wasm
    executable(
        'ozz-animation',
        srcs,
        include_directories: [ozz_inc, include_directories('src')],
        cpp_args: [
            '-DEMSCRIPTEN=1',
            '-sSIDE_MODULE=1',
            '-fPIC',
        ],
        link_args: [
            '-sEXPORT_ALL=1',
            '-sWASM=1',
            '-sSIDE_MODULE=1',
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
        'ozz-animation',
        srcs,
        include_directories: [ozz_inc, include_directories('src')],
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
