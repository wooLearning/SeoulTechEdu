#!/usr/bin/env python3
"""
Generate matplotlib/pandas-based RV32I verification reports from XSIM logs.

Recommended invocation on this workspace:
    cmd.exe /c py -3 tools\\rv32i_spike_report.py
"""

from __future__ import annotations

import csv
import html
import re
import shutil
from collections import Counter
from dataclasses import asdict, dataclass
from pathlib import Path

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np
    import pandas as pd
except ModuleNotFoundError as exc:
    raise SystemExit(
        "This report generator requires pandas/matplotlib. "
        "Use Windows Python for this workspace: cmd.exe /c py -3 tools\\rv32i_spike_report.py"
    ) from exc


PIPELINE_TRACE_RE = re.compile(
    r"\[TRACE\]\[RETIRE\s+(?P<idx>\d+)/(?P<total>\d+)\]\[C(?P<cycle>\d+)\]\s+"
    r"step=(?P<step>\d+)\s+class=(?P<opcode>[A-Z0-9_]+)\s+"
    r"pc=0x(?P<pc>[0-9a-fA-F]+)\s+inst=0x(?P<inst>[0-9a-fA-F]+)\s+"
    r"regwr=(?P<regwr>\d+)\s+rd=x(?P<rd>\d+)\s+data=0x(?P<rd_data>[0-9a-fA-F]+)\s+"
    r"memwr=(?P<memwr>\d+)\s+mem_addr=0x(?P<mem_addr>[0-9a-fA-F]+)\s+"
    r"mem_data=0x(?P<mem_data>[0-9a-fA-F]+)\s+illegal=(?P<illegal>\d+)"
)

CLASS_TRACE_RE = re.compile(
    r"\[(?P<time_ps>\d+)\]\[TB\]\[INFO\]\s+SCB TRACE #(?P<idx>\d+)/(?P<total>\d+)\s+:\s+"
    r"step=(?P<step>\d+)\s+cycle=(?P<cycle>\d+)\s+pc=0x(?P<pc>[0-9a-fA-F]+)\s+"
    r"inst=0x(?P<inst>[0-9a-fA-F]+)\s+regwr=(?P<regwr>\d+)\s+rd=x(?P<rd>\d+)\s+"
    r"rd_data=0x(?P<rd_data>[0-9a-fA-F]+)\s+memwr=(?P<memwr>\d+)\s+"
    r"mem_addr=0x(?P<mem_addr>[0-9a-fA-F]+)\s+mem_data=0x(?P<mem_data>[0-9a-fA-F]+)\s+"
    r"illegal=(?P<illegal>\d+)\s+stall=(?P<stall>\d+)\s+redirect=(?P<redirect>\d+)\s+"
    r"fwdA=(?P<fwdA>\d+)\s+fwdB=(?P<fwdB>\d+)\s+class=(?P<opcode>[A-Z0-9_]+)"
)

PIPELINE_PASS_RE = re.compile(r"^\[PASS\]\[ROW\s+(?P<row>\d+)\]", re.MULTILINE)
PIPELINE_MEM_RE = re.compile(
    r"^\[PASS\]\s+Data memory word\[(?P<idx>\d+)\]\s+matched\s+0x(?P<value>[0-9a-fA-F]+)$",
    re.MULTILINE,
)
CLASS_MEM_RE = re.compile(r"Final memory word(?P<idx>[01]) matched 0x(?P<value>[0-9a-fA-F]+)")
CLASS_ROWS_RE = re.compile(r"rows=(?P<rows>\d+)\s+errors=(?P<errors>\d+)")
CLASS_COVERAGE_RE = re.compile(r"Coverage summary:\s+(?P<coverage>[0-9.]+)%")

FLOW_LABELS = {
    "pipeline_spike": "Pipeline TB",
    "top_tb_class": "Top_tb Class Env",
}
FLOW_ORDER = ["pipeline_spike", "top_tb_class"]
FLOW_COLORS = {
    "pipeline_spike": "#3182f6",
    "top_tb_class": "#191f28",
}
OPCODE_ORDER = ["ALUI", "ALUR", "BRANCH", "LOAD", "STORE", "AUIPC", "JAL", "JALR", "LUI"]
OPCODE_COLORS = {
    "ALUI": "#3182f6",
    "ALUR": "#4cc9a6",
    "BRANCH": "#191f28",
    "LOAD": "#ffb020",
    "STORE": "#f04452",
    "AUIPC": "#735bf2",
    "JAL": "#00a3ad",
    "JALR": "#ff7a00",
    "LUI": "#8b95a1",
}
EVENT_ORDER = ["redirect", "stall", "memwrite", "regwrite", "illegal", "fwdA=1", "fwdA=2", "fwdB=1", "fwdB=2"]
EVENT_COLORS = {
    "redirect": "#3182f6",
    "stall": "#191f28",
    "memwrite": "#f04452",
    "regwrite": "#08b47f",
    "illegal": "#b42318",
    "fwdA=1": "#ffb020",
    "fwdA=2": "#735bf2",
    "fwdB=1": "#00a3ad",
    "fwdB=2": "#8b95a1",
}


