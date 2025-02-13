#pragma once

#include "../../stdint.h"

typedef struct {
  uint16_t      unknown;                  //0
  uint16_t      unused_1[59];             //59
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

#define ATA_PRIMARY_DRIVE_SELECT  0x1F6
#define ATA_PRIMARY_PORT          0x1F7
#define ATA_PRIMARY_DATA          0x1F0
#define ATA_MASTER_DRIVE          0xA0
#define ATA_LBA_PORT_1            0x1F2
#define ATA_LBA_PORT_2            0x1F3
#define ATA_LBA_PORT_3            0x1F4
#define ATA_LBA_PORT_4            0x1F5
#define ATA_IDENTIFY_COMMAND      0xEC

