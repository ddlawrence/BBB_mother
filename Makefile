# CROSSCOMPILE = arm-linux-gnueabihf-
# arm-none-eabi  toolchain for Windows based compiling
CROSSCOMPILE = arm-none-eabi-

CFLAGS = -mcpu=cortex-a8 -marm -Wall -O2 -nostdlib -nostartfiles -ffreestanding -fstack-usage -Wstack-usage=8192

all : rts.elf

olib\startup.o : slib\startup.s
	$(CROSSCOMPILE)as slib\startup.s -o olib\startup.o

main.o : main.c
	$(CROSSCOMPILE)gcc $(CFLAGS) -c main.c -o main.o

olib\pff.o : pFAT\pff.c
	$(CROSSCOMPILE)gcc $(CFLAGS) -c pFAT\pff.c -o olib\pff.o

olib\diskio.o : pFAT\diskio.c
	$(CROSSCOMPILE)gcc $(CFLAGS) -c pFAT\diskio.c -o olib\diskio.o

olib\div.o : pFAT\div.c
	$(CROSSCOMPILE)gcc $(CFLAGS) -c pFAT\div.c -o olib\div.o

olib\irq.o : slib\irq.s
	$(CROSSCOMPILE)gcc $(CFLAGS) -c slib\irq.s -o olib\irq.o

olib\uart.o : slib\uart.s
	$(CROSSCOMPILE)gcc $(CFLAGS) -c slib\uart.s -o olib\uart.o

olib\gpio.o : slib\gpio.s
	$(CROSSCOMPILE)gcc $(CFLAGS) -c slib\gpio.s -o olib\gpio.o

olib\mmc.o : slib\mmc.s
	$(CROSSCOMPILE)gcc $(CFLAGS) -c slib\mmc.s -o olib\mmc.o

olib\i2c.o : slib\i2c.s
	$(CROSSCOMPILE)as -c slib\i2c.s -o olib\i2c.o

olib\pwm.o : slib\pwm.s
	$(CROSSCOMPILE)as -c slib\pwm.s -o olib\pwm.o

olib\timer.o : slib\timer.s
	$(CROSSCOMPILE)gcc $(CFLAGS) -c slib\timer.s -o olib\timer.o

rts.elf : memmap.lds olib\startup.o main.o olib\pff.o olib\diskio.o olib\div.o \
          olib\irq.o olib\uart.o olib\gpio.o olib\mmc.o olib\i2c.o olib\pwm.o \
          olib\timer.o
	$(CROSSCOMPILE)ld -o rts.elf -T memmap.lds olib\startup.o main.o olib\pff.o olib\diskio.o \
    olib\div.o olib\irq.o olib\uart.o olib\gpio.o olib\mmc.o olib\i2c.o olib\pwm.o \
    olib\timer.o
	$(CROSSCOMPILE)objcopy rts.elf rts.bin -O srec
# srec format for jtag loading (ie binary format with a short header)
# binary format for MMC booting
#	$(CROSSCOMPILE)objcopy rts.elf app -O binary
	$(CROSSCOMPILE)objdump -M reg-names-raw -D rts.elf > rts.lst
#	$(CROSSCOMPILE)objdump -d -S -h -t rts.elf > rts.dmp

clean :
	-@del olib\*.o *.o *.lst *.elf *.bin *.su