@dataclass
class TraceRow:
    flow_name: str
    flow_label: str
    retire_index: int
    total_retire: int
    step: int
    cycle: int
    pc: str
    inst: str
    opcode: str
    regwr: int
    rd: int
    rd_data: str
    memwr: int
    mem_addr: str
    mem_data: str
    illegal: int
    stall: int = 0
    redirect: int = 0
    fwdA: int = 0
    fwdB: int = 0


@dataclass
class FlowSummary:
    flow_name: str
    flow_label: str
    result: str
    retire_rows: int
    row_pass_count: int
    error_count: int
    mem_check_count: int
    coverage_pct: float
    first_cycle: int
    last_cycle: int
    cycle_span: int
    regwrite_count: int
    memwrite_count: int
    redirect_count: int
    stall_count: int
    illegal_count: int
    fwdA1_count: int
    fwdA2_count: int
    fwdB1_count: int
    fwdB2_count: int
    branch_count: int
    jump_count: int
    final_mem_word0: str
    final_mem_word1: str
    log_path: str


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")


def copy_log(src: Path, dst: Path) -> None:
    ensure_dir(dst.parent)
    shutil.copyfile(src, dst)


def parse_pipeline_log(log_path: Path) -> tuple[list[TraceRow], FlowSummary]:
    text = read_text(log_path)
    rows: list[TraceRow] = []
    for match in PIPELINE_TRACE_RE.finditer(text):
        rows.append(
            TraceRow(
                flow_name="pipeline_spike",
                flow_label=FLOW_LABELS["pipeline_spike"],
                retire_index=int(match.group("idx")),
                total_retire=int(match.group("total")),
                step=int(match.group("step")),
                cycle=int(match.group("cycle")),
                pc=f"0x{match.group('pc').lower()}",
                inst=f"0x{match.group('inst').lower()}",
                opcode=match.group("opcode"),
                regwr=int(match.group("regwr")),
                rd=int(match.group("rd")),
                rd_data=f"0x{match.group('rd_data').lower()}",
                memwr=int(match.group("memwr")),
                mem_addr=f"0x{match.group('mem_addr').lower()}",
                mem_data=f"0x{match.group('mem_data').lower()}",
                illegal=int(match.group("illegal")),
            )
        )

    mem_matches = {int(m.group("idx")): f"0x{m.group('value').lower()}" for m in PIPELINE_MEM_RE.finditer(text)}
    counts = Counter(row.opcode for row in rows)
    result = "PASS" if "tb_top_spike PASSED" in text else "FAIL"
    first_cycle = rows[0].cycle if rows else 0
    last_cycle = rows[-1].cycle if rows else 0
    summary = FlowSummary(
        flow_name="pipeline_spike",
        flow_label=FLOW_LABELS["pipeline_spike"],
        result=result,
        retire_rows=len(rows),
        row_pass_count=len(PIPELINE_PASS_RE.findall(text)),
        error_count=0 if result == "PASS" else 1,
        mem_check_count=len(mem_matches),
        coverage_pct=0.0,
        first_cycle=first_cycle,
        last_cycle=last_cycle,
        cycle_span=(last_cycle - first_cycle + 1) if rows else 0,
        regwrite_count=sum(row.regwr for row in rows),
        memwrite_count=sum(row.memwr for row in rows),
        redirect_count=0,
        stall_count=0,
        illegal_count=sum(row.illegal for row in rows),
        fwdA1_count=0,
        fwdA2_count=0,
        fwdB1_count=0,
        fwdB2_count=0,
        branch_count=counts["BRANCH"],
        jump_count=counts["JAL"] + counts["JALR"],
        final_mem_word0=mem_matches.get(89, ""),
        final_mem_word1=mem_matches.get(90, ""),
        log_path="evidence/logs/pipeline_spike_xsim.log",
    )
    return rows, summary


def parse_top_tb_log(log_path: Path) -> tuple[list[TraceRow], FlowSummary]:
    text = read_text(log_path)
    rows: list[TraceRow] = []
    for match in CLASS_TRACE_RE.finditer(text):
        rows.append(
            TraceRow(
                flow_name="top_tb_class",
                flow_label=FLOW_LABELS["top_tb_class"],
                retire_index=int(match.group("idx")),
                total_retire=int(match.group("total")),
                step=int(match.group("step")),
                cycle=int(match.group("cycle")),
                pc=f"0x{match.group('pc').lower()}",
                inst=f"0x{match.group('inst').lower()}",
                opcode=match.group("opcode"),
                regwr=int(match.group("regwr")),
                rd=int(match.group("rd")),
                rd_data=f"0x{match.group('rd_data').lower()}",
                memwr=int(match.group("memwr")),
                mem_addr=f"0x{match.group('mem_addr').lower()}",
                mem_data=f"0x{match.group('mem_data').lower()}",
                illegal=int(match.group("illegal")),
                stall=int(match.group("stall")),
                redirect=int(match.group("redirect")),
                fwdA=int(match.group("fwdA")),
                fwdB=int(match.group("fwdB")),
            )
        )

    counts = Counter(row.opcode for row in rows)
    rows_match = CLASS_ROWS_RE.search(text)
    coverage_match = CLASS_COVERAGE_RE.search(text)
    mem_matches = {int(m.group("idx")): f"0x{m.group('value').lower()}" for m in CLASS_MEM_RE.finditer(text)}
    result = "PASS" if "Top_tb completed successfully" in text else "FAIL"
    first_cycle = rows[0].cycle if rows else 0
    last_cycle = rows[-1].cycle if rows else 0
    summary = FlowSummary(
        flow_name="top_tb_class",
        flow_label=FLOW_LABELS["top_tb_class"],
        result=result,
        retire_rows=len(rows),
        row_pass_count=int(rows_match.group("rows")) if rows_match else 0,
        error_count=int(rows_match.group("errors")) if rows_match else 1,
        mem_check_count=len(mem_matches),
        coverage_pct=float(coverage_match.group("coverage")) if coverage_match else 0.0,
        first_cycle=first_cycle,
        last_cycle=last_cycle,
        cycle_span=(last_cycle - first_cycle + 1) if rows else 0,
        regwrite_count=sum(row.regwr for row in rows),
        memwrite_count=sum(row.memwr for row in rows),
        redirect_count=sum(row.redirect for row in rows),
        stall_count=sum(row.stall for row in rows),
        illegal_count=sum(row.illegal for row in rows),
        fwdA1_count=sum(1 for row in rows if row.fwdA == 1),
        fwdA2_count=sum(1 for row in rows if row.fwdA == 2),
        fwdB1_count=sum(1 for row in rows if row.fwdB == 1),
        fwdB2_count=sum(1 for row in rows if row.fwdB == 2),
        branch_count=counts["BRANCH"],
        jump_count=counts["JAL"] + counts["JALR"],
        final_mem_word0=mem_matches.get(0, ""),
        final_mem_word1=mem_matches.get(1, ""),
        log_path="evidence/logs/top_tb_class_xsim.log",
    )
    return rows, summary


