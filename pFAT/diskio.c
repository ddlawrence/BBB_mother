//
//  Low level disk I/O module skeleton for Petit FatFs (C)ChaN, 2014
//  BBB MMC driver hacked from Jan Kees, github.com/keesj/bonecode
//  driver implemented in poll mode

#include <stdio.h>
#include <inttypes.h>
#include "pff.h"
#include "diskio.h"

#include "bbbMMC.h"

extern uint32_t mmc0_init();
extern uint32_t send_cmd(uint32_t command, uint32_t arg);

struct sd_card {
  uint32_t cid[4];    // Card Identification
  uint32_t rca;       // Relative card address
  uint32_t dsr;       // Driver stage register
  uint32_t csd[4];    // Card specific data
  uint32_t scr[2];    // SD configuration
  uint32_t ocr;       // Operation conditions
  uint32_t ssr[5];    // SD Status
  uint32_t csr;       // Card status
};
struct sd_card card;

//
//  Write a uint32_t value to a memory address
//
inline void write32(uint32_t address, uint32_t value) {
  REG(address)= value;
}
//
//  Read an uint32_t from a memory address
//
inline uint32_t read32(uint32_t address) {
  return REG(address);
}
//
//  Set a 32 bits value depending on a mask
//
inline void set32(uint32_t address, uint32_t mask, uint32_t value) {
  uint32_t val;
  val= read32(address);
  val&= ~(mask);  // clear the bits
  val|= (value & mask);  // apply the value using the mask
  write32(address, val);
}
//
//  read a SINGLE block 
//
int read_single_block(struct sd_card *card, uint32_t blknr, unsigned char *buf) {
  uint32_t count;
  uint32_t value;
  count= 0;
  set32(MMCHS0_REG_BASE + MMCHS_SD_IE, MMCHS_SD_IE_BRR_ENABLE, MMCHS_SD_IE_BRR_ENABLE_ENABLE);
  set32(MMCHS0_REG_BASE + MMCHS_SD_BLK, MMCHS_SD_BLK_BLEN, 512);
  if (send_cmd(MMCHS_SD_CMD_CMD17         // read single block
             | MMCHS_SD_CMD_DP_DATA       // Command with data transfer
             | MMCHS_SD_CMD_RSP_TYPE_48B  // type (R1)
             | MMCHS_SD_CMD_MSBS_SINGLE   // single block
             | MMCHS_SD_CMD_DDIR_READ     // read data from card
             , blknr)) {
    return 1;
  }
  while ((read32(MMCHS0_REG_BASE + MMCHS_SD_STAT)	& MMCHS_SD_IE_BRR_ENABLE_ENABLE) == 0) {
    count++;
  }
  if (!(read32(MMCHS0_REG_BASE + MMCHS_SD_PSTATE) & MMCHS_SD_PSTATE_BRE_EN)) {
    return 1; // We are not allowed to read data from the data buffer
  }
  for (count= 0; count < 512; count += 4) {
    value= read32(MMCHS0_REG_BASE + MMCHS_SD_DATA);
    buf[count]= *((char*) &value);
    buf[count + 1]= *((char*) &value + 1);
    buf[count + 2]= *((char*) &value + 2);
    buf[count + 3]= *((char*) &value + 3);
  }
  // Wait for TC
  while ((read32(MMCHS0_REG_BASE + MMCHS_SD_STAT) & MMCHS_SD_IE_TC_ENABLE_ENABLE) == 0) {
    count++;
  }
  write32(MMCHS0_REG_BASE + MMCHS_SD_STAT, MMCHS_SD_IE_TC_ENABLE_CLEAR);
  // clear and disable the bbr interrupt
  write32(MMCHS0_REG_BASE + MMCHS_SD_STAT, MMCHS_SD_IE_BRR_ENABLE_CLEAR);
  set32(MMCHS0_REG_BASE + MMCHS_SD_IE, MMCHS_SD_IE_BRR_ENABLE, MMCHS_SD_IE_BRR_ENABLE_DISABLE);
  return 0;
}
//
//  Initialize Disk Drive
//
DSTATUS disk_initialize (void)
{
  DSTATUS stat;
  int result;

  result = mmc0_init();            // assembly init routine
  if(result) return RES_ERROR;
  stat = RES_OK;
  return stat;
}
//
// Read Partial Sector
//
DRESULT disk_readp (BYTE* buff,		 // Pointer to the destination object
                    DWORD sector,	 // Sector number (LBA)
                    UINT offset,	 // Offset in the sector
                    UINT count) {	 // Byte count (bit15:destination)
  unsigned char temp[0x1500];
  unsigned char *pbuf = temp;
  DRESULT res;
  int i, result;
  if(offset > 511) return RES_PARERR;
  if(offset + count > 512) count = 512 - offset;
  result = read_single_block(&card, sector, pbuf);
  if(result) return RES_ERROR;
  for (i = 0; i < count; i++) {
    buff[i] = temp[i + offset];
  } 
  res = RES_OK;
  return res;
}
//
// Write Partial Sector
//
DRESULT disk_writep (
  const BYTE* buff,		// write data pointer, if NULL - initiate/finalize write operation
  DWORD sc) {         // Sector number (LBA) or Number of bytes to send
  DRESULT res;
  uint32_t i;
  uint32_t value;
  UINT bc;            // tx byte count
  static UINT wc;     // write count (count down from 512)

  i = 0;
  if (!buff) {
    if (sc) { 	// initiate write process
      set32(MMCHS0_REG_BASE + MMCHS_SD_IE, MMCHS_SD_IE_BWR_ENABLE, MMCHS_SD_IE_BWR_ENABLE_ENABLE);
      //set32(MMCHS0_REG_BASE + MMCHS_SD_IE, 0xfff , 0xfff);
      set32(MMCHS0_REG_BASE + MMCHS_SD_BLK, MMCHS_SD_BLK_BLEN, 512);
      // set timeout
      set32(MMCHS0_REG_BASE + MMCHS_SD_SYSCTL, MMCHS_SD_SYSCTL_DTO, MMCHS_SD_SYSCTL_DTO_2POW27);
      if (send_cmd(MMCHS_SD_CMD_CMD24         // write single block
                 | MMCHS_SD_CMD_DP_DATA       // Command with data transfer 
                 | MMCHS_SD_CMD_RSP_TYPE_48B  // type (R1b)
                 | MMCHS_SD_CMD_MSBS_SINGLE   // single block
                 | MMCHS_SD_CMD_DDIR_WRITE    // write to the card
                 , sc)) {
        return RES_ERROR;
      }
      // wait for the MMCHS_SD_IE_BWR_ENABLE interrupt
      while ((read32(MMCHS0_REG_BASE + MMCHS_SD_STAT) & MMCHS_SD_IE_BWR_ENABLE)	== 0) {
        i++;
      }
      if (!(read32(MMCHS0_REG_BASE + MMCHS_SD_PSTATE) & MMCHS_SD_PSTATE_BWE_EN)) {
        return RES_NOTRDY;  // not ready to write data
      }
      wc = 512;							// set byte counter
      res = RES_OK;
    } else {  // finalize write process
      bc = wc>>2;  // xmit 4 bytes in a single swoop
      while (bc--) write32(MMCHS0_REG_BASE + MMCHS_SD_DATA, 0);	// backfill block and CRC with 0s
      // Wait for TC
      while ((read32(MMCHS0_REG_BASE + MMCHS_SD_STAT)	& MMCHS_SD_IE_TC_ENABLE_ENABLE) == 0) {
        i++;
      }
      write32(MMCHS0_REG_BASE + MMCHS_SD_STAT, MMCHS_SD_IE_TC_ENABLE_CLEAR);
      write32(MMCHS0_REG_BASE + MMCHS_SD_STAT, MMCHS_SD_IE_CC_ENABLE_CLEAR);  // finished
      // clear the bwr interrupt TODO is this correct when writing?
      write32(MMCHS0_REG_BASE + MMCHS_SD_STAT, MMCHS_SD_IE_BWR_ENABLE_CLEAR);
      set32(MMCHS0_REG_BASE + MMCHS_SD_IE, MMCHS_SD_IE_BWR_ENABLE, MMCHS_SD_IE_BWR_ENABLE_DISABLE);
      res = RES_OK;
    }
  } else {	// Send data to the disk
    bc = (UINT)sc;
    i = 0;
    while (bc && wc) {	// Send data bytes to the card
      *((char*) &value)= buff[i];
      *((char*) &value + 1)= buff[i + 1];
      *((char*) &value + 2)= buff[i + 2];
      *((char*) &value + 3)= buff[i + 3];
      write32(MMCHS0_REG_BASE + MMCHS_SD_DATA, value);
      i += 4;
      wc -= 4;
      bc -= 4;
    }
    res = RES_OK;
  }
  return res;
}
//  FINITO
