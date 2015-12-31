//
// Mother
//
// mixed C & Assembly BARE METAL Runtime System 
// for the BeagleboneBlack
//
// General Purpose I/O control, interrupt driven
// UART external communication, interrupt driven
// MultiMediaCard/SDcard disk storage
// I2C bus communication
// Pulse Width Modulation control
// Real Time Clock, interrupt driven
//
// Use this main program and Assembly drivers as a skeleton for your application 
// and strip out/add on whatever you need, freely, without restriction.  
//
// I use a jtag cable to load/boot the BBB, but you can boot from MMC.
//
// built with GNU tools :) on platform Win32 :(
//
// The file must already exist on SDcard and be of fixed/known size.  This is a limitation 
// of pFAT, you don't like it, volunteer to port the full FAT filesystem  ;)
// If filesize is unknown, guess.  Blocksize is 512 bytes
// Use a terminal emulator on UART0 115200 baud, 8 data, 1 stop, No parity
//
// 0.  RTC timer will flash LED USR1 every second under interrupt control
// 1.  MMC will read/modify/write/reread a MMC FAT32 file called "FILE320.TXT"
// 2.  Press boot button to flash USRLED2 under interrupt control
// 3.  Characters received by UART0 will be echoed under interrupt control & FIFO
// 4.  C character will read and display the I2C Compass HMC5883l from Sparkfun
// 5.  S character will move the servo back & forth
//
// TODO UART interrupt echoing
// TODO implement IRQ read/write to MMC & I2C
// TODO implement a full FAT32 filesystem
// TODO bump up the mmc clock
// TODO bump up sysclk to 1GHz (currently 40Mhz)
// TODO ethernet
// TODO usb
// TODO dma
// TODO GNU libc port
// if you want to get involved, contact at www.baremetal.tech
//
#include <stdio.h>
#include <stdint.h>

#include "main.h"

#include "pfat\pff.h"

inline void servo_1(uint32_t tbprd) {
  pwm_write_A(SOC_EPWM_0_REGS, tbprd);
}
inline void servo_2(uint32_t tbprd) {
  pwm_write_B(SOC_EPWM_0_REGS, tbprd);
}
inline void servo_3(uint32_t tbprd) {
  pwm_write_A(SOC_EPWM_1_REGS, tbprd);
}
inline void servo_4(uint32_t tbprd) {
  pwm_write_B(SOC_EPWM_1_REGS, tbprd);
}
inline void servo_5(uint32_t tbprd) {
  pwm_write_A(SOC_EPWM_2_REGS, tbprd);
}
inline void servo_6(uint32_t tbprd) {
  pwm_write_B(SOC_EPWM_2_REGS, tbprd);
}

void uart_putf(const char *fmt, ...);

