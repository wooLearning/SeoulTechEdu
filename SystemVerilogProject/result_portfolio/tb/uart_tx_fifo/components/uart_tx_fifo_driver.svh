class uart_tx_fifo_driver;
  uart_tx_fifo_transaction tr;
  mailbox #(uart_tx_fifo_transaction) gen2drv_mbox;
  virtual uart_tx_fifo_if vif;
  event gen_next_ev;

  function new(
    mailbox #(uart_tx_fifo_transaction) gen2drv_mbox,
    virtual uart_tx_fifo_if vif,
    event gen_next_ev
  );
    this.gen2drv_mbox = gen2drv_mbox;
    this.vif          = vif;
    this.gen_next_ev  = gen_next_ev;
  endfunction

  task preset();
    vif.iRst      <= 1'b1;
    vif.iPush     <= 1'b0;
    vif.iPushData <= '0;
    repeat (6) @(posedge vif.iClk);
    vif.iRst <= 1'b0;
    repeat (4) @(posedge vif.iClk);
    $display("[UART-TXF][DRV] reset released");
  endtask

  task run(int run_count);
    for (int i = 0; i < run_count; i++) begin
      gen2drv_mbox.get(tr);
      vif.tbScenarioId <= tr.scenario_id;
      @(negedge vif.iClk);
      while (vif.oFull) @(negedge vif.iClk);
      vif.iPush     <= 1'b1;
      vif.iPushData <= tr.data;
      @(negedge vif.iClk);
      vif.iPush <= 1'b0;
      $display("[UART-TXF][DRV] pushed byte=%0h scenario=%s t=%0t",
        tr.data, tr.get_scenario_name(), $time);

      case (tr.scenario_id)
        uart_tx_fifo_transaction::SC_FILL: repeat (2) @(posedge vif.iClk);
        uart_tx_fifo_transaction::SC_BALANCED: begin
          wait (!vif.oBusy);
          @(posedge vif.iClk);
        end
        default: repeat (1) @(posedge vif.iClk);
      endcase
      -> gen_next_ev;
    end
  endtask
endclass
