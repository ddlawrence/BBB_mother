//
// interrupt service routines
//
.syntax unified
.data
SOC_AINTC_REGS          = 0x48200000  // BBB ARM Interrupt Controller base address
INTC_SYSCONFIG          = 0x10
INTC_SYSSTATUS          = 0x14
INTC_SIR_IRQ            = 0x40
INTC_CONTROL            = 0x48
INTC_MIR_CLEAR1         = 0xA8
INTC_MIR_CLEAR2         = 0xC8

.text

//
// ARM interrupt controller init
//
.global irq_init
irq_init:
    r_base .req r0
    ldr r_base, =SOC_AINTC_REGS
    mov r1, 0x2
    str r1, [r_base, INTC_SYSCONFIG]   // soft reset AINT controller spruh73l 6.5.1.2
1:  ldr	r1, [r_base, INTC_SYSSTATUS]   // (not really necessary)
    and r1, r1, 0x1
    cmp	r1, 0x1                        // test for reset complete spruh73l 6.5.1.3
    bne	1b

    mov r1, 0x1            // unmask interrupts on peripheral side spruh73l 6.2.1 & 6.3
    str r1, [r_base, INTC_MIR_CLEAR1]    // INTC_MIR_CLEAR1 #32 GPIOINT2A (for GPIOIRQ0)
    mov r1, 0x1 << 8
    str r1, [r_base, INTC_MIR_CLEAR2]    // INTC_MIR_CLEAR2 #72 UART0INT
    mov r1, 0x1 << 11
    str r1, [r_base, INTC_MIR_CLEAR2]    // INTC_MIR_CLEAR2 #75 RTCINT

// spruh73l 26.1.3.2 default boot procedure uses address 0x4030CE00
// for base of RAM exception vectors.  see tab 26.3 for vector addresses
    ldr r_base, =0x4030CE24   // register UND in interrupt vector
    ldr r1, =und_isr
    str r1, [r_base]
    ldr r_base, =0x4030CE38   // register IRQ in interrupt vector
    ldr r1, =irq_isr
    str r1, [r_base]

    mrs r1, cpsr
    bic r1, r1, #0x80  // enable IRQ, ie unmask IRQ bit of cpsr
    msr cpsr_c, r1     // 9.2.3.1 & fig 2.3 ARM System Developer’s Guide, Sloss et al

    bx lr
    .unreq r_base

//
// UND  undefined interrupt service routine
//
.global und_isr
und_isr:
    stmfd sp!, {r0-r1, r12, lr} // must align stack to 8-byte boundary, AAPCS
    mrs r12, spsr               // save program status register

    ldr r0, =SOC_UART_0_REGS  // print text "UND"
    mov r1, 0x55
    bl uart_tx
    mov r1, 0x4E
    bl uart_tx
    mov r1, 0x44
    bl uart_tx
    mov r1, 0x0A
    bl uart_tx

    msr spsr, r12                // restore status
    ldmfd sp!, {r0-r1, r12, pc}^ // ^ cpsr restored from spsr. do not adjust lr with UND 
                                 // cuz the instruction is undefined so skip over it

//
// IRQ interrupt service routine
//
// hacked from Al Selen, github.com/auselen
// & Mattius van Duin, TI.com e2e forum
// Non-nested interrupt handler per Sloss, 9.3.1
// Designed for very lean ISRs that are simple, fast and no loops.  
//
.global irq_isr
irq_isr:
    stmfd sp!, {r0-r3, r12, lr} // must align stack to 8-byte boundary
    mrs r12, spsr               // save program status register
/*
    mrs r1, cpsr
    orr r1, r1, #0x80  // disable IRQ,   TODO still spurious IRQs maybe mask them in xxx_isr 
    msr cpsr_c, r1     // this also screws up RTC!
*/
    ldr r0, =SOC_AINTC_REGS
    ldr r1, [r0, INTC_SIR_IRQ]  // fetch SIR_IRQ register spruh73l 6.2.2 & 6.5.1.4

    cmp r1, 0x80                // check spurious irq (only bits 0-6 are valid)
    bge irq_isr_exit

    adr r2, irq_vector          // jump to specific irq isr
    ldr r2, [r2, r1, lsl 2]
    blx r2

irq_isr_exit:
    ldr r0, =SOC_AINTC_REGS
    ldr r1, =0x1                // NewIRQAgr bit, reset IRQ output and enable new IRQ
    str r1, [r0, INTC_CONTROL]  // spruh73l 6.2.2 & 6.5.1.6
/*
    mrs r1, cpsr
    bic r1, r1, #0x80  // re-enable IRQ
    msr cpsr_c, r1
*/
    msr spsr, r12               // restore status
    ldmfd sp!, {r0-r3, r12, lr}
    subs pc, lr, #4             // adjust lr for pipeline & return to normal execution

