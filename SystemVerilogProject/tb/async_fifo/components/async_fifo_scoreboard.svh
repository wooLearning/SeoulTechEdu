// Reference model + checks for async_fifo behavior.
class async_fifo_scoreboard;
  async_fifo_transaction tr;
  async_fifo_coverage cov;
  mailbox #(async_fifo_transaction) mon2scb_mbox;
  event scb_done_ev;
  integer rSummaryFd;
  integer rScenarioFd;
  integer rTraceFd;
  string rSummaryCsvPath;
  string rScenarioCsvPath;
  string rTraceCsvPath;

  logic [7:0] rModelQ[$];
  logic [7:0] rExpectedRData;
  int rSampleCnt;
  int rRdTickCnt;
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
    mailbox #(async_fifo_transaction) mon2scb_mbox,
    event scb_done_ev
  );
    this.mon2scb_mbox = mon2scb_mbox;
    this.scb_done_ev  = scb_done_ev;
    this.cov          = new();
    this.rSampleCnt   = 0;
    this.rRdTickCnt   = 0;
    this.rPassCnt     = 0;
    this.rFailCnt     = 0;
    this.rWrAcceptCnt = 0;
    this.rRdAcceptCnt = 0;
    this.rWrBlockCnt  = 0;
    this.rRdBlockCnt  = 0;
    this.rFullSeenCnt = 0;
    this.rEmptySeenCnt = 0;
    this.rExpectedRData = '0;
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

  task automatic write_trace(
    string domain_name,
    bit wWrAccepted,
    bit wRdAccepted
  );
    if (rTraceFd != 0) begin
      $fwrite(
        rTraceFd,
        "async_fifo_src,%0d,%0t,%s,%0d,%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
        rSampleCnt,
        $time,
        domain_name,
        tr.scenario_id,
        tr.get_scenario_name(),
        tr.iWrEn,
        tr.iRdEn,
        wWrAccepted,
        wRdAccepted,
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
    while (rRdTickCnt < run_count) begin
      bit wWrAccepted;
      bit wRdAccepted;

      mon2scb_mbox.get(tr);
      rSampleCnt++;
      wWrAccepted = tr.isWrSample && tr.iWrEn && !tr.preFull;
      wRdAccepted = tr.isRdSample && tr.iRdEn && !tr.preEmpty;

      if (tr.scenario_id inside {[1:5]}) begin
        rScenarioSampleCnt[tr.scenario_id]++;
      end
      if (tr.oFull) rFullSeenCnt++;
      if (tr.oEmpty) rEmptySeenCnt++;

      cov.sample(
        tr.isWrSample,
        tr.isRdSample,
        tr.scenario_id,
        tr.iWrEn,
        tr.iRdEn,
        wWrAccepted,
        wRdAccepted,
        tr.oFull,
        tr.oEmpty
      );

      if (tr.isWrSample) begin
        if (wWrAccepted) begin
          rModelQ.push_back(tr.iWData);
          rWrAcceptCnt++;
          if (tr.scenario_id inside {[1:5]}) rScenarioWrAcceptCnt[tr.scenario_id]++;
          rPassCnt++;
          $display("[SCB-WR] PASS t=%0t scenario=%s push=%0h depth=%0d",
            $time, tr.get_scenario_name(), tr.iWData, rModelQ.size());
        end
        else if (tr.iWrEn) begin
          rWrBlockCnt++;
          if (tr.scenario_id inside {[1:5]}) rScenarioWrBlockCnt[tr.scenario_id]++;
          $display("[SCB-WR] BLOCK t=%0t scenario=%s full_pre=%0b depth=%0d",
            $time, tr.get_scenario_name(), tr.preFull, rModelQ.size());
        end
      end

      if (tr.isRdSample) begin
        rRdTickCnt++;
        if (wRdAccepted) begin
          if (rModelQ.size() == 0) begin
            rFailCnt++;
            $display("[SCB-RD] FAIL t=%0t accepted read but model queue empty", $time);
          end
          else begin
            rExpectedRData = rModelQ.pop_front();
            rRdAcceptCnt++;
            if (tr.scenario_id inside {[1:5]}) rScenarioRdAcceptCnt[tr.scenario_id]++;
            if (tr.oRData !== rExpectedRData) begin
              rFailCnt++;
              $display("[SCB-RD] FAIL t=%0t scenario=%s exp=%0h got=%0h depth_after=%0d",
                $time, tr.get_scenario_name(), rExpectedRData, tr.oRData, rModelQ.size());
            end
            else begin
              rPassCnt++;
              $display("[SCB-RD] PASS t=%0t scenario=%s exp=%0h got=%0h depth_after=%0d",
                $time, tr.get_scenario_name(), rExpectedRData, tr.oRData, rModelQ.size());
            end
          end
        end
        else if (tr.iRdEn) begin
          rRdBlockCnt++;
          if (tr.scenario_id inside {[1:5]}) rScenarioRdBlockCnt[tr.scenario_id]++;
          $display("[SCB-RD] BLOCK t=%0t scenario=%s empty_pre=%0b depth=%0d",
            $time, tr.get_scenario_name(), tr.preEmpty, rModelQ.size());
        end
      end

      if (tr.isWrSample) begin
        write_trace("wr", wWrAccepted, wRdAccepted);
      end
      else begin
        write_trace("rd", wWrAccepted, wRdAccepted);
      end
    end

    $display("[SCB][SUMMARY] sample=%0d rd_tick=%0d pass=%0d fail=%0d wr_acc=%0d rd_acc=%0d wr_block=%0d rd_block=%0d depth_left=%0d full_seen=%0d empty_seen=%0d",
      rSampleCnt, rRdTickCnt, rPassCnt, rFailCnt, rWrAcceptCnt, rRdAcceptCnt, rWrBlockCnt, rRdBlockCnt,
      rModelQ.size(), rFullSeenCnt, rEmptySeenCnt);
    $display("[SCB][COVERAGE] functional_coverage=%0.2f%%", cov.cg_async_fifo.get_inst_coverage());
    if (rSummaryFd != 0) begin
      $fwrite(
        rSummaryFd,
        "async_fifo_src,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0.2f,PASS\n",
        rSampleCnt,
        rRdTickCnt,
        rPassCnt,
        rFailCnt,
        rWrAcceptCnt,
        rRdAcceptCnt,
        rWrBlockCnt,
        rRdBlockCnt,
        rModelQ.size(),
        rFullSeenCnt,
        rEmptySeenCnt,
        cov.cg_async_fifo.get_inst_coverage()
      );
    end
    foreach (rScenarioSampleCnt[idx]) begin
      $display("[SCB][SCENARIO] id=%0d name=%s sample=%0d wr_acc=%0d rd_acc=%0d wr_block=%0d rd_block=%0d",
        idx,
        async_fifo_transaction::scenario_name_by_id(idx),
        rScenarioSampleCnt[idx],
        rScenarioWrAcceptCnt[idx],
        rScenarioRdAcceptCnt[idx],
        rScenarioWrBlockCnt[idx],
        rScenarioRdBlockCnt[idx]
      );
      if (rScenarioFd != 0) begin
        $fwrite(
          rScenarioFd,
          "async_fifo_src,%0d,%s,%0d,%0d,%0d,%0d,%0d\n",
          idx,
          async_fifo_transaction::scenario_name_by_id(idx),
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
    $display("[SCB][PASS] async_fifo scoreboard completed without mismatches");
    if (rSummaryFd != 0) $fclose(rSummaryFd);
    if (rScenarioFd != 0) $fclose(rScenarioFd);
    if (rTraceFd != 0) $fclose(rTraceFd);
    -> scb_done_ev;
  endtask
endclass
