class uart_rx_monitor;
  uart_rx_transaction tr;
  mailbox #(uart_rx_transaction) mon2scb_mbox;
  virtual uart_rx_if vif;

  function new(mailbox #(uart_rx_transaction) mon2scb_mbox, virtual uart_rx_if vif);
    this.mon2scb_mbox = mon2scb_mbox;
    this.vif          = vif;
  endfunction

  task run();
    forever begin
      @(posedge vif.iClk);
      if (vif.oValid) begin
        tr = new();
        tr.data = vif.oData;
        mon2scb_mbox.put(tr);
        $display("[UART-RX][MON] got byte=%0h t=%0t", tr.data, $time);
        while (vif.oValid) @(posedge vif.iClk);
      end
    end
  endtask
endclass
