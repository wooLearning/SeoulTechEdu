// Samples sync FIFO request/response after DUT updates and forwards to scoreboard.
class sync_fifo_monitor;
  sync_fifo_transaction tr;
  mailbox #(sync_fifo_transaction) mon2scb_mbox;
  virtual sync_fifo_if vif;

  function new(mailbox #(sync_fifo_transaction) mon2scb_mbox, virtual sync_fifo_if vif);
    this.mon2scb_mbox = mon2scb_mbox;
    this.vif          = vif;
  endfunction

  task run();
    forever begin
      // The monitor clocking block samples in the post-edge region, so no
      // extra `#1` stabilization is needed here.
      @(vif.mon_cb);

      tr = new();
      tr.scenario_id = vif.mon_cb.tbScenarioId;
      tr.iWrEn  = vif.mon_cb.iWrEn;
      tr.iRdEn  = vif.mon_cb.iRdEn;
      tr.iWData = vif.mon_cb.iWData;
      tr.oRData = vif.mon_cb.oRData;
      tr.oFull  = vif.mon_cb.oFull;
      tr.oEmpty = vif.mon_cb.oEmpty;

      mon2scb_mbox.put(tr);
      $display("[MON] t=%0t scenario=%s wr=%0b rd=%0b wdata=%0h rdata=%0h full=%0b empty=%0b",
        $time, tr.get_scenario_name(), tr.iWrEn, tr.iRdEn, tr.iWData, tr.oRData, tr.oFull, tr.oEmpty);
    end
  endtask
endclass
