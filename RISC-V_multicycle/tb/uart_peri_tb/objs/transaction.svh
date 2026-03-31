`ifndef UART_PERI_TRANSACTION_SVH
`define UART_PERI_TRANSACTION_SVH

class UartPeriTransaction;
    uart_peri_event_kind_e m_kind;
    byte unsigned          m_data;
    bit                    m_stop_ok;
    string                 m_note;

    function new(
        input uart_peri_event_kind_e kind = UART_PERI_EVT_TX_BYTE,
        input byte unsigned data = 8'h00,
        input bit stop_ok = 1'b1,
        input string note = ""
    );
        m_kind    = kind;
        m_data    = data;
        m_stop_ok = stop_ok;
        m_note    = note;
    endfunction

    function string sprint();
        return $sformatf(
            "kind=%0d data=0x%02h stop_ok=%0d note=%s",
            m_kind,
            m_data,
            m_stop_ok,
            m_note
        );
    endfunction
endclass

`endif
