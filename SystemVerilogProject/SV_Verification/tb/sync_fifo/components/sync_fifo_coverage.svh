// Dedicated coverage collector for sync FIFO samples.
class sync_fifo_coverage;
  bit rHitScenario[1:5];
  bit rHitReqMix[0:3];
  bit rHitWrPath[0:1];
  bit rHitRdPath[0:1];
  bit rHitFlag[0:2];

  // Coverage highlights scenario intent, request mix, acceptance, and flag state.
  covergroup cg_sync_fifo with function sample(
    int unsigned scenario_id,
    bit iWrEn,
    bit iRdEn,
    bit wrAccepted,
    bit rdAccepted,
    bit oFull,
    bit oEmpty
  );
    option.per_instance = 1;
    option.goal = 100;

    cp_scenario : coverpoint scenario_id {
      bins fill_burst      = {sync_fifo_transaction::SC_FILL_BURST};
      bins simul_stress    = {sync_fifo_transaction::SC_SIMUL_STRESS};
      bins drain_burst     = {sync_fifo_transaction::SC_DRAIN_BURST};
      bins flag_pressure   = {sync_fifo_transaction::SC_FLAG_PRESSURE};
      bins balanced_stream = {sync_fifo_transaction::SC_BALANCED_STREAM};
    }

    cp_req_mix : coverpoint {iWrEn, iRdEn} {
      bins idle   = {2'b00};
      bins write  = {2'b10};
      bins read   = {2'b01};
      bins both   = {2'b11};
    }

    cp_wr_path : coverpoint {iWrEn, wrAccepted} {
      bins idle     = {2'b00};
      bins accepted = {2'b11};
      bins blocked  = {2'b10};
      ignore_bins invalid = {2'b01};
    }

    cp_rd_path : coverpoint {iRdEn, rdAccepted} {
      bins idle     = {2'b00};
      bins accepted = {2'b11};
      bins blocked  = {2'b10};
      ignore_bins invalid = {2'b01};
    }

    cp_flag_state : coverpoint {oFull, oEmpty} {
      bins normal = {2'b00};
      bins full   = {2'b10};
      bins empty  = {2'b01};
      ignore_bins invalid = {2'b11};
    }

    cx_scenario_req  : cross cp_scenario, cp_req_mix;
    cx_scenario_flag : cross cp_scenario, cp_flag_state;
  endgroup

  function new();
    cg_sync_fifo = new();
    foreach (rHitScenario[idx]) begin
      rHitScenario[idx] = 1'b0;
    end
    foreach (rHitReqMix[idx]) begin
      rHitReqMix[idx] = 1'b0;
    end
    foreach (rHitWrPath[idx]) begin
      rHitWrPath[idx] = 1'b0;
    end
    foreach (rHitRdPath[idx]) begin
      rHitRdPath[idx] = 1'b0;
    end
    foreach (rHitFlag[idx]) begin
      rHitFlag[idx] = 1'b0;
    end
  endfunction

  function void sample(
    int unsigned scenario_id,
    bit iWrEn,
    bit iRdEn,
    bit wrAccepted,
    bit rdAccepted,
    bit oFull,
    bit oEmpty
  );
    cg_sync_fifo.sample(
      scenario_id,
      iWrEn,
      iRdEn,
      wrAccepted,
      rdAccepted,
      oFull,
      oEmpty
    );

    if (scenario_id inside {[1:5]}) begin
      rHitScenario[scenario_id] = 1'b1;
    end

    case ({iWrEn, iRdEn})
      2'b00: rHitReqMix[0] = 1'b1;
      2'b10: rHitReqMix[1] = 1'b1;
      2'b01: rHitReqMix[2] = 1'b1;
      2'b11: rHitReqMix[3] = 1'b1;
    endcase

    if (iWrEn && wrAccepted) begin
      rHitWrPath[0] = 1'b1;
    end
    else if (iWrEn && !wrAccepted) begin
      rHitWrPath[1] = 1'b1;
    end

    if (iRdEn && rdAccepted) begin
      rHitRdPath[0] = 1'b1;
    end
    else if (iRdEn && !rdAccepted) begin
      rHitRdPath[1] = 1'b1;
    end

    if (!oFull && !oEmpty) begin
      rHitFlag[0] = 1'b1;
    end
    else if (oFull && !oEmpty) begin
      rHitFlag[1] = 1'b1;
    end
    else if (!oFull && oEmpty) begin
      rHitFlag[2] = 1'b1;
    end
  endfunction

  function real get_coverage();
    int wCovered;
    int wTotal;

    wCovered = 0;
    wTotal   = 0;

    foreach (rHitScenario[idx]) begin
      wTotal++;
      if (rHitScenario[idx]) wCovered++;
    end
    foreach (rHitReqMix[idx]) begin
      wTotal++;
      if (rHitReqMix[idx]) wCovered++;
    end
    foreach (rHitWrPath[idx]) begin
      wTotal++;
      if (rHitWrPath[idx]) wCovered++;
    end
    foreach (rHitRdPath[idx]) begin
      wTotal++;
      if (rHitRdPath[idx]) wCovered++;
    end
    foreach (rHitFlag[idx]) begin
      wTotal++;
      if (rHitFlag[idx]) wCovered++;
    end

    if (wTotal == 0) begin
      return 0.0;
    end
    return (100.0 * wCovered) / wTotal;
  endfunction
endclass
