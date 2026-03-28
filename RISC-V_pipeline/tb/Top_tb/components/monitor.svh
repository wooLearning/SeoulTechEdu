`ifndef TOP_MONITOR_SVH
`define TOP_MONITOR_SVH

class TopMonitor;
    virtual Top_if vif_Top;
    mailbox #(TopTx) mbx_mon2scb;
    mailbox #(TopTx) mbx_mon2cov;
    int unsigned     m_cycle;
    int unsigned     m_seen_count;

    function new(
        virtual Top_if vif_Top,
        mailbox #(TopTx) mbx_mon2scb,
        mailbox #(TopTx) mbx_mon2cov
    );
        this.vif_Top = vif_Top;
        this.mbx_mon2scb = mbx_mon2scb;
        this.mbx_mon2cov = mbx_mon2cov;
        this.m_cycle = 0;
        this.m_seen_count = 0;
    endfunction

    virtual task run();
        TopTx tx_item;
        int idx;
        forever begin
            @(posedge vif_Top.iClk);
            m_cycle++;
            if (vif_Top.tb_trace_retire_valid) begin
                tx_item = new();
                tx_item.m_step_idx = m_seen_count;
                tx_item.m_cycle = m_cycle;
                tx_item.m_valid = vif_Top.tb_trace_retire_valid;
                tx_item.m_illegal = vif_Top.tb_trace_retire_illegal;
                tx_item.m_reg_write = vif_Top.tb_trace_retire_reg_write;
                tx_item.m_mem_write = vif_Top.tb_trace_retire_mem_write;
                tx_item.m_stall = vif_Top.tb_dbg_stall;
                tx_item.m_redirect = vif_Top.tb_dbg_redirect;
                tx_item.m_forward_a = vif_Top.tb_dbg_forward_a;
                tx_item.m_forward_b = vif_Top.tb_dbg_forward_b;
                tx_item.m_rd_addr = vif_Top.tb_trace_retire_rd_addr;
                tx_item.m_pc = vif_Top.tb_trace_retire_pc;
                tx_item.m_inst = vif_Top.tb_trace_retire_inst;
                tx_item.m_rd_data = vif_Top.tb_trace_retire_rd_data;
                tx_item.m_mem_addr = vif_Top.tb_trace_retire_mem_addr;
                tx_item.m_mem_data = vif_Top.tb_trace_retire_mem_data;
                tx_item.m_mem_word0 = vif_Top.tb_mem_word0;
                tx_item.m_mem_word1 = vif_Top.tb_mem_word1;
                for (idx = 0; idx < 32; idx = idx + 1) begin
                    tx_item.m_gpr[idx] = vif_Top.tb_gpr[idx];
                end
                mbx_mon2scb.put(tx_item.clone());
                mbx_mon2cov.put(tx_item.clone());
                m_seen_count++;
            end
        end
    endtask
endclass

`endif
