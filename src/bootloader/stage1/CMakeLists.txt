# Bootloader/CMakeLists.txt

# Specify the source file
set(BOOTLOADER_SRC ${CMAKE_CURRENT_SOURCE_DIR}/boot.asm)
set(BOOTLOADER_DEBUG_LINK ${CMAKE_CURRENT_SOURCE_DIR}/debug.ld)

# Add a target to assemble the bootloader (no linking)
assemble_binary(bootloader ${BOOTLOADER_SRC} "boot.bin")
assemble_debug_binary(bootloader_debug ${BOOTLOADER_SRC} ${BOOTLOADER_DEBUG_LINK} "boot")

# Create a target for the floppy disk image
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/floppy.img
    COMMAND dd if=/dev/zero of=${CMAKE_CURRENT_BINARY_DIR}/floppy.img bs=512 count=2880 status=none
    COMMAND dd if=${CMAKE_CURRENT_BINARY_DIR}/boot.bin of=${CMAKE_CURRENT_BINARY_DIR}/floppy.img bs=512 count=1 conv=notrunc status=none
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/boot.bin
    COMMENT "Creating floppy disk image"
)

# Create a custom target to build the floppy image
add_custom_target(floppy_image ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/floppy.img)

add_dependencies(floppy_image bootloader)
