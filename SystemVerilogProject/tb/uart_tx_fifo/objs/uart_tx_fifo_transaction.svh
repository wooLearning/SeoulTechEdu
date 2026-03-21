class uart_tx_fifo_transaction;
  localparam int SC_FILL = 1;
  localparam int SC_BALANCED = 2;
  localparam int SC_BURST = 3;

  rand bit [7:0] data;
  int unsigned scenario_id;

  static function string scenario_name_by_id(int unsigned id);
    case (id)
      SC_FILL:     return "fill_queue";
      SC_BALANCED: return "balanced_enqueue";
      SC_BURST:    return "burst_enqueue";
      default:     return "unknown";
    endcase
  endfunction

  function string get_scenario_name();
    return scenario_name_by_id(scenario_id);
  endfunction
endclass
