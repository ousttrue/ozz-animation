framework_inc = include_directories('..')
framework_lib = static_library(
    'framework',
    [
        'application.cc',
        'image.cc',
        'profile.cc',
        'utils.cc',
        'mesh.cc',
        'internal/camera.cc',
        'internal/immediate.cc',
        'internal/imgui_impl.cc',
        'internal/renderer_impl.cc',
        'internal/shader.cc',
        'internal/shooter.cc',
    ],
    include_directories: framework_inc,
    dependencies: [ozz_dep, glfw_dep],
)

framework_dep = declare_dependency(
    include_directories: framework_inc,
    link_with: framework_lib,
)
