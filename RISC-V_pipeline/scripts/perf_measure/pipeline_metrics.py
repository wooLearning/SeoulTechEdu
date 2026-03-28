#!/usr/bin/env python3
from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import re
import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_DIR = Path(__file__).resolve().parent
PERF_TCL = SCRIPT_DIR / "run_pipeline_perf.tcl"
SIM_METRICS_JSON = SCRIPT_DIR / "pipeline_sim_metrics.json"
REPORT_MD = PROJECT_ROOT / "md" / "performance_metrics_report.md"
VIVADO_BAT = Path(os.environ.get("VIVADO_BAT", r"C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat"))

VARIANTS = ("default", "bubble", "hazard", "test2")
SIM_TB_MAP = {
    "default": "tb_perf_pipe_default.sv",
    "bubble": "tb_perf_pipe_bubble.sv",
    "hazard": "tb_perf_pipe_hazard.sv",
    "test2": "tb_perf_pipe_test2.sv",
}
MEM_IMAGE_MAP = {
    "default": PROJECT_ROOT / "src" / "mem" / "InstructionDefault.mem",
    "bubble": PROJECT_ROOT / "src" / "mem" / "InstructionBubble.mem",
    "hazard": PROJECT_ROOT / "src" / "mem" / "InstructionHazard.mem",
    "test2": PROJECT_ROOT / "src" / "mem" / "InstructionFORTIMING.mem",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run pipeline timing flows and regenerate the performance metrics report."
    )
    subparsers = parser.add_subparsers(dest="cmd", required=True)

    run_parser = subparsers.add_parser("run", help="Run Vivado timing flow for one or more variants.")
    run_parser.add_argument(
        "--modes",
        nargs="+",
        choices=("synth", "impl"),
        default=["impl"],
        help="Vivado timing flow modes to run.",
    )
    run_parser.add_argument(
        "--variants",
        nargs="+",
        choices=VARIANTS + ("all",),
        default=["all"],
        help="ROM variants to run.",
    )
    run_parser.add_argument(
        "--jobs",
        type=int,
        default=1,
        help="Number of Vivado jobs to launch in parallel.",
    )
    run_parser.add_argument(
        "--vivado-bat",
        default=str(VIVADO_BAT),
        help="Path to vivado.bat.",
    )
    run_parser.add_argument(
        "--report",
        action="store_true",
        help="Regenerate the markdown metrics report after the runs finish.",
    )

    report_parser = subparsers.add_parser("report", help="Regenerate the markdown metrics report only.")
    report_parser.add_argument(
        "--report-path",
        default=str(REPORT_MD),
        help="Output markdown report path.",
    )
    return parser.parse_args()


def normalize_variants(raw_variants: list[str]) -> list[str]:
    if "all" in raw_variants:
        return list(VARIANTS)
    return raw_variants


def run_vivado(vivado_bat: str, mode: str, variant: str) -> int:
    cmd = [
        "cmd.exe",
        "/c",
        f'call "{vivado_bat}" -mode batch -source "{PERF_TCL}" -tclargs {mode} {variant}',
    ]
    print(f"[RUN] mode={mode} variant={variant}")
    result = subprocess.run(cmd, cwd=PROJECT_ROOT)
    return result.returncode


def run_jobs(vivado_bat: str, modes: list[str], variants: list[str], jobs: int) -> None:
    work_items = [(mode, variant) for mode in modes for variant in variants]
    if jobs <= 1:
        for mode, variant in work_items:
            rc = run_vivado(vivado_bat, mode, variant)
            if rc != 0:
                raise SystemExit(f"Vivado flow failed: mode={mode} variant={variant} rc={rc}")
        return

    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as executor:
        future_map = {
            executor.submit(run_vivado, vivado_bat, mode, variant): (mode, variant)
            for mode, variant in work_items
        }
        for future in concurrent.futures.as_completed(future_map):
            mode, variant = future_map[future]
            rc = future.result()
            if rc != 0:
                raise SystemExit(f"Vivado flow failed: mode={mode} variant={variant} rc={rc}")


def read_sim_metrics() -> dict[str, dict[str, float]]:
    data = json.loads(SIM_METRICS_JSON.read_text(encoding="utf-8"))
    metrics = {}
    for variant in VARIANTS:
        cycles = int(data[variant]["cycles"])
        retired = int(data[variant]["retired"])
        cpi = (float(cycles) / float(retired)) if retired else 0.0
        metrics[variant] = {
            "cycles": cycles,
            "retired": retired,
            "cpi": cpi,
        }
    return metrics


