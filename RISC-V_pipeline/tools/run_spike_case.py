#!/usr/bin/env python3
"""
Build, simulate, report, and archive one Spike verification case.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def run_cmd(project_root: Path, command: str) -> None:
    print(f"[CMD] {command}")
    subprocess.run(["cmd.exe", "/c", command], cwd=project_root, check=True)


def run_python(project_root: Path, script_rel: str, extra_args: list[str]) -> None:
    command = [sys.executable, str(project_root / script_rel), *extra_args]
    print(f"[PY ] {' '.join(command)}")
    subprocess.run(command, cwd=project_root, check=True)


def main() -> None:
    project_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description="Run one RV32I Spike case and publish archived outputs")
    parser.add_argument("--case-name", required=True, help="Case name, for example test_top or bubble_sort")
    parser.add_argument("--csv", required=True, help="Spike CSV path")
    parser.add_argument(
        "--word-check",
        action="append",
        default=[],
        help="Optional final memory expectation as ADDR=VALUE. May be used twice.",
    )
    args = parser.parse_args()

    csv_path = Path(args.csv)
    run_python(
        project_root,
        "tools/build_spike_artifacts.py",
        ["--csv", str(csv_path), *sum([["--word-check", item] for item in args.word_check[:2]], [])],
    )
    run_cmd(project_root, 'xvlog -prj tb\\pipeline\\tb_top_spike_vlog.prj -log tb\\pipeline\\xvlog_tb_top_spike.log')
    run_cmd(project_root, 'xelab -debug typical -s tb_top_spike_behav xil_defaultlib.tb_top_spike xil_defaultlib.glbl -log tb\\pipeline\\xelab_tb_top_spike.log')
    run_cmd(project_root, 'xsim tb_top_spike_behav -log tb\\pipeline\\xsim_tb_top_spike.log -runall')
    run_cmd(project_root, 'xvlog -prj tb\\Top_tb\\tb_top_class_vlog.prj -log tb\\Top_tb\\xvlog_tb_top_class.log')
    run_cmd(project_root, 'xelab -debug typical -s tb_top_class_behav xil_defaultlib.TbTop xil_defaultlib.glbl -log tb\\Top_tb\\xelab_tb_top_class.log')
    run_cmd(project_root, 'xsim tb_top_class_behav -log tb\\Top_tb\\xsim_tb_top_class.log -runall')
    run_python(project_root, "tools/rv32i_spike_report.py", [])
    run_python(
        project_root,
        "tools/publish_spike_case.py",
        ["--case-name", args.case_name, "--csv", str(csv_path)],
    )
    print(f"[INFO] completed case : {args.case_name}")


if __name__ == "__main__":
    main()
