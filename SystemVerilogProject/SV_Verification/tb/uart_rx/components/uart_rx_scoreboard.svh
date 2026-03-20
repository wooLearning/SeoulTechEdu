class uart_rx_scoreboard;
  uart_rx_transaction exp_tr;
  uart_rx_transaction act_tr;
  uart_rx_coverage cov;
  mailbox #(uart_rx_transaction) exp_mbox;
  mailbox #(uart_rx_transaction) mon2scb_mbox;
  virtual uart_rx_if vif;
  event scb_done_ev;

  int pass_cnt;
  int fail_cnt;
  int valid_cnt;
  int invalid_cnt;

  function new(
    mailbox #(uart_rx_transaction) exp_mbox,
    mailbox #(uart_rx_transaction) mon2scb_mbox,
    virtual uart_rx_if vif,
    event scb_done_ev
  );
    this.exp_mbox     = exp_mbox;
    this.mon2scb_mbox = mon2scb_mbox;
    this.vif          = vif;
    this.scb_done_ev  = scb_done_ev;
    this.cov          = new();
    this.pass_cnt     = 0;
    this.fail_cnt     = 0;
    this.valid_cnt    = 0;
    this.invalid_cnt  = 0;
  endfunction

  task run(int run_count);
    int get_ok;

    assert (vif != null) else $fatal(1, "[UART-RX][SCB] vif is null");
    for (int i = 0; i < run_count; i++) begin
      exp_mbox.get(exp_tr);
      if (exp_tr.expect_valid) begin
        valid_cnt++;
        mon2scb_mbox.get(act_tr);
        assert (!$isunknown(act_tr.data))
          else $fatal(1, "[UART-RX][SCB] act_tr.data is X/Z idx=%0d", i);
        cov.sample_item(act_tr.data, exp_tr.scenario_id);
        if (act_tr.data !== exp_tr.data) begin
          fail_cnt++;
          $display("[UART-RX][SCB] FAIL idx=%0d scenario=%s exp=%0h got=%0h",
            i, exp_tr.get_scenario_name(), exp_tr.data, act_tr.data);
        end
        else begin
          pass_cnt++;
          $display("[UART-RX][SCB] PASS idx=%0d scenario=%s data=%0h",
            i, exp_tr.get_scenario_name(), act_tr.data);
        end
      end
      else begin
        int unsigned observe_ticks16x;
        bit got_unexpected_valid;

        invalid_cnt = invalid_cnt + 1;
        observe_ticks16x = (exp_tr.observe_ticks16x == 0) ? (16 * 12) : exp_tr.observe_ticks16x;
        got_unexpected_valid = 1'b0;
        act_tr = null;
        for (int cnt = 0; cnt < observe_ticks16x; ) begin
          @(posedge vif.iClk);
          get_ok = mon2scb_mbox.try_get(act_tr);
          if (get_ok != 0) begin
            got_unexpected_valid = 1'b1;
            break;
          end
          if (vif.iTick16x) begin
            cnt++;
          end
        end
        if (got_unexpected_valid) begin
          fail_cnt++;
          $display("[UART-RX][SCB] FAIL idx=%0d invalid frame produced data=%0h",
            i, act_tr.data);
        end
        else begin
          pass_cnt++;
          $display("[UART-RX][SCB] PASS idx=%0d invalid frame produced no valid pulse", i);
        end
      end
    end

    $display("[UART-RX][SCB][SUMMARY] sample=%0d pass=%0d fail=%0d valid=%0d invalid=%0d",
      run_count, pass_cnt, fail_cnt, valid_cnt, invalid_cnt);
    $display("[UART-RX][SCB][COVERAGE] functional_coverage=%0.2f%%", cov.get_coverage());
    cov.report_bins();
    if (fail_cnt != 0) begin
      $fatal(1, "[UART-RX][SCB] mismatches=%0d", fail_cnt);
    end
    $display("[UART-RX][SCB][PASS] UART RX scoreboard completed without mismatches");
    -> scb_done_ev;
  endtask
endclass
