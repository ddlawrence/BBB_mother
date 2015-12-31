//
// I2C routines
// hacked from Nick Kondrashov, github.com/spbnick
//
.syntax unified
.data
I2C_SYSC            = 0x10
I2C_SYSC_SRST       = 1 << 1
I2C_IRQSTATUS_RAW   = 0x24
I2C_IRQSTATUS_XRDY  = 1 << 4
I2C_IRQSTATUS_RRDY  = 1 << 3
I2C_IRQSTATUS_ARDY  = 1 << 2
I2C_IRQSTATUS       = 0x28
I2C_SYSS            = 0x90
I2C_SYSS_RDONE      = 1
I2C_CNT             = 0x98
I2C_DATA            = 0x9c
I2C_CON             = 0xa4
I2C_CON_STT         = 1 << 0
I2C_CON_STP         = 1 << 1
I2C_CON_TRX         = 1 << 9
I2C_CON_MST         = 1 << 10
I2C_CON_EN          = 1 << 15
I2C_OA              = 0xa8
I2C_SA              = 0xac
I2C_PSC             = 0xb0
I2C_SCLL            = 0xb4
I2C_SCLH            = 0xb8

.text

//
// I2Cx module init
//
// @param base  I2C base address.
//
.global i2c_init
i2c_init:
    r_base      .req r0
    r_tmp       .req r1

    mov r_tmp, I2C_SYSC_SRST    // soft reset
    str r_tmp, [r_base, I2C_SYSC]

// set prescaler to obtain ICLK = 12 MHz from SCLK = 48 Mhz 
    mov r_tmp, 3                 // divisor = 4 
    str r_tmp, [r_base, I2C_PSC]

// set low/high time to get SCL of 100 MHz and duty about 50%
    mov r_tmp, 0x36              // U-boot setup: 61 ICLK low, 59 ICLK high
    str r_tmp, [r_base, I2C_SCLL]
    str r_tmp, [r_base, I2C_SCLH]

    mov r_tmp, 1    // set own address to 1
    str r_tmp, [r_base, I2C_OA]

    mov r_tmp, I2C_CON_EN    // enab module
    str r_tmp, [r_base, I2C_CON]

1:  ldr r_tmp, [r_base, I2C_SYSS]    // wait for reset
    tst r_tmp, I2C_SYSS_RDONE
    beq 1b

    mov r0, 0
    bx lr

    .unreq r_base
    .unreq r_tmp

//
// read a number of bytes from an I2C slave at a 7-bit bus address
//
// @param base          I2C base address
// @param slave_addr    slave address << 16 | slave register address
// @param ptr           pointer to buffer (for bytes read from slave)
// @param len           number of bytes to read
//
// @return number of unread bytes.  should be 0x0 for a complete transfer
//
.global i2c_read
i2c_read:
    r_base          .req r0
    r_slave_addr    .req r1
    r_ptr           .req r2
    r_len           .req r3
    r_tmp           .req r4

    push {r4, lr}

    ldr r_tmp, =0xffff    // clear all interrupt status bits
    str r_tmp, [r_base, I2C_IRQSTATUS]

// send the address/register

    ubfx r_tmp, r_slave_addr, 16, 7    // set slave address (7-bit default) (top 16 bits)
    str r_tmp, [r_base, I2C_SA]
    mov r_tmp, 0x1                     // 0x1 for 7-bit bus address or 0x2 for 10-bit
    str r_tmp, [r_base, I2C_CNT]       // see below for 10-bit bus addressing

    // start writing the address, don't stop (S A D)
    ldr r_tmp, =(I2C_CON_EN | I2C_CON_MST | I2C_CON_STT | I2C_CON_TRX)
    str r_tmp, [r_base, I2C_CON]

/*
// uncomment this for 10-bit bus addressing
1:  ldr r_tmp, [r_base, I2C_IRQSTATUS_RAW]    // wait for transmit-ready
    tst r_tmp, I2C_IRQSTATUS_XRDY
    beq 1b

    ubfx r_tmp, r_slave_addr, 8, 8            // send the lower 8-bit address as data
    str r_tmp, [r_base, I2C_DATA]             // for 10-bit bus addressing

    mov r_tmp, I2C_IRQSTATUS_XRDY             // clear transmit-ready
    str r_tmp, [r_base, I2C_IRQSTATUS]
// uncomment this for 10-bit bus addressing
*/

1:  ldr r_tmp, [r_base, I2C_IRQSTATUS_RAW]    // wait for transmit-ready
    tst r_tmp, I2C_IRQSTATUS_XRDY
    beq 1b

    ubfx r_tmp, r_slave_addr, 0, 8            // send the register byte (LSByte)
    str r_tmp, [r_base, I2C_DATA]

    mov r_tmp, I2C_IRQSTATUS_XRDY             // clear transmit-ready
    str r_tmp, [r_base, I2C_IRQSTATUS]

