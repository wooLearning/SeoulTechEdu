class uart_rx_driver;
  uart_rx_transaction tr;
  mailbox #(uart_rx_transaction) gen2drv_mbox;
  virtual uart_rx_if vif;
  event gen_next_ev;

  function new(
    mailbox #(uart_rx_transaction) gen2drv_mbox,
    virtual uart_rx_if vif,
    event gen_next_ev
  );
    this.gen2drv_mbox = gen2drv_mbox;
    this.vif          = vif;
    this.gen_next_ev  = gen_next_ev;
  endfunction

  task preset();
    vif.iRst  <= 1'b1;
    vif.iRx   <= 1'b1;
    repeat (6) @(posedge vif.iClk);
    vif.iRst  <= 1'b0;
    repeat (4) @(posedge vif.iClk);
    $display("[UART-RX][DRV] reset released");
  endtask

  task wait_16x_ticks(int n_ticks);
    int cnt;
    cnt = 0;
    while (cnt < n_ticks) begin
      @(posedge vif.iClk);
      if (vif.iTick16x) begin
        cnt++;
      end
    end
  endtask

  task send_uart_byte(logic [7:0] data);
    vif.iRx <= 1'b0;
    wait_16x_ticks(16);
    for (int bit_idx = 0; bit_idx < 8; bit_idx++) begin
      vif.iRx <= data[bit_idx];
      wait_16x_ticks(16);
    end
    vif.iRx <= 1'b1;
    wait_16x_ticks(16);
  endtask

  task send_invalid_stop_byte(logic [7:0] data, int unsigned low_hold_ticks16x);
    int unsigned hold_ticks;
    hold_ticks = (low_hold_ticks16x == 0) ? 16 : low_hold_ticks16x;
    vif.iRx <= 1'b0;
    wait_16x_ticks(16);
    for (int bit_idx = 0; bit_idx < 8; bit_idx++) begin
      vif.iRx <= data[bit_idx];
      wait_16x_ticks(16);
    end
    vif.iRx <= 1'b0;
    wait_16x_ticks(hold_ticks);
    vif.iRx <= 1'b1;
    wait_16x_ticks(16);
  endtask

  task run();
    assert (vif != null) else $fatal(1, "[UART-RX][DRV] vif is null");
    forever begin
      gen2drv_mbox.get(tr);
      vif.tbScenarioId = tr.scenario_id;
      case (tr.scenario_id)
        UART_RX_SC_VALID: begin
          send_uart_byte(tr.data);
          $display("[UART-RX][DRV] sent VALID byte=%0h t=%0t", tr.data, $time);
        end
        UART_RX_SC_INVALID_STOP: begin
          send_invalid_stop_byte(tr.data, tr.low_hold_ticks16x);
          $display("[UART-RX][DRV] sent INVALID(no_stop) byte=%0h t=%0t", tr.data, $time);
        end
        default: $fatal(1, "[UART-RX][DRV] unknown scenario=%0d", tr.scenario_id);
      endcase
      -> gen_next_ev;
    end
  endtask
endclass
