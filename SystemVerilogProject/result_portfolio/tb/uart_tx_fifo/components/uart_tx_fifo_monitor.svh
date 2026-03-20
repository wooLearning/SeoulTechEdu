class uart_tx_fifo_monitor;
  uart_tx_fifo_transaction tr;
  mailbox #(uart_tx_fifo_transaction) mon2scb_mbox;
  virtual uart_tx_fifo_if vif;

  function new(mailbox #(uart_tx_fifo_transaction) mon2scb_mbox, virtual uart_tx_fifo_if vif);
    this.mon2scb_mbox = mon2scb_mbox;
    this.vif          = vif;
  endfunction

  task run();
    forever begin
      @(posedge vif.iClk);
      #1;
      if (vif.oLaunchValid) begin
        tr = new();
        tr.data = vif.oLaunchData;
        tr.scenario_id = vif.tbScenarioId;
        mon2scb_mbox.put(tr);
        $display("[UART-TXF][MON] launch byte=%0h t=%0t", tr.data, $time);
        while (vif.oLaunchValid) begin
          @(posedge vif.iClk);
          #1;
        end
      end
    end
  endtask
endclass
