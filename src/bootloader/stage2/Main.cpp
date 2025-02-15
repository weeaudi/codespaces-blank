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
#include "arch/x86/idt.h"
#include "arch/x86/ata.h"

/**
 * @brief Entry function
 * @details takes in bootdrive number and partition address as arguments
 * 
 * @param[in] bootDrive Drive number passed by bios
 * @param[in] partition address in seg:off for partition data
 * @param[in] memoryMapAddress address to the memory map
 * @param[in] memoryMapSize number of entries in the memory map
 */

memory_map memoryMap[32];

extern "C" void Start(uint16_t bootDrive, uint32_t partition, uint64_t memoryMapAddress, uint8_t memoryMapSize){

    clear_screen();

    puts("Hello World!\nThis is a large test of everything!!!!!");

    if(memoryMapSize > 32){
        memoryMapSize = 32;
    }

    memcpy(&memoryMap, (void *)memoryMapAddress, memoryMapSize * 24);

    idt_init();

    ATA_IDENTIFY_PRIMARY();

    uint8_t buffer[512];

    ATA_READ_PRIMARY(&buffer, 1, 2);

    for(;;);

}