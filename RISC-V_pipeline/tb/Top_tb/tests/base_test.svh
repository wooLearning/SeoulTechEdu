`ifndef TOP_BASE_TEST_SVH
`define TOP_BASE_TEST_SVH

class TopBaseTest;
    TopConfig m_cfg;
    TopEnv m_env;
    virtual Top_if vif_Top;

    function new(virtual Top_if vif_Top);
        this.vif_Top = vif_Top;
        this.m_cfg = new();
    endfunction

    virtual task configure();
        m_cfg.m_verbose = 1'b1;
        m_cfg.m_timeout_cycles = 1200;
        m_cfg.m_check_all_registers = 1'b1;
    endtask

    virtual task run();
        int cyc;
        bit timed_out;
        configure();
        m_env = new(vif_Top, m_cfg);
        m_env.run();
        timed_out = 1'b1;

        for (cyc = 0; cyc < m_cfg.m_timeout_cycles; cyc = cyc + 1) begin
            @(posedge vif_Top.iClk);
            if (m_env.done()) begin
                timed_out = 1'b0;
                break;
            end
        end

        if (timed_out) begin
            `TB_ERR($sformatf("Top_tb timed out after %0d cycles", m_cfg.m_timeout_cycles));
            $fatal(1, "Top_tb timeout");
        end

        m_env.report();

        if (!m_env.passed()) begin
            $fatal(1, "Top_tb scoreboard reported failures");
        end

        `TB_INFO("Top_tb completed successfully");
    endtask
endclass

`endif
