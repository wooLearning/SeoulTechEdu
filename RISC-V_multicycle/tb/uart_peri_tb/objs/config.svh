`ifndef UART_PERI_CONFIG_SVH
`define UART_PERI_CONFIG_SVH

class UartPeriConfig;
    int unsigned m_clk_period_ns;
    int unsigned m_timeout_cycles;
    int unsigned m_apb_timeout_cycles;
    int unsigned m_baud_sel;
    int unsigned m_baud_rate;
    realtime     m_bit_period_ns;
    realtime     m_jitter_ns;
    bit          m_verbose;

    function new();
        m_clk_period_ns     = 10;
        m_timeout_cycles    = 1_000_000;
        m_apb_timeout_cycles = 100_000;
        m_verbose           = 1'b1;
        set_baud_sel(4'd5);
        m_jitter_ns         = m_bit_period_ns * 0.08;
    endfunction

    function void set_baud_sel(input int unsigned baud_sel);
        m_baud_sel = baud_sel;
        case (baud_sel)
            4'd0:    m_baud_rate = 9600;
            4'd1:    m_baud_rate = 14400;
            4'd2:    m_baud_rate = 19200;
            4'd3:    m_baud_rate = 38400;
            4'd4:    m_baud_rate = 57600;
            4'd5:    m_baud_rate = 115200;
            4'd6:    m_baud_rate = 230400;
            4'd7:    m_baud_rate = 460800;
            4'd8:    m_baud_rate = 921600;
            default: m_baud_rate = 9600;
        endcase
        m_bit_period_ns = 1_000_000_000.0 / m_baud_rate;
    endfunction
endclass

`endif
