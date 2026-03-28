`ifndef TOP_TEST_02_SVH
`define TOP_TEST_02_SVH

class TopTest02 extends TopBaseTest;
    function new(virtual Top_if vif_Top);
        super.new(vif_Top);
    endfunction

    virtual task configure();
        super.configure();
        m_cfg.m_verbose = 1'b0;
    endtask
endclass

`endif
