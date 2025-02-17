/**
 * @file fat.h
 * @author Aidcraft
 * @brief Fat driver
 * @version 0.0.2
 * @date 2025-02-16
 *
 * @copyright Copyright (c) 2025 Aiden Gursky. All Rights Reserved
 * @par License:
 * This project is released under the Artistic License 2.0
 *
 */
#pragma once

#include "../../stdint.h"
#include "../../stdio.h"
#include "../../stddef.h"
#include "../../string.h"
#include "../../mbr.h"
#include "../../memory/memory.h"

typedef struct 
{
    uint8_t Name[11];
    uint8_t Attributes;
    uint8_t _Reserved;
    uint8_t CreatedTimeTenths;
    uint16_t CreatedTime;
    uint16_t CreatedDate;
    uint16_t AccessedDate;
    uint16_t FirstClusterHigh;
    uint16_t ModifiedTime;
    uint16_t ModifiedDate;
    uint16_t FirstClusterLow;
    uint32_t Size;
} __attribute__((packed)) FAT_DirectoryEntry;

typedef struct 
{
    int Handle;
    bool IsDirectory;
    uint32_t Position;
    uint32_t Size;
} FAT_File;

enum FAT_Attributes
{
    FAT_ATTRIBUTE_READ_ONLY         = 0x01,
    FAT_ATTRIBUTE_HIDDEN            = 0x02,
    FAT_ATTRIBUTE_SYSTEM            = 0x04,
    FAT_ATTRIBUTE_VOLUME_ID         = 0x08,
    FAT_ATTRIBUTE_DIRECTORY         = 0x10,
    FAT_ATTRIBUTE_ARCHIVE           = 0x20,
    FAT_ATTRIBUTE_LFN               = FAT_ATTRIBUTE_READ_ONLY | FAT_ATTRIBUTE_HIDDEN | FAT_ATTRIBUTE_SYSTEM | FAT_ATTRIBUTE_VOLUME_ID
};

class fatFS
{
private:
    Partition* Disk;
    uint8_t FatType;

    bool readBootSector();
    uint32_t clusterToLba(uint32_t cluster);
    void FAT_Detect();
    bool findFile(FAT_File* file, const char* name, FAT_DirectoryEntry* entryOut);
    bool readEntry(FAT_File* file, FAT_DirectoryEntry* entry);
    uint32_t nextCluster(uint32_t currentCluster);
    bool readFat(uint32_t fatIndex);
    void close(FAT_File* file);
    FAT_File* openEntry(FAT_DirectoryEntry* entry);

public:

    /// @brief Reads from the file
    /// @param file File descriptor
    /// @param byteCount number of bytes to read
    /// @param dataOut buffer to read to
    /// @return number of bytes read
    uint32_t read(FAT_File* file, uint32_t byteCount, void* dataOut);

    /// @brief Opens a file
    /// @param disk Pointer to the disk
    /// @param path Path to the file
    /// @return Pointer to the file
    FAT_File* open(const char* path);

    /// @brief Constructor for FAT file system
    /// @param Disk pointer to disk partition
    fatFS(Partition* Disk);

    /// @brief Initializes the FAT file system
    /// @return Success or failure
    bool Init();
};
