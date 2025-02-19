/**
 * @file Main.cpp
 * @author Aidcraft
 * @brief Main entry point into the second stage bootloader
 * @version 0.0.2
 * @date 2025-01-21
 *
 * @copyright Copyright (c) 2025 Aiden Gursky. All Rights Reserved
 * @par License:
 * This project is released under the Artistic License 2.0
 *
 */

#include "stdint.h"
#include "stdio.h"
#include "memory/memory.h"
#include "memory/paging.h"
#include "arch/x86-64/idt.h"
#include "arch/x86-64/ata.h"
#include "fs/FAT/fat.h"
#include "disk.h"
#include "mbr.h"

/// @brief the full memory map
memory_map memoryMap[32];

/**
 * @brief Entry function
 * @details takes in bootdrive number and partition address as arguments
 *
 * @param[in] bootDrive Drive number passed by bios
 * @param[in] partitionAddress address in seg:off for partition data
 * @param[in] memoryMapAddress address to the memory map
 * @param[in] memoryMapSize number of entries in the memory map
 */
extern "C" void Start(uint16_t bootDrive, uint64_t partitionAddress, uint64_t memoryMapAddress, uint8_t memoryMapSize)
{

    init_map();

    disk Disk(&ATA_READ_PRIMARY);
    Partition part(&Disk);
    fatFS FatFileSystem(&part);

    clear_screen();

    puts("Hello World!\nThis is a large test of everything!!!!!\n");

    if (memoryMapSize > 32)
    {
        memoryMapSize = 32;
    }

    memcpy(&memoryMap, (void *)memoryMapAddress, memoryMapSize * 24);

    idt_init();

    ATA_IDENTIFY_PRIMARY();

    Disk.Init(bootDrive);
    part.Init((void *)partitionAddress);

    if (!FatFileSystem.Init())
    {
        puts("Failed to initialize FAT file system\n");
        while (1)
            ;
    }

    FAT_File *kernelFile = FatFileSystem.open("boot/kernel.elf");

    if (kernelFile == NULL)
    {
        puts("Failed to open file\r\n");
        while (1)
            ;
    }

    if (kernelFile->Size >= MEMORY_KERNEL_SIZE)
    {
        puts("File is too large to fit in memory!\r\n");
        while (1)
            ;
    }

    for (uint8_t i = 0; i < memoryMapSize; i++)
    {
        if (memoryMap[i].type == 1)
        {
            if (memoryMap[i].base > MEMORY_STAGE2_END)
            {
                if ((memoryMap[i].length + 0x1000) > MEMORY_KERNEL_SIZE)
                {
                    uint64_t base = (memoryMap[i].base + 0x1000) & 0xFFFFFFFFFFFFF000;
                    page_range_large(base, MEMORY_KERNEL_START, MEMORY_KERNEL_SIZE);
                    break;
                }
            }
        }
    }

    uint32_t read = FatFileSystem.read(kernelFile, kernelFile->Size, (void *)MEMORY_KERNEL_START);

    for (;;)
        ;
}