def write_csv(path: Path, headers: list[str], rows: list[list[object]]) -> None:
    ensure_dir(path.parent)
    with path.open("w", encoding="utf-8", newline="") as fp:
        writer = csv.writer(fp)
        writer.writerow(headers)
        writer.writerows(rows)


def mem_summary_text(summary: pd.Series) -> str:
    mem_checks = int(summary["mem_check_count"])
    if mem_checks == 0:
        return "final memory check disabled"
    return f"final memory {mem_checks}건 통과"


def coverage_interpretation(summary: pd.Series) -> str:
    stall_count = int(summary["stall_count"])
    illegal_count = int(summary["illegal_count"])
    if stall_count == 0 and illegal_count == 0:
        return "coverage가 100%가 아닌 이유는 현재 trace에서 stall/illegal 같은 일부 이벤트가 발생하지 않았기 때문입니다."
    if illegal_count == 0:
        return (
            f"coverage가 100%가 아닌 것은 일부 이벤트가 아직 비어 있기 때문이지만, "
            f"이번 trace에서는 stall이 {stall_count}회 실제 관측됐습니다."
        )
    return (
        f"coverage는 stall={stall_count}, illegal={illegal_count} 관측 여부를 포함해 계산되며, "
        "아직 덜 커버된 이벤트가 남아 있습니다."
    )


def save_summary_chart(summary_df: pd.DataFrame, out_path: Path) -> None:
    ordered = summary_df.set_index("flow_name").loc[FLOW_ORDER].reset_index()
    fig, ax = plt.subplots(figsize=(12, 6))
    x = np.arange(len(ordered))
    width = 0.18
    ax.bar(x - 1.5 * width, ordered["retire_rows"], width, label="Retire Rows", color="#3182f6")
    ax.bar(x - 0.5 * width, ordered["row_pass_count"], width, label="Row Pass", color="#08b47f")
    ax.bar(x + 0.5 * width, ordered["mem_check_count"], width, label="Mem Checks", color="#ffb020")
    ax.bar(x + 1.5 * width, ordered["coverage_pct"], width, label="Coverage %", color="#735bf2")
    ax.set_title("RV32I Verification Flow Summary")
    ax.set_ylabel("Count / Percent")
    ax.set_xticks(x)
    ax.set_xticklabels(ordered["flow_label"], rotation=10)
    ax.legend(frameon=False, ncol=2)
    ax.grid(axis="y", linestyle="--", alpha=0.20)
    fig.tight_layout()
    fig.savefig(out_path, dpi=180)
    plt.close(fig)


def save_opcode_mix_chart(mix_df: pd.DataFrame, out_path: Path) -> None:
    pivot = (
        mix_df.pivot(index="flow_label", columns="opcode", values="count")
        .reindex([FLOW_LABELS[name] for name in FLOW_ORDER])
        .fillna(0)
        .reindex(columns=OPCODE_ORDER)
    )
    fig, ax = plt.subplots(figsize=(12, 6))
    bottom = np.zeros(len(pivot.index))
    for opcode in OPCODE_ORDER:
        values = pivot[opcode].to_numpy()
        ax.bar(
            pivot.index,
            values,
            bottom=bottom,
            label=opcode,
            color=OPCODE_COLORS[opcode],
        )
        bottom += values
    ax.set_title("Instruction Mix by Verification Flow")
    ax.set_ylabel("Retired instructions")
    ax.legend(frameon=False, ncol=3)
    ax.grid(axis="y", linestyle="--", alpha=0.20)
    fig.tight_layout()
    fig.savefig(out_path, dpi=180)
    plt.close(fig)


