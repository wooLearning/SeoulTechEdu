// Monitors async_fifo on both clock domains and forwards samples to scoreboard.
class async_fifo_monitor;
  async_fifo_transaction tr;
  mailbox #(async_fifo_transaction) mon2scb_mbox;
  virtual async_fifo_if vif;

  function new(mailbox #(async_fifo_transaction) mon2scb_mbox, virtual async_fifo_if vif);
    this.mon2scb_mbox = mon2scb_mbox;
    this.vif          = vif;
  endfunction

  task run();
    fork
      begin : wr_mon
        forever begin
          @(vif.wr_pre_cb);
          @(vif.wr_mon_cb);
          tr = new();
          tr.isWrSample = 1'b1;
          tr.isRdSample = 1'b0;
          tr.scenario_id = vif.wr_pre_cb.tbScenarioId;
          tr.preFull    = vif.wr_pre_cb.oFull;
          tr.preEmpty   = vif.wr_pre_cb.oEmpty;
          tr.iWrEn      = vif.wr_pre_cb.iWrEn;
          tr.iRdEn      = vif.wr_pre_cb.iRdEn;
          tr.iWData     = vif.wr_pre_cb.iWData;
          tr.oRData     = vif.wr_mon_cb.oRData;
          tr.oFull      = vif.wr_mon_cb.oFull;
          tr.oEmpty     = vif.wr_mon_cb.oEmpty;
          mon2scb_mbox.put(tr);
          $display("[MON-WR] t=%0t scenario=%s wr_en=%0b wdata=%0h full=%0b empty=%0b",
            $time, tr.get_scenario_name(), tr.iWrEn, tr.iWData, tr.oFull, tr.oEmpty);
        end
      end

      begin : rd_mon
        forever begin
          @(vif.rd_pre_cb);
          @(vif.rd_mon_cb);
          tr = new();
          tr.isWrSample = 1'b0;
          tr.isRdSample = 1'b1;
          tr.scenario_id = vif.rd_pre_cb.tbScenarioId;
          tr.preFull    = vif.rd_pre_cb.oFull;
          tr.preEmpty   = vif.rd_pre_cb.oEmpty;
          tr.iWrEn      = vif.rd_pre_cb.iWrEn;
          tr.iRdEn      = vif.rd_pre_cb.iRdEn;
          tr.iWData     = vif.rd_pre_cb.iWData;
          tr.oRData     = vif.rd_mon_cb.oRData;
          tr.oFull      = vif.rd_mon_cb.oFull;
          tr.oEmpty     = vif.rd_mon_cb.oEmpty;
          mon2scb_mbox.put(tr);
          $display("[MON-RD] t=%0t scenario=%s rd_en=%0b rdata=%0h full=%0b empty=%0b",
            $time, tr.get_scenario_name(), tr.iRdEn, tr.oRData, tr.oFull, tr.oEmpty);
        end
      end
    join
  endtask
endclass
