/**
 * @file ata.cpp
 * @author Aidcraft
 * @brief A simple bare bones ATA PIO driver for stage2
 * @version 0.1
 * @date 2025-02-13
 *
 * @copyright Copyright (c) 2025
 *
 */

#include "ata.h"
#include "io.h"
#include "../../memory/memory.h"

static IDENTIFY_RETURN identifyReturn;

void ATA_IDENTIFY_PRIMARY()
{
    outw(ATA_PRIMARY_RW_DRIVE, ATA_PRIMARY_ID_SELECT);
    outw(ATA_PRIMARY_RW_SECTOR_COUNT, 0);
    outw(ATA_PRIMARY_RW_LBA0, 0);
    outw(ATA_PRIMARY_RW_LBA1, 0);
    outw(ATA_PRIMARY_RW_LBA2, 0);
    outw(ATA_PRIMARY_W_COMMAND, ATA_CMD_IDENTIFY);

    uint16_t status;
    status = inw(ATA_PRIMARY_R_STATUS);

    if (status == 0)
    {
        return;
    }

    while ((status & 0x80) != 0)
    {
        uint16_t lba_mid, lba_high;

        lba_mid = inw(ATA_PRIMARY_RW_LBA1);

        if (lba_mid != 0)
        {
            return;
        }

        lba_high = inw(ATA_PRIMARY_RW_LBA2);

        if (lba_high != 0)
        {
            return;
        }

        status = inw(ATA_PRIMARY_R_STATUS);

        if ((status & 8) != 0)
        {
            break;
        }

        if ((status & 1) != 0)
        {
            return;
        }
    }

    uint16_t buffer[256];

    for (uint16_t i = 0; i < 256; i++)
    {
        buffer[i] = inw(ATA_PRIMARY_RW_DATA);
    }

    memcpy(&identifyReturn, (void *)buffer, 512);
}

bool ATA_READ_PRIMARY(void *buffer, uint8_t sectorCount, uint32_t LBA)
{
    // set drive
    DriveHeadRegister drive;
    drive.head      =   LBA >> 24 & 0x0F;
    drive.drv       =   0;
    drive.lba       =   1;
    drive.always1_5 =   1;
    drive.always1_7 =   1; 

    outb(ATA_PRIMARY_RW_DRIVE, *(reinterpret_cast<uint8_t*>(&drive)));

    outb(ATA_PRIMARY_W_FEATURE, 0);

    outb(ATA_PRIMARY_RW_SECTOR_COUNT, sectorCount);
    outb(ATA_PRIMARY_RW_LBA0, LBA);
    outb(ATA_PRIMARY_RW_LBA1, LBA >> 8);
    outb(ATA_PRIMARY_RW_LBA2, LBA >> 16);

    outb(ATA_PRIMARY_W_COMMAND, ATA_CMD_READ_PIO);

    // make sure that err and df are properly cleared
    inb(ATA_PRIMARY_R_STATUS);
    inb(ATA_PRIMARY_R_STATUS);
    inb(ATA_PRIMARY_R_STATUS);
    inb(ATA_PRIMARY_R_STATUS);

    uint8_t status = inb(ATA_PRIMARY_R_STATUS);

read_loop:

    while (true) {
        if ((status & 0x80) == 0){
            if ((status & 0x8) == 8){
                break;
            }
        }
        if (status & 0x1 != 0){
            return false;
        }
        if (status & 0x20 != 0){
            return false;
        }

        status = inb(ATA_PRIMARY_R_STATUS);
    }

    for(int i = 0; i < 256; i++){
        uint16_t word = inw(ATA_PRIMARY_RW_DATA);
        memcpy(buffer, &word, 2);
        buffer = static_cast<uint8_t*>(buffer) + 2;
    }

    sectorCount -= 1;

    if (sectorCount != 0) {
        goto read_loop;
    }

    return true;

}
