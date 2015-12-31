//
// UART routines
//
.syntax unified
.data
.global SOC_UART_0_REGS
SOC_UART_0_REGS             = 0x44E09000
SOC_UART_1_REGS             = 0x48022000
SOC_UART_2_REGS             = 0x48024000

SOC_CM_PER_REGS             = 0x44E00000
CM_PER_L4LS_CLKSTCTRL       = 0x0
CM_PER_L3S_CLKSTCTRL        = 0x4
CM_PER_L3_CLKSTCTRL         = 0xC
CM_PER_L4LS_CLKCTRL         = 0x60
CM_PER_UART1_CLKCTRL        = 0x6C
CM_PER_UART2_CLKCTRL        = 0x70
CM_PER_L3_INSTR_CLKCTRL     = 0xDC
CM_PER_L3_CLKCTRL           = 0xE0
CM_PER_L4HS_CLKSTCTRL       = 0x11C
CM_PER_L4HS_CLKCTRL         = 0x120

SOC_CM_WKUP_REGS            = 0x44E00400
CM_WKUP_CLKSTCTRL           = 0x0
CM_WKUP_UART0_CLKCTRL       = 0xB4

SOC_AINTC_REGS          = 0x48200000    // Interrupt Controller base address
INTC_MIR_CLEAR2         = 0xC8
INTC_MIR_SET2           = 0xCC

SOC_CONTROL_REGS        = 0x44E10000
CONF_UART_0_RXD         = 0x970
CONF_UART_0_TXD         = 0x974
CONF_UART_1_RXD         = 0x980
CONF_UART_1_TXD         = 0x984
CONF_UART_2_RXD         = 0x990
CONF_UART_2_TXD         = 0x994  // pattern continues

UART_DLL           = 0x0
UART_RHR           = 0x0
UART_THR           = 0x0
UART_DLH           = 0x4
UART_IER           = 0x4
UART_FCR           = 0x8
UART_EFR           = 0x8
UART_IIR           = 0x8
UART_LCR           = 0xC
UART_MCR           = 0x10
UART_LSR           = 0x14
UART_MDR1          = 0x20
UART_SCR           = 0x40
UART_SYSC          = 0x54
UART_SYSS          = 0x58

.text
//
// uart0 module init
//
// @return   0=success or 1=fail
//
.global uart0_init
uart0_init:
    r_base .req r0
    ldr r_base, =SOC_UART_0_REGS
    mov r1, 0x2                // SOFTRESET, spruh73l 19.5.1.43
    str r1, [r_base, UART_SYSC]
1:  ldr r1, [r_base, UART_SYSS]
    tst r1, 0x1                // wait for RESETDONE spruh73l tab 19-73
    beq 1b

    mov r1, #0x8               // disable IDLEMODE, spruh73l 19.5.1.43 & tab 19-72
    str r1, [r_base, UART_SYSC]

    mov r1, 0x83          // DIV_EN (mode A), 8 data bits, spruh73l 19.5.1.13 19.4.1.1.2
    str r1, [r_base, UART_LCR]
    mov r1, 0x1A          // CLOCK_LSB=0x1A, spruh73l 19.5.1.3
    str r1, [r_base, UART_DLL]

// the following code prepares FIFOs for IRQ
    mov r1, 0x10          // ENHANCEDEN=1 (enab R/W access to UART_FCR), spruh73l 19.5.1.8
    str r1, [r_base, UART_EFR]
    mov r1, 0x57          // FIFO triggers, clr & enab, spruh73l 19.5.1.11
    str r1, [r_base, UART_FCR]
    mov r1, 0x0           // ENHANCEDEN=0 (disab R/W access to UART_FCR), spruh73l 19.5.1.8
    str r1, [r_base, UART_EFR]
// end of FIFO-IRQ code

    mov r1, 0x0           // MODESELECT-UART 16x mode, spruh73l 19.5.1.26 
    str r1, [r_base, UART_MDR1]
    ldr r1, [r_base, UART_LCR]
    bic r1, r1, 0x80      // clear DIV_EN, switch to operational mode, spruh73l 19.5.1.13
    str r1, [r_base, UART_LCR]

// the following extra code prepares FIFOs for IRQ
    mov r1, 0xC8       // Rx & Tx FIFO granularity=1, TXEMPTYCTLIT=1 , spruh73l 19.5.1.39
    str r1, [r_base, UART_SCR]
// end of extra FIFO-IRQ code
    
    mov r1, 0x1                // enab interrupt RHR_IT, spruh73l 19.5.1.6, 19.3.6.2
    str r1, [r_base, UART_IER]

    mov r0, 0
    bx lr
    .unreq r_base

//
// uart0 interrupt service routine
//
// see interrupt handling procedure spruh73l 19.3.5.1.1
//
// RHR interrupt is enabled most the time.  It is momentarily
// disabled by this ISR during processing, then re-enabled by this ISR.  
//
// THR interrupt is disabled most of the time.  It is momentarily
// enabled by uart_txi() to transmit a byte, then disabled by this ISR.  
//
.global uart0_isr
uart0_isr:

