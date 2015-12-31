//
// Timer routines: RTC 
//
.syntax unified
.data
CM_PER_BASE              = 0x44E00000
CM_RTC_RTC_CLKCTRL       = 0x0  // spruh73l 8.1.12.6.1
CM_RTC_CLKSTCTRL         = 0x4  // spruh73l 8.1.12.6.2

SOC_RTC_0_REGS           = 0x44E3E000
RTC_CTRL_REG             = 0x40
RTC_STATUS_REG           = 0x44
RTC_INTERRUPTS_REG       = 0x48
RTC_OSC_REG              = 0x54
KICK0R                   = 0x6C
KICK1R                   = 0x70
SECONDS_REG              = 0x00
MINUTES_REG              = 0x04
HOURS_REG                = 0x08
DAYS_REG                 = 0x0C
MONTHS_REG               = 0x10
YEARS_REG                = 0x14
WEEKS_REG                = 0x18

GPIO_CLEARDATAOUT		    = 0x190
GPIO_SETDATAOUT		      = 0x194

.text
//
// rtc module init
//
// @return   0=success or 1=fail
//
.global rtc_init
rtc_init:
    r_base .req r0
    ldr r_base, =CM_PER_BASE
    mov r1, 0x2
    str r1, [r_base, CM_RTC_RTC_CLKCTRL]  // MODULEMODE enab spruh73l 8.1.12.6.1
    mov r1, 0x2                           // transition crtl SW_ WKUP spruh73l 8.1.12.6.2
    str r1, [r_base, CM_RTC_CLKSTCTRL]

    ldr r_base, =SOC_RTC_0_REGS
    ldr r1, =0x83E70B13          // disab write protection
    str r1, [r_base, KICK0R]
    ldr r1, =0x95A4F1E0
    str r1, [r_base, KICK1R]
    ldr r1, =0x48                // select 32k ext clk & enab, spruh73l 20.3.3.2, tab 20.82
    str r1, [r_base, RTC_OSC_REG]
    ldr r1, =0x1                 // RTC enab, functional & running, spruh73l tab 20.77
    str r1, [r_base, RTC_CTRL_REG]

1:  ldr r1, [r_base, RTC_STATUS_REG]
    and r1, r1, 0x1
    cmp	r1, 0x0                        // wait for BUSY bit to clear, spruh73l 20.3.5.15
    bne	1b

    ldr r1, =0x4                       // enab interrupt every second, spruh73l 20.3.5.16 
    str r1, [r_base, RTC_INTERRUPTS_REG] 
    mov r_base, #0x0
    bx lr
    .unreq r_base

//
// rtc interrupt service routine
//
// hacked from Al Selen at github.com/auselen
//
.global rtc_isr
rtc_isr:
    ldr r0, =SOC_RTC_0_REGS   // retrieve time from RTC, spruh73l 20.3.3.5.1
    ldr r1, =sec              // C variable
    ldr r2, [r0, SECONDS_REG]
    str r2, [r1]
    ldr r1, =min              // C variable
    ldr r2, [r0, MINUTES_REG]
    str r2, [r1]
    ldr r1, =hour             // C variable
    ldr r2, [r0, HOURS_REG]
    str r2, [r1]
    ldr r1, =rtc_irq_count    // C variable, increment counter
    ldr r2, [r1]
    add r2, r2, #0x1
    str r2, [r1]

    ldr r0, =SOC_GPIO_1_REGS  // actuate LED USR1
    mov r1, 0x1<<21
    ands r2, r2, 0x1          // flip-flop on rtc_irq_count
    beq 1f
    str r1, [r0, GPIO_SETDATAOUT]
    bx lr
1:
    str r1, [r0, GPIO_CLEARDATAOUT]
    bx lr
