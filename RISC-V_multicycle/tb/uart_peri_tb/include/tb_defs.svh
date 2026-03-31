`ifndef UART_PERI_TB_DEFS_SVH
`define UART_PERI_TB_DEFS_SVH

typedef enum int unsigned {
    UART_PERI_EVT_TX_BYTE
} uart_peri_event_kind_e;

`define UART_TB_INFO(MSG)  $display("[%0t][UART_TB][INFO] %s", $time, MSG)
`define UART_TB_WARN(MSG)  $display("[%0t][UART_TB][WARN] %s", $time, MSG)
`define UART_TB_ERR(MSG)   $error("[%0t][UART_TB][ERR ] %s", $time, MSG)
`define UART_TB_FATAL(MSG) $fatal(1, "[%0t][UART_TB][FATAL] %s", $time, MSG)

`endif
