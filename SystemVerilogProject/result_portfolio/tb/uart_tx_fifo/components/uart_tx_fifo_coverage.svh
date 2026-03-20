class uart_tx_fifo_coverage;
  covergroup cg_uart_txf with function sample(int unsigned scenario_id, bit full_flag);
    option.per_instance = 1;
    cp_scenario: coverpoint scenario_id {
      bins fill_queue       = {uart_tx_fifo_transaction::SC_FILL};
      bins balanced_enqueue = {uart_tx_fifo_transaction::SC_BALANCED};
      bins burst_enqueue    = {uart_tx_fifo_transaction::SC_BURST};
    }
    cp_full: coverpoint full_flag;
    cx_scenario_full: cross cp_scenario, cp_full;
  endgroup

  function new();
    cg_uart_txf = new();
  endfunction

  function void sample_item(int unsigned scenario_id, bit full_flag);
    cg_uart_txf.sample(scenario_id, full_flag);
  endfunction

  function real get_coverage();
    return cg_uart_txf.get_inst_coverage();
  endfunction
endclass
