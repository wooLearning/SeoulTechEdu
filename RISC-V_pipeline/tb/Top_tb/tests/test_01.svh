`ifndef TOP_TEST_01_SVH
`define TOP_TEST_01_SVH

class TopTest01 extends TopBaseTest;
    function new(virtual Top_if vif_Top);
        super.new(vif_Top);
    endfunction

    virtual task configure();
        super.configure();
        m_cfg.m_verbose = 1'b1;
    endtask
endclass

`endif
