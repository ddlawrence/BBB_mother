//
// startup.s
//
.equ STACK_SIZE, 8192
_start:
    ldr sp, =0x4030CDFC     // svc stack pointer
    sub r1, sp, #STACK_SIZE

    mrs r3, cpsr            // save cpsr_svc

    mov r2, #0x1b           // undef stack pointer
    msr cpsr_cxsf, r2
    mov sp, r1
    sub r1, sp, #STACK_SIZE

    mov r2, #0x12           // irq stack pointer
    msr cpsr_cxsf, r2
    mov sp, r1
    sub r1, sp, #STACK_SIZE

    msr cpsr_cxsf, r3       // return to svc mode

    mov r3, r0
// zero out bss
    ldr     r0, =__bss_start__
    ldr     r1, =__bss_size__
    add     r1, r0
    mov     r2, #0
0:
    cmp     r0, r1
    strlt   r2, [r0], #4
    blt     0b

    mov     r0, r3  // restore boot parameters, not impt, spruh73l 26.1.10.2 
    b       main

loop:
    b loop
