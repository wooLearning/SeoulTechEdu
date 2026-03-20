// Transaction object for async FIFO stimulus and monitored samples.
class fifo_transaction;
  localparam int unsigned SC_FILL_BURST    = 1;
  localparam int unsigned SC_MIXED_STRESS  = 2;
  localparam int unsigned SC_DRAIN_BURST   = 3;
  localparam int unsigned SC_FULL_PRESSURE = 4;
  localparam int unsigned SC_EMPTY_PRESSURE = 5;

  // Generator-driven request fields (one write edge + one read edge worth of requests).
  rand bit       iWrEn;
  rand bit       iRdEn;
  rand bit [7:0] iWData;
  int unsigned   scenario_id;

  // Monitor tags to distinguish write-domain and read-domain samples.
  bit isWrSample;
  bit isRdSample;
  // Full/empty values sampled just before the active edge for acceptance decisions.
  bit preFull;
  bit preEmpty;

  // Sampled DUT state/IO at a clock edge.
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

  function void display(string tag = "TR");
    $display("[%s] scenario=%s wrS=%0b rdS=%0b iWrEn=%0b iRdEn=%0b iWData=%0h oRData=%0h preFull=%0b preEmpty=%0b full=%0b empty=%0b",
      tag, get_scenario_name(), isWrSample, isRdSample, iWrEn, iRdEn, iWData, oRData, preFull, preEmpty, oFull, oEmpty);
  endfunction
endclass
