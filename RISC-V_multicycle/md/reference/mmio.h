#ifndef MMIO_H
#define MMIO_H

typedef unsigned int u32;

/* 32-bit MMIO access helper */
#define MMIO32(addr) (*(volatile u32 *)(addr))

/* Peripheral base addresses */
#define GPO_BASE   0x20000000u
#define GPI_BASE   0x20001000u
#define GPIO_BASE  0x20002000u
#define FND_BASE   0x20003000u
#define UART_BASE  0x20004000u

/* GPO registers */
#define GPO_CTL    MMIO32(GPO_BASE  + 0x00u)
#define GPO_ODATA  MMIO32(GPO_BASE  + 0x04u)

/* GPI registers */
#define GPI_CTL    MMIO32(GPI_BASE  + 0x00u)
#define GPI_IDATA  MMIO32(GPI_BASE  + 0x04u)

/* GPIO registers */
#define GPIO_CTL   MMIO32(GPIO_BASE + 0x00u)
#define GPIO_ODATA MMIO32(GPIO_BASE + 0x04u)
#define GPIO_IDATA MMIO32(GPIO_BASE + 0x08u)

/* FND register: bit0 = 0 stop, 1 run */
#define FND_RUN    MMIO32(FND_BASE  + 0x00u)

/* UART registers */
#define UART_ID      MMIO32(UART_BASE + 0x00u)
#define UART_STATUS  MMIO32(UART_BASE + 0x04u)
#define UART_TXDATA  MMIO32(UART_BASE + 0x08u)
#define UART_RXDATA  MMIO32(UART_BASE + 0x0Cu)
#define UART_CONTROL MMIO32(UART_BASE + 0x10u)
#define UART_BAUDCFG MMIO32(UART_BASE + 0x14u)

/* Common bit masks */
#define FND_RUN_EN               (1u << 0)

#define UART_STATUS_TX_FULL      (1u << 0)
#define UART_STATUS_TX_EMPTY     (1u << 1)
#define UART_STATUS_RX_FULL      (1u << 2)
#define UART_STATUS_RX_EMPTY     (1u << 3)
#define UART_STATUS_TX_BUSY      (1u << 4)
#define UART_STATUS_RX_OVERFLOW  (1u << 5)
#define UART_STATUS_FRAME_ERROR  (1u << 6)

#define UART_CONTROL_CLR_OVERFLOW (1u << 0)
#define UART_CONTROL_CLR_FRAME    (1u << 1)

#define UART_BAUD_SEL_9600        0u
#define UART_BAUD_SEL_14400       1u
#define UART_BAUD_SEL_19200       2u
#define UART_BAUD_SEL_38400       3u
#define UART_BAUD_SEL_57600       4u
#define UART_BAUD_SEL_115200      5u
#define UART_BAUD_SEL_230400      6u
#define UART_BAUD_SEL_460800      7u
#define UART_BAUD_SEL_921600      8u

#define UART_BAUDCFG_APB_SEL_MASK    0x0000000Fu
#define UART_BAUDCFG_SOURCE_SEL_BIT  (1u << 4)
#define UART_BAUDCFG_ACTIVE_SEL_SHIFT 8u
#define UART_BAUDCFG_ACTIVE_SEL_MASK (0xFu << UART_BAUDCFG_ACTIVE_SEL_SHIFT)

#define UART_BAUDCFG_USE_SWITCH      0u
#define UART_BAUDCFG_USE_APB         1u
#define UART_BAUDCFG_MAKE(source_sel, baud_sel) \
    ((((source_sel) & 0x1u) << 4) | ((baud_sel) & UART_BAUDCFG_APB_SEL_MASK))
#define UART_BAUDCFG_GET_APB_SEL(value)    ((value) & UART_BAUDCFG_APB_SEL_MASK)
#define UART_BAUDCFG_GET_SOURCE_SEL(value) (((value) >> 4) & 0x1u)
#define UART_BAUDCFG_GET_ACTIVE_SEL(value) (((value) >> UART_BAUDCFG_ACTIVE_SEL_SHIFT) & 0xFu)

/* Demo firmware default setup values */
#define GPO_CTL_INIT              0xFFFFu
#define GPO_ODATA_INIT            0x0000u
#define GPI_CTL_INIT              0x07FFu
#define GPI_SW_MASK               0x07FFu
#define GPI_UART_APB_SEL_MASK     0x000Fu
#define GPI_UART_SOURCE_SEL_BIT   (1u << 4)
#define GPI_FND_RUN_REQ_BIT       (1u << 5)
#define GPI_GPIO_PATTERN_SHIFT    6u
#define GPI_GPIO_PATTERN_MASK     (0xFu << GPI_GPIO_PATTERN_SHIFT)
#define GPIO_CTL_INIT             0x000Fu
#define GPIO_ODATA_INIT           0x0005u
#define GPIO_PATTERN_MASK         0x000Fu
#define GPO_SWITCH_MIRROR_MASK    0x03FFu
#define GPO_ACTIVE_BAUD_SHIFT     11u
#define GPO_ACTIVE_BAUD_MASK      (0xFu << GPO_ACTIVE_BAUD_SHIFT)
#define GPO_UART_SOURCE_BIT       (1u << 10)
#define GPO_FND_RUN_BIT           (1u << 15)
#define FND_RUN_INIT              FND_RUN_EN
#define UART_CONTROL_INIT         0u
#define UART_CONTROL_CLEAR_ALL    (UART_CONTROL_CLR_OVERFLOW | UART_CONTROL_CLR_FRAME)
#define UART_BAUDCFG_INIT         UART_BAUDCFG_MAKE(UART_BAUDCFG_USE_SWITCH, UART_BAUD_SEL_115200)

#endif
