class uart_fifo_transaction;
  localparam int SC_FILL_THEN_DRAIN = 1;
  localparam int SC_BALANCED        = 2;
  localparam int SC_BURST_DRAIN     = 3;

  rand bit [7:0] data;
  int unsigned   scenario_id;
  int unsigned   pop_count_after_send;

  static function string scenario_name_by_id(int unsigned id);
    case (id)
      SC_FILL_THEN_DRAIN: return "fill_then_drain";
      SC_BALANCED:        return "balanced";
      SC_BURST_DRAIN:     return "burst_drain";
      default:            return "unknown";
    endcase
  endfunction

  function string get_scenario_name();
    return scenario_name_by_id(scenario_id);
  endfunction
endclass
