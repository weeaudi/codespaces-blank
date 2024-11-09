# Bootloader/CMakeLists.txt

# Specify the source file
set(BOOTLOADER_SRC boot.asm)

# Create a target to build the bootloader
add_custom_target(bootloader ALL
    COMMAND yasm ${CMAKE_CURRENT_SOURCE_DIR}/${BOOTLOADER_SRC} -o ${CMAKE_CURRENT_BINARY_DIR}/boot.bin
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS ${BOOTLOADER_SRC}
)

# Specify the output directory for the binary
set_target_properties(bootloader PROPERTIES
    OUTPUT_NAME "boot"
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

# Create a target for the floppy disk image
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/floppy.img
    COMMAND ${CMAKE_COMMAND} -E echo "Creating floppy disk image..."
    COMMAND dd if=/dev/zero of=${CMAKE_CURRENT_BINARY_DIR}/floppy.img bs=512 count=2880
    COMMAND dd if=${CMAKE_CURRENT_BINARY_DIR}/boot.bin of=${CMAKE_CURRENT_BINARY_DIR}/floppy.img bs=512 count=1 conv=notrunc
    DEPENDS bootloader
    COMMENT "Creating floppy disk image"
)

# Create a custom target to build the floppy image
add_custom_target(floppy_image ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/floppy.img)

add_dependencies(floppy_image bootloader)