//
// BeagleboneBlack - main header file
//
#define SOC_CM_PER_REGS            0x44E00000

// gpio
#define SOC_GPIO_1_REGS            0x4804c000
volatile uint32_t gpio_irq_count=0;
extern uint32_t gpio_init(uint32_t gpio_base_addr, uint32_t gpio_pins);
extern void gpio_on(uint32_t gpio_base_addr, uint32_t gpio_pins);
extern void gpio_off(uint32_t gpio_base_addr, uint32_t gpio_pins);
extern void blink32(uint32_t data);

// uart
#define SOC_UART_0_REGS            0x44E09000
#define CONF_UART_0_RXD            0x970
#define CONF_UART_0_TXD            0x974
volatile uint32_t uart0_irq_count=0;
volatile uint32_t uart0_rbuf;
volatile uint32_t uart0_tbuf;
volatile uint32_t consoleUART = SOC_UART_0_REGS;
extern uint32_t uart0_init(uint32_t uart_base_addr);
extern uint32_t uart_rx(uint32_t uart_base_addr);
extern void uart_tx(uint32_t uart_base_addr, uint32_t byte);
extern void uart_txi(uint32_t uart_base_addr);
extern void hexprint(uint32_t word);
extern void pinmux(uint32_t pin, uint32_t val);

// i2c
#define SOC_I2C_0_REGS             0x44E0B000
#define SOC_I2C_1_REGS             0x4802A000
#define SOC_I2C_2_REGS             0x4819C000
#define CONF_I2C1_SDA              0x958
#define CONF_I2C1_SCL              0x95c
#define CM_PER_I2C1_CLKCTRL        0x48
extern uint32_t i2c_init(uint32_t i2c_base_addr);
extern uint32_t i2c_read(uint32_t base_addr, uint32_t slave_addr, uint32_t buf_ptr, uint32_t len);
extern uint32_t i2c_write(uint32_t base_addr, uint32_t slave_addr, uint32_t data);
extern void poke(uint32_t base_addr, uint32_t offset, uint32_t value);

// pwm
#define SOC_PWMSS0_REGS          0x48300000
#define SOC_PWMSS1_REGS          0x48302000
#define SOC_PWMSS2_REGS          0x48304000
#define SOC_EPWM_REGS            0x200
#define SOC_EPWM_0_REGS          SOC_PWMSS0_REGS + SOC_EPWM_REGS
#define SOC_EPWM_1_REGS          SOC_PWMSS1_REGS + SOC_EPWM_REGS
#define SOC_EPWM_2_REGS          SOC_PWMSS2_REGS + SOC_EPWM_REGS
#define GPIO_0_22                0x0820
#define GPIO_0_23                0x0824
#define GPIO_1_18                0x0848
#define GPIO_1_19                0x084c
#define GPIO_3_14                0x0990
#define GPIO_3_15                0x0994
extern uint32_t pwm_clk_init(uint32_t pwm_base_addr);
extern uint32_t pwm_init(uint32_t pwm_base_addr);
extern void pwm_write_A(uint32_t pwm_base_addr, uint32_t period);
extern void pwm_write_B(uint32_t pwm_base_addr, uint32_t period);
// PWM_PRESCALE of 224 = 14 * X  (X=1,2,4...128), see TBCTL Register, spruh73l 15.2.4.1
#define PWM_PRESCALE     224  // pwm clk divider (14*16) ~TBCLK
// TICKS_PER_MS * PWM_PERIOD_MS = period of pwm output in ticks = TBPRD (16 bits wide)
#define TICKS_PER_MS     446  // ticks per msec (pwm clock)
#define PWM_PERIOD_MS    20   // pwm output period in ms, which = 50Hz (RC-servo standard)

// irq
extern void irq_init();
extern void irq_isr();
extern void und_isr();

// rtc
extern void rtc_init();
extern void rtc_irq();
volatile uint32_t rtc_irq_count=0;
volatile uint32_t hour, min, sec;

// mmc
extern uint32_t mmc0_init();
