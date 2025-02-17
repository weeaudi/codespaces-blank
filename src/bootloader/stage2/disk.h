/**
 * @file disk.h
 * @author Aidcraft
 * @brief Disk class
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

/// @brief Function pointer for disk read function
using DiskReadFunc = bool (*)(void *, uint8_t, uint32_t);

class disk
{
private:
    DiskReadFunc readFunc;

public:
    /// @brief Reads from the disk
    /// @param buffer Buffer to read into
    /// @param sectorCount number of sectors to read
    /// @param LBA LBA to read from
    /// @return Sucess or failure
    bool read(void *buffer, uint8_t sectorCount, uint32_t LBA)
    {
        return readFunc(buffer, sectorCount, LBA);
    }

    /// @brief Initializes the disk
    /// @param id Id of the disk
    void Init(uint8_t id)
    {
        this->id = id;
    }

    /// @brief Id of the disk
    uint8_t id;

    /// @brief Constructor for disk
    /// @param readFunc Function to read from the disk (void* buffer, uint8_t sectorCount, uint32_t LBA)
    disk(DiskReadFunc readFunc);
};
