set(APP_NAME ozz_skin)
#add_executable(${APP_NAME} ozz_skin.cpp)
list(APPEND src ozz_skin.cpp)

set(OZZ_DATA_FILES
        ${CMAKE_CURRENT_SOURCE_DIR}/../../data/ozz_skin_animation.ozz
        ${CMAKE_CURRENT_SOURCE_DIR}/../../data/ozz_skin_skeleton.ozz
        ${CMAKE_CURRENT_SOURCE_DIR}/../../data/ozz_skin_mesh.ozz)

# shader compile
if(WIN32)
    set(SOKOL_SHDC "${CMAKE_CURRENT_SOURCE_DIR}/../../tools/bin/win32/sokol-shdc.exe")
elseif(APPLE)
    if (${CMAKE_HOST_SYSTEM_PROCESSOR} STREQUAL "AMD64")
        set(SOKOL_SHDC "${CMAKE_CURRENT_SOURCE_DIR}/../../tools/bin/osx/sokol-shdc")
    else()
        set(SOKOL_SHDC "${CMAKE_CURRENT_SOURCE_DIR}/../../tools/bin/osx_arm64/sokol-shdc")
    endif()
elseif(UNIX AND NOT APPLE) # Linux
    set(SOKOL_SHDC "${CMAKE_CURRENT_SOURCE_DIR}/../../tools/bin/linux/sokol-shdc")
endif()

set(SHADER_SOURCE_FILES ${CMAKE_CURRENT_SOURCE_DIR}/ozz_skin.glsl)
foreach(GLSL ${SHADER_SOURCE_FILES})
    get_filename_component(FILE_NAME ${GLSL} NAME)
    set(SHADER_HEADER "${CMAKE_CURRENT_BINARY_DIR}/shdc/${FILE_NAME}.h")
    add_custom_command(
            OUTPUT ${SHADER_HEADER}
#            TARGET ${APP_NAME} PRE_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/shdc/"
            COMMAND ${SOKOL_SHDC} --input ${GLSL} --output ${SHADER_HEADER} --slang glsl330
            DEPENDS ${GLSL}
            VERBATIM
    )
#    add_executable(${APP_NAME} ${SHADER_HEADER})
    list(APPEND src ${SHADER_HEADER})
endforeach(GLSL)

add_executable(${APP_NAME} ${src})
target_link_libraries(${APP_NAME} PRIVATE imgui ozzanim sokol util)
target_include_directories(${APP_NAME} PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/shdc/")

foreach(OZZ_DATA_FILE ${OZZ_DATA_FILES})
    add_custom_command(
            TARGET ${APP_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/data/"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different ${OZZ_DATA_FILE} "${CMAKE_CURRENT_BINARY_DIR}/data/"
            DEPENDS ${OZZ_DATA_FILE}
            VERBATIM
    )
endforeach(OZZ_DATA_FILE)
