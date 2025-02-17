#include "fat.h"

#include "../../stdint.h"
#include "../../stdio.h"
#include "../../stddef.h"
#include "../../string.h"
#include "../../mbr.h"
#include "../../memory/memory.h"

#define SECTOR_SIZE 512
#define MAX_PATH_SIZE 256
#define MAX_FILE_HANDLES 10
#define ROOT_DIRECTORY_HANDLE -1
#define FAT_CACHE_SIZE 5

#define min(a, b) ((a) < (b) ? (a) : (b))
#define max(a, b) ((a) > (b) ? (a) : (b))

typedef struct
{
    // extended boot record
    uint8_t DriveNumber;
    uint8_t _Reserved;
    uint8_t Signature;
    uint32_t VolumeId;       // serial number, value doesn't matter
    uint8_t VolumeLabel[11]; // 11 bytes, padded with spaces
    uint8_t SystemId[8];
} __attribute__((packed)) FAT_ExtendedBootRecord;

typedef struct
{
    uint32_t SectorsPerFat;
    uint16_t Flags;
    uint16_t FatVersion;
    uint32_t RootDirectoryCluster;
    uint16_t FSInfoSector;
    uint16_t BackupBootSector;
    uint8_t _Reserved[12];
    FAT_ExtendedBootRecord EBR;

} __attribute((packed)) FAT32_ExtendedBootRecord;

typedef struct
{
    uint8_t BootJumpInstruction[3];
    uint8_t OemIdentifier[8];
    uint16_t BytesPerSector;
    uint8_t SectorsPerCluster;
    uint16_t ReservedSectors;
    uint8_t FatCount;
    uint16_t DirEntryCount;
    uint16_t TotalSectors;
    uint8_t MediaDescriptorType;
    uint16_t SectorsPerFat;
    uint16_t SectorsPerTrack;
    uint16_t Heads;
    uint32_t HiddenSectors;
    uint32_t LargeSectorCount;

    union
    {
        FAT_ExtendedBootRecord EBR1216;
        FAT32_ExtendedBootRecord EBR32;
    };

    // ... we don't care about code ...

} __attribute__((packed)) FAT_BootSector;

typedef struct
{
    uint8_t Buffer[SECTOR_SIZE];
    FAT_File Public;
    bool Opened;
    uint32_t FirstCluster;
    uint32_t CurrentCluster;
    uint32_t CurrentSectorInCluster;

} FAT_FileData;

typedef struct
{
    union
    {
        FAT_BootSector BootSector;
        uint8_t BootSectorBytes[SECTOR_SIZE];
    } BS;

    FAT_FileData RootDirectory;

    FAT_FileData OpenedFiles[MAX_FILE_HANDLES];

    uint8_t FatCache[FAT_CACHE_SIZE * SECTOR_SIZE];
    uint32_t FatCachePosition;

} FAT_Data;

static FAT_Data *g_Data;
static uint32_t g_DataSectionLba;
static uint32_t g_TotalSectors;
static uint32_t g_SectorsPerFat;

fatFS::fatFS(Partition *Disk)
{
    this->Disk = Disk;
}

bool fatFS::readBootSector()
{
    return this->Disk->Partition_Read(&g_Data->BS, 1, 0);
}

uint32_t fatFS::clusterToLba(uint32_t cluster)
{
    return g_DataSectionLba + (cluster - 2) * g_Data->BS.BootSector.SectorsPerCluster;
}

void fatFS::FAT_Detect()
{
    uint32_t dataClusters = (g_TotalSectors - g_DataSectionLba) / g_Data->BS.BootSector.SectorsPerCluster;
    if (dataClusters < 0xFF5)
        this->FatType = 12;
    else if (g_Data->BS.BootSector.SectorsPerFat != 0)
        this->FatType = 16;
    else
        this->FatType = 32;
}

