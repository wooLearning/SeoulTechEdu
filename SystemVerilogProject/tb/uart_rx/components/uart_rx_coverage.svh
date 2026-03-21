class uart_rx_coverage;
  int sample_cnt;
  int bin_zero_cnt;
  int bin_all_ones_cnt;
  int bin_ascii_cnt;
  int bin_other_cnt;
  int bin_valid_cnt;
  int bin_invalid_cnt;
  covergroup cg_uart_rx with function sample(bit [7:0] data, int unsigned scenario_id);
    option.per_instance = 1;
    option.goal = 100;
    type_option.merge_instances = 1;
    cp_data: coverpoint data iff (scenario_id == UART_RX_SC_VALID) {
      bins zero     = {8'h00};
      bins all_ones = {8'hFF};
      bins ascii    = {[8'h20:8'h7E]};
      bins other    = default;
    }
    cp_scenario: coverpoint scenario_id {
      bins valid_frame  = {UART_RX_SC_VALID};
      bins invalid_stop = {UART_RX_SC_INVALID_STOP};
    }
  endgroup

  function new();
    cg_uart_rx = new();
    sample_cnt = 0;
    bin_zero_cnt = 0;
    bin_all_ones_cnt = 0;
    bin_ascii_cnt = 0;
    bin_other_cnt = 0;
    bin_valid_cnt = 0;
    bin_invalid_cnt = 0;
  endfunction

  function void sample_item(bit [7:0] data, int unsigned scenario_id);
    sample_cnt++;
    if (data == 8'h00) bin_zero_cnt++;
    else if (data == 8'hFF) bin_all_ones_cnt++;
    else if ((data >= 8'h20) && (data <= 8'h7E)) bin_ascii_cnt++;
    else bin_other_cnt++;
    if (scenario_id == UART_RX_SC_VALID) bin_valid_cnt++;
    else if (scenario_id == UART_RX_SC_INVALID_STOP) bin_invalid_cnt++;
    cg_uart_rx.sample(data, scenario_id);
  endfunction

  function void sample_invalid_stop();
    bin_invalid_cnt++;
    cg_uart_rx.sample('0, UART_RX_SC_INVALID_STOP);
  endfunction

  function void report_bins();
    $display("[UART-RX][COV] samples=%0d zero=%0d ones=%0d ascii=%0d other=%0d valid=%0d invalid=%0d",
      sample_cnt, bin_zero_cnt, bin_all_ones_cnt, bin_ascii_cnt, bin_other_cnt, bin_valid_cnt, bin_invalid_cnt);
  endfunction
endclass
