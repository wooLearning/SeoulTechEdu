// Drives async FIFO write/read requests on separate clocks.
class fifo_driver;
  fifo_transaction tr;
  mailbox #(fifo_transaction) gen2drv_mbox;
  virtual fifo_if vif;
  event gen_next_ev;

  function new(
    mailbox #(fifo_transaction) gen2drv_mbox,
    virtual fifo_if vif,
    event gen_next_ev
  );
    this.gen2drv_mbox = gen2drv_mbox;
    this.vif          = vif;
    this.gen_next_ev  = gen_next_ev;
  endfunction

  task preset();
    vif.iWrEn  <= 1'b0;
    vif.iRdEn  <= 1'b0;
    vif.iWData <= '0;
    vif.iRstn  <= 1'b0;
    vif.tbScenarioId <= 0;

    // Let both domains observe reset for a few cycles.
    repeat (3) @(posedge vif.iWrClk);
    repeat (3) @(posedge vif.iRdClk);
    vif.iRstn <= 1'b1;
    @(posedge vif.iWrClk);
    @(posedge vif.iRdClk);
    $display("[DRV] reset released");
  endtask

  task push(input logic [7:0] wdata);
    // Drive through the write-domain clocking block on inactive edges.
    @(vif.wr_drv_cb);
    vif.wr_drv_cb.iWrEn  <= 1'b1;
    vif.wr_drv_cb.iWData <= wdata;
    @(vif.wr_drv_cb);
    vif.wr_drv_cb.iWrEn  <= 1'b0;
    vif.wr_drv_cb.iWData <= wdata;
  endtask

  task pop();
    // Drive through the read-domain clocking block on inactive edges.
    @(vif.rd_drv_cb);
    vif.rd_drv_cb.iRdEn <= 1'b1;
    @(vif.rd_drv_cb);
    vif.rd_drv_cb.iRdEn <= 1'b0;
  endtask

  task run();
    assert_vif_valid: assert (vif != null)
      else $fatal(1, "vif is null in fifo_driver");

    forever begin
      gen2drv_mbox.get(tr);
      assert_tr_valid: assert (tr != null)
        else $fatal(1, "Received null transaction in fifo_driver");

      vif.tbScenarioId <= tr.scenario_id;

      // One transaction schedules one write-side request and one read-side request.
      fork
        begin
          if (tr.iWrEn) begin
            push(tr.iWData);
          end else begin
            // Still consume one write-domain cycle through the clocking block.
            @(vif.wr_drv_cb);
            vif.wr_drv_cb.iWrEn  <= 1'b0;
            vif.wr_drv_cb.iWData <= tr.iWData;
            @(vif.wr_drv_cb);
          end
        end
        begin
          if (tr.iRdEn) begin
            pop();
          end else begin
            // Still consume one read-domain cycle through the clocking block.
            @(vif.rd_drv_cb);
            vif.rd_drv_cb.iRdEn <= 1'b0;
            @(vif.rd_drv_cb);
          end
        end
      join

      $display("[DRV] scenario=%s wr_en=%0b rd_en=%0b wdata=%0h @%0t",
        tr.get_scenario_name(), tr.iWrEn, tr.iRdEn, tr.iWData, $time);
      -> gen_next_ev;
    end
  endtask
endclass
