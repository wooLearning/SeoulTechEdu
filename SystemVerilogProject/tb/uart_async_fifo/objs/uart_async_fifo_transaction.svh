class uart_async_fifo_transaction;
  localparam int SC_FILL = 1;
  localparam int SC_BALANCED = 2;
  localparam int SC_DRAIN = 3;

  rand bit [7:0] data;
  int unsigned scenario_id;
  int unsigned pop_count_after_send;

  static function string scenario_name_by_id(int unsigned id);
    case (id)
      SC_FILL:     return "fill_async";
      SC_BALANCED: return "balanced_async";
      SC_DRAIN:    return "drain_async";
      default:     return "unknown";
    endcase
  endfunction

  function string get_scenario_name();
    return scenario_name_by_id(scenario_id);
  endfunction
endclass