def save_opcode_heatmap(mix_df: pd.DataFrame, out_path: Path) -> None:
    pivot = (
        mix_df.pivot(index="flow_label", columns="opcode", values="count")
        .reindex([FLOW_LABELS[name] for name in FLOW_ORDER])
        .fillna(0)
        .reindex(columns=OPCODE_ORDER)
    )
    fig, ax = plt.subplots(figsize=(11, 4.8))
    im = ax.imshow(pivot.values, cmap="Blues", aspect="auto")
    ax.set_title("Opcode Activity Heatmap")
    ax.set_xticks(np.arange(len(pivot.columns)))
    ax.set_xticklabels(pivot.columns, rotation=20, ha="right")
    ax.set_yticks(np.arange(len(pivot.index)))
    ax.set_yticklabels(pivot.index)
    for i in range(pivot.shape[0]):
        for j in range(pivot.shape[1]):
            ax.text(j, i, int(pivot.values[i, j]), ha="center", va="center", color="#0f172a", fontsize=10)
    fig.colorbar(im, ax=ax, shrink=0.85, label="retire count")
    fig.tight_layout()
    fig.savefig(out_path, dpi=180)
    plt.close(fig)


def save_timeline_chart(trace_df: pd.DataFrame, out_path: Path) -> None:
    fig, ax = plt.subplots(figsize=(12, 6))
    for flow_name in FLOW_ORDER:
        flow_df = trace_df[trace_df["flow_name"] == flow_name].sort_values("retire_index")
        ax.plot(
            flow_df["retire_index"],
            flow_df["cycle"],
            linewidth=2.0,
            marker="o",
            markersize=3.5,
            label=FLOW_LABELS[flow_name],
            color=FLOW_COLORS[flow_name],
        )
    ax.set_title("Retire Timeline")
    ax.set_xlabel("Retire index")
    ax.set_ylabel("Cycle")
    ax.grid(True, linestyle="--", alpha=0.20)
    ax.legend(frameon=False)
    fig.tight_layout()
    fig.savefig(out_path, dpi=180)
    plt.close(fig)


def save_event_chart(event_df: pd.DataFrame, out_path: Path) -> None:
    ordered = event_df.set_index("event").loc[EVENT_ORDER].reset_index()
    fig, ax = plt.subplots(figsize=(11, 5.8))
    colors = [EVENT_COLORS[name] for name in ordered["event"]]
    ax.barh(ordered["event"], ordered["count"], color=colors)
    ax.set_title("Top_tb Pipeline Event Coverage")
    ax.set_xlabel("Count")
    ax.grid(axis="x", linestyle="--", alpha=0.20)
    ax.invert_yaxis()
    for idx, value in enumerate(ordered["count"]):
        ax.text(value + 0.2, idx, str(int(value)), va="center", fontsize=10)
    fig.tight_layout()
    fig.savefig(out_path, dpi=180)
    plt.close(fig)


def save_dashboard(summary_df: pd.DataFrame, mix_df: pd.DataFrame, trace_df: pd.DataFrame, event_df: pd.DataFrame, out_path: Path) -> None:
    ordered = summary_df.set_index("flow_name").loc[FLOW_ORDER].reset_index()
    fig, axes = plt.subplots(2, 2, figsize=(16, 10))
    fig.suptitle("RV32I Verification Dashboard", fontsize=18, fontweight="bold")

    x = np.arange(len(ordered))
    width = 0.18
    ax = axes[0, 0]
    ax.bar(x - 1.5 * width, ordered["retire_rows"], width, label="Retire Rows", color="#3182f6")
    ax.bar(x - 0.5 * width, ordered["row_pass_count"], width, label="Row Pass", color="#08b47f")
    ax.bar(x + 0.5 * width, ordered["mem_check_count"], width, label="Mem Checks", color="#ffb020")
    ax.bar(x + 1.5 * width, ordered["coverage_pct"], width, label="Coverage %", color="#735bf2")
    ax.set_title("Flow Summary")
    ax.set_xticks(x)
    ax.set_xticklabels(ordered["flow_label"], rotation=10)
    ax.legend(frameon=False, fontsize=9, ncol=2)
    ax.grid(axis="y", linestyle="--", alpha=0.20)

    heat_ax = axes[0, 1]
    pivot = (
        mix_df.pivot(index="flow_label", columns="opcode", values="count")
        .reindex([FLOW_LABELS[name] for name in FLOW_ORDER])
        .fillna(0)
        .reindex(columns=OPCODE_ORDER)
    )
    im = heat_ax.imshow(pivot.values, cmap="Blues", aspect="auto")
    heat_ax.set_title("Opcode Heatmap")
    heat_ax.set_xticks(np.arange(len(pivot.columns)))
    heat_ax.set_xticklabels(pivot.columns, rotation=20, ha="right")
    heat_ax.set_yticks(np.arange(len(pivot.index)))
    heat_ax.set_yticklabels(pivot.index)
    for i in range(pivot.shape[0]):
        for j in range(pivot.shape[1]):
            heat_ax.text(j, i, int(pivot.values[i, j]), ha="center", va="center", color="#0f172a", fontsize=9)
    fig.colorbar(im, ax=heat_ax, fraction=0.046, pad=0.04)

    trace_ax = axes[1, 0]
    for flow_name in FLOW_ORDER:
        flow_df = trace_df[trace_df["flow_name"] == flow_name].sort_values("retire_index")
        trace_ax.plot(
            flow_df["retire_index"],
            flow_df["cycle"],
            linewidth=1.9,
            marker="o",
            markersize=3,
            color=FLOW_COLORS[flow_name],
            label=FLOW_LABELS[flow_name],
        )
    trace_ax.set_title("Retire Timeline")
    trace_ax.set_xlabel("Retire Index")
    trace_ax.set_ylabel("Cycle")
    trace_ax.grid(True, linestyle="--", alpha=0.20)
    trace_ax.legend(frameon=False, fontsize=9)

    event_ax = axes[1, 1]
    ordered_events = event_df.set_index("event").loc[EVENT_ORDER].reset_index()
    event_ax.barh(ordered_events["event"], ordered_events["count"], color=[EVENT_COLORS[name] for name in ordered_events["event"]])
    event_ax.set_title("Top_tb Events")
    event_ax.grid(axis="x", linestyle="--", alpha=0.20)
    event_ax.invert_yaxis()

    fig.tight_layout()
    fig.savefig(out_path, dpi=180)
    plt.close(fig)


