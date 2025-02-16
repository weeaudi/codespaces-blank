#pragma once

#include "../../stdint.h"

/// @brief Data returned from the IDENTIFY command
typedef struct {
  uint16_t      unused_1[60];             //59
  uint32_t      number_of_lba28_sectors;  //60+61
  uint16_t      unused_2[21];             //82
  uint16_t      lba48_support;            //83
  uint16_t      unused_3[4];              //87
  uint16_t      UDMA_MODES;               //88
  uint16_t      unused_4[4];              //92
  uint16_t      conductor_80_support;     //93
  uint16_t      unused_5[6];              //99
  uint64_t      number_of_lba48_sectors;  //100-103
  uint16_t      unused_6[152];            //255
} IDENTIFY_RETURN;

#define ATA_PRIMARY_IO_BASE             0x1F0
#define ATA_PRIMARY_CONTROL_BASE        0x3F6

#define ATA_PRIMARY_RW_DATA         ATA_PRIMARY_IO_BASE + 0
#define ATA_PRIMARY_R_ERROR         ATA_PRIMARY_IO_BASE + 1
#define ATA_PRIMARY_W_FEATURE       ATA_PRIMARY_IO_BASE + 1
#define ATA_PRIMARY_RW_SECTOR_COUNT ATA_PRIMARY_IO_BASE + 2
#define ATA_PRIMARY_RW_LBA0         ATA_PRIMARY_IO_BASE + 3
#define ATA_PRIMARY_RW_LBA1         ATA_PRIMARY_IO_BASE + 4
#define ATA_PRIMARY_RW_LBA2         ATA_PRIMARY_IO_BASE + 5
#define ATA_PRIMARY_RW_DRIVE        ATA_PRIMARY_IO_BASE + 6
#define ATA_PRIMARY_R_STATUS        ATA_PRIMARY_IO_BASE + 7
#define ATA_PRIMARY_W_COMMAND       ATA_PRIMARY_IO_BASE + 7

#define ATA_PRIMARY_R_ALT_STATUS    ATA_PRIMARY_CONTROL_BASE + 0
#define ATA_PRIMARY_W_DEVCTRL       ATA_PRIMARY_CONTROL_BASE + 0
#define ATA_PRIMARY_R_DRIVE_ADDR    ATA_PRIMARY_CONTROL_BASE + 1

#define ATA_ERROR_AMNF              1 << 0
#define ATA_ERROR_TKZNF             1 << 1
#define ATA_ERROR_ABRT              1 << 2
#define ATA_ERROR_MCR               1 << 3
#define ATA_ERROR_IDNF              1 << 4
#define ATA_ERROR_MC                1 << 5
#define ATA_ERROR_UNC               1 << 6
#define ATA_ERROR_BBK               1 << 7

#define ATA_CMD_READ_PIO            0x20
#define ATA_CMD_READ_PIO_EXT        0x24
#define ATA_CMD_READ_DMA            0xC8
#define ATA_CMD_READ_DMA_EXT        0x25
#define ATA_CMD_WRITE_PIO           0x30
#define ATA_CMD_WRITE_PIO_EXT       0x34
#define ATA_CMD_WRITE_DMA           0xCA
#define ATA_CMD_WRITE_DMA_EXT       0x35
#define ATA_CMD_CACHE_FLUSH         0xE7
#define ATA_CMD_CACHE_FLUSH_EXT     0xEA
#define ATA_CMD_PACKET              0xA0
#define ATA_CMD_IDENTIFY_PACKET     0xA1
#define ATA_CMD_IDENTIFY            0xEC

#define ATA_PRIMARY_ID_SELECT          0xA0
#define ATA_SECONDARY_ID_SELECT        0xB0

typedef struct {
    /// @brief Bits 0-3: CHS head / LBA bits 24-27
    unsigned int head      : 4;  

    /// @brief Bit 4: Drive select (0 = Master, 1 = Slave)
    unsigned int drv       : 1;  

    /// @brief Bit 5: Always set to 1
    unsigned int always1_5 : 1;  

    /// @brief Bit 6: LBA mode (1) or CHS mode (0)
    unsigned int lba       : 1;  

    /// @brief Bit 7: Always set to 1
    unsigned int always1_7 : 1;  

} __attribute__((packed)) DriveHeadRegister;


/**
 * @brief Currently Unused (will identify the current primary drive)
 * 
 */
void ATA_IDENTIFY_PRIMARY();

/**
 * @brief Reads from the primary disk into buffer
 * 
 * @param[out] buffer Buffer to write to. must be 512 bytes per sector
 * @param[in] sectorCount number of sectors to read
 * @param[in] LBA LBA to read from starting with 0
 * @return true Sucsses 
 * @return false Failed
 */
bool ATA_READ_PRIMARY(void *buffer, uint8_t sectorCount, uint32_t LBA);