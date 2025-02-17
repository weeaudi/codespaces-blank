#include "mbr.h"

Partition::Partition(disk* Disk)
{
    this->Disk = Disk;
}

bool Partition::Partition_Read(void* buffer, uint32_t sectorCount, uint32_t LBA)
{
    return this->Disk->read(buffer, sectorCount, this->partitionAddress + LBA);
}

void Partition::Init(void* partitionAddress)
{
    if(Disk->id < 0x80){
        puts("ERROR: Partitioning not supported on non-sata disks");
        while(1);
    }

    this->entry = (MBR_ENTRY*)partitionAddress;
    this->partitionAddress = entry->LBAOfFirstSector;
    this->partitionSize = entry->numberOfSectors;
}
