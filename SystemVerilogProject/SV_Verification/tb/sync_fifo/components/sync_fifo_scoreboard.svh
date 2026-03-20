// Reference model + checks for sync FIFO behavior (coverage delegated to sync_fifo_coverage).
class sync_fifo_scoreboard;
  sync_fifo_transaction tr;
  sync_fifo_coverage cov;
  mailbox #(sync_fifo_transaction) mon2scb_mbox;
  event gen_next_ev;
  event scb_done_ev;
  int rDepth;
  integer rSummaryFd;
  integer rScenarioFd;
  integer rTraceFd;
  string rSummaryCsvPath;
  string rScenarioCsvPath;
  string rTraceCsvPath;

  logic [7:0] rModelQ[$];
  logic [7:0] rExpectedRData;
  int rSampleCnt;
  int rPassCnt;
  int rFailCnt;
  int rWrAcceptCnt;
  int rRdAcceptCnt;
  int rWrBlockCnt;
  int rRdBlockCnt;
  int rScenarioSampleCnt[1:5];
  int rScenarioWrAcceptCnt[1:5];
  int rScenarioRdAcceptCnt[1:5];
  int rScenarioWrBlockCnt[1:5];
  int rScenarioRdBlockCnt[1:5];
  int rFullSeenCnt;
  int rEmptySeenCnt;

  function new(
    mailbox #(sync_fifo_transaction) mon2scb_mbox,
    event gen_next_ev,
    event scb_done_ev,
    int rDepth
  );
    this.mon2scb_mbox = mon2scb_mbox;
    this.gen_next_ev  = gen_next_ev;
    this.scb_done_ev  = scb_done_ev;
    this.rDepth       = rDepth;
    this.cov          = new();
    this.rExpectedRData = '0;
    this.rSampleCnt   = 0;
    this.rPassCnt     = 0;
    this.rFailCnt     = 0;
    this.rWrAcceptCnt = 0;
    this.rRdAcceptCnt = 0;
    this.rWrBlockCnt  = 0;
    this.rRdBlockCnt  = 0;
    this.rFullSeenCnt = 0;
    this.rEmptySeenCnt = 0;
    this.rSummaryFd    = 0;
    this.rScenarioFd   = 0;
    this.rTraceFd      = 0;
    this.rSummaryCsvPath  = "";
    this.rScenarioCsvPath = "";
    this.rTraceCsvPath    = "";
    foreach (rScenarioSampleCnt[idx]) begin
      rScenarioSampleCnt[idx]    = 0;
      rScenarioWrAcceptCnt[idx]  = 0;
      rScenarioRdAcceptCnt[idx]  = 0;
      rScenarioWrBlockCnt[idx]   = 0;
      rScenarioRdBlockCnt[idx]   = 0;
    end
  endfunction

  task automatic setup_csv();
    if ($value$plusargs("CSV_SUMMARY=%s", rSummaryCsvPath)) begin
      rSummaryFd = $fopen(rSummaryCsvPath, "w");
      if (rSummaryFd != 0) begin
        $fwrite(rSummaryFd,
          "module_name,sample_count,rd_tick,pass_count,fail_count,wr_acc_count,rd_acc_count,wr_block_count,rd_block_count,depth_left,full_seen_count,empty_seen_count,coverage_pct,status\n");
      end
    end

    if ($value$plusargs("CSV_SCENARIO=%s", rScenarioCsvPath)) begin
      rScenarioFd = $fopen(rScenarioCsvPath, "w");
      if (rScenarioFd != 0) begin
        $fwrite(rScenarioFd,
          "module_name,scenario_id,scenario_name,sample_count,wr_acc_count,rd_acc_count,wr_block_count,rd_block_count\n");
      end
    end

    if ($value$plusargs("CSV_TRACE=%s", rTraceCsvPath)) begin
      rTraceFd = $fopen(rTraceCsvPath, "w");
      if (rTraceFd != 0) begin
        $fwrite(rTraceFd,
          "module_name,sample_index,sim_time,domain,scenario_id,scenario_name,wr_req,rd_req,wr_accepted,rd_accepted,full_flag,empty_flag,depth_after,pass_count,fail_count\n");
      end
    end
  endtask

  task automatic write_trace(bit wWrAccept, bit wRdAccept);
    if (rTraceFd != 0) begin
      $fwrite(
        rTraceFd,
        "sync_fifo,%0d,%0t,single,%0d,%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
        rSampleCnt,
        $time,
        tr.scenario_id,
        tr.get_scenario_name(),
        tr.iWrEn,
        tr.iRdEn,
        wWrAccept,
        wRdAccept,
        tr.oFull,
        tr.oEmpty,
        rModelQ.size(),
        rPassCnt,
        rFailCnt
      );
    end
  endtask

  task run(int run_count);
    setup_csv();
    repeat (run_count) begin
      int wPreCount;
      bit wRdAccept;
      bit wWrAccept;
      bit wExpectedFull;
      bit wExpectedEmpty;

      mon2scb_mbox.get(tr);
      rSampleCnt++;
      if (tr.scenario_id inside {[1:5]}) begin
        rScenarioSampleCnt[tr.scenario_id]++;
      end
      if (tr.oFull) begin
        rFullSeenCnt++;
      end
      if (tr.oEmpty) begin
        rEmptySeenCnt++;
      end

      wPreCount = rModelQ.size();
      wRdAccept = tr.iRdEn && (wPreCount > 0);
      // Match DUT behavior: allow write on full when a read also succeeds in the same cycle.
      wWrAccept = tr.iWrEn && ((wPreCount < rDepth) || wRdAccept);

      cov.sample(
        tr.scenario_id,
        tr.iWrEn,
        tr.iRdEn,
        wWrAccept,
        wRdAccept,
        tr.oFull,
        tr.oEmpty
      );

      if (wRdAccept) begin
        rExpectedRData = rModelQ.pop_front();
        rRdAcceptCnt++;
        if (tr.scenario_id inside {[1:5]}) begin
          rScenarioRdAcceptCnt[tr.scenario_id]++;
        end
        if (tr.oRData !== rExpectedRData) begin
          rFailCnt++;
          $display("[SCB] FAIL-RD t=%0t scenario=%s exp=%0h got=%0h pre_count=%0d",
            $time, tr.get_scenario_name(), rExpectedRData, tr.oRData, wPreCount);
        end
        else begin
          rPassCnt++;
          $display("[SCB] PASS-RD t=%0t scenario=%s exp=%0h got=%0h",
            $time, tr.get_scenario_name(), rExpectedRData, tr.oRData);
        end
      end
      else if (tr.iRdEn) begin
        rRdBlockCnt++;
        if (tr.scenario_id inside {[1:5]}) begin
          rScenarioRdBlockCnt[tr.scenario_id]++;
        end
        $display("[SCB] BLOCK-RD t=%0t scenario=%s pre_count=%0d",
          $time, tr.get_scenario_name(), wPreCount);
      end

      if (wWrAccept) begin
        rModelQ.push_back(tr.iWData);
        rWrAcceptCnt++;
        if (tr.scenario_id inside {[1:5]}) begin
          rScenarioWrAcceptCnt[tr.scenario_id]++;
        end
      end
      else if (tr.iWrEn) begin
        rWrBlockCnt++;
        if (tr.scenario_id inside {[1:5]}) begin
          rScenarioWrBlockCnt[tr.scenario_id]++;
        end
        $display("[SCB] BLOCK-WR t=%0t scenario=%s pre_count=%0d",
          $time, tr.get_scenario_name(), wPreCount);
      end

      // Flag checks are based on the post-transaction queue depth.
      wExpectedEmpty = (rModelQ.size() == 0);
      wExpectedFull  = (rModelQ.size() == rDepth);

      if (tr.oEmpty !== wExpectedEmpty) begin
        rFailCnt++;
        $display("[SCB] FAIL-FLAG t=%0t scenario=%s empty exp=%0b got=%0b depth=%0d",
          $time, tr.get_scenario_name(), wExpectedEmpty, tr.oEmpty, rModelQ.size());
      end
      else begin
        rPassCnt++;
      end

      if (tr.oFull !== wExpectedFull) begin
        rFailCnt++;
        $display("[SCB] FAIL-FLAG t=%0t scenario=%s full exp=%0b got=%0b depth=%0d",
          $time, tr.get_scenario_name(), wExpectedFull, tr.oFull, rModelQ.size());
      end
      else begin
        rPassCnt++;
      end

      write_trace(wWrAccept, wRdAccept);

      -> gen_next_ev;
    end

    $display("[SCB][SUMMARY] sample=%0d pass=%0d fail=%0d wr_acc=%0d rd_acc=%0d wr_block=%0d rd_block=%0d depth_left=%0d full_seen=%0d empty_seen=%0d",
      rSampleCnt, rPassCnt, rFailCnt, rWrAcceptCnt, rRdAcceptCnt, rWrBlockCnt, rRdBlockCnt,
      rModelQ.size(), rFullSeenCnt, rEmptySeenCnt);
    $display("[SCB][COVERAGE] functional_coverage=%0.2f%%", cov.get_coverage());
    if (rSummaryFd != 0) begin
      $fwrite(
        rSummaryFd,
        "sync_fifo,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0.2f,PASS\n",
        rSampleCnt,
        0,
        rPassCnt,
        rFailCnt,
        rWrAcceptCnt,
        rRdAcceptCnt,
        rWrBlockCnt,
        rRdBlockCnt,
        rModelQ.size(),
        rFullSeenCnt,
        rEmptySeenCnt,
        cov.get_coverage()
      );
    end
    foreach (rScenarioSampleCnt[idx]) begin
      $display("[SCB][SCENARIO] id=%0d name=%s sample=%0d wr_acc=%0d rd_acc=%0d wr_block=%0d rd_block=%0d",
        idx,
        sync_fifo_transaction::scenario_name_by_id(idx),
        rScenarioSampleCnt[idx],
        rScenarioWrAcceptCnt[idx],
        rScenarioRdAcceptCnt[idx],
        rScenarioWrBlockCnt[idx],
        rScenarioRdBlockCnt[idx]
      );
      if (rScenarioFd != 0) begin
        $fwrite(
          rScenarioFd,
          "sync_fifo,%0d,%s,%0d,%0d,%0d,%0d,%0d\n",
          idx,
          sync_fifo_transaction::scenario_name_by_id(idx),
          rScenarioSampleCnt[idx],
          rScenarioWrAcceptCnt[idx],
          rScenarioRdAcceptCnt[idx],
          rScenarioWrBlockCnt[idx],
          rScenarioRdBlockCnt[idx]
        );
      end
    end

    if (rFailCnt != 0) begin
      $fatal(1, "[SCB] completed with %0d mismatches", rFailCnt);
    end
    $display("[SCB][PASS] Sync FIFO scoreboard completed without mismatches");
    if (rSummaryFd != 0) $fclose(rSummaryFd);
    if (rScenarioFd != 0) $fclose(rScenarioFd);
    if (rTraceFd != 0) $fclose(rTraceFd);
    -> scb_done_ev;
  endtask
endclass
