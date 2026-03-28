`ifndef TOP_ENVIRONMENT_SVH
`define TOP_ENVIRONMENT_SVH

class TopEnv;
    TopConfig m_cfg;

    TopMonitor m_monitor;
    TopScoreboard m_scoreboard;
    TopCoverage m_coverage;

    mailbox #(TopTx) mbx_mon2scb;
    mailbox #(TopTx) mbx_mon2cov;

    virtual Top_if vif_Top;

    function new(virtual Top_if vif_Top, TopConfig cfg = null);
        this.vif_Top = vif_Top;
        if (cfg == null) begin
            m_cfg = new();
        end else begin
            m_cfg = cfg;
        end

        mbx_mon2scb = new();
        mbx_mon2cov = new();

        m_monitor = new(vif_Top, mbx_mon2scb, mbx_mon2cov);
        m_scoreboard = new(vif_Top, m_cfg, mbx_mon2scb);
        m_coverage = new(mbx_mon2cov);
    endfunction

    virtual task run();
        fork
            m_monitor.run();
            m_scoreboard.run();
            m_coverage.run();
        join_none
    endtask

    virtual function bit done();
        return m_scoreboard.m_done;
    endfunction

    virtual function bit passed();
        return m_scoreboard.m_passed;
    endfunction

    virtual task report();
        m_coverage.report();
    endtask
endclass

`endif
