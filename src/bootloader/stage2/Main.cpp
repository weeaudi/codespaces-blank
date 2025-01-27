/**
 * @file Main.cpp
 * @include{lineno} Main.cpp
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

/**
 * @brief Entry function
 * @details takes in bootdrive number and partition address as arguments
 * @fn Start
 * @param[in] bootDrive Drive number passed by bios
 * @param[in] partition address in seg:off for partition data
 */
extern "C" void Start(uint16_t bootDrive, uint32_t partition, uint64_t memoryMapAddress){

    

}