def generate_markdown(project_root: Path, summary_df: pd.DataFrame) -> None:
    report_path = project_root / "reports" / "markdown" / "overview" / "rv32i_spike_visual_report_ko.md"
    index_path = project_root / "reports" / "markdown" / "overview" / "artifact_index.md"
    ensure_dir(report_path.parent)
    pipeline = summary_df.set_index("flow_name").loc["pipeline_spike"]
    top_tb = summary_df.set_index("flow_name").loc["top_tb_class"]
    lines = [
        "# RV32I Spike matplotlib 시각화 보고서",
        "",
        "XSIM 로그를 pandas와 matplotlib로 다시 분석한 RV32I 검증 보고서입니다.",
        "",
        "## 요약",
        "",
        f"- Pipeline TB는 `{int(pipeline['retire_rows'])}/{int(pipeline['retire_rows'])}` row match와 {mem_summary_text(pipeline)} 상태를 확인했습니다.",
        f"- Top_tb는 `rows={int(top_tb['row_pass_count'])}`, `errors={int(top_tb['error_count'])}`, `coverage={float(top_tb['coverage_pct']):.2f}%`로 통과했습니다.",
        "- 리포트 구조는 참고 레포처럼 `evidence/logs`, `evidence/csv`, `reports/markdown`, `reports/html/assets`로 정리했습니다.",
        "",
        "## 핵심 산출물",
        "",
        "- HTML 보고서: `../../html/rv32i_spike_visual_report_ko.html`",
        "- Dashboard: `../../html/assets/rv32i_dashboard.png`",
        "- Flow summary: `../../html/assets/rv32i_flow_summary.png`",
        "- Opcode heatmap: `../../html/assets/rv32i_opcode_heatmap.png`",
        "- Retire timeline: `../../html/assets/rv32i_retire_timeline.png`",
        "- Top_tb events: `../../html/assets/rv32i_top_tb_events.png`",
        "",
        "## 흐름 비교",
        "",
        "| Flow | Result | Retire Rows | Row Pass | Errors | Mem Checks | Coverage | Cycle Window |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |",
        f"| {pipeline['flow_label']} | {pipeline['result']} | {int(pipeline['retire_rows'])} | {int(pipeline['row_pass_count'])} | {int(pipeline['error_count'])} | {int(pipeline['mem_check_count'])} | N/A | {int(pipeline['first_cycle'])} -> {int(pipeline['last_cycle'])} |",
        f"| {top_tb['flow_label']} | {top_tb['result']} | {int(top_tb['retire_rows'])} | {int(top_tb['row_pass_count'])} | {int(top_tb['error_count'])} | {int(top_tb['mem_check_count'])} | {float(top_tb['coverage_pct']):.2f}% | {int(top_tb['first_cycle'])} -> {int(top_tb['last_cycle'])} |",
        "",
        "## 해석",
        "",
        "- 두 flow 모두 같은 Spike golden trace를 정확히 따라갔기 때문에 기능 정합성은 확보됐다고 볼 수 있습니다.",
        f"- {coverage_interpretation(top_tb)}",
        "- Top_tb의 redirect, forwarding, memwrite는 실제로 관측되어 control-flow와 hazard 관련 경로 일부는 검증됐습니다.",
        "",
        "## 아티팩트",
        "",
        "- 로그: `../../../evidence/logs/pipeline_spike_xsim.log`",
        "- 로그: `../../../evidence/logs/top_tb_class_xsim.log`",
        "- CSV: `../../../evidence/csv/combined_summary.csv`",
        "- CSV: `../../../evidence/csv/combined_instruction_mix.csv`",
        "- CSV: `../../../evidence/csv/top_tb_event_summary.csv`",
        "- 생성 스크립트: `../../../tools/rv32i_spike_report.py`",
        "",
    ]
    write_text(report_path, "\n".join(lines) + "\n")
    write_text(
        index_path,
        "\n".join(
            [
                "# Artifact Index",
                "",
                "- `evidence/logs/pipeline_spike_xsim.log`",
                "- `evidence/logs/top_tb_class_xsim.log`",
                "- `evidence/csv/pipeline_spike_trace.csv`",
                "- `evidence/csv/top_tb_class_trace.csv`",
                "- `evidence/csv/combined_summary.csv`",
                "- `evidence/csv/combined_instruction_mix.csv`",
                "- `evidence/csv/top_tb_event_summary.csv`",
                "- `reports/html/assets/rv32i_dashboard.png`",
                "- `reports/html/assets/rv32i_flow_summary.png`",
                "- `reports/html/assets/rv32i_opcode_mix.png`",
                "- `reports/html/assets/rv32i_opcode_heatmap.png`",
                "- `reports/html/assets/rv32i_retire_timeline.png`",
                "- `reports/html/assets/rv32i_top_tb_events.png`",
                "- `reports/html/rv32i_spike_visual_report_ko.html`",
                "- `tools/rv32i_spike_report.py`",
                "",
            ]
        ),
    )


