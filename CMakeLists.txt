cmake_minimum_required(VERSION 3.10)

set(PROJECT_VERSION_MAJOR 0)
set(PROJECT_VERSION_MINOR 0)
set(PROJECT_VERSION_PATCH 2)

project(AidOs3 VERSION "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}")

include(ExternalProject)
include(Tools.cmake)

set(GCC_VERSION 13.2.0)
set(BINUTILS_VERSION 2.41)

set(32TARGET i686-elf)
set(32PREFIX_DIR ${CMAKE_SOURCE_DIR}/Tools/${32TARGET})

set(64TARGET x86_64-elf)
set(64PREFIX_DIR ${CMAKE_SOURCE_DIR}/Tools/${32TARGET})

set(GCC_URL "https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz")
set(BINUTILS_URL "https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.gz")

ExternalProject_Add(
    binutils32
    URL ${BINUTILS_URL}
    PREFIX ${32PREFIX_DIR}
    DOWNLOAD_EXTRACT_TIMESTAMP true
    CONFIGURE_COMMAND <SOURCE_DIR>/configure --target=${32TARGET} --prefix=${32PREFIX_DIR} --with-sysroot= --disable-nls --disable-werror
    BUILD_COMMAND make -j4 
    INSTALL_COMMAND make install
)

ExternalProject_Add(
    binutils64
    URL ${BINUTILS_URL}
    PREFIX ${64PREFIX_DIR}
    DOWNLOAD_EXTRACT_TIMESTAMP true
    CONFIGURE_COMMAND <SOURCE_DIR>/configure --target=${64TARGET} --prefix=${64PREFIX_DIR} --with-sysroot= --disable-nls --disable-werror
    BUILD_COMMAND make -j4 
    INSTALL_COMMAND make install
)

ExternalProject_Add(
    gcc32
    DEPENDS binutils32
    URL ${GCC_URL}
    PREFIX ${32PREFIX_DIR}
    DOWNLOAD_EXTRACT_TIMESTAMP true
    CONFIGURE_COMMAND <SOURCE_DIR>/configure --target=${32TARGET} --prefix=${32PREFIX_DIR} --disable-nls --enable-languages=c,c++ --without-headers
    BUILD_COMMAND make -j4 all-gcc all-target-libgcc
    INSTALL_COMMAND make install-gcc install-target-libgcc
)

ExternalProject_Add(
    gcc64
    DEPENDS binutils64
    URL ${GCC_URL}
    PREFIX ${64PREFIX_DIR}
    DOWNLOAD_EXTRACT_TIMESTAMP true
    CONFIGURE_COMMAND <SOURCE_DIR>/configure --target=${64TARGET} --prefix=${64PREFIX_DIR} --disable-nls --enable-languages=c,c++ --without-headers
    BUILD_COMMAND make -j4 all-gcc all-target-libgcc
    INSTALL_COMMAND make install-gcc install-target-libgcc
)

set(CMAKE_C_COMPILER "${32PREFIX_DIR}/bin/${64TARGET}-gcc")
set(CMAKE_CXX_COMPILER "${32PREFIX_DIR}/bin/${64TARGET}-g++")
set(CMAKE_ASM_COMPILER yasm)
enable_language(ASM)
set(CMAKE_FLAGS "")
set(CMAKE_ASM_COMPILE_OBJECT
    "<CMAKE_ASM_COMPILER> <FLAGS> <SOURCE> -o <OBJECT>"
)
set(CMAKE_ASM_FLAGS  "${CMAKE_ASM_FLAGS} -f elf64 -g dwarf2")
set(CMAKE_ASM_FLAGS_DEBUG "")
set(CMAKE_LINKER "${64PREFIX_DIR}/bin/${64TARGET}-g++")
set(CMAKE_ASM_LINK_EXECUTABLE "${CMAKE_LINKER} <CMAKE_ASM_LINK_FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")
set(CMAKE_AR "${PREFIX_DIR}/bin/${TARGET}-ar")
set(CMAKE_NM "${PREFIX_DIR}/bin/${TARGET}-nm")
set(CMAKE_OBJCOPY "${PREFIX_DIR}/bin/${TARGET}-objcopy")
set(CMAKE_OBJDUMP "${PREFIX_DIR}/bin/${TARGET}-objdump")

add_subdirectory(${CMAKE_SOURCE_DIR}/src)
add_subdirectory(${CMAKE_SOURCE_DIR}/image)

set(DISK_IMAGE "${CMAKE_BINARY_DIR}/out/aidos_${CMAKE_PROJECT_VERSION}.raw")

add_custom_target(run
    COMMAND qemu-system-x86_64 -hda ${DISK_IMAGE}
    DEPENDS build_disk
    COMMENT "Running the boot image in QEMU"
)

add_custom_target(debug
    COMMAND qemu-system-x86_64 -debugcon stdio -hda ${DISK_IMAGE} -s -S -m 128M
    DEPENDS build_disk stage1_debug_output stage2_debug_output
    COMMENT "Debugging the boot image in QEMU"
)

# Define a custom target to process the .asm file
add_custom_target(asm4doxy
    COMMAND ./scripts/asm4doxy.pl src/bootloader/stage1/boot.asm -od src/bootloader/stage1/
    COMMAND ./scripts/asm4doxy.pl src/bootloader/stage2/entry.asm -od src/bootloader/stage2/
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
