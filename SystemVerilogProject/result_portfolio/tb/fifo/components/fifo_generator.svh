// Generates randomized write/read request pairs for async FIFO stimulus.
class fifo_generator;
  fifo_transaction tr;
  mailbox #(fifo_transaction) gen2drv_mbox;
  event gen_next_ev;

  function new(mailbox #(fifo_transaction) gen2drv_mbox, event gen_next_ev);
    this.gen2drv_mbox = gen2drv_mbox;
    this.gen_next_ev  = gen_next_ev;
  endfunction

  function automatic int unsigned pick_scenario(int iter, int run_count);
    int phase_len;

    // Async FIFO monitor observes extra write/read ticks beyond generator iterations.
    // Use shorter phases so all showcase scenarios appear before the scoreboard ends.
    phase_len = (run_count < 10) ? 1 : (run_count / 10);
    if (iter < (phase_len * 1)) return fifo_transaction::SC_FILL_BURST;
    if (iter < (phase_len * 2)) return fifo_transaction::SC_MIXED_STRESS;
    if (iter < (phase_len * 3)) return fifo_transaction::SC_DRAIN_BURST;
    if (iter < (phase_len * 4)) return fifo_transaction::SC_FULL_PRESSURE;
    return fifo_transaction::SC_EMPTY_PRESSURE;
  endfunction

  task run(int run_count);
    int unsigned wPrevScenarioId;
    int rScenarioGenCnt[1:5];

    wPrevScenarioId = 0;
    foreach (rScenarioGenCnt[idx]) begin
      rScenarioGenCnt[idx] = 0;
    end

    for (int i = 0; i < run_count; i++) begin
      tr = new();
      if (!tr.randomize()) begin
        $fatal(1, "[GEN] randomization failed");
      end

      tr.scenario_id = pick_scenario(i, run_count);
      rScenarioGenCnt[tr.scenario_id]++;

      if (tr.scenario_id != wPrevScenarioId) begin
        wPrevScenarioId = tr.scenario_id;
        $display("[GEN][PHASE] iter=%0d scenario=%s",
          i, fifo_transaction::scenario_name_by_id(tr.scenario_id));
      end

      // Each phase intentionally biases traffic toward a verification objective.
      case (tr.scenario_id)
        fifo_transaction::SC_FILL_BURST: begin
          tr.iWrEn = 1'b1;
          tr.iRdEn = ($urandom_range(0, 99) < 10);
        end

        fifo_transaction::SC_MIXED_STRESS: begin
          tr.iWrEn = ($urandom_range(0, 99) < 80);
          tr.iRdEn = ($urandom_range(0, 99) < 65);
          if ((i % 4) == 0) begin
            tr.iWrEn = 1'b1;
            tr.iRdEn = 1'b1;
          end
        end

        fifo_transaction::SC_FULL_PRESSURE: begin
          tr.iWrEn = 1'b1;
          tr.iRdEn = ($urandom_range(0, 99) < 20);
        end

        fifo_transaction::SC_DRAIN_BURST: begin
          tr.iWrEn = ($urandom_range(0, 99) < 15);
          tr.iRdEn = 1'b1;
        end

        fifo_transaction::SC_EMPTY_PRESSURE: begin
          tr.iWrEn = ($urandom_range(0, 99) < 20);
          tr.iRdEn = 1'b1;
          if ((i % 6) == 0) begin
            tr.iWrEn = 1'b0;
            tr.iRdEn = 1'b1;
          end
        end

        default: begin
          tr.iWrEn = 1'b1;
          tr.iRdEn = 1'b0;
        end
      endcase

      // Deterministic perturbation keeps the data pattern readable in wave/log review.
      tr.iWData = tr.iWData ^ i[7:0] ^ {3'b0, tr.scenario_id[4:0]};

      if ((i % 11) == 0) begin
        // Periodically force simultaneous requests to stress acceptance logic.
        tr.iWrEn = 1'b1;
        tr.iRdEn = 1'b1;
      end

      gen2drv_mbox.put(tr);
      @(gen_next_ev);
    end

    foreach (rScenarioGenCnt[idx]) begin
      $display("[GEN][SUMMARY] scenario=%s generated=%0d",
        fifo_transaction::scenario_name_by_id(idx), rScenarioGenCnt[idx]);
    end
    $display("[GEN] finished: run_count=%0d", run_count);
  endtask
endclass
