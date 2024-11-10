add_subdirectory(bootloader)

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/out/floppy.img
    COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_BINARY_DIR}/out/floppy.img
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/src/bootloader/stage1/floppy.img ${CMAKE_BINARY_DIR}/out/floppy.img
    DEPENDS ${CMAKE_BINARY_DIR}/src/bootloader/stage1/floppy.img
)
add_custom_target(floppy_image_output ALL DEPENDS ${CMAKE_BINARY_DIR}/out/floppy.img)
add_dependencies(floppy_image_output floppy_image)

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/out/debug/stage1-debug
    COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_BINARY_DIR}/out/debug/stage1-debug
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/src/bootloader/stage1/boot-debug ${CMAKE_BINARY_DIR}/out/debug/stage1-debug
    DEPENDS ${CMAKE_BINARY_DIR}/src/bootloader/stage1/boot-debug
)
add_custom_target(stage1_debug_output ALL DEPENDS ${CMAKE_BINARY_DIR}/out/debug/stage1-debug)
add_dependencies(stage1_debug_output bootloader_debug)
