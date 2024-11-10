function(assemble_binary TARGET_NAME ASM_FILE OUTPUT_FILE)
    add_custom_command(
        OUTPUT ${OUTPUT_FILE}
        COMMAND ${CMAKE_ASM_COMPILER} ${CMAKE_ASM_FLAGS} -o ${OUTPUT_FILE} ${ASM_FILE}
        DEPENDS ${ASM_FILE}
    )
    add_custom_target(${TARGET_NAME} ALL DEPENDS ${OUTPUT_FILE})
endfunction()

function(modify_org TARGET_NAME ASM_FILE)
    # Define the modified file path
    set(MODIFIED_ASM_FILE "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}_modified.asm")
    
    # Copy the original ASM file to the build directory
    add_custom_command(
        OUTPUT "${MODIFIED_ASM_FILE}-intermediate"
        COMMAND ${CMAKE_COMMAND} -E copy ${ASM_FILE} "${MODIFIED_ASM_FILE}-intermediate"
        DEPENDS ${ASM_FILE}
        COMMENT "Copying original ASM file to build directory"
    )
    
    # Modify the copied file to comment out 'org' directive lines
    add_custom_command(
        OUTPUT ${MODIFIED_ASM_FILE}
        COMMAND sed -i '/^\\s*org/ s/^/\; /' "${MODIFIED_ASM_FILE}-intermediate"
        COMMAND ${CMAKE_COMMAND} -E copy "${MODIFIED_ASM_FILE}-intermediate" ${MODIFIED_ASM_FILE}
        DEPENDS "${MODIFIED_ASM_FILE}-intermediate"
        COMMENT "Commenting out 'org' directive in ASM file"
    )

    add_custom_target(${TARGET_NAME} ALL DEPENDS ${MODIFIED_ASM_FILE})
endfunction()

function(assemble_debug_binary TARGET_NAME ASM_FILE DEBUG_LINKER_FILE OUTPUT_FILE)
    # Define the modified assembly file for debugging
    set(MODIFIED_ASM_FILE "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}-stripped_modified.asm")

    # Copy and modify the assembly file before proceeding
    modify_org("${TARGET_NAME}-stripped" ${ASM_FILE})

    # Assemble with debug symbols (comment out 'org' lines)
    add_custom_command(
        OUTPUT "${OUTPUT_FILE}-elf"
        COMMAND ${CMAKE_ASM_COMPILER} ${CMAKE_DEBUG_ASM_FLAGS} -o "${OUTPUT_FILE}-elf" ${MODIFIED_ASM_FILE}
        DEPENDS "${TARGET_NAME}-stripped"
        COMMENT "Assembling modified ASM file for debug symbols"
    )

    # Link the object file with the debug linker script
    add_custom_command(
        OUTPUT "${OUTPUT_FILE}-debug"
        COMMAND ${CMAKE_LINKER} -T ${DEBUG_LINKER_FILE} -o "${OUTPUT_FILE}-debug" "${OUTPUT_FILE}-elf"
        DEPENDS "${OUTPUT_FILE}-elf" ${DEBUG_LINKER_FILE}
        COMMENT "Linking ELF file with debug symbols"
    )

    add_custom_target(${TARGET_NAME} ALL DEPENDS "${OUTPUT_FILE}-debug")
endfunction()

