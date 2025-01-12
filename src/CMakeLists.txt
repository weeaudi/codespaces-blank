add_subdirectory(bootloader)

# Create a target for the floppy disk image
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/floppy.img
    COMMAND dd if=/dev/zero of=${CMAKE_CURRENT_BINARY_DIR}/floppy.img bs=512 count=2880 status=none
    COMMAND dd if=${CMAKE_CURRENT_BINARY_DIR}/bootloader/stage1/boot.bin of=${CMAKE_CURRENT_BINARY_DIR}/floppy.img bs=512 count=1 conv=notrunc status=none
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/bootloader/stage1/boot.bin
    COMMENT "Creating floppy disk image"
)

# Create a custom target to build the floppy image
add_custom_target(floppy_image ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/floppy.img)

add_dependencies(floppy_image bootloader)

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/out/floppy.img
    COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_BINARY_DIR}/out/floppy.img
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/src/floppy.img ${CMAKE_BINARY_DIR}/out/floppy.img
    DEPENDS ${CMAKE_BINARY_DIR}/src/floppy.img
)
add_custom_target(floppy_image_output ALL DEPENDS ${CMAKE_BINARY_DIR}/out/floppy.img)
add_dependencies(floppy_image_output floppy_image)

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/out/debug/stage1-debug
    COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_BINARY_DIR}/out/debug/stage1-debug
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/src/bootloader/stage1/bootloader-debug ${CMAKE_BINARY_DIR}/out/debug/stage1-debug
    DEPENDS ${CMAKE_BINARY_DIR}/src/bootloader/stage1/bootloader-debug
)
add_custom_target(stage1_debug_output ALL DEPENDS ${CMAKE_BINARY_DIR}/out/debug/stage1-debug)
add_dependencies(stage1_debug_output bootloader_debug)
