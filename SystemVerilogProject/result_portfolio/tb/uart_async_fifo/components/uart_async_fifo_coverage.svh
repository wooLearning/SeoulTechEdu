class uart_async_fifo_coverage;
  covergroup cg_uart_af with function sample(int unsigned scenario_id, bit full_flag, bit empty_flag);
    option.per_instance = 1;
    cp_scenario: coverpoint scenario_id {
      bins fill_async = {uart_async_fifo_transaction::SC_FILL};
      bins balanced_async = {uart_async_fifo_transaction::SC_BALANCED};
      bins drain_async = {uart_async_fifo_transaction::SC_DRAIN};
    }
    cp_flag_state: coverpoint {full_flag, empty_flag} {
      bins normal = {2'b00};
      bins full = {2'b10};
      bins empty = {2'b01};
    }
    cx_scenario_flag: cross cp_scenario, cp_flag_state;
  endgroup

  function new();
    cg_uart_af = new();
  endfunction

  function void sample_item(int unsigned scenario_id, bit full_flag, bit empty_flag);
    cg_uart_af.sample(scenario_id, full_flag, empty_flag);
  endfunction

  function real get_coverage();
    return cg_uart_af.get_inst_coverage();
  endfunction
endclass