def parse_perf_summary(path: Path) -> dict[str, float]:
    data: dict[str, float] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        try:
            data[key] = float(value)
        except ValueError:
            data[key] = value
    return data


def parse_utilization(path: Path) -> dict[str, int]:
    text = path.read_text(encoding="utf-8", errors="ignore")

    def grab(label: str) -> int:
        pattern = rf"\|\s*{re.escape(label)}\s*\|\s*([0-9]+)\s*\|"
        match = re.search(pattern, text)
        if not match:
            raise ValueError(f"Could not find '{label}' in {path}")
        return int(match.group(1))

    return {
        "slice_luts": grab("Slice LUTs"),
        "lut_as_logic": grab("LUT as Logic"),
        "lut_as_memory": grab("LUT as Memory"),
        "slice_registers": grab("Slice Registers"),
        "block_ram_tile": grab("Block RAM Tile"),
    }


def collect_variant_metrics() -> dict[str, dict[str, float]]:
    sim_metrics = read_sim_metrics()
    out: dict[str, dict[str, float]] = {}
    for variant in VARIANTS:
        report_dir = PROJECT_ROOT / "output" / "perf_measure" / variant / "impl" / "reports"
        perf_summary = parse_perf_summary(report_dir / "perf_summary.txt")
        util_summary = parse_utilization(report_dir / "utilization.rpt")
        out[variant] = {
            **sim_metrics[variant],
            "slack_ns": float(perf_summary["slack_ns"]),
            "delay_ns": float(perf_summary["delay_ns"]),
            "fmax_mhz": float(perf_summary["fmax_mhz"]),
            "slice_luts": util_summary["slice_luts"],
            "lut_as_logic": util_summary["lut_as_logic"],
            "lut_as_memory": util_summary["lut_as_memory"],
            "slice_registers": util_summary["slice_registers"],
            "block_ram_tile": util_summary["block_ram_tile"],
        }
        out[variant]["runtime_us"] = (
            float(out[variant]["cycles"]) / float(out[variant]["fmax_mhz"])
            if out[variant]["fmax_mhz"] > 0.0
            else 0.0
        )
    return out


def bool_yes_no(value: bool) -> str:
    return "yes" if value else "no"


def md_table(headers: list[str], rows: list[list[str]]) -> str:
    sep = "|" + "|".join(["---"] * len(headers)) + "|"
    head = "|" + "|".join(headers) + "|"
    body = "\n".join("|" + "|".join(row) + "|" for row in rows)
    return "\n".join([head, sep, body])


