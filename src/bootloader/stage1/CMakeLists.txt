# Bootloader/CMakeLists.txt

# Specify the source file
set(BOOTLOADER_SRC ${CMAKE_CURRENT_SOURCE_DIR}/boot.asm)
set(BOOTLOADER_DEBUG_LINK ${CMAKE_CURRENT_SOURCE_DIR}/debug.ld)

# Add a target to assemble the bootloader (no linking)
assemble_binary(bootloader ${BOOTLOADER_SRC} "boot.bin")
assemble_debug_binary(bootloader_debug ${BOOTLOADER_SRC} ${BOOTLOADER_DEBUG_LINK} "boot")
