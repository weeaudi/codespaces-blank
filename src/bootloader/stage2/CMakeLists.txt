
file(GLOB CPP_SOURCE_FILES ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp)

set(STAGE2_SRC 
    ${CMAKE_CURRENT_SOURCE_DIR}/entry.asm
    ${CMAKE_CURRENT_SOURCE_DIR}/crti.asm
    ${CMAKE_CURRENT_SOURCE_DIR}/crtn.asm
    ${CPP_SOURCE_FILES}
)
set(STAGE2_LINK ${CMAKE_CURRENT_SOURCE_DIR}/linker.ld)

add_executable(stage2 ${STAGE2_SRC})

set_target_properties(stage2 PROPERTIES OUTPUT_NAME "stage2.elf")

set(CRTBEGIN_OBJ ${64PREFIX_DIR}/lib/gcc/x86_64-elf/13.2.0/crtbegin.o)
set(CRTEND_OBJ ${64PREFIX_DIR}/lib/gcc/x86_64-elf/13.2.0/crtend.o)

target_link_options(stage2 PRIVATE 
    -Wl,-T ${STAGE2_LINK}               # Use linker script
    -Wl,--no-warn-rwx-segment           # Suppress warnings
    -nostdlib                           # Avoid linking standard libraries
    ${CRTBEGIN_OBJ}                     # Precompiled crtbegin.o
    -Wl,-Map=${CMAKE_BINARY_DIR}/src/bootloader/stage2/stage2.map  # Generate map file
    ${CRTEND_OBJ}                       # Precompiled crtend.o
)

add_custom_command( 
    OUTPUT ${CMAKE_BINARY_DIR}/out/debug/stage2.elf
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/src/bootloader/stage2/stage2.elf ${CMAKE_BINARY_DIR}/out/debug/stage2.elf
    DEPENDS stage2
)

add_custom_target(stage2_debug_output ALL DEPENDS ${CMAKE_BINARY_DIR}/out/debug/stage2.elf)