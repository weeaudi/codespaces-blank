function(assemble_binary TARGET_NAME ASM_FILE LINKER_SCRIPT OUTPUT_FILE)
    
    add_executable(${TARGET_NAME} ${ASM_FILE})

    set_target_properties(${TARGET_NAME} PROPERTIES OUTPUT_NAME ${OUTPUT_FILE}) 

    get_filename_component(BASE_NAME ${OUTPUT_FILE} NAME_WE)

    set(MAP_FILE "${BASE_NAME}.map")

    target_link_options(${TARGET_NAME} PRIVATE 
        -Wl,-T ${LINKER_SCRIPT} -Wl,--no-warn-rwx-segment -nostdlib -Wl,-Map=${MAP_FILE}
    )

endfunction()


function(assemble_debug_binary TARGET_NAME ASM_FILE DEBUG_LINKER_SCRIPT OUTPUT_FILE)
    add_executable(${TARGET_NAME} ${ASM_FILE})

    set_target_properties(${TARGET_NAME} PROPERTIES OUTPUT_NAME ${OUTPUT_FILE}) 

    target_link_options(${TARGET_NAME} PRIVATE 
        -Wl,-T ${DEBUG_LINKER_SCRIPT} -Wl,--no-warn-rwx-segment -nostdlib
    )
endfunction()



