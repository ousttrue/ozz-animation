glfw_inc = include_directories('include')
glfw_lib = static_library(
    'glfw',
    [
        'lib/win32/win32_dllmain.c',
        'lib/win32/win32_enable.c',
        'lib/win32/win32_fullscreen.c',
        'lib/win32/win32_glext.c',
        'lib/win32/win32_init.c',
        'lib/win32/win32_joystick.c',
        'lib/win32/win32_thread.c',
        'lib/win32/win32_time.c',
        'lib/win32/win32_window.c',
        'lib/enable.c',
        'lib/fullscreen.c',
        'lib/glext.c',
        'lib/image.c',
        'lib/init.c',
        'lib/input.c',
        'lib/joystick.c',
        'lib/stream.c',
        'lib/tga.c',
        'lib/thread.c',
        'lib/time.c',
        'lib/window.c',
    ],
    include_directories: include_directories('lib'),
    c_args: [
        '-DWIN32=1',
    ],
)
glfw_dep = declare_dependency(
    include_directories: glfw_inc,
    link_with: glfw_lib,
)