bool fatFS::Init()
{

    g_Data = (FAT_Data *)MEMORY_FAT_START;

    if (!this->readBootSector())
    {
        puts("Failed to read boot sector");
        return false;
    }

    g_Data->FatCachePosition = 0xFFFFFFFF;

    g_TotalSectors = g_Data->BS.BootSector.TotalSectors;
    if (g_TotalSectors == 0)
    { // fat32
        g_TotalSectors = g_Data->BS.BootSector.LargeSectorCount;
    }

    bool isFat32 = false;
    g_SectorsPerFat = g_Data->BS.BootSector.SectorsPerFat;
    if (g_SectorsPerFat == 0)
    { // fat32
        isFat32 = true;
        g_SectorsPerFat = g_Data->BS.BootSector.EBR32.SectorsPerFat;
    }

    // open root directory file
    uint32_t rootDirLba;
    uint32_t rootDirSize;
    if (isFat32)
    {
        g_DataSectionLba = g_Data->BS.BootSector.ReservedSectors + g_SectorsPerFat * g_Data->BS.BootSector.FatCount;
        rootDirLba = this->clusterToLba(g_Data->BS.BootSector.EBR32.RootDirectoryCluster);
        rootDirSize = 0;
    }
    else
    {
        rootDirLba = g_Data->BS.BootSector.ReservedSectors + g_SectorsPerFat * g_Data->BS.BootSector.FatCount;
        rootDirSize = sizeof(FAT_DirectoryEntry) * g_Data->BS.BootSector.DirEntryCount;
        uint32_t rootDirSectors = (rootDirSize + g_Data->BS.BootSector.BytesPerSector - 1) / g_Data->BS.BootSector.BytesPerSector;
        g_DataSectionLba = rootDirLba + rootDirSectors;
    }

    g_Data->RootDirectory.Public.Handle = ROOT_DIRECTORY_HANDLE;
    g_Data->RootDirectory.Public.IsDirectory = true;
    g_Data->RootDirectory.Public.Position = 0;
    g_Data->RootDirectory.Public.Size = sizeof(FAT_DirectoryEntry) * g_Data->BS.BootSector.DirEntryCount;
    g_Data->RootDirectory.Opened = true;
    g_Data->RootDirectory.FirstCluster = rootDirLba;
    g_Data->RootDirectory.CurrentCluster = rootDirLba;
    g_Data->RootDirectory.CurrentSectorInCluster = 0;

    if (!this->Disk->Partition_Read(&g_Data->RootDirectory.Buffer, 1, rootDirLba))
    {
        puts("Failed to read root directory\n");
        return false;
    }

    this->FAT_Detect();

    for (int i = 0; i < MAX_FILE_HANDLES; i++)
        g_Data->OpenedFiles[i].Opened = false;

    return true;
}

FAT_File *fatFS::open(const char *path)
{
    char name[MAX_PATH_SIZE];

    // ignore leading slash
    if (path[0] == '/')
        path++;

    FAT_File *current = &g_Data->RootDirectory.Public;

    while (*path)
    {
        // extract next file name from path
        bool isLast = false;
        const char *delim = strchr(path, '/');
        if (delim != NULL)
        {
            memcpy(name, path, delim - path);
            name[delim - path] = '\0';
            path = delim + 1;
        }
        else
        {
            unsigned len = strlen(path);
            memcpy(name, path, len);
            name[len + 1] = '\0';
            path += len;
            isLast = true;
        }
        // find directory entry in current directory
        FAT_DirectoryEntry entry;
        if (this->findFile(current, name, &entry))
        {
            this->close(current);

            // check if directory
            if (!isLast && entry.Attributes & FAT_ATTRIBUTE_DIRECTORY == 0)
            {
                puts("FAT: not a directory\r\n");
                return NULL;
            }

            // open new directory entry
            current = this->openEntry(&entry);
        }
        else
        {
            this->close(current);

            puts("FAT: not found\r\n");
            return NULL;
        }
    }

    return current;
}

bool fatFS::findFile(FAT_File *file, const char *name, FAT_DirectoryEntry *entryOut)
{
    char fatName[12];
    FAT_DirectoryEntry entry;

    // convert from name to fat name
    memset(fatName, ' ', sizeof(fatName));
    fatName[11] = '\0';

    const char *ext = strchr(name, '.');
    if (ext == NULL)
        ext = name + 11;

    for (int i = 0; i < 8 && name[i] && name + i < ext; i++)
        fatName[i] = toupper(name[i]);

    if (ext != name + 11)
    {
        for (int i = 0; i < 3 && ext[i + 1]; i++)
            fatName[i + 8] = toupper(ext[i + 1]);
    }

    while (this->readEntry(file, &entry))
    {
        if (memcmp(fatName, entry.Name, 11) == true)
        {
            *entryOut = entry;
            return true;
        }
    }

    return false;
}

bool fatFS::readEntry(FAT_File *file, FAT_DirectoryEntry *dirEntry)
{
    uint32_t output = this->read(file, sizeof(FAT_DirectoryEntry), dirEntry) == sizeof(FAT_DirectoryEntry);
    if (output && dirEntry->Name[0] == 0)
        output = false;
    return output;
}

