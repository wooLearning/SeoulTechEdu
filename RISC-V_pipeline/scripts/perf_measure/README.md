# Performance Measure Scripts

This folder is the single entry point for pipeline timing metrics and report generation.

## Main Files

- `pipeline_metrics.py`
  - top-level runner
  - can launch one or more Vivado timing flows
  - can regenerate the markdown metrics report
  - supports parallel variant execution with `--jobs`
- `run_pipeline_perf.tcl`
  - low-level Vivado batch flow
  - handles `synth|impl` and `default|bubble|hazard|test2`
- `pipeline_sim_metrics.json`
  - checked-in simulation metric seed used by the report generator
- `filelists/pipeline_sources.f`
  - source order for the pipeline RTL
- `perf_clock.xdc`
  - clock constraint used for timing measurement

## Recommended Usage

Generate the markdown report from the current output folders:

```bash
python3 scripts/perf_measure/pipeline_metrics.py report
```

Run post-implementation timing for all four variants and regenerate the report:

```bash
python3 scripts/perf_measure/pipeline_metrics.py run --modes impl --variants all --report
```

Run synthesis-only timing for `default` and `bubble` in parallel:

```bash
python3 scripts/perf_measure/pipeline_metrics.py run --modes synth --variants default bubble --jobs 2
```

Windows wrapper:

```bat
scripts\perf_measure\run_pipeline_metrics_win.bat run --modes impl --variants all --report
```

## Low-Level Vivado Usage

If you want to bypass the Python runner, the Tcl flow is still available directly:

```bash
vivado -mode batch -source scripts/perf_measure/run_pipeline_perf.tcl -tclargs impl default
vivado -mode batch -source scripts/perf_measure/run_pipeline_perf.tcl -tclargs impl bubble
vivado -mode batch -source scripts/perf_measure/run_pipeline_perf.tcl -tclargs impl hazard
vivado -mode batch -source scripts/perf_measure/run_pipeline_perf.tcl -tclargs impl test2
```

## Outputs

- timing/utilization reports:
  - `output/perf_measure/<variant>/<mode>/reports/*`
- routed checkpoint:
  - `output/perf_measure/<variant>/impl/top_routed.dcp`
- markdown report:
  - `md/performance_metrics_report.md`

## Path Policy

- Instruction-memory images are now selected with absolute-path constants from `src/InstrMemPathsPkg.sv`.
- The shared instruction ROM is `src/InstrRom.sv`.
- The active image is passed through `Top.P_INSTR_MEM_FILE`.
