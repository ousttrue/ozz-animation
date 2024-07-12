project('ozz', ['c', 'cpp'])

subdir('extern/glfw')

gl_dep = dependency('opengl')

ozz_inc = include_directories('include')
ozz_lib = static_library(
    'ozz',
    [
        'src/base/platform.cc',
        'src/base/log.cc',
        'src/base/memory/allocator.cc',
        'src/base/containers/string_archive.cc',
        'src/base/io/archive.cc',
        'src/base/io/stream.cc',
        'src/base/maths/box.cc',
        'src/base/maths/simd_math.cc',
        'src/base/maths/math_archive.cc',
        'src/base/maths/soa_math_archive.cc',
        'src/base/maths/simd_math_archive.cc',
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
        'src/options/options.cc',
        'src/geometry/runtime/skinning_job.cc',
    ],
    include_directories: [ozz_inc, include_directories('src')],
)
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
