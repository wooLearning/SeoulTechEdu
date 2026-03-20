// Dedicated coverage collector for async FIFO TB samples.
class fifo_coverage;
  bit rHitScenario[1:5];
  bit rHitDomain[0:1];
  bit rHitWrPath[0:1];
  bit rHitRdPath[0:1];
  bit rHitFlag[0:2];

  // Coverage focuses on scenario intent, domain sampling, acceptance, and flag states.
  covergroup cg_fifo with function sample(
    bit isWrSample,
    bit isRdSample,
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

    cp_domain : coverpoint {isWrSample, isRdSample} {
      bins wr_tick = {2'b10};
      bins rd_tick = {2'b01};
    }

    cp_scenario : coverpoint scenario_id {
      bins fill_burst     = {fifo_transaction::SC_FILL_BURST};
      bins mixed_stress   = {fifo_transaction::SC_MIXED_STRESS};
      bins drain_burst    = {fifo_transaction::SC_DRAIN_BURST};
      bins full_pressure  = {fifo_transaction::SC_FULL_PRESSURE};
      bins empty_pressure = {fifo_transaction::SC_EMPTY_PRESSURE};
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

    cx_scenario_domain : cross cp_scenario, cp_domain;
    cx_scenario_flag   : cross cp_scenario, cp_flag_state;
  endgroup

  function new();
    cg_fifo = new();
    foreach (rHitScenario[idx]) begin
      rHitScenario[idx] = 1'b0;
    end
    foreach (rHitDomain[idx]) begin
      rHitDomain[idx] = 1'b0;
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
    bit isWrSample,
    bit isRdSample,
    int unsigned scenario_id,
    bit iWrEn,
    bit iRdEn,
    bit wrAccepted,
    bit rdAccepted,
    bit oFull,
    bit oEmpty
  );
    cg_fifo.sample(
      isWrSample,
      isRdSample,
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

    if (isWrSample) begin
      rHitDomain[0] = 1'b1;
    end
    if (isRdSample) begin
      rHitDomain[1] = 1'b1;
    end

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
    foreach (rHitDomain[idx]) begin
      wTotal++;
      if (rHitDomain[idx]) wCovered++;
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
