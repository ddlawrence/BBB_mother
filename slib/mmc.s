//
// MMC0 routines
//
.syntax unified
.data
.global MMCHS0_REG_BASE
MMCHS0_REG_BASE               = 0x48060000
MMCHS_SD_SYSCONFIG            = 0x110  // SD system configuration
MMCHS_SD_SYSSTATUS            = 0x114  // SD system status
MMCHS_SD_CON                  = 0x12c  // Configuration (func mode, card init...)
MMCHS_SD_ARG                  = 0x208  // command argument bit 38-8 of command format
MMCHS_SD_CMD                  = 0x20c  // Command and transfer mode
MMCHS_SD_HCTL                 = 0x228  // host control (power ,wake-up, transfer)
MMCHS_SD_CAPA                 = 0x240  // capabilities of host controller
MMCHS_SD_SYSCTL               = 0x22c  // SD System Control (reset, clocks & timeout)
MMCHS_SD_STAT                 = 0x230  // SD Interrupt Status
MMCHS_SD_IE                   = 0x234  // SD Interrupt Enable register

MMCHS_SD_SYSCONFIG_SOFTRESET        = 0x2
MMCHS_SD_SYSSTATUS_RESETDONE        = 0x1
MMCHS_SD_CAPA_VS_MASK               = 0x7 << 24    // voltage mask
MMCHS_SD_CAPA_VS18                  = 0x1 << 26    // 1.8 volt
MMCHS_SD_CAPA_VS30                  = 0x1 << 25    // 3.0 volt
MMCHS_SD_SYSCONFIG_AUTOIDLE                    = 0x1 << 0  // Internal clock gating strategy
MMCHS_SD_SYSCONFIG_AUTOIDLE_EN                 = 0x1 << 0  // Automatic clock gating strategy
MMCHS_SD_SYSCONFIG_ENAWAKEUP                   = 0x1 << 2  // Wake-up feature control
MMCHS_SD_SYSCONFIG_ENAWAKEUP_EN                = 0x1 << 2  // Enable wake-up capability
MMCHS_SD_SYSCONFIG_SIDLEMODE                   = 0x3 << 3  // Power management
MMCHS_SD_SYSCONFIG_SIDLEMODE_IDLE              = 0x2 << 3  // Acknowledge IDLE request switch to wake-up mode
MMCHS_SD_SYSCONFIG_CLOCKACTIVITY               = 0x3 << 8  // Clock activity during wake-up
MMCHS_SD_SYSCONFIG_CLOCKACTIVITY_OFF           = 0x0 << 8  // Interface and functional clock can be switched off
MMCHS_SD_SYSCONFIG_STANDBYMODE                 = 0x3 << 12 //Configuration for standby
MMCHS_SD_SYSCONFIG_STANDBYMODE_WAKEUP_INTERNAL = 0x2 << 12 // Go into wake-up mode based on internal knowledge
MMCHS_SD_HCTL_IWE       = 0x1 << 24  // wake-up event on SD interrupt
MMCHS_SD_HCTL_IWE_EN    = 0x1 << 24  // Enable wake-up on SD interrupt
MMCHS_SD_CON_DW8        = 0x1 << 5   // 8-bit mode MMC select , For SD clear this bit
MMCHS_SD_CON_DW8_1BIT   = 0x0 << 5   // 1 or 4 bits data width configuration(also set SD_HCTL)
MMCHS_SD_HCTL_DTW       = 0x1 << 1   // Data transfer width.(must be set after a successful ACMD6)
MMCHS_SD_HCTL_DTW_1BIT  = 0x0 << 1   // 1 bit transfer width
MMCHS_SD_HCTL_SDVS      = 0x7 << 9   // SD bus voltage select
MMCHS_SD_HCTL_SDVS_VS30 = 0x6 << 9   // 3.0 V
MMCHS_SD_HCTL_SDBP      = 0x1 << 8   // SD bus power
MMCHS_SD_HCTL_SDBP_ON   = 0x1 << 8   // SD Power on (start card detect?)
MMCHS_SD_SYSCTL_ICE     = 0x1 << 0   // Internal clock enable register 
MMCHS_SD_SYSCTL_ICE_EN  = 0x1 << 0   // Enable internal clock
MMCHS_SD_SYSCTL_CLKD    = 0x3ff << 6 // 10 bits clock frequency select
MMCHS_SD_SYSCTL_CEN     = 0x1 << 2   // Card lock enable provide clock to the card
MMCHS_SD_SYSCTL_CEN_EN  = 0x1 << 2   // Internal clock is stable  
MMCHS_SD_SYSCTL_ICS        = 0x1 << 1   // Internal clock stable register 
MMCHS_SD_SYSCTL_ICS_STABLE = 0x1 << 1   // Internal clock is stable  
MMCHS_SD_IE_CC_EN          = 0x1 << 0   // Command complete interrupt enable
MMCHS_SD_IE_CC_EN_EN       = 0x1 << 0   // Command complete Interrupts are enabled
MMCHS_SD_IE_CC_EN_CLR      = 0x1 << 0   // Clearing is done by writing a 0x1
MMCHS_SD_IE_TC_EN          = 0x1 << 1   // Transfer complete interrupt enable
MMCHS_SD_IE_TC_EN_EN       = 0x1 << 1   // Transfer complete Interrupts are enabled
MMCHS_SD_IE_TC_EN_CLR      = 0x1 << 1   // Clearing TC is done by writing a 0x1
MMCHS_SD_IE_ERROR_MASK     = (0xff << 15 | 0x3 << 24 | 0x03 << 28)  // 0x337f8000
MMCHS_SD_STAT_ERROR_MASK   = (0xff << 15 | 0x3 << 24 | 0x03 << 28)
MMCHS_SD_CON_INIT          = 0x1 << 1   // Send initialization stream (all cards)
MMCHS_SD_CON_INIT_NOINIT   = 0x0 << 1   // Do nothing
MMCHS_SD_CON_INIT_INIT     = 0x1 << 1   // Send initialization stream
MMCHS_SD_STAT_CC           = 0x1 << 0   // Command complete status
MMCHS_SD_STAT_CC_RAISED    = 0x1 << 0   // Command completed
MMCHS_SD_CMD_MASK = ~(0x1<<30|0x1<<31|0x1<<18|0x1<<3)  // bits 30, 31 & 18 are reserved
MMCHS_SD_CMD_RSP_TYPE      = (0x3 << 16)     // Response type
MMCHS_SD_CMD_RSP_TYPE_48B_BUSY = (0x3 << 16) // Response len 48 bits with busy after response

