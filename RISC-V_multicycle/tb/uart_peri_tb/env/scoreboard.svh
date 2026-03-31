`ifndef UART_PERI_SCOREBOARD_SVH
`define UART_PERI_SCOREBOARD_SVH

class UartPeriScoreboard;
    mailbox #(UartPeriTransaction) mbx_mon2scb;
    virtual uart_peri_if           vif_uart_peri;
    byte unsigned                  m_expected_tx_q[$];
    int unsigned                   m_match_count;
    int unsigned                   m_mismatch_count;

    function new(
        virtual uart_peri_if vif_arg,
        mailbox #(UartPeriTransaction) mbx_arg
    );
        vif_uart_peri = vif_arg;
        mbx_mon2scb = mbx_arg;
        m_match_count = 0;
        m_mismatch_count = 0;
    endfunction

    virtual function void expect_tx_byte(input byte unsigned data);
        m_expected_tx_q.push_back(data);
        `UART_TB_INFO($sformatf("SCB expect TX byte 0x%02h", data));
    endfunction

    virtual task run();
        UartPeriTransaction actual_tx;
        forever begin
            mbx_mon2scb.get(actual_tx);
            if (m_expected_tx_q.size() == 0) begin
                m_mismatch_count++;
                `UART_TB_ERR($sformatf("Unexpected TX byte observed: %s", actual_tx.sprint()));
            end else begin
                byte unsigned expected_tx;
                expected_tx = m_expected_tx_q.pop_front();
                if (!actual_tx.m_stop_ok) begin
                    m_mismatch_count++;
                    `UART_TB_ERR($sformatf("TX stop bit invalid for data 0x%02h", actual_tx.m_data));
                end else if (actual_tx.m_data !== expected_tx) begin
                    m_mismatch_count++;
                    `UART_TB_ERR($sformatf(
                        "TX mismatch got=0x%02h exp=0x%02h",
                        actual_tx.m_data,
                        expected_tx
                    ));
                end else begin
                    m_match_count++;
                    `UART_TB_INFO($sformatf("SCB matched TX byte 0x%02h", actual_tx.m_data));
                end
            end
        end
    endtask

    virtual function void check_pending_empty();
        if (m_expected_tx_q.size() != 0) begin
            m_mismatch_count += m_expected_tx_q.size();
            `UART_TB_ERR($sformatf(
                "Unmatched expected TX bytes remain: %0d",
                m_expected_tx_q.size()
            ));
        end
    endfunction

    virtual function bit has_failures();
        return (m_mismatch_count != 0) || vif_uart_peri.mon_timeout_hit;
    endfunction
endclass

`endif
