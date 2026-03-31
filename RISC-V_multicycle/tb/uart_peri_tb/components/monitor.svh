`ifndef UART_PERI_MONITOR_SVH
`define UART_PERI_MONITOR_SVH

class UartPeriMonitor;
    UartPeriConfig                m_cfg;
    mailbox #(UartPeriTransaction) mbx_mon2scb;
    virtual uart_peri_if          vif_uart_peri;

    function new(
        virtual uart_peri_if vif_arg,
        UartPeriConfig cfg,
        mailbox #(UartPeriTransaction) mbx_arg
    );
        vif_uart_peri = vif_arg;
        m_cfg = cfg;
        mbx_mon2scb = mbx_arg;
    endfunction

    virtual task run();
        UartPeriTransaction tx_item;
        byte unsigned       tx_data;
        bit                 stop_ok;

        wait (vif_uart_peri.presetn === 1'b1);
        forever begin
            vif_uart_peri.capture_uart_tx_frame(tx_data, stop_ok, m_cfg.m_bit_period_ns);
            tx_item = new(UART_PERI_EVT_TX_BYTE, tx_data, stop_ok, "serial_tx");
            mbx_mon2scb.put(tx_item);
            if (m_cfg.m_verbose) begin
                `UART_TB_INFO($sformatf("MON captured %s", tx_item.sprint()));
            end
        end
    endtask
endclass

`endif
