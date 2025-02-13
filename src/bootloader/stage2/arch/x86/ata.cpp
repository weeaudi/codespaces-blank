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

uint16_t buffer[256];

void ATA_IDENTIFY_PRIMARY(){
  outw(ATA_PRIMARY_DRIVE_SELECT, ATA_MASTER_DRIVE);
  outw(ATA_LBA_PORT_1, 0);
  outw(ATA_LBA_PORT_2, 0);
  outw(ATA_LBA_PORT_3, 0);
  outw(ATA_LBA_PORT_4, 0);
  outw(ATA_PRIMARY_PORT, ATA_IDENTIFY_COMMAND);

  uint16_t status;
  status = inw(ATA_PRIMARY_PORT);

  if (status == 0){
    return;
  }

  while ((status & 0x80) != 0){
    uint16_t lba_mid, lba_high;

    lba_mid = inw(ATA_LBA_PORT_3);

    if (lba_mid != 0){
      return;
    }

    lba_high = inw(ATA_LBA_PORT_4);

    if(lba_high != 0){
      return;
    }

    status = inw(ATA_PRIMARY_PORT);

    if ((status & 8) != 0){
      break;
    }

    if ((status & 1) != 0){
      return;
    }

  }

  for (uint16_t i = 0; i < 256; i++){
    buffer[i] = inw(ATA_PRIMARY_DATA);
  }

  memcpy(&identifyReturn, (void*)buffer, 256);

}