uint32_t fatFS::read(FAT_File *file, uint32_t byteCount, void *dataOut)
{
    // get file data
    FAT_FileData *fd = (file->Handle == ROOT_DIRECTORY_HANDLE)
                           ? &g_Data->RootDirectory
                           : &g_Data->OpenedFiles[file->Handle];

    uint8_t *u8DataOut = (uint8_t *)dataOut;

    // don't read past the end of the file
    if (!fd->Public.IsDirectory || (fd->Public.IsDirectory && fd->Public.Size != 0))
        byteCount = min(byteCount, fd->Public.Size - fd->Public.Position);

    while (byteCount > 0)
    {
        uint32_t leftInBuffer = SECTOR_SIZE - (fd->Public.Position % SECTOR_SIZE);
        uint32_t take = min(byteCount, leftInBuffer);

        memcpy(u8DataOut, fd->Buffer + fd->Public.Position % SECTOR_SIZE, take);
        u8DataOut += take;
        fd->Public.Position += take;
        byteCount -= take;

        // printf("leftInBuffer=%lu take=%lu\r\n", leftInBuffer, take);
        // See if we need to read more data
        if (leftInBuffer == take)
        {
            // calculate next cluster & sector to read
            if (++fd->CurrentSectorInCluster >= g_Data->BS.BootSector.SectorsPerCluster)
            {
                fd->CurrentSectorInCluster = 0;
                fd->CurrentCluster = this->nextCluster(fd->CurrentCluster);
            }

            if (fd->CurrentCluster >= 0xFFFFFFF8)
            {
                // Mark end of file
                fd->Public.Size = fd->Public.Position;
                break;
            }

            // read next sector
            if (!this->Disk->Partition_Read(fd->Buffer, 1, this->clusterToLba(fd->CurrentCluster) + fd->CurrentSectorInCluster))
            {
                printf("FAT: read error!\r\n");
                break;
            }
        }
    }

    return u8DataOut - (uint8_t *)dataOut;
}

uint32_t fatFS::nextCluster(uint32_t currentCluster)
{
    // Determine the byte offset of the entry we need to read
    uint32_t fatIndex;
    if (this->FatType == 12)
    {
        fatIndex = currentCluster * 3 / 2;
    }
    else if (this->FatType == 16)
    {
        fatIndex = currentCluster * 2;
    }
    else /*if (this->FatType == 32)*/
    {
        fatIndex = currentCluster * 4;
    }

    // Make sure cache has the right number
    uint32_t fatIndexSector = fatIndex / SECTOR_SIZE;
    if (fatIndexSector < g_Data->FatCachePosition || fatIndexSector >= g_Data->FatCachePosition + FAT_CACHE_SIZE)
    {
        this->readFat(fatIndexSector);
        g_Data->FatCachePosition = fatIndexSector;
    }

    fatIndex -= (g_Data->FatCachePosition * SECTOR_SIZE);

    uint32_t nextCluster;
    if (this->FatType == 12)
    {
        if (currentCluster % 2 == 0)
            nextCluster = (*(uint16_t *)(g_Data->FatCache + fatIndex)) & 0x0FFF;
        else
            nextCluster = (*(uint16_t *)(g_Data->FatCache + fatIndex)) >> 4;

        if (nextCluster >= 0xFF8)
        {
            nextCluster |= 0xFFFFF000;
        }
    }
    else if (this->FatType == 16)
    {
        nextCluster = *(uint16_t *)(g_Data->FatCache + fatIndex);
        if (nextCluster >= 0xFFF8)
        {
            nextCluster |= 0xFFFF0000;
        }
    }
    else /*if (this->FatType == 32)*/
    {
        nextCluster = *(uint32_t *)(g_Data->FatCache + fatIndex);
    }

    return nextCluster;
}

bool fatFS::readFat(uint32_t lbaIndex)
{
    return this->Disk->Partition_Read(g_Data->FatCache, FAT_CACHE_SIZE, g_Data->BS.BootSector.ReservedSectors + lbaIndex);
}

void fatFS::close(FAT_File *file)
{
    if (file->Handle == ROOT_DIRECTORY_HANDLE)
    {
        file->Position = 0;
        g_Data->RootDirectory.CurrentCluster = g_Data->RootDirectory.FirstCluster;
    }
    else
    {
        g_Data->OpenedFiles[file->Handle].Opened = false;
    }
}

FAT_File *fatFS::openEntry(FAT_DirectoryEntry *entry)
{
    // find empty handle
    int handle = -1;
    for (int i = 0; i < MAX_FILE_HANDLES && handle < 0; i++)
    {
        if (!g_Data->OpenedFiles[i].Opened)
            handle = i;
    }

    // out of handles
    if (handle < 0)
    {
        printf("FAT: out of file handles\r\n");
        return 0;
    }

    // setup vars
    FAT_FileData *fd = &g_Data->OpenedFiles[handle];
    fd->Public.Handle = handle;
    fd->Public.IsDirectory = (entry->Attributes & FAT_ATTRIBUTE_DIRECTORY) != 0;
    fd->Public.Position = 0;
    fd->Public.Size = entry->Size;
    fd->FirstCluster = entry->FirstClusterLow + ((uint32_t)entry->FirstClusterHigh << 16);
    fd->CurrentCluster = fd->FirstCluster;
    fd->CurrentSectorInCluster = 0;

    if (!this->Disk->Partition_Read(fd->Buffer, 1, this->clusterToLba(fd->CurrentCluster)))
    {
        printf("FAT: open entry failed - read error cluster=%u lba=%u\n", fd->CurrentCluster, this->clusterToLba(fd->CurrentCluster));
        for (int i = 0; i < 11; i++)
            printf("%c", entry->Name[i]);
        printf("\n");
        return 0;
    }

    fd->Opened = true;
    return &fd->Public;
}