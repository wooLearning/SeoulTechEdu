// Dedicated coverage collector for async FIFO TB samples.
class fifo_coverage;
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
    type_option.merge_instances = 1;

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
      bins accepted = {2'b11};
      bins blocked  = {2'b10};
      ignore_bins idle_or_invalid = {2'b00, 2'b01};
    }

    cp_rd_path : coverpoint {iRdEn, rdAccepted} {
      bins accepted = {2'b11};
      bins blocked  = {2'b10};
      ignore_bins idle_or_invalid = {2'b00, 2'b01};
    }

    cp_flag_state : coverpoint {oFull, oEmpty} {
      bins normal = {2'b00};
      bins full   = {2'b10};
      bins empty  = {2'b01};
      ignore_bins invalid = {2'b11};
    }

  endgroup

  function new();
    cg_fifo = new();
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
  endfunction
endclass