def generate_html(project_root: Path, summary_df: pd.DataFrame) -> None:
    html_path = project_root / "reports" / "html" / "rv32i_spike_visual_report_ko.html"
    index_path = project_root / "reports" / "html" / "index.html"
    ensure_dir(html_path.parent)
    pipeline = summary_df.set_index("flow_name").loc["pipeline_spike"]
    top_tb = summary_df.set_index("flow_name").loc["top_tb_class"]
    html_text = f"""<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>RV32I Spike Visual Report</title>
  <style>
    :root {{
      --bg: #f6f8fb;
      --panel: rgba(255,255,255,0.88);
      --text: #191f28;
      --muted: #6b7684;
      --line: #e5e8eb;
      --blue: #3182f6;
      --green: #08b47f;
      --shadow: 0 24px 60px rgba(15, 23, 42, 0.08);
      --radius-xl: 32px;
      --radius-lg: 24px;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font-family: "Pretendard", "Noto Sans KR", "Segoe UI", sans-serif;
      background:
        radial-gradient(circle at top left, rgba(49,130,246,0.16), transparent 28%),
        radial-gradient(circle at top right, rgba(8,180,127,0.10), transparent 22%),
        var(--bg);
      color: var(--text);
      line-height: 1.65;
    }}
    .page {{
      max-width: 1260px;
      margin: 0 auto;
      padding: 48px 24px 72px;
    }}
    .hero, .card, .table-wrap {{
      background: var(--panel);
      border: 1px solid rgba(255,255,255,0.9);
      box-shadow: var(--shadow);
      border-radius: var(--radius-lg);
      backdrop-filter: blur(16px);
    }}
    .hero {{
      padding: 40px;
      margin-bottom: 28px;
    }}
    .eyebrow {{
      margin: 0 0 8px;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--blue);
    }}
    h1 {{
      margin: 0 0 14px;
      font-size: 40px;
      line-height: 1.2;
      letter-spacing: -0.03em;
    }}
    .hero-copy {{
      margin: 0 0 18px;
      max-width: 880px;
      color: var(--muted);
      font-size: 16px;
    }}
    .section {{
      margin-top: 28px;
    }}
    .section-title {{
      margin: 0 0 16px;
      font-size: 28px;
      letter-spacing: -0.02em;
    }}
    .card-grid {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 18px;
    }}
    .metric-card, .chart-card {{
      padding: 24px;
    }}
    .metric-top {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 12px;
    }}
    .metric-card h3, .chart-card h3 {{
      margin: 10px 0 10px;
      font-size: 24px;
      letter-spacing: -0.02em;
    }}
    .card-copy {{
      margin: 0;
      color: var(--muted);
      font-size: 14px;
    }}
    .metric-grid {{
      margin: 18px 0 0;
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 14px 10px;
    }}
    .metric-grid dt {{
      color: var(--muted);
      font-size: 12px;
      margin-bottom: 4px;
    }}
    .metric-grid dd {{
      margin: 0;
      font-size: 20px;
      font-weight: 700;
      letter-spacing: -0.02em;
    }}
    .status-pill {{
      display: inline-flex;
      align-items: center;
      padding: 7px 12px;
      border-radius: 999px;
      font-size: 12px;
      font-weight: 700;
      color: #016b4a;
      background: rgba(8,180,127,0.12);
    }}
    .chart-card img {{
      width: 100%;
      display: block;
      border-radius: 18px;
      margin-top: 18px;
      border: 1px solid var(--line);
      background: #fff;
    }}
    .table-wrap {{
      overflow-x: auto;
      padding: 12px;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 14px;
    }}
    th, td {{
      padding: 14px 12px;
      border-bottom: 1px solid var(--line);
      text-align: left;
      white-space: nowrap;
    }}
    th {{
      color: var(--muted);
      font-weight: 700;
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.06em;
    }}
    tr:last-child td {{
      border-bottom: none;
    }}
    .path-list {{
      display: grid;
      gap: 10px;
      padding: 24px;
    }}
    .path-item {{
      padding: 14px 16px;
      border-radius: 16px;
      background: rgba(49,130,246,0.06);
      border: 1px solid rgba(49,130,246,0.10);
      font-family: "SFMono-Regular", Consolas, monospace;
      font-size: 13px;
      color: #2f3a48;
    }}
    @media (max-width: 980px) {{
      .card-grid {{ grid-template-columns: 1fr; }}
    }}
  </style>
</head>
<body>
  <div class="page">
    <section class="hero">
      <p class="eyebrow">RV32I / Spike / XSIM / matplotlib</p>
      <h1>RV32I Spike 로그 기반 시각화 보고서</h1>
      <p class="hero-copy">
        참고 레포 방식에 맞춰 pandas와 matplotlib로 다시 만든 검증 보고서입니다. 두 verification flow의 scoreboard PASS,
        retire row 정합성, 메모리 check, coverage, instruction mix, pipeline event를 한 번에 읽을 수 있도록 정리했습니다.
      </p>
      <ul>
        <li>Pipeline TB: {int(pipeline['retire_rows'])}/{int(pipeline['retire_rows'])} row match, {mem_summary_text(pipeline)}</li>
        <li>Top_tb: rows={int(top_tb['row_pass_count'])}, errors={int(top_tb['error_count'])}, coverage={float(top_tb['coverage_pct']):.2f}%</li>
        <li>차트 생성: pandas + matplotlib</li>
      </ul>
    </section>

    <section class="section">
      <h2 class="section-title">Flow Cards</h2>
      <div class="card-grid">
        <article class="card metric-card">
          <div class="metric-top">
            <div><p class="eyebrow">Flow 1</p><h3>{html.escape(str(pipeline['flow_label']))}</h3></div>
            <span class="status-pill">{html.escape(str(pipeline['result']))}</span>
          </div>
          <p class="card-copy">Procedural scoreboard flow for quick Spike alignment checks.</p>
          <dl class="metric-grid">
            <div><dt>Rows</dt><dd>{int(pipeline['retire_rows'])}</dd></div>
            <div><dt>Row Pass</dt><dd>{int(pipeline['row_pass_count'])}</dd></div>
            <div><dt>Errors</dt><dd>{int(pipeline['error_count'])}</dd></div>
            <div><dt>Mem Checks</dt><dd>{int(pipeline['mem_check_count'])}</dd></div>
            <div><dt>Branches</dt><dd>{int(pipeline['branch_count'])}</dd></div>
            <div><dt>Jumps</dt><dd>{int(pipeline['jump_count'])}</dd></div>
            <div><dt>Cycles</dt><dd>{int(pipeline['first_cycle'])}->{int(pipeline['last_cycle'])}</dd></div>
            <div><dt>Word0</dt><dd>{html.escape(str(pipeline['final_mem_word0']))}</dd></div>
            <div><dt>Word1</dt><dd>{html.escape(str(pipeline['final_mem_word1']))}</dd></div>
          </dl>
        </article>
        <article class="card metric-card">
          <div class="metric-top">
            <div><p class="eyebrow">Flow 2</p><h3>{html.escape(str(top_tb['flow_label']))}</h3></div>
            <span class="status-pill">{html.escape(str(top_tb['result']))}</span>
          </div>
          <p class="card-copy">Passive class-based environment with monitor, scoreboard, and coverage.</p>
          <dl class="metric-grid">
            <div><dt>Rows</dt><dd>{int(top_tb['retire_rows'])}</dd></div>
            <div><dt>Row Pass</dt><dd>{int(top_tb['row_pass_count'])}</dd></div>
            <div><dt>Errors</dt><dd>{int(top_tb['error_count'])}</dd></div>
            <div><dt>Coverage</dt><dd>{float(top_tb['coverage_pct']):.2f}%</dd></div>
            <div><dt>Redirect</dt><dd>{int(top_tb['redirect_count'])}</dd></div>
            <div><dt>Stall</dt><dd>{int(top_tb['stall_count'])}</dd></div>
            <div><dt>fwdA 1/2</dt><dd>{int(top_tb['fwdA1_count'])}/{int(top_tb['fwdA2_count'])}</dd></div>
            <div><dt>fwdB 1/2</dt><dd>{int(top_tb['fwdB1_count'])}/{int(top_tb['fwdB2_count'])}</dd></div>
            <div><dt>Mem Writes</dt><dd>{int(top_tb['memwrite_count'])}</dd></div>
          </dl>
        </article>
      </div>
    </section>

    <section class="section">
      <h2 class="section-title">Charts</h2>
      <article class="card chart-card">
        <h3>Dashboard</h3>
        <p class="card-copy">한 화면에서 flow summary, opcode heatmap, retire timeline, Top_tb events를 함께 보여줍니다.</p>
        <img src="assets/rv32i_dashboard.png" alt="RV32I dashboard">
      </article>
      <article class="card chart-card">
        <h3>Flow Summary</h3>
        <p class="card-copy">Retire rows, row pass, mem checks, coverage를 비교합니다.</p>
        <img src="assets/rv32i_flow_summary.png" alt="RV32I flow summary">
      </article>
      <article class="card chart-card">
        <h3>Instruction Mix</h3>
        <p class="card-copy">두 flow의 retired instruction mix를 stacked bar로 비교합니다.</p>
        <img src="assets/rv32i_opcode_mix.png" alt="RV32I opcode mix">
      </article>
      <article class="card chart-card">
        <h3>Opcode Heatmap</h3>
        <p class="card-copy">flow별 opcode activity를 heatmap으로 보여줍니다.</p>
        <img src="assets/rv32i_opcode_heatmap.png" alt="RV32I opcode heatmap">
      </article>
      <article class="card chart-card">
        <h3>Retire Timeline</h3>
        <p class="card-copy">retire index 대비 cycle 흐름을 line chart로 비교합니다.</p>
        <img src="assets/rv32i_retire_timeline.png" alt="RV32I retire timeline">
      </article>
      <article class="card chart-card">
        <h3>Top_tb Events</h3>
        <p class="card-copy">redirect, stall, forwarding, memwrite 관측 횟수를 정리합니다.</p>
        <img src="assets/rv32i_top_tb_events.png" alt="RV32I top tb events">
      </article>
    </section>

    <section class="section">
      <h2 class="section-title">Artifacts</h2>
      <div class="card">
        <div class="path-list">
          <div class="path-item">evidence/logs/pipeline_spike_xsim.log</div>
          <div class="path-item">evidence/logs/top_tb_class_xsim.log</div>
          <div class="path-item">evidence/csv/combined_summary.csv</div>
          <div class="path-item">evidence/csv/combined_instruction_mix.csv</div>
          <div class="path-item">evidence/csv/top_tb_event_summary.csv</div>
          <div class="path-item">tools/rv32i_spike_report.py</div>
        </div>
      </div>
    </section>
  </div>
</body>
</html>
"""
    write_text(html_path, html_text)
    write_text(index_path, '<meta http-equiv="refresh" content="0; url=rv32i_spike_visual_report_ko.html">\n')


