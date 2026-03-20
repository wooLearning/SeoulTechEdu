// Transaction object for async_fifo stimulus and monitored samples.
class async_fifo_transaction;
  localparam int unsigned SC_FILL_BURST     = 1;
  localparam int unsigned SC_MIXED_STRESS   = 2;
  localparam int unsigned SC_DRAIN_BURST    = 3;
  localparam int unsigned SC_FULL_PRESSURE  = 4;
  localparam int unsigned SC_EMPTY_PRESSURE = 5;

  rand bit       iWrEn;
  rand bit       iRdEn;
  rand bit [7:0] iWData;
  int unsigned   scenario_id;

  bit isWrSample;
  bit isRdSample;
  bit preFull;
  bit preEmpty;

  logic [7:0] oRData;
  logic       oFull;
  logic       oEmpty;

  constraint c_req_dist {
    iWrEn dist {1 := 6, 0 := 4};
    iRdEn dist {1 := 6, 0 := 4};
  }

  static function string scenario_name_by_id(int unsigned id);
    case (id)
      SC_FILL_BURST:     return "fill_burst";
      SC_MIXED_STRESS:   return "mixed_stress";
      SC_DRAIN_BURST:    return "drain_burst";
      SC_FULL_PRESSURE:  return "full_pressure";
      SC_EMPTY_PRESSURE: return "empty_pressure";
      default:           return "unclassified";
    endcase
  endfunction

  function string get_scenario_name();
    return scenario_name_by_id(scenario_id);
  endfunction
endclass
