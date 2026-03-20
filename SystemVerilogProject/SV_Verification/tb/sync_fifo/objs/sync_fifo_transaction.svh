// Transaction object for synchronous FIFO stimulus and observed outputs.
class sync_fifo_transaction;
  localparam int unsigned SC_FILL_BURST      = 1;
  localparam int unsigned SC_SIMUL_STRESS    = 2;
  localparam int unsigned SC_DRAIN_BURST     = 3;
  localparam int unsigned SC_FLAG_PRESSURE   = 4;
  localparam int unsigned SC_BALANCED_STREAM = 5;

  // Request-side fields generated before the active edge.
  rand bit       iWrEn;
  rand bit       iRdEn;
  rand bit [7:0] iWData;
  int unsigned   scenario_id;

  // Response-side fields sampled by the monitor after the active edge.
  logic [7:0] oRData;
  logic       oFull;
  logic       oEmpty;

  constraint c_req_dist {
    iWrEn dist {1 := 6, 0 := 4};
    iRdEn dist {1 := 6, 0 := 4};
  }

  static function string scenario_name_by_id(int unsigned id);
    case (id)
      SC_FILL_BURST:      return "fill_burst";
      SC_SIMUL_STRESS:    return "simul_stress";
      SC_DRAIN_BURST:     return "drain_burst";
      SC_FLAG_PRESSURE:   return "flag_pressure";
      SC_BALANCED_STREAM: return "balanced_stream";
      default:            return "unclassified";
    endcase
  endfunction

  function string get_scenario_name();
    return scenario_name_by_id(scenario_id);
  endfunction

  function void display(string tag = "TR");
    $display("[%s] scenario=%s iWrEn=%0b iRdEn=%0b iWData=%0h oRData=%0h full=%0b empty=%0b",
      tag, get_scenario_name(), iWrEn, iRdEn, iWData, oRData, oFull, oEmpty);
  endfunction
endclass