.text

.macro setreg32
    ldr	r4, [r0, r1]          // macro setreg32
    and	r3, r3, r2            // r0  register base address
    bic	r4, r4, r2            // r1  offset from base address
    orr	r3, r4, r3            // r2  mask
    str	r3, [r0, r1]          // r3  data
.endm

//
// mmc0 module init
//
// originally written in C by Jan Kees   github.com/keesj
//
// @return   0=success or 1=fail
//
.global mmc0_init
mmc0_init:
    r_base .req r0
    push {r4, lr}
    ldr r_base, =MMCHS0_REG_BASE
    ldr r1, [r_base, MMCHS_SD_SYSCONFIG]
    mvn r2, MMCHS_SD_SYSCONFIG_SOFTRESET  // SOFTRESET, spruh73l 18.2.2.2, Table 18-15
    and r1, r1, r2
    mov r2, MMCHS_SD_SYSCONFIG_SOFTRESET
    orr r1, r1, r2
    str r1, [r_base, MMCHS_SD_SYSCONFIG]
1:  ldr r1, [r_base, MMCHS_SD_SYSSTATUS]
    cmp r1, MMCHS_SD_SYSSTATUS_RESETDONE  // wait for RESETDONE, spruh73l Table 18-16
    bne 1b

    ldr r_base, =MMCHS0_REG_BASE
    mov r1, MMCHS_SD_CAPA  // Set SD default capabilities
    mov r2, MMCHS_SD_CAPA_VS_MASK
    mov r3, MMCHS_SD_CAPA_VS18 | MMCHS_SD_CAPA_VS30
    setreg32
    mov r1, MMCHS_SD_SYSCONFIG  // wake-up configuration
    ldr r2, =(MMCHS_SD_SYSCONFIG_AUTOIDLE | MMCHS_SD_SYSCONFIG_ENAWAKEUP | MMCHS_SD_SYSCONFIG_SIDLEMODE | MMCHS_SD_SYSCONFIG_CLOCKACTIVITY | MMCHS_SD_SYSCONFIG_STANDBYMODE)
    ldr r3, =(MMCHS_SD_SYSCONFIG_AUTOIDLE_EN | MMCHS_SD_SYSCONFIG_ENAWAKEUP_EN | MMCHS_SD_SYSCONFIG_SIDLEMODE_IDLE | MMCHS_SD_SYSCONFIG_CLOCKACTIVITY_OFF | MMCHS_SD_SYSCONFIG_STANDBYMODE_WAKEUP_INTERNAL)
    setreg32
    mov r1, MMCHS_SD_HCTL  // Wake-up on sd interrupt SDIO
    ldr r2, =MMCHS_SD_HCTL_IWE
    ldr r3, =MMCHS_SD_HCTL_IWE_EN
    setreg32
    mov r1, MMCHS_SD_CON  // Configure data and command transfer (1 bit mode)
    ldr r2, =MMCHS_SD_CON_DW8
    ldr r3, =MMCHS_SD_CON_DW8_1BIT
    setreg32
    mov r1, MMCHS_SD_HCTL
    ldr r2, =MMCHS_SD_HCTL_DTW
    ldr r3, =MMCHS_SD_HCTL_DTW_1BIT
    setreg32
    mov r1, MMCHS_SD_HCTL  // Configure card voltage
    ldr r2, =MMCHS_SD_HCTL_SDVS
    ldr r3, =MMCHS_SD_HCTL_SDVS_VS30
    setreg32
    mov r1, MMCHS_SD_HCTL  // Power on the host controller
    ldr r2, =MMCHS_SD_HCTL_SDBP
    ldr r3, =MMCHS_SD_HCTL_SDBP_ON
    setreg32

