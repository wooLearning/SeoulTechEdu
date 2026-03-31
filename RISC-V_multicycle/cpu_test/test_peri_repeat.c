#include "mmio.h"

#ifndef STEP_DELAY_LOOPS
#define STEP_DELAY_LOOPS 200000u
#endif

#ifndef HEARTBEAT_MASK
#define HEARTBEAT_MASK   0x7u
#endif

static void cpu_delay_loops(volatile u32 loops) {
    while (loops--) {
        __asm__ volatile ("nop");
    }
}

static void uart_putc(char ch) {
    while (UART_STATUS & UART_STATUS_TX_FULL) {
    }
    UART_TXDATA = (u32)(unsigned char)ch;
}

static void uart_puts(const char *text) {
    while (*text) {
        uart_putc(*text++);
    }
}

static void uart_put_hex4(u32 value) {
    value &= 0xFu;
    uart_putc((value < 10u) ? (char)('0' + value) : (char)('A' + (value - 10u)));
}

static void uart_put_hex8(u32 value) {
    uart_put_hex4(value >> 4);
    uart_put_hex4(value);
}

static void uart_put_hex16(u32 value) {
    uart_put_hex8(value >> 8);
    uart_put_hex8(value);
}

static void uart_put_hex32(u32 value) {
    uart_put_hex16(value >> 16);
    uart_put_hex16(value);
}

static void uart_put_crlf(void) {
    uart_puts("\r\n");
}

static void log_reg32(const char *name, u32 value) {
    uart_puts(name);
    uart_puts("=0x");
    uart_put_hex32(value);
    uart_put_crlf();
}

static void clear_uart_errors_if_needed(void) {
    u32 control = 0u;
    u32 status = UART_STATUS;

    if (status & UART_STATUS_RX_OVERFLOW) {
        control |= UART_CONTROL_CLR_OVERFLOW;
    }
    if (status & UART_STATUS_FRAME_ERROR) {
        control |= UART_CONTROL_CLR_FRAME;
    }

    if (control != 0u) {
        UART_CONTROL = control;
        UART_CONTROL = 0u;
    }
}

static int uart_try_getc(unsigned char *out_ch) {
    if (UART_STATUS & UART_STATUS_RX_EMPTY) {
        return 0;
    }

    *out_ch = (unsigned char)(UART_RXDATA & 0xFFu);
    return 1;
}

static void uart_put_baud_name(u32 baud_sel) {
    switch (baud_sel & 0xFu) {
        case UART_BAUD_SEL_9600:   uart_puts("9600"); break;
        case UART_BAUD_SEL_14400:  uart_puts("14400"); break;
        case UART_BAUD_SEL_19200:  uart_puts("19200"); break;
        case UART_BAUD_SEL_38400:  uart_puts("38400"); break;
        case UART_BAUD_SEL_57600:  uart_puts("57600"); break;
        case UART_BAUD_SEL_115200: uart_puts("115200"); break;
        case UART_BAUD_SEL_230400: uart_puts("230400"); break;
        case UART_BAUD_SEL_460800: uart_puts("460800"); break;
        case UART_BAUD_SEL_921600: uart_puts("921600"); break;
        default:                   uart_puts("9600"); break;
    }
}

static void log_baudcfg(u32 baudcfg) {
    uart_puts("BAUDCFG src=");
    uart_putc(UART_BAUDCFG_GET_SOURCE_SEL(baudcfg) ? 'A' : 'S');
    uart_puts(" req=0x");
    uart_put_hex8(UART_BAUDCFG_GET_APB_SEL(baudcfg));
    uart_puts(" act=0x");
    uart_put_hex8(UART_BAUDCFG_GET_ACTIVE_SEL(baudcfg));
    uart_puts(" rate=");
    uart_put_baud_name(UART_BAUDCFG_GET_ACTIVE_SEL(baudcfg));
    uart_puts("bps");
    uart_put_crlf();
}

