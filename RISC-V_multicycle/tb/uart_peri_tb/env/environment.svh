`ifndef UART_PERI_ENVIRONMENT_SVH
`define UART_PERI_ENVIRONMENT_SVH

class UartPeriEnv;
    UartPeriConfig                 m_cfg;
    UartPeriDriver                 m_driver;
    UartPeriMonitor                m_monitor;
    UartPeriScoreboard             m_scoreboard;
    mailbox #(UartPeriTransaction) mbx_mon2scb;
    virtual uart_peri_if           vif_uart_peri;

    function new(
        virtual uart_peri_if vif_arg,
        UartPeriConfig cfg = null
    );
        vif_uart_peri = vif_arg;
        if (cfg == null) begin
            m_cfg = new();
        end else begin
            m_cfg = cfg;
        end

        mbx_mon2scb = new();
        m_driver = new(vif_arg, m_cfg);
        m_monitor = new(vif_arg, m_cfg, mbx_mon2scb);
        m_scoreboard = new(vif_arg, mbx_mon2scb);
    endfunction

    virtual task run();
        fork
            m_driver.run();
            m_monitor.run();
            m_scoreboard.run();
        join_none
    endtask

    virtual function bit has_failures();
        return m_scoreboard.has_failures();
    endfunction
endclass

`endif
