//
// GPIO routines
//
.syntax unified
.data
SOC_CM_PER_REGS         = 0x44E00000
CM_PER_GPIO1_CLKCTRL    = 0xac
CM_PER_GPIO2_CLKCTRL    = 0xb0

SOC_CONTROL_REGS        = 0x44E10000
GPIO_1_21               = 0x854      // LED USR1
GPIO_1_22               = 0x858      // LED USR2
GPIO_1_23               = 0x85C      // LED USR3
GPIO_1_24               = 0x860      // LED USR4

.global SOC_GPIO_1_REGS    // allow global access to USR LEDs
.global GPIO_CLEARDATAOUT
.global GPIO_SETDATAOUT

SOC_GPIO_0_REGS         = 0x44E07000
SOC_GPIO_1_REGS         = 0x4804c000
SOC_GPIO_2_REGS         = 0x481ac000
SOC_GPIO_3_REGS         = 0x481AE000
GPIO_SYSCONFIG          = 0x10
GPIO_IRQSTATUS_RAW_0    = 0x24
GPIO_IRQSTATUS_0 	      = 0x2c
GPIO_IRQSTATUS_SET_0    = 0x34
GPIO_SYSSTATUS          = 0x114
GPIO_CTRL               = 0x130
GPIO_OE                 = 0x134
GPIO_DATAIN	            = 0x138
GPIO_LEVELDETECT0       = 0x140
GPIO_LEVELDETECT1       = 0x144
GPIO_RISINGDETECT	      = 0x148
GPIO_FALLINGDETECT      = 0x14c
GPIO_DEBOUNCENABLE	    = 0x150
GPIO_DEBOUNCINGTIME     = 0x154
GPIO_CLEARDATAOUT		    = 0x190
GPIO_SETDATAOUT		      = 0x194

.text
//
// gpio module init
// hacked from Nick Kondrashov github/spbnick
// & Mattius van Duin, TI e2e forum
//
// @param gpio_base_addr      uint32, GPIO module base address
// @param gpio_pins           uint32, a bit for each pin
//
// @return   0=success or 1=fail
//
.global gpio_init
gpio_init:
    r_base .req r0
    r_pin .req r1
    ldr r2, =SOC_CM_PER_REGS            // Enable GPIO module clocks
    ldr r3, =0x40002                    // FCLK_EN, MODULEMODE ENABLE, spruh73l 8.1.12.1.30 
    str r3, [r2, CM_PER_GPIO1_CLKCTRL]  // for USRLEDs
    str r3, [r2, CM_PER_GPIO2_CLKCTRL]  // for boot button GPIO2_8

    mvn r_pin, r_pin                // enable pins/lines for output, spruh73l 25.4.1.16 
    str r_pin, [r_base, GPIO_OE]

    ldr	r2, =SOC_GPIO_2_REGS
    mov	r3, 0x2                     // soft reset gpio module, spruh73l 25.3.2.4, tab 25-7
    str	r3, [r2, GPIO_SYSCONFIG]
1:  ldr	r3, [r2, GPIO_SYSSTATUS]
    tst	r3, 0x1                     // wait for reset complete, spruh73l tab 25-19
    beq	1b
    mov r3, 0x10                    // IDLEMODE = smart
    str	r3, [r2, GPIO_SYSCONFIG]
    mov	r3, 0x0
    str	r3, [r2, GPIO_CTRL]         // module enable (default)
    mov	r3, 1 << 8                  // setup boot button for irq
    str	r3, [r2, GPIO_OE]           // enable for input (default)
    str	r3, [r2, GPIO_IRQSTATUS_SET_0]
    str	r3, [r2, GPIO_DEBOUNCENABLE]
    str	r3, [r2, GPIO_RISINGDETECT]
    str	r3, [r2, GPIO_FALLINGDETECT]
    mov r3, 0x10                      // debounce time n * 31usec
    str	r3, [r2, GPIO_DEBOUNCINGTIME]
    mov r_base, #0x0
    bx lr
    .unreq r_base
    .unreq r_pin