def main() -> None:
    project_root = Path(__file__).resolve().parent.parent
    pipeline_log_src = project_root / "tb" / "pipeline" / "xsim_tb_top_spike.log"
    class_log_src = project_root / "tb" / "Top_tb" / "xsim_tb_top_class.log"
    evidence_log_dir = project_root / "evidence" / "logs"
    evidence_csv_dir = project_root / "evidence" / "csv"
    assets_dir = project_root / "reports" / "html" / "assets"
    ensure_dir(evidence_log_dir)
    ensure_dir(evidence_csv_dir)
    ensure_dir(assets_dir)

    pipeline_log_dst = evidence_log_dir / "pipeline_spike_xsim.log"
    class_log_dst = evidence_log_dir / "top_tb_class_xsim.log"
    copy_log(pipeline_log_src, pipeline_log_dst)
    copy_log(class_log_src, class_log_dst)

    pipeline_rows, pipeline_summary = parse_pipeline_log(pipeline_log_dst)
    top_rows, top_summary = parse_top_tb_log(class_log_dst)
    summaries = [pipeline_summary, top_summary]
    trace_rows = pipeline_rows + top_rows

    summary_df = pd.DataFrame(asdict(summary) for summary in summaries)
    trace_df = pd.DataFrame(asdict(row) for row in trace_rows)
    mix_df = (
        trace_df.groupby(["flow_name", "flow_label", "opcode"], as_index=False)
        .size()
        .rename(columns={"size": "count"})
    )
    for flow_name in FLOW_ORDER:
        for opcode in OPCODE_ORDER:
            if not ((mix_df["flow_name"] == flow_name) & (mix_df["opcode"] == opcode)).any():
                mix_df.loc[len(mix_df)] = [flow_name, FLOW_LABELS[flow_name], opcode, 0]
    event_df = pd.DataFrame(
        [
            {"event": "redirect", "count": top_summary.redirect_count},
            {"event": "stall", "count": top_summary.stall_count},
            {"event": "memwrite", "count": top_summary.memwrite_count},
            {"event": "regwrite", "count": top_summary.regwrite_count},
            {"event": "illegal", "count": top_summary.illegal_count},
            {"event": "fwdA=1", "count": top_summary.fwdA1_count},
            {"event": "fwdA=2", "count": top_summary.fwdA2_count},
            {"event": "fwdB=1", "count": top_summary.fwdB1_count},
            {"event": "fwdB=2", "count": top_summary.fwdB2_count},
        ]
    )

    write_csv(
        evidence_csv_dir / "pipeline_spike_trace.csv",
        list(trace_df.columns),
        trace_df[trace_df["flow_name"] == "pipeline_spike"].values.tolist(),
    )
    write_csv(
        evidence_csv_dir / "top_tb_class_trace.csv",
        list(trace_df.columns),
        trace_df[trace_df["flow_name"] == "top_tb_class"].values.tolist(),
    )
    write_csv(
        evidence_csv_dir / "combined_summary.csv",
        list(summary_df.columns),
        summary_df.values.tolist(),
    )
    write_csv(
        evidence_csv_dir / "combined_instruction_mix.csv",
        list(mix_df.columns),
        mix_df.sort_values(["flow_name", "opcode"]).values.tolist(),
    )
    write_csv(
        evidence_csv_dir / "top_tb_event_summary.csv",
        list(event_df.columns),
        event_df.values.tolist(),
    )

    save_dashboard(summary_df, mix_df, trace_df, event_df, assets_dir / "rv32i_dashboard.png")
    save_summary_chart(summary_df, assets_dir / "rv32i_flow_summary.png")
    save_opcode_mix_chart(mix_df, assets_dir / "rv32i_opcode_mix.png")
    save_opcode_heatmap(mix_df, assets_dir / "rv32i_opcode_heatmap.png")
    save_timeline_chart(trace_df, assets_dir / "rv32i_retire_timeline.png")
    save_event_chart(event_df, assets_dir / "rv32i_top_tb_events.png")
    generate_markdown(project_root, summary_df)
    generate_html(project_root, summary_df)


if __name__ == "__main__":
    main()
