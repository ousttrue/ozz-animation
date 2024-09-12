set(APP_NAME ozz_anim)
add_executable(${APP_NAME} ozz_anim.cpp)
target_link_libraries(${APP_NAME} PRIVATE imgui ozzanim sokol util)
set(OZZ_DATA_FILES
        ${CMAKE_CURRENT_SOURCE_DIR}/../../data/ozz_skin_animation.ozz
        ${CMAKE_CURRENT_SOURCE_DIR}/../../data/ozz_skin_skeleton.ozz)

foreach(OZZ_DATA_FILE ${OZZ_DATA_FILES})
    add_custom_command(
            TARGET ${APP_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/data/"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different ${OZZ_DATA_FILE} "${CMAKE_CURRENT_BINARY_DIR}/data/"
            DEPENDS ${OZZ_DATA_FILE}
            VERBATIM
    )
endforeach(OZZ_DATA_FILE)