//    ldr r2, =SOC_AINTC_REGS        // TODO does not stop spurious IRQs
//    mov r1, 0x1 << 8
//    str r1, [r2, INTC_MIR_SET2]    // INTC_MIR_SET2 #72 UART0INT (mask it)

    ldr r0, =SOC_UART_0_REGS
    ldr r1, [r0, UART_IIR]      // read interrupt ID register spruh73l 19.5.1.9
    mov r2, 0x0                 // disab UART interrupts (clobber them all)
    str r2, [r0, UART_IER]
    and r1, r1, #0x3E           // strip out IT_TYPE  tab 19-38
    cmp r1, #0x4                // RHR interrupt bit
    bne 1f
    ldr r2, [r0, UART_RHR]      // read byte
    ldr r1, =uart0_rbuf         // store byte in C variable
    str r2, [r1]
    b uart0_isr_exit
1:
    cmp r1, #0x2                // THR interrupt bit
    bne uart0_isr_exit
    ldr r1, =uart0_tbuf         // get tx byte
    ldr r2, [r1]
    str r2, [r0, UART_THR]      // write out byte

uart0_isr_exit:
    ldr r2, =uart0_irq_count    // increment counter, C variable
    ldr r1, [r2]
    add r1, r1, #0x1
    str r1, [r2]

//    ldr r2, =SOC_AINTC_REGS        // TODO does not stop spurious IRQs
//    mov r1, 0x1 << 8
//    str r1, [r2, INTC_MIR_CLEAR2]    // INTC_MIR_CLEAR2 #72 UART0INT  (unmask it)

    mov r2, 0x1                 // re-enab RHR interrupts only
    str r2, [r0, UART_IER]
    bx lr

//
// transmit a single byte with UARTx (interrupt mode)
//
// @param uart_base_addr    uint32, UARTx module base address
//
// The transmit buffer uart0_tbuf (a global variable) must contain 
// the data byte in the LSByte before calling this routine.  
//
.global uart_txi
uart_txi:
    r_base .req r0
    mov r1, 0x3                // enab interrupts: THR_IT RHR_IT, spruh73l 19.5.1.6, 19.3.6.2
    str r1, [r_base, UART_IER] // this will cause a THR interrupt pronto
    bx lr
    .unreq r_base

//
// receive a single byte from UARTx (poll mode)
//
// @param uart_base_addr    uint32, UARTx module base address
//
// @return                  uint32, LSByte contains a single received byte 
//
.global uart_rx
uart_rx:
    r_base .req r0
    r_byte .req r1
1:  ldr	r2, [r_base, UART_LSR]
    tst	r2, 0x1               // wait for rx FIFO not empty, spruh73l tab 19-48
    beq	1b
    ldr r_byte, [r_base, 0x0]
    mov r0, r_byte
    bx lr
    .unreq r_base
    .unreq r_byte

//
// transmit a single byte with UARTx (poll mode)
//
// @param uart_base_addr    uint32, UARTx module base address
// @param uart_byte         uint32, LSByte contains a single byte to transmit
//
.global uart_tx
uart_tx:
    r_base .req r0
    r_byte .req r1
1:  ldr	r2, [r_base, UART_LSR]
    tst	r2, 0x20             // wait for tx FIFO empty, spruh73l 19.5.1.19, tab 19-48
    beq	1b
    str r_byte, [r_base, 0x0]
    bx lr
    .unreq r_base
    .unreq r_byte

//
// pinmux setup
//
// @param pin          uint32, pinmux address (offset = 0x800–0xA34) spruh73l 9.3.1.49
// @param val          uint32, pinmux mode/value spruh73l 9.2.2
//
// eg  pin:  CONF_UART_1_RXD (=0x980) for UART1 Rx pin, see hw_control_AM335x.h
//     pin:  GPIO_1_23 (=0x85C) for LED USR3, see pin_mux.h
//     val:  mov r_tmp, #0x27    Fast slew, Rx disab, pull-up enab, mode 7
//     values/default values are pad dependant, see spruh73l 9.2.2 or Peripheral doc
//     set mode per P8 & P9 Header Tables, see www.derekmolloy.ie
//
.global pinmux
pinmux:
    r_pin .req r0
    r_val .req r1
    ldr r2, =SOC_CONTROL_REGS
    str r_val, [r2, r_pin]
    bx lr
    .unreq r_pin
    .unreq r_val
//
// hexprint
//
// @param data              uint32, word (4 bytes) to print in hex format
//
.global hexprint
hexprint:
    r_data .req r0
    r_base .req r1
    stmfd sp!, {r0-r4, lr}
    mov r4, r_data
    mov r3, #0x8
    ldr r_base, =SOC_UART_0_REGS
hexloop:
    mov r4, r4, ror #28
    and r_data, r4, #0xF
    cmp r_data, #0xA
    addlt r_data, r_data, #0x30
    addge r_data, r_data, #0x37
1:  ldr	r2, [r_base, UART_LSR]
    and r2, r2, 0x20
    cmp	r2, 0x20             // wait for tx FIFO empty, spruh73l tab 19-48
    bne	1b
    str r_data, [r_base, 0x0]
    sub r3, r3, #0x1
    cmp r3, #0x0
    bne hexloop
    mov r_data, 0x0A
1:  ldr	r2, [r_base, UART_LSR]
    and r2, r2, 0x20
    cmp	r2, 0x20             // wait for tx FIFO empty, spruh73l tab 19-48
    bne	1b
    str r_data, [r_base, 0x0]
    ldmfd sp!, {r0-r4, pc}
    .unreq r_data
    .unreq r_base
