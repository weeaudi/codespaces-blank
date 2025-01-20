add_subdirectory(bootloader)

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/out/debug/stage1-debug
    COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_BINARY_DIR}/out/debug/stage1-debug
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/src/bootloader/stage1/bootloader-debug ${CMAKE_BINARY_DIR}/out/debug/stage1-debug
    DEPENDS ${CMAKE_BINARY_DIR}/src/bootloader/stage1/bootloader-debug
)
add_custom_target(stage1_debug_output ALL DEPENDS ${CMAKE_BINARY_DIR}/out/debug/stage1-debug)
add_dependencies(stage1_debug_output bootloader_debug)
