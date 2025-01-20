cmake_minimum_required(VERSION 3.10)

set(PROJECT_VERSION_MAJOR 0)
set(PROJECT_VERSION_MINOR 0)
set(PROJECT_VERSION_PATCH 2)

project(AidOs3 VERSION "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}")

include(ExternalProject)
include(Tools.cmake)

set(GCC_VERSION 13.2.0)
set(BINUTILS_VERSION 2.41)

set(TARGET i686-elf)
set(PREFIX_DIR ${CMAKE_SOURCE_DIR}/Tools/${TARGET})

set(GCC_URL "https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz")
set(BINUTILS_URL "https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.gz")

ExternalProject_Add(
    binutils
    URL ${BINUTILS_URL}
    PREFIX ${PREFIX_DIR}
    DOWNLOAD_EXTRACT_TIMESTAMP true
    CONFIGURE_COMMAND <SOURCE_DIR>/configure --target=${TARGET} --prefix=${PREFIX_DIR} --with-sysroot= --disable-nls --disable-werror
    BUILD_COMMAND make -j4 
    INSTALL_COMMAND make install
)

ExternalProject_Add(
    gcc
    DEPENDS binutils
    URL ${GCC_URL}
    PREFIX ${PREFIX_DIR}
    DOWNLOAD_EXTRACT_TIMESTAMP true
    CONFIGURE_COMMAND <SOURCE_DIR>/configure --target=${TARGET} --prefix=${PREFIX_DIR} --disable-nls --enable-languages=c,c++ --without-headers
    BUILD_COMMAND make -j4 all-gcc all-target-libgcc
    INSTALL_COMMAND make install-gcc install-target-libgcc
)

if(NOT DEFINED CMAKE_C_COMPILER)
    set(CMAKE_C_COMPILER "${PREFIX_DIR}/bin/${TARGET}-gcc")
endif()

if(NOT DEFINED CMAKE_CXX_COMPILER)
    set(CMAKE_CXX_COMPILER "${PREFIX_DIR}/bin/${TARGET}-g++")
endif()
enable_language(ASM)
set(CMAKE_ASM_COMPILER yasm)
set(CMAKE_FLAGS "")
set(CMAKE_ASM_COMPILE_OBJECT
    "<CMAKE_ASM_COMPILER> <FLAGS> <SOURCE> -o <OBJECT>"
)
set(CMAKE_ASM_FLAGS  "${CMAKE_ASM_FLAGS} -f elf32 -g dwarf2")
set(CMAKE_ASM_FLAGS_DEBUG "")
set(CMAKE_LINKER "${PREFIX_DIR}/bin/${TARGET}-g++")
set(CMAKE_ASM_LINK_EXECUTABLE "${CMAKE_LINKER} <CMAKE_ASM_LINK_FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")
set(CMAKE_AR "${PREFIX_DIR}/bin/${TARGET}-ar")
set(CMAKE_NM "${PREFIX_DIR}/bin/${TARGET}-nm")
set(CMAKE_OBJCOPY "${PREFIX_DIR}/bin/${TARGET}-objcopy")
set(CMAKE_OBJDUMP "${PREFIX_DIR}/bin/${TARGET}-objdump")

add_subdirectory(src)

add_custom_target(run
    COMMAND qemu-system-i386 -fda ${CMAKE_BINARY_DIR}/out/floppy-${CMAKE_PROJECT_VERSION}.img
    DEPENDS ${CMAKE_BINARY_DIR}/out/floppy-${CMAKE_PROJECT_VERSION}.img
)
add_dependencies(run floppy_image_output)

add_custom_target(debug
    COMMAND qemu-system-i386 -debugcon stdio -fda ${CMAKE_BINARY_DIR}/out/floppy-${CMAKE_PROJECT_VERSION}.img -s -S -m 128M
    DEPENDS ${CMAKE_BINARY_DIR}/out/floppy-${CMAKE_PROJECT_VERSION}.img
)

add_dependencies(debug floppy_image_output)
add_dependencies(debug stage1_debug_output)



# Define a custom target to process the .asm file
add_custom_target(asm4doxy
    COMMAND ./scripts/asm4doxy.pl src/bootloader/stage1/boot.asm -od src/bootloader/stage1/
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}  # Set working directory
    COMMENT "Running asm4doxy to preprocess boot.asm for Doxygen"
    VERBATIM
)

# Define a custom target to run Doxygen
find_package(Doxygen REQUIRED)
add_custom_target(gendocs
    COMMAND ${DOXYGEN_EXECUTABLE} Doxyfile
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}  # Set working directory
    COMMENT "Running Doxygen to generate documentation"
    VERBATIM
    DEPENDS asm4doxy
)

