#
# 1) A function to assemble and link an assembly file with a given linker script
#    for a “non-debug” (release) build.
#
function(assemble_binary TARGET_NAME ASM_FILE LINKER_SCRIPT OUTPUT_FILE)
    
    add_executable(${TARGET_NAME} ${ASM_FILE})

    set_target_properties(${TARGET_NAME} PROPERTIES OUTPUT_NAME ${OUTPUT_FILE}) 

    target_link_options(${TARGET_NAME} PRIVATE 
        -Wl,-T ${LINKER_SCRIPT} -Wl,--no-warn-rwx-segment -nostdlib
    )

endfunction()


#
# 2) A function to assemble (with debug info) and link an assembly file
#    using a special debug linker script.
#
function(assemble_debug_binary TARGET_NAME ASM_FILE DEBUG_LINKER_SCRIPT OUTPUT_FILE)
    add_executable(${TARGET_NAME} ${ASM_FILE})

    set_target_properties(${TARGET_NAME} PROPERTIES OUTPUT_NAME ${OUTPUT_FILE}) 

    target_link_options(${TARGET_NAME} PRIVATE 
        -Wl,-T ${DEBUG_LINKER_SCRIPT} -Wl,--no-warn-rwx-segment -nostdlib
    )
endfunction()



