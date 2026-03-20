// Drives sync FIFO requests before active clock edge.
class sync_fifo_driver;
  sync_fifo_transaction tr;
  mailbox #(sync_fifo_transaction) gen2drv_mbox;
  virtual sync_fifo_if vif;

  function new(mailbox #(sync_fifo_transaction) gen2drv_mbox, virtual sync_fifo_if vif);
    this.gen2drv_mbox = gen2drv_mbox;
    this.vif          = vif;
  endfunction

  task preset();
    vif.iWrEn  <= 1'b0;
    vif.iRdEn  <= 1'b0;
    vif.iWData <= '0;
    vif.iRstn  <= 1'b0;
    vif.tbScenarioId <= 0;
    repeat (2) @(posedge vif.iClk);
    vif.iRstn <= 1'b1;
    @(posedge vif.iClk);
    $display("[DRV] reset released");
  endtask

  task run();
    forever begin
      gen2drv_mbox.get(tr);

      // Drive through the clocking block on the inactive phase.
      @(vif.drv_cb);
      vif.drv_cb.tbScenarioId <= tr.scenario_id;
      vif.drv_cb.iWrEn  <= tr.iWrEn;
      vif.drv_cb.iRdEn  <= tr.iRdEn;
      vif.drv_cb.iWData <= tr.iWData;

      $display("[DRV] t=%0t scenario=%s wr=%0b rd=%0b wdata=%0h",
        $time, tr.get_scenario_name(), tr.iWrEn, tr.iRdEn, tr.iWData);
    end
  endtask
endclass
