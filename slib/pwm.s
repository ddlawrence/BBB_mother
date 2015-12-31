//
// PWM routines
//
.syntax unified
.data
SOC_PRCM_REGS                        = 0x44E00000
CM_PER_EPWMSS0_CLKCTRL               = 0xd4
CM_PER_EPWMSS1_CLKCTRL               = 0xcc
CM_PER_EPWMSS2_CLKCTRL               = 0xd8
CM_PER_EPWMSSx_CLKCTRL_MODULEMODE_ENABLE  = 0x2
CM_PER_EPWMSSx_CLKCTRL_IDLEST             = 0x30000

SOC_CONTROL_REGS                   = 0x44E10000
CONTROL_PWMSS_CTRL                 = 0x664
CONTROL_PWMSS_CTRL_PWMSS0_TBCLKEN  = 0x00000001
CONTROL_PWMSS_CTRL_PWMSS1_TBCLKEN  = 0x00000002
CONTROL_PWMSS_CTRL_PWMSS2_TBCLKEN  = 0x00000004

SOC_PWMSS0_REGS               = 0x48300000
SOC_PWMSS1_REGS               = 0x48302000
SOC_PWMSS2_REGS               = 0x48304000
SOC_EPWM_REGS                 = 0x00000200
SOC_EPWM_0_REGS               = SOC_PWMSS0_REGS + SOC_EPWM_REGS
SOC_EPWM_1_REGS               = SOC_PWMSS1_REGS + SOC_EPWM_REGS
SOC_EPWM_2_REGS               = SOC_PWMSS2_REGS + SOC_EPWM_REGS
EHRPWM_TBCTL		              = 0x0
EHRPWM_TBSTS		              = 0x2
EHRPWM_TBPRD		              = 0xA
EHRPWM_CMPA		                = 0x12
EHRPWM_CMPB		                = 0x14
EHRPWM_AQCTLA		              = 0x16
EHRPWM_AQCTLB		              = 0x18
EHRPWM_AQSFRC		              = 0x1A
EHRPWM_CMPCTL		              = 0xE

PWM_PERIOD_MS                 = 20   // pwm output period [ms] (20ms = 50Hz)
TICKS_PER_MS                  = 446

PWMSS_CLOCK_CONFIG            = 0x08
PWMSS_EHRPWM_CLK_EN           = 0x100

.text

.macro setreg32
    ldr	r4, [r0, r1]          // macro setreg32
    and	r3, r3, r2            // r0  register base address
    bic	r4, r4, r2            // r1  offset from base address
    orr	r3, r4, r3            // r2  mask
    str	r3, [r0, r1]          // r3  data
.endm

//
// PWMx Clock init
//
// @param base  uint_32, PWM base address.
//
// @return      uint_32, 0=success or 1=fail
//
// Overall execution speed is 2-3x faster if this is separate from the rest of PWM init.
// The L3 & L4 clock setup code was removed, this seemingly had no effect.
//
.global pwm_clk_init
pwm_clk_init:
    r_base      .req r0

    ldr r2, =SOC_PWMSS0_REGS
    cmp r_base, r2
    ldreq r1, =SOC_PRCM_REGS + CM_PER_EPWMSS0_CLKCTRL  // PWM0
    beq 1f
    ldr r2, =SOC_PWMSS1_REGS
    cmp r_base, r2
    ldreq r1, =SOC_PRCM_REGS + CM_PER_EPWMSS1_CLKCTRL  // PWM1
    beq 1f
    ldr r2, =SOC_PWMSS2_REGS
    cmp r_base, r2
    ldreq r1, =SOC_PRCM_REGS + CM_PER_EPWMSS2_CLKCTRL  // PWM2
// TODO test for bad base reg here
1:  ldr r2, [r1]
    orr r2, r2, CM_PER_EPWMSSx_CLKCTRL_MODULEMODE_ENABLE
    str r2, [r1]                  // config PWMx functional clock, spruh73l 8.1.12.1.36 
1:  ldr	r2, [r1]
    tst	r2, CM_PER_EPWMSSx_CLKCTRL_MODULEMODE_ENABLE  // wait for enab
    beq	1b
1:  ldr	r2, [r1]
    tst	r2, CM_PER_EPWMSSx_CLKCTRL_IDLEST  // wait for Func status, spruh73l 8.1.12.1.36 
    bne	1b

    mov r0, 0
    bx lr

    .unreq r_base