//
// gpio interrupt service routine
//
// hacked from Mattius van Duin, TI e2e forum
//
.global gpio_isr
gpio_isr:
    ldr	r0, =SOC_GPIO_2_REGS        // boot button is at GPIO2_8
    mov	r1, 1 << 8                  // clear INTLINE[8] of GPIOIRQ0 interrupt
    str	r1, [r0, GPIO_IRQSTATUS_0]  // spruh73l 25.4.1.6

    ldr	r1, [r0, GPIO_DATAIN]       // read all GPIO2 pins
    tst	r1, 1 << 8                  // test boot button
    ldr	r0, =SOC_GPIO_1_REGS        // actuate USRLED2
    mov	r1, 1 << 22                 // USRLED2 is GPIO1_22
    beq	1f
    str	r1, [r0, GPIO_CLEARDATAOUT]
    b gpio_isr_exit
1:  str	r1, [r0, GPIO_SETDATAOUT]

gpio_isr_exit:
    ldr r0, =gpio_irq_count    // increment counter, C variable
    ldr r1, [r0]
    add r1, r1, #0x1
    str r1, [r0]
    bx lr

//
// turn on/set gpio pin/line(s)
//
// @param gpio_base_addr    uint32, GPIO module base address
// @param gpio_pins         uint32, a bit for every pin/line
//
// NB only pins written with a 1 will be affected
//
.global gpio_on
gpio_on:
    r_base .req r0
    r_pin .req r1
    str r_pin, [r_base, GPIO_SETDATAOUT]
    bx lr
    .unreq r_base
    .unreq r_pin

//
// turn off/reset gpio pin/line(s)
//
// @param gpio_base_addr    uint32, GPIO module base address
// @param gpio_pins         uint32, a bit for every pin/line
//
.global gpio_off
gpio_off:
    r_base .req r0
    r_pin .req r1
    str r_pin, [r_base, GPIO_CLEARDATAOUT]
    bx lr
    .unreq r_base
    .unreq r_pin

//
// read gpio pins/lines
//
// @param gpio_base_addr    uint32, GPIO module base address
//
// @return   r0 - uint32, sampled input data, a bit for every pin/line
//
.global gpio_read
gpio_read:
    r_base .req r0
    ldr	r1, [r0, GPIO_DATAIN]       // read all 32 GPIO pins
    mov r0, r1
    bx lr
    .unreq r_base

//
// blink a 32bit word on the USER LEDs
//
// @param data         uint32
//
// light the 4 LEDs according to the half-bytes set in data (r0)
// Least Significant half-Byte displayed first
// half-bytes preceded by strobe of all 4 LEDs
// an easy way to probe a register! (a poor man's logic anaylzer)
//
.global blink32
blink32:
    r_data .req r0
    r_base .req r1
    stmfd sp!, {r0-r4, lr}
    mov r4, r_data
    mov r3, #0x8                           // counter, 8 half-bytes per word
    ldr r_base, =SOC_GPIO_1_REGS
blinkloop:
    mov	r_data, #0X1E00000                 // strobe LEDs to mark beginning of half-byte
    str	r_data, [r_base, GPIO_CLEARDATAOUT]
    mov r2, #0x100000                      // small delay
1:  sub r2, r2, #0x1
    cmp r2, #0x0
    bne 1b
    str	r_data, [r_base, GPIO_SETDATAOUT]
    mov r2, #0x80000                       // small delay
1:  sub r2, r2, #0x1
    cmp r2, #0x0
    bne 1b
    str	r_data, [r_base, GPIO_CLEARDATAOUT]
    mov r2, #0x100000                      // small delay
1:  sub r2, r2, #0x1
    cmp r2, #0x0
    bne 1b

    and r_data, r4, #0xF                   // write out half-byte to LED pins
    mov r4, r4, lsr #4
    mov	r_data, r_data, lsl #21
    str	r_data, [r_base, GPIO_SETDATAOUT]

    mov r2, #0x1000000                     // kill time between half-bytes
1:  sub r2, r2, #0x1
    cmp r2, #0x0
    bne 1b

    sub r3, r3, #0x1                       // do next half-byte
    cmp r3, #0x0
    bne blinkloop
    ldmfd sp!, {r0-r4, pc}
    .unreq r_data
    .unreq r_base