int main(void) {
#ifdef FAST_UART_SEQ
    static const u32 baud_seq[4] = {
        UART_BAUD_SEL_921600,
        UART_BAUD_SEL_921600,
        UART_BAUD_SEL_921600,
        UART_BAUD_SEL_921600
    };
#else
    static const u32 baud_seq[4] = {
        UART_BAUD_SEL_9600,
        UART_BAUD_SEL_115200,
        UART_BAUD_SEL_460800,
        UART_BAUD_SEL_921600
    };
#endif

    u32 iter = 0u;
    u32 gpo_pat = 0x0001u;
    u32 gpio_pat = 0x1u;
    u32 fnd_run = FND_RUN_EN;

    GPO_CTL = GPO_CTL_INIT;
    GPO_ODATA = GPO_ODATA_INIT;
    GPI_CTL = GPI_CTL_INIT;
    GPIO_CTL = 0x000Fu;
    GPIO_ODATA = 0x0000u;
    FND_RUN = fnd_run;
    UART_CONTROL = UART_CONTROL_CLEAR_ALL;
    UART_CONTROL = 0u;
    UART_BAUDCFG = UART_BAUDCFG_MAKE(UART_BAUDCFG_USE_APB, UART_BAUD_SEL_115200);

    uart_puts("CPU ROM peripheral repeat test boot");
    uart_put_crlf();
    log_reg32("UART_ID", UART_ID);
    log_reg32("GPI_CTL", GPI_CTL);
    log_reg32("GPO_CTL", GPO_CTL);
    log_reg32("GPIO_CTL", GPIO_CTL);
    log_reg32("FND_RUN", FND_RUN);
    log_baudcfg(UART_BAUDCFG);

    while (1) {
        u32 gpi_value;
        u32 gpio_idata;
        u32 baudcfg;
        unsigned char rx_ch;

        clear_uart_errors_if_needed();

        gpi_value = GPI_IDATA;
        cpu_delay_loops(STEP_DELAY_LOOPS);

        GPO_ODATA = ((iter & 0xFu) << 12) | (gpi_value & 0x03FFu) | (fnd_run ? GPO_FND_RUN_BIT : 0u);
        cpu_delay_loops(STEP_DELAY_LOOPS);

        GPIO_CTL = 0x000Fu;
        GPIO_ODATA = gpio_pat & 0xFu;
        cpu_delay_loops(STEP_DELAY_LOOPS);

        gpio_idata = GPIO_IDATA;
        cpu_delay_loops(STEP_DELAY_LOOPS);

        fnd_run = (iter & 0x1u) ? FND_RUN_EN : 0u;
        FND_RUN = fnd_run;
        cpu_delay_loops(STEP_DELAY_LOOPS);

        UART_BAUDCFG = UART_BAUDCFG_MAKE(UART_BAUDCFG_USE_APB, baud_seq[iter & 0x3u]);
        baudcfg = UART_BAUDCFG;
        cpu_delay_loops(STEP_DELAY_LOOPS);

        uart_puts("ITER 0x");
        uart_put_hex8(iter);
        uart_puts(" GPI=0x");
        uart_put_hex32(gpi_value);
        uart_puts(" GPO=0x");
        uart_put_hex32(GPO_ODATA);
        uart_puts(" GPIO_IDATA=0x");
        uart_put_hex32(gpio_idata);
        uart_puts(" FND=");
        uart_putc(fnd_run ? '1' : '0');
        uart_put_crlf();
        log_baudcfg(baudcfg);

        if (uart_try_getc(&rx_ch)) {
            uart_puts("RX=0x");
            uart_put_hex8((u32)rx_ch);
            uart_puts(" ECHO");
            uart_put_crlf();
            uart_putc((char)rx_ch);
        }

        if ((iter & HEARTBEAT_MASK) == 0u) {
            uart_puts("HB gpo_pat=0x");
            uart_put_hex16(gpo_pat);
            uart_puts(" gpio_pat=0x");
            uart_put_hex8(gpio_pat);
            uart_put_crlf();
        }

        gpo_pat = ((gpo_pat << 1) & 0xFFFFu);
        if (gpo_pat == 0u) {
            gpo_pat = 0x0001u;
        }

        gpio_pat = ((gpio_pat << 1) & 0xFu);
        if (gpio_pat == 0u) {
            gpio_pat = 0x1u;
        }

        iter++;
    }

    return 0;
}
