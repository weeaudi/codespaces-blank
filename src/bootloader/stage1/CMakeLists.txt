# Specify the source file
set(BOOTLOADER_SRC boot.asm)
set(BOOTLOADER_LINK ${CMAKE_CURRENT_SOURCE_DIR}/linker.ld)
set(BOOTLOADER_DEBUG_LINK ${CMAKE_CURRENT_SOURCE_DIR}/debug.ld)

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/out/debug/stage1-debug
    COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_BINARY_DIR}/out/debug/stage1-debug
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/src/bootloader/stage1/bootloader-debug ${CMAKE_BINARY_DIR}/out/debug/stage1-debug
    DEPENDS ${CMAKE_BINARY_DIR}/src/bootloader/stage1/bootloader-debug
)
add_custom_target(stage1_debug_output ALL DEPENDS ${CMAKE_BINARY_DIR}/out/debug/stage1-debug)
add_dependencies(stage1_debug_output bootloader_debug)

function(assemble_binary TARGET_NAME ASM_FILE LINKER_SCRIPT OUTPUT_FILE)
    
    add_executable(${TARGET_NAME} ${ASM_FILE})

    set_target_properties(${TARGET_NAME} PROPERTIES OUTPUT_NAME ${OUTPUT_FILE}) 
    set_target_properties(${TARGET_NAME} PROPERTIES COMPILE_FLAGS "-I ${CMAKE_CURRENT_SOURCE_DIR}")
    set_target_properties(${TARGET_NAME} PROPERTIES LINKER_LANGUAGE C)

    get_filename_component(BASE_NAME ${OUTPUT_FILE} NAME_WE)

    set(MAP_FILE "${BASE_NAME}.map")

    target_link_options(${TARGET_NAME} PRIVATE 
        -Wl,-T ${LINKER_SCRIPT} -Wl,--no-warn-rwx-segment -nostdlib -Wl,-Map=${MAP_FILE}
    )

endfunction()


function(assemble_debug_binary TARGET_NAME ASM_FILE DEBUG_LINKER_SCRIPT OUTPUT_FILE)
    add_executable(${TARGET_NAME} ${ASM_FILE})

    set_target_properties(${TARGET_NAME} PROPERTIES OUTPUT_NAME ${OUTPUT_FILE}) 
    set_target_properties(${TARGET_NAME} PROPERTIES COMPILE_FLAGS "-I ${CMAKE_CURRENT_SOURCE_DIR}")
    set_target_properties(${TARGET_NAME} PROPERTIES LINKER_LANGUAGE C)

    target_link_options(${TARGET_NAME} PRIVATE 
        -Wl,-T ${DEBUG_LINKER_SCRIPT} -Wl,--no-warn-rwx-segment -nostdlib
    )
endfunction()

# Add a target to assemble the bootloader (no linking)
assemble_binary(bootloader ${BOOTLOADER_SRC} ${BOOTLOADER_LINK} "boot.bin")
assemble_debug_binary(bootloader_debug ${BOOTLOADER_SRC} ${BOOTLOADER_DEBUG_LINK} "bootloader-debug")