//
// PWMx init
// heavily hacked PWM config code from Rodrigo Fagundez, e2e.ti.com
//
// @param base  uint_32, PWM base address.
//
// @return      uint_32, 0=success or 1=fail
//
.global pwm_init
pwm_init:
    r_base      .req r0

    ldr r1, [r_base, PWMSS_CLOCK_CONFIG]
    orr r1, r1, PWMSS_EHRPWM_CLK_EN  // enab PWMSS (subsystem) clock, spruh73l 15.1.2.3
    str r1, [r_base, PWMSS_CLOCK_CONFIG]

    ldr r1, =SOC_CONTROL_REGS + CONTROL_PWMSS_CTRL
    ldr r2, [r1]  // enable Time-Base Clock, spruh73l 9.3.1.30
                  // this feeds TBCLK of spruh73l 15.2.2.3 Time-Base Submodule, see Fig 15-11
    ldr r3, =SOC_PWMSS0_REGS
    cmp r_base, r3
    moveq r4, CONTROL_PWMSS_CTRL_PWMSS0_TBCLKEN  // PWM0
    beq 1f
    ldr r3, =SOC_PWMSS1_REGS
    cmp r_base, r3
    moveq r4, CONTROL_PWMSS_CTRL_PWMSS1_TBCLKEN  // PWM1
    beq 1f
    ldr r3, =SOC_PWMSS2_REGS
    cmp r_base, r3
    moveq r4, CONTROL_PWMSS_CTRL_PWMSS2_TBCLKEN  // PWM2
    beq 1f
    mov r0, 1  // ERR bad base reg
    bx lr

1:  orr r2, r2, r4
    str r2, [r1]  // write Time-Base Clock enab

1:  ldr	r2, [r1]
    tst	r2, r4  // wait for enab
    beq	1b

    add r_base, r_base, SOC_EPWM_REGS  // prog ePWM Module

    ldr r1, =EHRPWM_TBCTL   // prog Time-Base Control Register
    mov r2, 0x4 << 0xa      // CLKDIV config Time-Base Clock prescaler, spruh73l 15.2.4.1
    orr r2, r2, 0x7 << 0x7  // HSPCLKDIV  ditto HighSpeed
    mov r3, 0x7 << 0xa      // CLKDIV mask 
    orr r3, r3, 0x7 << 0x7  // HSPCLKDIV mask
    setreg32

    mov r2, 0x8         // EHRPWM_PRD_LOAD_SHADOW_MASK
    orr r2, r2, 0x3     // EHRPWM_COUNTER_MODE_MASK
    mov r3, 0x0 << 0x3  // EHRPWM_SHADOW_WRITE_ENABLE, spruh73l 15.2.4.1 
    orr r3, r3, 0x0     // EHRPWM_COUNT_UP, pwm period parms spruh73l 15.2.2.3.3 
    setreg32
 
    ldr r1, =(PWM_PERIOD_MS * TICKS_PER_MS)  // = TBPRD = 1/freq
    strh r1, [r_base, EHRPWM_TBPRD]          // config PWM period, spruh73l 15.2.4.6

    ldr r1, =0x12  // CAU:force low, ZRO:force high, all else:action disab
    strh r1, [r_base, EHRPWM_AQCTLA]  // config action output A, spruh73l 15.2.4.11

    ldr r1, =0x102  // CBU:force low, ZRO:force high, all else:action disab
    strh r1, [r_base, EHRPWM_AQCTLB]  // config action output B, spruh73l 15.2.4.12

    ldrh r1, [r_base, EHRPWM_TBSTS]
    mov r0, 0x1
    tst	r1, 0x1  // check TB clock status counting UP, spruh73l 15.2.4.2
    movne r0, 0x0

    bx lr

    .unreq r_base

//
// write to PWM module channel A
//
// r0           uint_32, ePWM base address
// r1           uint_32, period [ticks], must not be greater than TBPRD above
//
.global pwm_write_A
pwm_write_A:
    strh r1, [r0, EHRPWM_CMPA]  // set the Compare A register, spruh73l 15.2.4.9
    bx lr

//
// write to PWM module channel B
//
// r0           uint_32, ePWM base address
// r1           uint_32, period [ticks], must not be greater than TBPRD above
//
.global pwm_write_B
pwm_write_B:
    strh r1, [r0, EHRPWM_CMPB]  // set the Compare B register, spruh73l 15.2.4.10
    bx lr
