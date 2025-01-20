set(STAGE2_SRC ${CMAKE_CURRENT_SOURCE_DIR}/entry.asm)
set(STAGE2_LINK ${CMAKE_CURRENT_SOURCE_DIR}/linker.ld)

assemble_binary(stage2 ${STAGE2_SRC} ${STAGE2_LINK} "stage2.elf")

add_custom_command( 
    OUTPUT ${CMAKE_BINARY_DIR}/out/debug/stage2.elf
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/src/bootloader/stage2/stage2.elf ${CMAKE_BINARY_DIR}/out/debug/stage2.elf
    DEPENDS stage2
)

add_custom_target(stage2_debug_output ALL DEPENDS ${CMAKE_BINARY_DIR}/out/debug/stage2.elf)