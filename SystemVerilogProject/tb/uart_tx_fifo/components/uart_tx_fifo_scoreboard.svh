class uart_tx_fifo_scoreboard;
  uart_tx_fifo_transaction exp_tr;
  uart_tx_fifo_transaction act_tr;
  uart_tx_fifo_coverage cov;
  mailbox #(uart_tx_fifo_transaction) exp_mbox;
  mailbox #(uart_tx_fifo_transaction) mon2scb_mbox;
  virtual uart_tx_fifo_if vif;
  event scb_done_ev;
  int pass_cnt;
  int fail_cnt;

  function new(
    mailbox #(uart_tx_fifo_transaction) exp_mbox,
    mailbox #(uart_tx_fifo_transaction) mon2scb_mbox,
    virtual uart_tx_fifo_if vif,
    event scb_done_ev
  );
    this.exp_mbox = exp_mbox;
    this.mon2scb_mbox = mon2scb_mbox;
    this.vif = vif;
    this.scb_done_ev = scb_done_ev;
    this.cov = new();
    this.pass_cnt = 0;
    this.fail_cnt = 0;
  endfunction

  task run(int run_count);
    for (int i = 0; i < run_count; i++) begin
      exp_mbox.get(exp_tr);
      mon2scb_mbox.get(act_tr);
      cov.sample_item(exp_tr.scenario_id, vif.oFull);
      if (act_tr.data !== exp_tr.data) begin
        fail_cnt++;
        $display("[UART-TXF][SCB] FAIL idx=%0d scenario=%s exp=%0h got=%0h",
          i, exp_tr.get_scenario_name(), exp_tr.data, act_tr.data);
      end else begin
        pass_cnt++;
        $display("[UART-TXF][SCB] PASS idx=%0d scenario=%s data=%0h",
          i, exp_tr.get_scenario_name(), act_tr.data);
      end
    end
    $display("[UART-TXF][SCB][SUMMARY] sample=%0d pass=%0d fail=%0d",
      run_count, pass_cnt, fail_cnt);
    $display("[UART-TXF][SCB][COVERAGE] functional_coverage=%0.2f%%", cov.cg_uart_txf.get_inst_coverage());
    if (fail_cnt != 0) $fatal(1, "[UART-TXF][SCB] mismatches=%0d", fail_cnt);
    $display("[UART-TXF][SCB][PASS] UART TX+FIFO scoreboard completed without mismatches");
    -> scb_done_ev;
  endtask
endclass
