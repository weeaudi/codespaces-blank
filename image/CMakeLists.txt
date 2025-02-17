set(STAGE1_BIN   "${CMAKE_BINARY_DIR}/src/bootloader/stage1/boot.bin")
set(STAGE2_ELF   "${CMAKE_BINARY_DIR}/src/bootloader/stage2/stage2.elf")
set(KERNEL_ELF   "${CMAKE_SOURCE_DIR}/tmp/kernel.elf")

set(DISKSIZE_BYTES 512000000) # 512 * 1000 * 1000  512 MB
set(DISK_FS_TYPE "fat32")

set(DISK_IMAGE "${CMAKE_BINARY_DIR}/out/aidos_${CMAKE_PROJECT_VERSION}.raw")

set(EXTRA_FILES
    ""
    )

add_custom_command(
    OUTPUT "${DISK_IMAGE}"
    COMMAND mkdir ${CMAKE_BINARY_DIR}/out -p
    COMMAND ${CMAKE_COMMAND} -E echo ">> Building full disk image with partitions..."
    COMMAND python3 "${CMAKE_SOURCE_DIR}/scripts/build_disk.py"
            "${DISK_IMAGE}"
            "${STAGE1_BIN}"
            "${STAGE2_ELF}"
            "${KERNEL_ELF}"
            "${DISKSIZE_BYTES}"
            "${DISK_FS_TYPE}"
            ${EXTRA_FILES}           
    DEPENDS 
        ${STAGE1_BIN}
        ${STAGE2_ELF}
        ${KERNEL_ELF}
    COMMENT "Creating a partitioned disk image (${DISK_IMAGE})"
    VERBATIM
)

add_custom_target(build_disk ALL
    DEPENDS "${DISK_IMAGE}" bootloader stage2
    COMMENT "Partitioned disk image creation complete."
)