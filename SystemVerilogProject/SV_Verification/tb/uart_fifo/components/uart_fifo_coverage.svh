class uart_fifo_coverage;
  covergroup cg_uart_fifo with function sample(
    int unsigned scenario_id,
    bit full_flag,
    bit empty_flag
  );
    option.per_instance = 1;
    cp_scenario: coverpoint scenario_id {
      bins fill_then_drain = {uart_fifo_transaction::SC_FILL_THEN_DRAIN};
      bins balanced        = {uart_fifo_transaction::SC_BALANCED};
      bins burst_drain     = {uart_fifo_transaction::SC_BURST_DRAIN};
    }
    cp_flag_state: coverpoint {full_flag, empty_flag} {
      bins normal = {2'b00};
      bins full   = {2'b10};
      bins empty  = {2'b01};
    }
    cx_scenario_flag: cross cp_scenario, cp_flag_state;
  endgroup

  function new();
    cg_uart_fifo = new();
  endfunction

  function void sample_item(int unsigned scenario_id, bit full_flag, bit empty_flag);
    cg_uart_fifo.sample(scenario_id, full_flag, empty_flag);
  endfunction

  function real get_coverage();
    return cg_uart_fifo.get_inst_coverage();
  endfunction
endclass
