`ifndef TOP_SCOREBOARD_SVH
`define TOP_SCOREBOARD_SVH

class TopScoreboard;
    virtual Top_if vif_Top;
    TopConfig      m_cfg;
    mailbox #(TopTx) mbx_mon2scb;
    int unsigned m_checked_count;
    int unsigned m_error_count;
    bit          m_done;
    bit          m_passed;

    function new(
        virtual Top_if vif_Top,
        TopConfig cfg,
        mailbox #(TopTx) mbx_mon2scb
    );
        this.vif_Top = vif_Top;
        this.m_cfg = cfg;
        this.mbx_mon2scb = mbx_mon2scb;
        m_checked_count = 0;
        m_error_count = 0;
        m_done = 1'b0;
        m_passed = 1'b0;
    endfunction

    virtual function int compare(input TopTx tx_actual);
        int err_cnt;
        int idx;
        err_cnt = 0;

        if (tx_actual.m_pc !== LP_SPIKE_TRACE_PC[m_checked_count]) begin
            `TB_ERR($sformatf(
                "ROW %0d PC mismatch got=0x%08h exp=0x%08h",
                m_checked_count,
                tx_actual.m_pc,
                LP_SPIKE_TRACE_PC[m_checked_count]
            ));
            err_cnt++;
        end

        if (tx_actual.m_inst !== LP_SPIKE_TRACE_INST[m_checked_count]) begin
            `TB_ERR($sformatf(
                "ROW %0d INST mismatch got=0x%08h exp=0x%08h",
                m_checked_count,
                tx_actual.m_inst,
                LP_SPIKE_TRACE_INST[m_checked_count]
            ));
            err_cnt++;
        end

        if (m_cfg.m_check_all_registers) begin
            for (idx = 0; idx < 32; idx = idx + 1) begin
                if (tx_actual.m_gpr[idx] !== LP_SPIKE_TRACE_GPR[m_checked_count][idx]) begin
                    `TB_ERR($sformatf(
                        "ROW %0d x%0d mismatch got=0x%08h exp=0x%08h",
                        m_checked_count,
                        idx,
                        tx_actual.m_gpr[idx],
                        LP_SPIKE_TRACE_GPR[m_checked_count][idx]
                    ));
                    err_cnt++;
                end
            end
        end

        return err_cnt;
    endfunction

    virtual task run();
        TopTx tx_actual;
        int row_err_cnt;
        forever begin
            if (m_checked_count == LP_SPIKE_TRACE_DEPTH) begin
                break;
            end

            mbx_mon2scb.get(tx_actual);
            `TB_INFO($sformatf(
                "SCB TRACE #%0d/%0d : %s class=%s",
                m_checked_count + 1,
                LP_SPIKE_TRACE_DEPTH,
                tx_actual.sprint(),
                trace_opcode_name(tx_actual.m_inst)
            ));

            row_err_cnt = compare(tx_actual);
            if (row_err_cnt != 0) begin
                m_error_count += row_err_cnt;
            end else begin
                if (m_cfg.m_verbose) begin
                    `TB_INFO($sformatf("SCB PASS #%0d", m_checked_count + 1));
                end
            end
            m_checked_count++;
        end

        if (LP_SPIKE_CHECK_FINAL_MEM) begin
            if (vif_Top.tb_mem_word0 !== LP_SPIKE_DATA_WORD0_EXP) begin
                `TB_ERR($sformatf(
                    "Final memory word0 mismatch got=0x%08h exp=0x%08h",
                    vif_Top.tb_mem_word0,
                    LP_SPIKE_DATA_WORD0_EXP
                ));
                m_error_count++;
            end else begin
                `TB_INFO($sformatf("Final memory word0 matched 0x%08h", LP_SPIKE_DATA_WORD0_EXP));
            end

            if (vif_Top.tb_mem_word1 !== LP_SPIKE_DATA_WORD1_EXP) begin
                `TB_ERR($sformatf(
                    "Final memory word1 mismatch got=0x%08h exp=0x%08h",
                    vif_Top.tb_mem_word1,
                    LP_SPIKE_DATA_WORD1_EXP
                ));
                m_error_count++;
            end else begin
                `TB_INFO($sformatf("Final memory word1 matched 0x%08h", LP_SPIKE_DATA_WORD1_EXP));
            end
        end else begin
            `TB_INFO("Final memory check disabled for this trace package");
        end

        m_done = 1'b1;
        m_passed = (m_error_count == 0) && (m_checked_count == LP_SPIKE_TRACE_DEPTH);

        if (m_passed) begin
            `TB_INFO($sformatf(
                "Scoreboard completed successfully: rows=%0d errors=%0d",
                m_checked_count,
                m_error_count
            ));
        end else begin
            `TB_ERR($sformatf(
                "Scoreboard completed with failures: rows=%0d errors=%0d",
                m_checked_count,
                m_error_count
            ));
        end
    endtask
endclass

`endif