uint32_t main() {
  uint32_t old_count=0, usr_leds;

  char i2c_buf[32];
  uint16_t x, y, z;

  uint32_t i=0, base, delta, direction, tbprd;

  FATFS fs;                           // Work area (file system object) for the volume
  BYTE buff[0x1000];                  // File read buffer
  uint32_t br;                        // File read byte count
  uint32_t bw;                        // File write byte count
  uint32_t ofs;                       // byte offset from beginning of file
  FRESULT res = FR_NOT_READY;         // Petit FatFs function common result code
  char filename[16] = "FILE320.TXT";  // file to open, old DOS filename convention
  uint32_t nbytes = 2048;             // max filesize/# bytes to read/write, multiple of 4

  usr_leds = 0xf << 21;  // enab USR LEDs, pin # 21-24
  gpio_init(SOC_GPIO_1_REGS, usr_leds);

  pinmux(CONF_UART_0_RXD, 0X30);     // PullUp, RxActive, MUXmode 0
  pinmux(CONF_UART_0_TXD, 0x10);     // PullUp, MUXmode 0, spruh73l 9.2.2, 9.3.1.49
  uart0_init(consoleUART);
  uart_tx(consoleUART, 0x0A);   // print n! in poll mode
  uart_tx(consoleUART, 0x6E);
  uart_tx(consoleUART, 0x21);
  uart_tx(consoleUART, 0x0A);

  poke(SOC_CM_PER_REGS, CM_PER_I2C1_CLKCTRL, 0x2);  // I2C1 module clock ENAB
  pinmux(CONF_I2C1_SDA, 0x72);  // Slow slew, receiver enabled, PullUp, MUXmode 2
  pinmux(CONF_I2C1_SCL, 0x72);  // was 0X62, spruh73l 9.2.2
  i2c_init(SOC_I2C_1_REGS);

  pinmux(GPIO_0_22, 4);  // pin P8_19  ehrpwm2A
  pinmux(GPIO_0_23, 4);  // pin P8_13  ehrpwm2B
  pinmux(GPIO_1_18, 6);  // pin P9_14  ehrpwm1A
  pinmux(GPIO_1_19, 6);  // pin P9_16  ehrpwm1B
  pinmux(GPIO_3_14, 1);  // pin P9_31  ehrpwm0A
  pinmux(GPIO_3_15, 1);  // pin P9_29  ehrpwm0B
  pwm_clk_init(SOC_PWMSS0_REGS);
  pwm_clk_init(SOC_PWMSS1_REGS);
  pwm_clk_init(SOC_PWMSS2_REGS);
  pwm_init(SOC_PWMSS0_REGS);
  pwm_init(SOC_PWMSS1_REGS);
  pwm_init(SOC_PWMSS2_REGS);

  irq_init();

  rtc_init();

  asm volatile(".word 0xe7f000f0");  // undefined instruction (test UND isr) remove later

  i2c_write(SOC_I2C_1_REGS, 0x1e0000, 0x70);  // 0x1e is the Compass Module address
  i2c_write(SOC_I2C_1_REGS, 0x1e0001, 0xa0);  // reg values per HMC5883L-FDS.pdf p18
  i2c_write(SOC_I2C_1_REGS, 0x1e0002, 0x00);

  uart_putf("\n-----pFATfs test-----\n");
// mount the volume
  res = pf_mount(&fs);      // mmc0_init() is called from pf_mount
  uart_putf("pf_mount ret 0x%x\n", res);
  if (res) goto spin;
// open a file
  uart_putf("opening %s\n", filename);
  res = pf_open(filename);
  uart_putf("pf_open ret 0x%x\n", res);
  if (res) goto spin;
// read file to buffer
  res = pf_read(buff, nbytes, &br);
  uart_putf("pf_read ret 0x%x\n", res);
  if (res) goto spin;
  buff[br] = 0x0;    // terminate the file buffer (just in case)
  uart_putf("file contents>\n%s<  %d bytes read\n", buff, br);
// make a small change to buffer data
  if(buff[3] == 0x58) buff[3] = 0x44;
  else buff[3] = 0x58;
// must call lseek before initial write operation
  ofs = 0;
  res = pf_lseek(ofs);
  if (res) goto spin;
// write to file
  res = pf_write(buff, br, &bw);
  uart_putf("pf_write  %d bytes ret 0x%x\n", bw, res);
  if (res) goto spin;
// check successful completion of write process
  if(bw < br)   uart_putf("ERR - attempt to write beyond EOF\n");
// terminate file write process
  res = pf_write(0, 0, &bw);
  uart_putf("pf_write close ret 0x%x\n", res);
  if (res) goto spin;
// read and display file
  ofs = 0;
  res = pf_lseek(ofs);
  uart_putf("pf_lseek to offset 0x%x ret 0x%x\n", ofs, res);
  res = pf_read(buff, nbytes, &br);
  buff[br] = 0x0;
  uart_putf("pf_read ret 0x%x\n", res);
  uart_putf("new file contents>\n%s<  %d bytes read\n", buff, br);

  base = (TICKS_PER_MS * PWM_PERIOD_MS)/20; // 1 msec base pulse width - RC Servo
  delta = base/10;                          // .1 msec pulse width increment
  i = 4;
  direction = 1;
spin:
  while (1) {
    if(old_count != uart0_irq_count) {  // trigger on changed IRQ count
      old_count = uart0_irq_count;
      if(uart0_rbuf >= 0x20) {          // ASCII char received
        uart0_tbuf = uart0_rbuf;
        uart_txi(consoleUART);          // echo char in interrupt mode
        if(uart0_rbuf == 'C') {         // take a Compass reading
          gpio_on(SOC_GPIO_1_REGS, 0x4<<21);  // flash LED USR3
          i2c_read(SOC_I2C_1_REGS, 0x1e0000, (uint32_t)i2c_buf, 13);  // read all 13 compass registers
          uart_tx(consoleUART, 0x0A);
          x = (i2c_buf[3] <<8) | i2c_buf[4];
          hexprint(x);
          y = (i2c_buf[5] <<8) | i2c_buf[6];
          hexprint(y);
          z = (i2c_buf[7] <<8) | i2c_buf[8];
          hexprint(z);
          uart_tx(consoleUART, 0x0A);
          gpio_off(SOC_GPIO_1_REGS, 0x4<<21);
        } else 
        if(uart0_rbuf == 'S') {         // move the Servos
          if(direction == 1) i++;
          if(direction == 0) i--;
          tbprd = base + (delta * i);
          servo_1(tbprd);
          servo_2(tbprd);
          servo_3(tbprd);
          servo_4(tbprd);
          servo_5(tbprd);
          servo_6(tbprd);
          if(i <= 0) direction = 1;
          if(i >= 10) direction = 0;
        }
        uart0_rbuf = 0x0;  // TODO needed 4 irq echo
      }
    }
  }
}
//
// uart_putf - ascii formatted print to uart
// 
// hacked from github.com/auselen
//
void uart_putf(const char *fmt, ...) {
  int *stack_head = __builtin_frame_address(0);
  stack_head += 2; // skip fmt, skip stack_head
  while (*fmt) {
    if (*fmt == '%') {
      fmt++;
      switch (*fmt++) {
        case 'c': {
          uart_tx(consoleUART, *stack_head++);
          break;
        }
        case 's': {
          const char *s = (char *) *stack_head++;
          while (*s) {
            uart_tx(consoleUART, *s++);
          }
          break;
        }
        case 'x': {
          int num = *stack_head++;
          int shift = 28;
          while (shift >= 0) {
            int hd = (num >> shift) & 0xf;
            if (hd > 9)
              hd += 'A' - 10;
            else
              hd += '0';
            uart_tx(consoleUART, hd);
            shift -= 4;
          }
          break;
        }
        case 'd': {
          int num = *stack_head++;
          char buf[16];
          char *s = buf + (sizeof(buf) / sizeof(buf[0])) - 1;
          char *e = s;
          do {
            *--s = '0' + num % 10;
          } while (num /= 10);
          while (s < e)
            uart_tx(consoleUART, *s++);
            break;
        }
        default:
          uart_tx(consoleUART, '?');
      }
    } else {
      uart_tx(consoleUART, *fmt++);
    }
  }
}