# Gather all source files (*.asm and *.cpp) in this subdirectory.
file(GLOB_RECURSE STAGE2_SRC "*.asm" "*.cpp")

# Remove the CRT assembly sources so they aren’t compiled automatically.
foreach(src ${STAGE2_SRC})
    if(src MATCHES "crti\\.asm$" OR src MATCHES "crtn\\.asm$")
        list(REMOVE_ITEM STAGE2_SRC ${src})
    endif()
endforeach()

# Set the path to our linker script (assumed to be in this subdirectory)
set(STAGE2_LINK ${CMAKE_CURRENT_SOURCE_DIR}/linker.ld)

# Create the stage2 executable target from the remaining sources.
add_executable(stage2 ${STAGE2_SRC})
set_target_properties(stage2 PROPERTIES OUTPUT_NAME "stage2.elf")

# Define paths to GCC-provided CRT objects.
set(CRTBEGIN_OBJ ${64PREFIX_DIR}/lib/gcc/x86_64-elf/13.2.0/crtbegin.o)
set(CRTEND_OBJ   ${64PREFIX_DIR}/lib/gcc/x86_64-elf/13.2.0/crtend.o)

##############################
# Build our custom CRT objects using YASM
##############################

# Specify the CRT assembly sources (located in the source directory)
set(CRTI_SRC ${CMAKE_CURRENT_SOURCE_DIR}/crti.asm)
set(CRTN_SRC ${CMAKE_CURRENT_SOURCE_DIR}/crtn.asm)

# Set output object files to be in the build directory.
set(CRTI_OBJ ${CMAKE_CURRENT_BINARY_DIR}/crti.o)
set(CRTN_OBJ ${CMAKE_CURRENT_BINARY_DIR}/crtn.o)

# Assemble crti.o using yasm.
add_custom_command(
    OUTPUT ${CRTI_OBJ}
    COMMAND yasm -f elf64 ${CRTI_SRC} -o ${CRTI_OBJ}
    DEPENDS ${CRTI_SRC}
    COMMENT "Assembling crti.o with yasm"
)

# Assemble crtn.o using yasm.
add_custom_command(
    OUTPUT ${CRTN_OBJ}
    COMMAND yasm -f elf64 ${CRTN_SRC} -o ${CRTN_OBJ}
    DEPENDS ${CRTN_SRC}
    COMMENT "Assembling crtn.o with yasm"
)

# Create a target to ensure these objects are built before linking.
add_custom_target(crt_objects ALL 
    DEPENDS ${CRTI_OBJ} ${CRTN_OBJ}
)

# Ensure the stage2 target builds after our CRT objects.
add_dependencies(stage2 crt_objects)

##############################
# Set up linker options and enforce link order
##############################
target_link_options(stage2 PRIVATE 
    -Wl,-T ${STAGE2_LINK}                         # Use our custom linker script.
    -Wl,--no-warn-rwx-segment                     # Suppress warnings.
    -nostdlib                                     # Do not link the standard libraries.
    -Wl,-Map=${CMAKE_BINARY_DIR}/src/bootloader/stage2/stage2.map  # Generate a map file.
    ${CRTI_OBJ}
    ${CRTBEGIN_OBJ}
)

# Explicitly add CRT objects in the proper order:
#   1. crti.o         (custom built, in build directory)
#   2. crtbegin.o     (GCC provided)
#   3. [target’s object files] (automatically inserted)
#   4. crtend.o       (GCC provided)
#   5. crtn.o         (custom built, in build directory)
target_link_libraries(stage2 PRIVATE
    ${CRTEND_OBJ}
    ${CRTN_OBJ}
)

##############################
# (Optional) Copy the final executable to an output directory
##############################
add_custom_command( 
    OUTPUT ${CMAKE_BINARY_DIR}/out/debug/stage2.elf
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:stage2> ${CMAKE_BINARY_DIR}/out/debug/stage2.elf
    DEPENDS stage2
)

add_custom_target(stage2_debug_output ALL 
    DEPENDS ${CMAKE_BINARY_DIR}/out/debug/stage2.elf
)
