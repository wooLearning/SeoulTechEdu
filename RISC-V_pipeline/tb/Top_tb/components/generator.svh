`ifndef TOP_GENERATOR_SVH
`define TOP_GENERATOR_SVH

class TopGenerator;
    TopConfig m_cfg;
    mailbox #(TopTx) mbx_gen2drv;

    function new(input TopConfig cfg, mailbox #(TopTx) mbx_gen2drv);
        this.m_cfg = cfg;
        this.mbx_gen2drv = mbx_gen2drv;
    endfunction

    virtual task run();
        TopTx tx_item;
        repeat (m_cfg.m_num_transactions) begin
            tx_item = new();
            if (!tx_item.randomize()) begin
                `TB_ERR("Generator randomization failed")
            end
            mbx_gen2drv.put(tx_item);
            if (m_cfg.m_verbose) begin
                `TB_INFO($sformatf("GEN : %s", tx_item.sprint()))
            end
        end
    endtask
endclass

`endif
