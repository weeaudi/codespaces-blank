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
extern "C" void Start(uint16_t bootDrive, uint64_t partitionAddress, uint64_t memoryMapAddress, uint8_t memoryMapSize){

    disk Disk(&ATA_READ_PRIMARY);
    Partition part(&Disk);
    fatFS FatFileSystem(&part);

    clear_screen();

    puts("Hello World!\nThis is a large test of everything!!!!!\n");

    if(memoryMapSize > 32){
        memoryMapSize = 32;
    }

    memcpy(&memoryMap, (void *)memoryMapAddress, memoryMapSize * 24);

    idt_init();

    ATA_IDENTIFY_PRIMARY();

    Disk.Init(bootDrive);
    part.Init((void*)partitionAddress);

    if(!FatFileSystem.Init()){
        puts("Failed to initialize FAT file system\n");
        while(1);
    }

    FAT_File* file = FatFileSystem.open("boot/kernel.elf");

    uint8_t buffer[512];

    uint32_t read = FatFileSystem.read(file, 512, buffer);

    for(;;);

}