//
//  ARM Cortex-A8 Interrupts  spruh73l 6.3
//
irq_vector:
.word	0            // 0   Cortex-A8 ICECrusher
.word	0            // 1   Cortex-A8 debug tx
.word	0            // 2   Cortex-A8 debug rx
.word	0            // 3   Cortex-A8 PMU
.word	0            // 4   ELM
.word	0            // 5   SSM WFI
.word	0            // 6   SSM
.word	0            // 7   External IRQ ("NMI")
.word	0            // 8   L3 firewall error
.word	0            // 9   L3 interconnect debug error
.word	0            // 10  L3 interconnect non-debug error
.word	0            // 11  PRCM MPU irq
.word	0            // 12  EDMA client 0
.word	0            // 13  EDMA protection error
.word	0            // 14  EDMA CC error
.word	0            // 15  Watchdog 0
.word	0            // 16  ADC / Touchscreen controller
.word	0            // 17  USB queue manager and CPPI
.word	0            // 18  USB port 0
.word	0            // 19  USB port 1
.word	0            // 20  PRUSS host event 0
.word	0            // 21  PRUSS host event 1
.word	0            // 22  PRUSS host event 2
.word	0            // 23  PRUSS host event 3
.word	0            // 24  PRUSS host event 4
.word	0            // 25  PRUSS host event 5
.word	0            // 26  PRUSS host event 6
.word	0            // 27  PRUSS host event 7
.word	0            // 28  MMC/SD 1
.word	0            // 29  MMC/SD 2
.word	0            // 30  I2C 2
.word	0            // 31  eCAP 0
.word	gpio_isr     // 32  GPIO 2 irq 0  -  GPIOINT2A
.word	0            // 33  GPIO 2 irq 1
.word	0            // 34  USB wakeup
.word	0            // 35  PCIe wakeup
.word	0            // 36  LCD controller
.word	0            // 37  SGX530 error in IMG bus
.word	0            // 38  reserved
.word	0            // 39  ePWM 2
.word	0            // 40  Ethernet core 0 rx low on bufs
.word	0            // 41  Ethernet core 0 rx dma completion
.word	0            // 42  Ethernet core 0 tx dma completion
.word	0            // 43  Ethernet core 0 misc irq
.word	0            // 44  UART 3
.word	0            // 45  UART 4
.word	0            // 46  UART 5
.word	0            // 47  eCAP 1
.word	0            // 48  reserved
.word	0            // 49  reserved
.word	0            // 50  reserved
.word	0            // 51  reserved
.word	0            // 52  DCAN 0 irq 0
.word	0            // 53  DCAN 0 irq 1
.word	0            // 54  DCAN 0 parity
.word	0            // 55  DCAN 1 irq 0
.word	0            // 56  DCAN 1 irq 1
.word	0            // 57  DCAN 1 parity
.word	0            // 58  ePWM 0 TZ
.word	0            // 59  ePWM 1 TZ
.word	0            // 60  ePWM 2 TZ
.word	0            // 61  eCAP 2
.word	0            // 62  GPIO 3 irq 0
.word	0            // 63  GPIO 3 irq 1
.word	0            // 64  MMC/SD 0
.word	0            // 65  SPI 0
.word	0            // 66  Timer 0
.word	0            // 67  Timer 1
.word	0            // 68  Timer 2
.word	0            // 69  Timer 3
.word	0            // 70  I2C 0
.word	0            // 71  I2C 1
.word	uart0_isr    // 72  UART 0  -  UART0INT
.word	0            // 73  UART 1
.word	0            // 74  UART 2
.word	rtc_isr      // 75  RTC periodic  -  RTCINT
.word	0            // 76  RTC alarm
.word	0            // 77  System mailbox irq 0
.word	0            // 78  Wakeup-M3
.word	0            // 79  eQEP 0
.word	0            // 80  McASP 0 out
.word	0            // 81  McASP 0 in
.word	0            // 82  McASP 1 out
.word	0            // 83  McASP 1 in
.word	0            // 84  reserved
.word	0            // 85  reserved
.word	0            // 86  ePWM 0
.word	0            // 87  ePWM 1
.word	0            // 88  eQEP 1
.word	0            // 89  eQEP 2
.word	0            // 90  External DMA/IRQ pin 2
.word	0            // 91  Watchdog 1
.word	0            // 92  Timer 4
.word	0            // 93  Timer 5
.word	0            // 94  Timer 6
.word	0            // 95  Timer 7
.word	0            // 96  GPIO 0 irq 0
.word	0            // 97  GPIO 0 irq 1
.word	0            // 98  GPIO 1 irq 0
.word	0            // 99  GPIO 1 irq 1
.word	0            // 100 GPMC
.word	0            // 101 EMIF 0 error
.word	0            // 102 reserved
.word	0            // 103 reserved
.word	0            // 104 reserved
.word	0            // 105 reserved
.word	0            // 106 reserved
.word	0            // 107 reserved
.word	0            // 108 reserved
.word	0            // 109 reserved
.word	0            // 110 reserved
.word	0            // 111 reserved
.word	0            // 112 EDMA TC 0 error
.word	0            // 113 EDMA TC 1 error
.word	0            // 114 EDMA TC 2 error
.word	0            // 115 Touchscreen Pen
.word	0            // 116 reserved
.word	0            // 117 reserved
.word	0            // 118 reserved
.word	0            // 119 reserved
.word	0            // 120 SmartReflex 0 (MPU)
.word	0            // 121 SmartReflex 1 (core)
.word	0            // 122 reserved
.word	0            // 123 External DMA/IRQ pin 0
.word	0            // 124 External DMA/IRQ pin 1
.word	0            // 125 SPI 1
.word	0            // 126 reserved
.word	0            // 127 reserved