1:  ldr r1, [r_base, MMCHS_SD_HCTL]  // wait for SDBP_POWER_ON set, spruh73l, Tab 18-31
    and r1, r1, MMCHS_SD_HCTL_SDBP
    cmp r1, MMCHS_SD_HCTL_SDBP_ON
    bne 1b

    mov r1, MMCHS_SD_SYSCTL  // Enab internal clock & clock to card
    ldr r2, =MMCHS_SD_SYSCTL_ICE
    ldr r3, =MMCHS_SD_SYSCTL_ICE_EN
    setreg32
    mov r1, MMCHS_SD_SYSCTL  // external clock enable
    ldr r2, =MMCHS_SD_SYSCTL_CLKD                     // TODO Fix, this one is very slow
    ldr r3, =(0x3ff << 6)
    setreg32
    mov r1, MMCHS_SD_SYSCTL
    ldr r2, =MMCHS_SD_SYSCTL_CEN
    ldr r3, =MMCHS_SD_SYSCTL_CEN_EN
    setreg32

1:  ldr r1, [r_base, MMCHS_SD_SYSCTL]  // wait for internal clk stable, spruh73l, 18.4.1.18 
    and r1, r1, MMCHS_SD_SYSCTL_ICS
    cmp r1, MMCHS_SD_SYSCTL_ICS_STABLE
    bne 1b

    mov r1, MMCHS_SD_IE  // enab cmd interrupt, spruh73l, 18.3.3.2
    ldr r2, =MMCHS_SD_IE_CC_EN             // Card Detection, Identification, and Selection
    ldr r3, =MMCHS_SD_IE_CC_EN_EN
    setreg32
    mov r1, MMCHS_SD_IE  // enable transfer complete interrupt
    ldr r2, =MMCHS_SD_IE_TC_EN
    ldr r3, =MMCHS_SD_IE_TC_EN_EN
    setreg32
    mov r1, MMCHS_SD_IE  // enable error interrupts
    ldr r2, =MMCHS_SD_IE_ERROR_MASK
    ldr r3, =0x0fffffff
