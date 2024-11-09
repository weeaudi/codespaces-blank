cmake_minimum_required(VERSION 3.10)
project(Bootloader)

# Set the assembler to YASM
set(CMAKE_ASM_YASM_FLAGS "-f bin")

# Add the Bootloader directory
add_subdirectory(stage1)
