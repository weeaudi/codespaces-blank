/**
 * @file mbr.h
 * @author Aidcraft
 * @brief MBR structs
 * @version 0.0.2
 * @date 2025-02-16
 * 
 * @copyright Copyright (c) 2025 Aiden Gursky. All Rights Reserved
 * @par License:
 * This project is released under the Artistic License 2.0
 * 
 */

#pragma once

#include "stdint.h"
#include "disk.h"
#include "stdio.h"

typedef struct
{
    /// @brief Attributes for the partition
    uint8_t driveAttribute;

    /// @brief CHS of the first byte of the partition
    uint8_t chsStart[3];

    /// @brief Partition type
    uint8_t partitionType;

    /// @brief CHS of the last byte of the partition
    uint8_t chsEnd[3];

    /// @brief LBA of the first sector of the partition
    uint32_t LBAOfFirstSector;

    /// @brief Number of sectors in the partition
    uint32_t numberOfSectors;
} __attribute__((packed)) MBR_ENTRY;


class Partition
{
private:
    MBR_ENTRY* entry;
    uint32_t partitionAddress;
    uint32_t partitionSize;
    disk* Disk;
public:

    /// @brief Reads from the partition
    /// @param buffer buffer to read into
    /// @param sectorCount number of sectors to read
    /// @param LBA LBA to read from
    /// @return Success or failure
    bool Partition_Read(void* buffer, uint32_t sectorCount, uint32_t LBA);

    /// @brief Sets up the partition
    /// @param partitionAddress 
    void Init(void* partitionAddress);

    /// @brief Constructor
    /// @param Disk Pointer to the disk to use
    Partition(disk* Disk);
};