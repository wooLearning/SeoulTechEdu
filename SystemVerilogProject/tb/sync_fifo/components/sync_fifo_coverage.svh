// Dedicated coverage collector for sync FIFO samples.
class sync_fifo_coverage;
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
    type_option.merge_instances = 1;

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
    cg_sync_fifo = new();
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
  endfunction
endclass
