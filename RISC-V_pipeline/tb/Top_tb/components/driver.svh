`ifndef TOP_DRIVER_SVH
`define TOP_DRIVER_SVH

class TopDriver;
    virtual Top_if vif_Top;
    mailbox #(TopTx) mbx_gen2drv;

    function new(virtual Top_if vif_Top, mailbox #(TopTx) mbx_gen2drv);
        this.vif_Top = vif_Top;
        this.mbx_gen2drv = mbx_gen2drv;
    endfunction

    virtual task drive_one(input TopTx tx_item);
        @(posedge vif_Top.iClk);
        vif_Top.tb_data_in <= tx_item.m_data;
        vif_Top.tb_valid <= tx_item.m_valid;

        do begin
            @(posedge vif_Top.iClk);
        end while (!vif_Top.tb_ready);

        vif_Top.tb_valid <= 1'b0;
    endtask

    virtual task run();
        TopTx tx_item;
        vif_Top.tb_data_in <= '0;
        vif_Top.tb_valid <= 1'b0;

        forever begin
            mbx_gen2drv.get(tx_item);
            drive_one(tx_item);
        end
    endtask
endclass

`endif
