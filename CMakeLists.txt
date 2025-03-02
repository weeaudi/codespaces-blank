cmake_minimum_required(VERSION 3.10)

include(ExternalProject)

#----------------------------------------------------------------------------
# Check for required tools
#----------------------------------------------------------------------------
# Check for Nasm
find_program(NASM_EXECUTABLE nasm)
if(NOT NASM_EXECUTABLE)
  message(FATAL_ERROR "Nasm is not installed. Please install Nasm.")
endif()

set(CMAKE_ASM_COMPILER ${NASM_EXECUTABLE})
enable_language(ASM_NASM)

# Check for kconfig-mconf (part of kconfig-frontends)
find_program(KCONFIG_MCONF_EXECUTABLE kconfig-mconf)
if(NOT KCONFIG_MCONF_EXECUTABLE)
  message(FATAL_ERROR "kconfig-mconf is not available. Please install kconfig-frontends.")
endif()

#----------------------------------------------------------------------------
# Run kconfig-mconf if configuration does not exist
#----------------------------------------------------------------------------
# Path to the generated configuration file
set(CONFIG_FILE "${CMAKE_BINARY_DIR}/.config")

if(EXISTS ${CONFIG_FILE})
  message(STATUS "Parsing configuration file: ${CONFIG_FILE}")
  file(STRINGS "${CONFIG_FILE}" CONFIG_LINES)

  foreach(line IN LISTS CONFIG_LINES)
    # Skip comment lines.
    if(line MATCHES "^#")
      continue()
    endif()
    # Match lines like: CONFIG_VARNAME="value"
    if(line MATCHES "^CONFIG_([A-Za-z0-9_]+)=(.*)")
      set(varName ${CMAKE_MATCH_1})
      set(varValue ${CMAKE_MATCH_2})
      # Remove any surrounding quotes from the value
      string(REGEX REPLACE "^\"(.*)\"$" "\\1" varValue "${varValue}")
      message(STATUS "Parsed variable: ${varName} = ${varValue}")
      # Set the variable in the CMake cache (or as a normal variable)
      set(${varName} "${varValue}" CACHE STRING "Parsed from .config")
    endif()
  endforeach()
else()
  message(FATAL_ERROR "Configuration file not found.  Please run kconfig-mconf ../Kconfig to
  generate the configuration.")
endif()

project(aidos3 VERSION ${VERSION_NUMBER})

# Substitute placeholders
string(REPLACE "@GCC_VERSION@" "${GCC_VERSION}" GCC_URL "${GCC_URL}")
string(REPLACE "@BINUTILS_VERSION@" "${BINUTILS_VERSION}" BINUTILS_URL "${BINUTILS_URL}")
string(REPLACE "@TARGET@" "${TARGET}" PREFIX_DIR "${PREFIX_DIR}")

set(PREFIX_DIR ${CMAKE_SOURCE_DIR}/${PREFIX_DIR})

#----------------------------------------------------------------------------
# Add external projects for build tools
#----------------------------------------------------------------------------
ExternalProject_Add(
  binutils
  URL ${BINUTILS_URL}
  URL_MD5 9ef8d27543a854eaecc8ceeadc100697
  PREFIX ${CMAKE_SOURCE_DIR}/${PREFIX_DIR}
  DOWNLOAD_EXTRACT_TIMESTAMP true
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --target=${TARGET} --prefix=${CMAKE_SOURCE_DIR}/${PREFIX_DIR} --with-sysroot= --disable-nls --disable-werror
  BUILD_COMMAND make -j16
  INSTALL_COMMAND make install
)

ExternalProject_Add(
  gcc
  DEPENDS binutils
  URL ${GCC_URL}
  URL_MD5 aeb5ac806c34d47e725bdd025f34bac4
  PREFIX ${CMAKE_SOURCE_DIR}/${PREFIX_DIR}
  DOWNLOAD_EXTRACT_TIMESTAMP true
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --target=${TARGET} --prefix=${CMAKE_SOURCE_DIR}/${PREFIX_DIR} --disable-nls --enable-languages=c,c++ --without-headers
  BUILD_COMMAND make -j16 all-gcc all-target-libgcc
  INSTALL_COMMAND make install-gcc install-target-libgcc
)

set(CMAKE_C_COMPILER "${PREFIX_DIR}/bin/${TARGET}-gcc")
set(CMAKE_CXX_COMPILER "${PREFIX_DIR}/bin/${TARGET}-g++")
set(CMAKE_ASM_NASM_FLAGS  "-f elf64 -g")
set(CMAKE_ASM_NASM_COMPILE_OBJECT "<CMAKE_ASM_NASM_COMPILER> <DEFINES> <INCLUDES> <FLAGS> -o <OBJECT> <SOURCE>")
set(CMAKE_LINKER "${PREFIX_DIR}/bin/${TARGET}-g++")
set(CMAKE_AR "${PREFIX_DIR}/bin/${TARGET}-ar")
set(CMAKE_NM "${PREFIX_DIR}/bin/${TARGET}-nm")
set(CMAKE_OBJCOPY "${PREFIX_DIR}/bin/${TARGET}-objcopy")
set(CMAKE_OBJDUMP "${PREFIX_DIR}/bin/${TARGET}-objdump")

add_subdirectory(${CMAKE_SOURCE_DIR}/src)
add_subdirectory(${CMAKE_SOURCE_DIR}/image)

set(DISK_IMAGE "${CMAKE_BINARY_DIR}/out/aidos_${CMAKE_PROJECT_VERSION}.raw")

set(CMAKE_VS_STARTUP_PROJECT "run")
add_custom_target(run
    COMMAND qemu-system-x86_64 -hda ${DISK_IMAGE}
    DEPENDS build_disk
    COMMENT "Running the boot image in QEMU"
)

add_custom_target(debug
    COMMAND qemu-system-x86_64 -debugcon stdio -hda ${DISK_IMAGE} -s -S
    DEPENDS build_disk stage1_debug_output stage2_debug_output
    COMMENT "Debugging the boot image in QEMU"
)