// NB skip BADA interrupt it gets raised, unknown reason (maybe mask clobbers 0x337f8000)
    setreg32
    mov r1, MMCHS_SD_STAT  // purge error interrupts
    ldr r2, =MMCHS_SD_STAT_ERROR_MASK
    ldr r3, =0xffffffff
    setreg32
    mov r1, MMCHS_SD_CON  // send init signal to host controller
                          // does not actually send a cmd to a card
    ldr r2, =MMCHS_SD_CON_INIT
    ldr r3, =MMCHS_SD_CON_INIT_INIT
    setreg32

    mov r1, 0x0  // SD command 0, type other commands, not response...
    str r1, [r_base, MMCHS_SD_CMD]

1:  ldr r1, [r_base, MMCHS_SD_STAT]  // wait for command complete, spruh73l 18.4.1.19 
    and r2, r1, MMCHS_SD_STAT_CC
    cmp r2, MMCHS_SD_STAT_CC_RAISED
    beq 1f
    tst r1, 0x8000         // check for ERR interrupt
    beq 1b
    mov r0, 0x1            // flag error & exit
    b mmc0_init_exit
1:
    mov r1, MMCHS_SD_STAT  // clear cc interrupt status
    ldr r2, =MMCHS_SD_IE_CC_EN
    ldr r3, =MMCHS_SD_IE_CC_EN_EN
    setreg32
    mov r1, MMCHS_SD_CON  // clr INIT bit to end init sequence
    ldr r2, =MMCHS_SD_CON_INIT
    ldr r3, =MMCHS_SD_CON_INIT_NOINIT
    setreg32
    mov r0, 0x0
mmc0_init_exit:
    pop {r4, pc}
    .unreq r_base

//
//  Send a command to card
//
// @param command      uint32, SD CMD
// @param arg          uint32, arguement
//
// @return   0=success or 1=fail
//
// originally written in C by Jan Kees   github.com/keesj
//
.global send_cmd
send_cmd:
    push {r4, r5, r6, lr}
    mov r3, r0
    mov r5, r0
    mov r4, r1
    ldr r0, =MMCHS0_REG_BASE
    ldr r1, =0xffff
    ldr r2, [r0, MMCHS_SD_STAT]  // read current interrupt status
    tst r2, r1                   // fail if an interrupt is already asserted
    beq 1f
    mov r0, 0x1
    b send_cmd_exit
1:
    str r4, [r0, MMCHS_SD_ARG]  // set arguments

    mov r1, MMCHS_SD_CMD  // set command
    ldr r2, =MMCHS_SD_CMD_MASK
    setreg32

1:  ldr r1, [r0, MMCHS_SD_STAT]  // wait for completion
    ldr r2, =0xffff
    tst r1, r2
    beq 1b

    ldr r1, [r0, MMCHS_SD_STAT]
    tst r1, 0x8000               // check again for ERR interrupt
    beq 1f
    mov r1, MMCHS_SD_STAT  // clear errors & exit
    ldr r2, =MMCHS_SD_STAT_ERROR_MASK
    mvn r3, 0x0
    setreg32
    mov r0, 0x1            // we currently only support 2.0
    b send_cmd_exit
1:
    and r5, r5, MMCHS_SD_CMD_RSP_TYPE
    cmp r5, MMCHS_SD_CMD_RSP_TYPE_48B_BUSY  // check if CMD response type 48B
    bne 1f

    // Command with busy response *CAN* also set the TC bit if they exit busy
2:  ldr r1, [r0, MMCHS_SD_STAT]  // therefore wait for CMD completion
    mov r2, MMCHS_SD_IE_TC_EN_EN
    tst r1, r2
    beq 2b

    mov r1, MMCHS_SD_IE_TC_EN_CLR  // clear the TC status
    str r1, [r0, MMCHS_SD_STAT]
1:
    mov r1, MMCHS_SD_IE_CC_EN_CLR  // clear the CC status
    str r1, [r0, MMCHS_SD_STAT]

    mov r0, 0x0
send_cmd_exit:
    pop {r4, r5, r6, pc}

// TODO read32 & write32 & set32 (inline might work)
