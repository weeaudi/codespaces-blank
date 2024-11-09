cmake_minimum_required(VERSION 3.10)

set(PROJECT_VERSION_MAJOR 0)
set(PROJECT_VERSION_MINOR 0)
set(PROJECT_VERSION_PATCH 1)

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
set(CMAKE_ASM_FLAGS "-f" "bin")
set(CMAKE_DEBUG_ASM_FLAGS "-f" "elf32" "-g" "dwarf2")
set(CMAKE_LINKER "${PREFIX_DIR}/bin/${TARGET}-ld")
set(CMAKE_AR "${PREFIX_DIR}/bin/${TARGET}-ar")
set(CMAKE_NM "${PREFIX_DIR}/bin/${TARGET}-nm")
set(CMAKE_OBJCOPY "${PREFIX_DIR}/bin/${TARGET}-objcopy")
set(CMAKE_OBJDUMP "${PREFIX_DIR}/bin/${TARGET}-objdump")

# Custom target to increment the build number and generate the header
add_custom_target(IncrementBuildNumber ALL
    COMMAND ${CMAKE_COMMAND} -P "${CMAKE_SOURCE_DIR}/Increment.cmake"
)

# Read the incremented value from the cache file
set(CACHE_FILE "${CMAKE_SOURCE_DIR}/build/BuildNumberCache.txt")

set(DOLLAR_SIGN "\\$")

add_custom_target(PrintBuildMessage ALL
    DEPENDS IncrementBuildNumber
    COMMAND /bin/sh -c "echo Building: ${PROJECT_NAME} Version ${PROJECT_VERSION} Build Number: $$\\(cat ${CACHE_FILE}\\)"
)


# Make sure PrintBuildMessage runs after IncrementBuildNumber
add_dependencies(PrintBuildMessage IncrementBuildNumber)

add_subdirectory(src)
