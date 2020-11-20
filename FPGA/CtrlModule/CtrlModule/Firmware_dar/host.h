#ifndef HOST_H
#define HOST_H

#define HOSTBASE 0xFFFFFFE0
#define HW_HOST(x) *(volatile unsigned int *)(HOSTBASE+x)

/* -- WRITE FROM ZPU HOST TO CORE -- */
/*-----------------------------------*/

/* Host control register */
#define REG_HOST_CONTROL 0x00
#define HOST_CONTROL_RESET 1
#define HOST_CONTROL_DIVERT_KEYBOARD 2
#define HOST_CONTROL_DIVERT_SDCARD 4

/* DIP switches / "Front Panel" controls - bits 15 downto 0 */
#define REG_HOST_SW 0x04

/* D64 Interface */
#define REG_D64_DATA_OUT 0x08
#define REG_D64_CONTROL 0x0C

/* TAP Interface */
#define REG_TAP_DATA 0x10
#define REG_TAP_CONTROL 0x14
#define REG_TAP_COUNT_DOWN 0x18
#define REG_TAP_COUNT_UP 0x1C

/* -- READ FROM CORE TO ZPU -- */
/*-----------------------------*/
#define REG_HOST_ 0x00
#define REG_D64_STATUS 0x04
#define REG_D64_DATA_IN 0x08
#define REG_TAP_STATUS 0x0C

#endif