1:  ldr r_tmp, [r_base, I2C_IRQSTATUS_RAW]    // wait for/clear end-of-transfer
    tst r_tmp, I2C_IRQSTATUS_ARDY
    beq 1b
    mov r_tmp, I2C_IRQSTATUS_ARDY
    str r_tmp, [r_base, I2C_IRQSTATUS]

// read the data

    ubfx r_tmp, r_slave_addr, 16, 7    // set slave address
    str r_tmp, [r_base, I2C_SA]
    ubfx r_tmp, r_len, 0, 16           // set number of data bytes to transfer
    str r_tmp, [r_base, I2C_CNT]

    // start reading the data, stop (S A D * r_len P)
    ldr r_tmp, =(I2C_CON_EN | I2C_CON_MST | I2C_CON_STT | I2C_CON_STP)
    str r_tmp, [r_base, I2C_CON]

1:  ldr r_tmp, [r_base, I2C_IRQSTATUS_RAW]    // wait for receive-ready or transfer-done
    tst r_tmp, I2C_IRQSTATUS_ARDY
    bne i2c_read_exit
    tst r_tmp, I2C_IRQSTATUS_RRDY
    beq 1b

    ldr r_tmp, [r_base, I2C_DATA]    // transfer byte
    strb r_tmp, [r_ptr], 1
    sub r_len, r_len, 1

    mov r_tmp, I2C_IRQSTATUS_RRDY    // clear receive-ready
    str r_tmp, [r_base, I2C_IRQSTATUS]

    b 1b    // repeat

i2c_read_exit:
    ldr r_tmp, =0xffff    // clear all interrupt status bits
    str r_tmp, [r_base, I2C_IRQSTATUS]

    mov r0, r_len
    pop {r4, pc}

    .unreq  r_base
    .unreq  r_slave_addr
    .unreq  r_ptr
    .unreq  r_len
    .unreq  r_tmp
    
//
// write a byte to I2C slave at a 7-bit bus address
//
// @param base          I2C base address
// @param slave_addr    slave address << 16 | slave register address
// @param data          data byte to write to the slave register
//
// @return number of unwritten bytes.  should be 0x0 for a complete transfer
//
//  TODO implement for 10-bit bus addressing
.global i2c_write
i2c_write:
    r_base          .req r0
    r_slave_addr    .req r1
    r_data          .req r2
    r_tmp           .req r3

    ldr r_tmp, =0xffff    // clear all interrupt status bits
    str r_tmp, [r_base, I2C_IRQSTATUS]

// send the address/register byte/data byte

    ubfx r_tmp, r_slave_addr, 16, 7    // set slave address
    str r_tmp, [r_base, I2C_SA]
    mov r_tmp, 0x2                     // set number of bytes to transfer
    str r_tmp, [r_base, I2C_CNT]

    // start writing the address (S A D D P)
    ldr r_tmp, =(I2C_CON_EN | I2C_CON_MST | I2C_CON_STT | I2C_CON_STP | I2C_CON_TRX)
    str r_tmp, [r_base, I2C_CON]

1:  ldr r_tmp, [r_base, I2C_IRQSTATUS_RAW]  // wait for transmit-ready
    tst r_tmp, I2C_IRQSTATUS_XRDY
    beq 1b

    ubfx r_tmp, r_slave_addr, 0, 8          // write the register byte
    str r_tmp, [r_base, I2C_DATA]

    mov r_tmp, I2C_IRQSTATUS_XRDY           // clear transmit-ready
    str r_tmp, [r_base, I2C_IRQSTATUS]

1:  ldr r_tmp, [r_base, I2C_IRQSTATUS_RAW]  // wait for transmit-ready
    tst r_tmp, I2C_IRQSTATUS_XRDY
    beq 1b

    ubfx r_tmp, r_data, 0, 8                // write the data byte
    str r_tmp, [r_base, I2C_DATA]

    mov r_tmp, I2C_IRQSTATUS_XRDY           // clear transmit-ready
    str r_tmp, [r_base, I2C_IRQSTATUS]

    // Wait for/clear end-of-transfer
1:  ldr r_tmp, [r_base, I2C_IRQSTATUS_RAW]  // wait for receive-ready or transfer-done
    tst r_tmp, I2C_IRQSTATUS_ARDY
    beq 1b
    mov r_tmp, I2C_IRQSTATUS_ARDY
    str r_tmp, [r_base, I2C_IRQSTATUS]

    bx lr

    .unreq  r_base
    .unreq  r_slave_addr
    .unreq  r_data
    .unreq  r_tmp
//
// poke a register
//
// @param base         uint32, base register address
// @param offset       uint32, address offset
// @param val          uint32, value to write
//
.global poke
poke:
    r_base .req r0
    r_off .req r1
    r_val .req r2
    str r_val, [r_base, r_off]
    bx lr
    .unreq r_base
    .unreq r_off
    .unreq r_val