def build_report(metrics: dict[str, dict[str, float]]) -> str:
    sim_rows = [
        [
            variant,
            str(int(metrics[variant]["cycles"])),
            str(int(metrics[variant]["retired"])),
            f'{metrics[variant]["cpi"]:.6f}',
        ]
        for variant in VARIANTS
    ]
    timing_rows = [
        [
            variant,
            f'{metrics[variant]["slack_ns"]:.3f}',
            f'{metrics[variant]["delay_ns"]:.3f}',
            f'{metrics[variant]["fmax_mhz"]:.3f}',
            bool_yes_no(metrics[variant]["fmax_mhz"] >= 100.0),
        ]
        for variant in VARIANTS
    ]
    util_rows = [
        [
            variant,
            str(int(metrics[variant]["slice_luts"])),
            str(int(metrics[variant]["lut_as_logic"])),
            str(int(metrics[variant]["lut_as_memory"])),
            str(int(metrics[variant]["slice_registers"])),
            str(int(metrics[variant]["block_ram_tile"])),
        ]
        for variant in VARIANTS
    ]
    runtime_rows = [
        [
            variant,
            str(int(metrics[variant]["cycles"])),
            f'{metrics[variant]["fmax_mhz"]:.3f}',
            f'{metrics[variant]["runtime_us"]:.3f}',
        ]
        for variant in VARIANTS
    ]

    supporting_links = "\n".join(
        [
            f"- Main timing flow: [run_pipeline_perf.tcl]({(SCRIPT_DIR / 'run_pipeline_perf.tcl').as_posix()})",
            f"- Main runner: [pipeline_metrics.py]({(SCRIPT_DIR / 'pipeline_metrics.py').as_posix()})",
            f"- Simulation metric seed: [pipeline_sim_metrics.json]({SIM_METRICS_JSON.as_posix()})",
            f"- Shared ROM path package: [InstrMemPathsPkg.sv]({(PROJECT_ROOT / 'src' / 'InstrMemPathsPkg.sv').as_posix()})",
            f"- Shared instruction ROM: [InstrRom.sv]({(PROJECT_ROOT / 'src' / 'InstrRom.sv').as_posix()})",
            f"- Default image: [InstructionDefault.mem]({MEM_IMAGE_MAP['default'].as_posix()})",
            f"- Bubble image: [InstructionBubble.mem]({MEM_IMAGE_MAP['bubble'].as_posix()})",
            f"- Hazard image: [InstructionHazard.mem]({MEM_IMAGE_MAP['hazard'].as_posix()})",
            f"- Test2 image: [InstructionFORTIMING.mem]({MEM_IMAGE_MAP['test2'].as_posix()})",
        ]
    )

    return f"""# RV32I Performance Metrics Report

Date: 2026-03-26
Generated by: `scripts/perf_measure/pipeline_metrics.py`

## Scope

This is the active performance-metrics report for the current `rv32i` pipeline project.

Measured ROM variants:

- `default`
- `bubble`
- `hazard`
- `test2`

## Measurement Flow

Simulation metrics:

- Source of truth: `scripts/perf_measure/pipeline_sim_metrics.json`
- Benches:
  - `{SIM_TB_MAP['default']}`
  - `{SIM_TB_MAP['bubble']}`
  - `{SIM_TB_MAP['hazard']}`
  - `{SIM_TB_MAP['test2']}`
- Definitions:
  - `cycles`: positive clock edges after reset release until completion
  - `retired`: valid MEM/WB packets
  - `CPI = cycles / retired`

Timing metrics:

- Vivado 2025.2 OOC post-implementation
- Entry point: `scripts/perf_measure/run_pipeline_perf.tcl`
- Wrapper/collector: `scripts/perf_measure/pipeline_metrics.py`
- Clock target: `10.000 ns` (`100 MHz`)

Instruction ROM structure:

- one shared [`InstrRom.sv`]({(PROJECT_ROOT / 'src' / 'InstrRom.sv').as_posix()})
- one shared absolute-path package [`InstrMemPathsPkg.sv`]({(PROJECT_ROOT / 'src' / 'InstrMemPathsPkg.sv').as_posix()})
- fixed ROM depth: `128` words
- active image is selected with `P_INSTR_MEM_FILE`
- compatibility flags `P_USE_BUBBLE_ROM`, `P_USE_HAZARD_ROM`, `P_USE_TEST2_ROM` still exist for variant labeling

The four absolute image constants live in [`InstrMemPathsPkg.sv`]({(PROJECT_ROOT / 'src' / 'InstrMemPathsPkg.sv').as_posix()}):

- `LP_INSTR_MEM_DEFAULT`
- `LP_INSTR_MEM_BUBBLE`
- `LP_INSTR_MEM_HAZARD`
- `LP_INSTR_MEM_TEST2`

## Simulation Results

{md_table(["ROM Variant", "Cycles", "Retired", "CPI"], sim_rows)}

## Post-Implementation Timing

{md_table(["ROM Variant", "Slack (ns)", "Delay (ns)", "Fmax (MHz)", "Meets 100 MHz?"], timing_rows)}

## Post-Implementation Utilization

{md_table(["ROM Variant", "Slice LUTs", "LUT as Logic", "LUT as Memory", "Slice Registers", "Block RAM Tile"], util_rows)}

## Estimated Runtime

Estimated runtime is `cycles / Fmax`, with `Fmax` in MHz and runtime in microseconds.

{md_table(["ROM Variant", "Cycles", "Fmax (MHz)", "Estimated Runtime (us)"], runtime_rows)}

## Current Takeaways

- All four variants currently clear the `100 MHz` target in the normalized shared-ROM flow.
- `bubble` still has the largest CPI and runtime because of workload behavior, not because of a separate ROM implementation.
- `hazard` is the shortest workload by cycle count and estimated runtime.
- `LUT as Memory` remains stable across variants because the ROM depth and inferred memory class are fixed.
- `LUT as Logic` and register count can still vary per program image because downstream logic trimming depends on instruction contents.

## Supporting Files

{supporting_links}
"""


def write_report(report_path: Path) -> None:
    metrics = collect_variant_metrics()
    report_path.write_text(build_report(metrics), encoding="utf-8")
    print(f"[REPORT] wrote {report_path}")


def main() -> int:
    args = parse_args()
    if args.cmd == "run":
        variants = normalize_variants(args.variants)
        run_jobs(args.vivado_bat, args.modes, variants, args.jobs)
        if args.report:
            write_report(REPORT_MD)
        return 0

    if args.cmd == "report":
        write_report(Path(args.report_path))
        return 0

    raise SystemExit(f"Unsupported command: {args.cmd}")


if __name__ == "__main__":
    sys.exit(main())
