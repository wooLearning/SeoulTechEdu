#!/usr/bin/env python3
"""
Generate portfolio-ready Python charts and Toss-style reports from TB-emitted CSV files.

Run with a Python environment that has pandas and matplotlib installed.
"""

from __future__ import annotations

from dataclasses import dataclass
from html import escape
from pathlib import Path
import shutil

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


DISPLAY_NAME = {
    "async_fifo_src": "Async FIFO (Dedicated RTL)",
    "async_fifo": "Async FIFO (Showcase)",
    "sync_fifo": "Sync FIFO",
}

MODULE_ORDER = ["async_fifo_src", "async_fifo", "sync_fifo"]
CHART_FILES = [
    "python_dashboard.png",
    "python_module_overview.png",
    "python_scenario_heatmap.png",
    "python_trace_timeseries.png",
    "python_depth_histogram.png",
]
CSV_FILES = [
    "combined_summary.csv",
    "combined_scenarios.csv",
    "combined_trace.csv",
]
DOC_FILES = [
    "reports/markdown/overview/verification_overview.md",
    "reports/markdown/overview/portfolio_report_ko.md",
    "reports/markdown/overview/module_reports_index_ko.md",
    "reports/markdown/module_reports/fifo_report_ko.md",
    "reports/markdown/module_reports/async_fifo_src_report_ko.md",
    "reports/markdown/module_reports/sync_fifo_report_ko.md",
]


@dataclass
class ReportPaths:
    project_root: Path
    package_dir: Path
    package_assets_dir: Path
    package_data_dir: Path
    package_md_path: Path
    package_html_path: Path
    package_index_html_path: Path
    package_start_md_path: Path


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def rel_to(root: Path, path: Path) -> str:
    return str(path.relative_to(root)).replace("\\", "/")


def load_csvs(csv_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    summary_frames = [pd.read_csv(path) for path in sorted(csv_dir.glob("*_summary.csv")) if not path.name.startswith("combined_")]
    scenario_frames = [pd.read_csv(path) for path in sorted(csv_dir.glob("*_scenarios.csv")) if not path.name.startswith("combined_")]
    trace_frames = [pd.read_csv(path) for path in sorted(csv_dir.glob("*_trace.csv")) if not path.name.startswith("combined_")]

    if not summary_frames or not scenario_frames or not trace_frames:
        raise SystemExit(f"TB CSV files are missing under {csv_dir}")

    summary_df = pd.concat(summary_frames, ignore_index=True)
    scenario_df = pd.concat(scenario_frames, ignore_index=True)
    trace_df = pd.concat(trace_frames, ignore_index=True)
    summary_df["module_label"] = summary_df["module_name"].map(DISPLAY_NAME)
    scenario_df["module_label"] = scenario_df["module_name"].map(DISPLAY_NAME)
    trace_df["module_label"] = trace_df["module_name"].map(DISPLAY_NAME)
    return summary_df, scenario_df, trace_df


def save_bar_chart(summary_df: pd.DataFrame, out_path: Path) -> None:
    ordered = summary_df.set_index("module_name").loc[MODULE_ORDER].reset_index()
    labels = ordered["module_label"].tolist()
    x = np.arange(len(labels))
    width = 0.18

    fig, ax = plt.subplots(figsize=(12, 6))
    ax.bar(x - 1.5 * width, ordered["wr_acc_count"], width, label="WR Accepted", color="#3182f6")
    ax.bar(x - 0.5 * width, ordered["rd_acc_count"], width, label="RD Accepted", color="#4cc9a6")
    ax.bar(x + 0.5 * width, ordered["wr_block_count"], width, label="WR Blocked", color="#ffb020")
    ax.bar(x + 1.5 * width, ordered["rd_block_count"], width, label="RD Blocked", color="#f04452")
    ax.set_title("SystemVerilog Verification Transfer Overview")
    ax.set_ylabel("Count")
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=10)
    ax.legend(frameon=False, ncol=2)
    ax.grid(axis="y", linestyle="--", alpha=0.20)
    fig.tight_layout()
    fig.savefig(out_path, dpi=180)
    plt.close(fig)


def save_heatmap(scenario_df: pd.DataFrame, out_path: Path) -> None:
    scenario_order = list(scenario_df["scenario_name"].drop_duplicates())
    pivot = (
        scenario_df.assign(activity=scenario_df["wr_acc_count"] + scenario_df["rd_acc_count"])
        .pivot(index="module_label", columns="scenario_name", values="activity")
        .reindex([DISPLAY_NAME[m] for m in MODULE_ORDER])
        .fillna(0)
        .reindex(columns=scenario_order)
    )

    fig, ax = plt.subplots(figsize=(12, 5))
    im = ax.imshow(pivot.values, cmap="Blues", aspect="auto")
    ax.set_title("Scenario Activity Heatmap")
    ax.set_xticks(np.arange(len(pivot.columns)))
    ax.set_xticklabels(pivot.columns, rotation=20, ha="right")
    ax.set_yticks(np.arange(len(pivot.index)))
    ax.set_yticklabels(pivot.index)
    for i in range(pivot.shape[0]):
        for j in range(pivot.shape[1]):
            ax.text(j, i, int(pivot.values[i, j]), ha="center", va="center", color="#0f172a", fontsize=10)
    fig.colorbar(im, ax=ax, shrink=0.85, label="Accepted operations")
    fig.tight_layout()
    fig.savefig(out_path, dpi=180)
    plt.close(fig)


def save_trace_plot(trace_df: pd.DataFrame, out_path: Path) -> None:
    fig, ax = plt.subplots(figsize=(12, 6))
    focus_modules = ["async_fifo_src", "sync_fifo"]
    colors = {
        "async_fifo_src": "#3182f6",
        "sync_fifo": "#191f28",
    }
    for module_name in focus_modules:
        module_df = trace_df[trace_df["module_name"] == module_name].copy()
        module_df = module_df.sort_values("sample_index").head(220)
        ax.plot(
            module_df["sample_index"],
            module_df["depth_after"],
            linewidth=1.9,
            label=DISPLAY_NAME[module_name],
            color=colors[module_name],
        )
    ax.set_title("Reference Model Depth Trend")
    ax.set_xlabel("Sample Index")
    ax.set_ylabel("Depth After Transaction")
    ax.grid(True, linestyle="--", alpha=0.20)
    ax.legend(frameon=False)
    fig.tight_layout()
    fig.savefig(out_path, dpi=180)
    plt.close(fig)


def save_histogram(trace_df: pd.DataFrame, out_path: Path) -> None:
    fig, ax = plt.subplots(figsize=(10, 6))
    for module_name, color in [
        ("async_fifo_src", "#3182f6"),
        ("async_fifo", "#4cc9a6"),
        ("sync_fifo", "#8b95a1"),
    ]:
        module_df = trace_df[trace_df["module_name"] == module_name]
        ax.hist(
            module_df["depth_after"],
            bins=12,
            alpha=0.55,
            label=DISPLAY_NAME[module_name],
            color=color,
        )
    ax.set_title("Depth Distribution by Verification Target")
    ax.set_xlabel("Depth After Transaction")
    ax.set_ylabel("Frequency")
    ax.legend(frameon=False)
    ax.grid(axis="y", linestyle="--", alpha=0.20)
    fig.tight_layout()
    fig.savefig(out_path, dpi=180)
    plt.close(fig)


def save_dashboard(
    summary_df: pd.DataFrame,
    scenario_df: pd.DataFrame,
    trace_df: pd.DataFrame,
    out_path: Path,
) -> None:
    ordered = summary_df.set_index("module_name").loc[MODULE_ORDER].reset_index()
    fig, axes = plt.subplots(2, 2, figsize=(16, 10))
    fig.suptitle("SystemVerilog Verification Dashboard", fontsize=18, fontweight="bold")

    x = np.arange(len(ordered))
    width = 0.18
    ax = axes[0, 0]
    ax.bar(x - 1.5 * width, ordered["wr_acc_count"], width, label="WR Acc", color="#3182f6")
    ax.bar(x - 0.5 * width, ordered["rd_acc_count"], width, label="RD Acc", color="#4cc9a6")
    ax.bar(x + 0.5 * width, ordered["wr_block_count"], width, label="WR Block", color="#ffb020")
    ax.bar(x + 1.5 * width, ordered["rd_block_count"], width, label="RD Block", color="#f04452")
    ax.set_title("Transfer Overview")
    ax.set_xticks(x)
    ax.set_xticklabels(ordered["module_label"], rotation=10)
    ax.legend(frameon=False, fontsize=9)
    ax.grid(axis="y", linestyle="--", alpha=0.20)

    heatmap_ax = axes[0, 1]
    scenario_order = list(scenario_df["scenario_name"].drop_duplicates())
    pivot = (
        scenario_df.assign(activity=scenario_df["wr_acc_count"] + scenario_df["rd_acc_count"])
        .pivot(index="module_label", columns="scenario_name", values="activity")
        .reindex([DISPLAY_NAME[m] for m in MODULE_ORDER])
        .fillna(0)
        .reindex(columns=scenario_order)
    )
    im = heatmap_ax.imshow(pivot.values, cmap="Blues", aspect="auto")
    heatmap_ax.set_title("Scenario Heatmap")
    heatmap_ax.set_xticks(np.arange(len(pivot.columns)))
    heatmap_ax.set_xticklabels(pivot.columns, rotation=25, ha="right")
    heatmap_ax.set_yticks(np.arange(len(pivot.index)))
    heatmap_ax.set_yticklabels(pivot.index)
    for i in range(pivot.shape[0]):
        for j in range(pivot.shape[1]):
            heatmap_ax.text(j, i, int(pivot.values[i, j]), ha="center", va="center", color="#0f172a", fontsize=9)
    fig.colorbar(im, ax=heatmap_ax, fraction=0.046, pad=0.04)

    trace_ax = axes[1, 0]
    for module_name, color in [("async_fifo_src", "#3182f6"), ("sync_fifo", "#191f28")]:
        module_df = trace_df[trace_df["module_name"] == module_name].sort_values("sample_index").head(220)
        trace_ax.plot(
            module_df["sample_index"],
            module_df["depth_after"],
            linewidth=1.8,
            color=color,
            label=DISPLAY_NAME[module_name],
        )
    trace_ax.set_title("Depth Trend")
    trace_ax.set_xlabel("Sample Index")
    trace_ax.set_ylabel("Depth")
    trace_ax.grid(True, linestyle="--", alpha=0.20)
    trace_ax.legend(frameon=False, fontsize=9)

    hist_ax = axes[1, 1]
    for module_name, color in [
        ("async_fifo_src", "#3182f6"),
        ("async_fifo", "#4cc9a6"),
        ("sync_fifo", "#8b95a1"),
    ]:
        module_df = trace_df[trace_df["module_name"] == module_name]
        hist_ax.hist(module_df["depth_after"], bins=12, alpha=0.55, label=DISPLAY_NAME[module_name], color=color)
    hist_ax.set_title("Depth Histogram")
    hist_ax.set_xlabel("Depth")
    hist_ax.set_ylabel("Frequency")
    hist_ax.legend(frameon=False, fontsize=9)
    hist_ax.grid(axis="y", linestyle="--", alpha=0.20)

    fig.tight_layout(rect=[0, 0.02, 1, 0.96])
    fig.savefig(out_path, dpi=180)
    plt.close(fig)


def build_summary_table(summary_df: pd.DataFrame) -> str:
    ordered = summary_df.set_index("module_name").loc[MODULE_ORDER].reset_index()
    rows = [
        "| 모듈 | 결과 | 샘플 | PASS | FAIL | WR Acc | RD Acc | WR Block | RD Block | Coverage |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for _, row in ordered.iterrows():
        rows.append(
            "| {label} | {status} | {sample} | {pass_cnt} | {fail_cnt} | {wr_acc} | {rd_acc} | {wr_blk} | {rd_blk} | {cov:.2f}% |".format(
                label=row["module_label"],
                status=row["status"],
                sample=int(row["sample_count"]),
                pass_cnt=int(row["pass_count"]),
                fail_cnt=int(row["fail_count"]),
                wr_acc=int(row["wr_acc_count"]),
                rd_acc=int(row["rd_acc_count"]),
                wr_blk=int(row["wr_block_count"]),
                rd_blk=int(row["rd_block_count"]),
                cov=float(row["coverage_pct"]),
            )
        )
    return "\n".join(rows)


def build_module_cards(summary_df: pd.DataFrame) -> str:
    ordered = summary_df.set_index("module_name").loc[MODULE_ORDER].reset_index()
    cards = []
    for _, row in ordered.iterrows():
        status_class = "status-pass" if row["status"] == "PASS" else "status-fail"
        cards.append(
            f"""
            <article class="metric-card">
              <div class="metric-top">
                <span class="eyebrow">{escape(row["module_label"])}</span>
                <span class="status-pill {status_class}">{escape(str(row["status"]))}</span>
              </div>
              <h3>{int(row["sample_count"]):,} samples observed</h3>
              <p class="card-copy">Accepted path와 blocked path를 함께 집계해 boundary condition까지 검증한 결과입니다.</p>
              <dl class="metric-grid">
                <div><dt>PASS</dt><dd>{int(row["pass_count"]):,}</dd></div>
                <div><dt>FAIL</dt><dd>{int(row["fail_count"]):,}</dd></div>
                <div><dt>WR Acc</dt><dd>{int(row["wr_acc_count"]):,}</dd></div>
                <div><dt>RD Acc</dt><dd>{int(row["rd_acc_count"]):,}</dd></div>
                <div><dt>WR Block</dt><dd>{int(row["wr_block_count"]):,}</dd></div>
                <div><dt>RD Block</dt><dd>{int(row["rd_block_count"]):,}</dd></div>
              </dl>
            </article>
            """
        )
    return "\n".join(cards)


def build_scenario_table(scenario_df: pd.DataFrame) -> str:
    working = scenario_df.copy()
    working["activity"] = working["wr_acc_count"] + working["rd_acc_count"]
    working["module_label"] = working["module_name"].map(DISPLAY_NAME)
    working = working.sort_values(["module_name", "scenario_id"])
    rows = [
        "| 모듈 | 시나리오 | 샘플 | WR Acc | RD Acc | WR Block | RD Block | Activity |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for _, row in working.iterrows():
        rows.append(
            "| {module} | {scenario} | {sample} | {wr_acc} | {rd_acc} | {wr_blk} | {rd_blk} | {activity} |".format(
                module=row["module_label"],
                scenario=row["scenario_name"],
                sample=int(row["sample_count"]),
                wr_acc=int(row["wr_acc_count"]),
                rd_acc=int(row["rd_acc_count"]),
                wr_blk=int(row["wr_block_count"]),
                rd_blk=int(row["rd_block_count"]),
                activity=int(row["activity"]),
            )
        )
    return "\n".join(rows)


def build_html_report(
    summary_df: pd.DataFrame,
    scenario_df: pd.DataFrame,
    paths: ReportPaths,
) -> str:
    ordered = summary_df.set_index("module_name").loc[MODULE_ORDER].reset_index()
    summary_cards = build_module_cards(summary_df)
    scenario_rows = []
    scenario_view = scenario_df.copy()
    scenario_view["module_label"] = scenario_view["module_name"].map(DISPLAY_NAME)
    scenario_view["activity"] = scenario_view["wr_acc_count"] + scenario_view["rd_acc_count"]
    scenario_view = scenario_view.sort_values(["module_name", "scenario_id"])
    for _, row in scenario_view.iterrows():
        scenario_rows.append(
            f"""
            <tr>
              <td>{escape(row["module_label"])}</td>
              <td>{escape(row["scenario_name"])}</td>
              <td>{int(row["sample_count"]):,}</td>
              <td>{int(row["wr_acc_count"]):,}</td>
              <td>{int(row["rd_acc_count"]):,}</td>
              <td>{int(row["wr_block_count"]):,}</td>
              <td>{int(row["rd_block_count"]):,}</td>
              <td>{int(row["activity"]):,}</td>
            </tr>
            """
        )

    hero_points = """
    <li>TB scoreboard가 생성한 CSV를 Python으로 다시 시각화했습니다.</li>
    <li>accepted path와 blocked path를 함께 집계했습니다.</li>
    <li>`clocking block`을 drive, pre-sample, post-sample 단계로 나눠 사용했습니다.</li>
    """

    chart_card = lambda title, file_name, desc: f"""
      <article class="chart-card">
        <div class="card-head">
          <div>
            <p class="eyebrow">Python Visualization</p>
            <h3>{title}</h3>
          </div>
          <p class="card-copy">{desc}</p>
        </div>
        <img src="assets/{file_name}" alt="{title}">
      </article>
    """

    chart_explanations = """
      <article class="info-card">
        <p class="eyebrow">Chart Guide</p>
        <h3>1. Verification Dashboard</h3>
        <p class="card-copy">
          4개 핵심 그래프를 한 화면에 모아 둔 요약 화면입니다.
        </p>
      </article>
      <article class="info-card">
        <p class="eyebrow">Chart Guide</p>
        <h3>2. Module Transfer Overview</h3>
        <p class="card-copy">
          x축은 모듈, y축은 횟수입니다. WR/RD accepted와 WR/RD blocked를 함께 표시합니다.
        </p>
      </article>
      <article class="info-card">
        <p class="eyebrow">Chart Guide</p>
        <h3>3. Scenario Activity Heatmap</h3>
        <p class="card-copy">
          x축은 시나리오, y축은 모듈이며 각 셀의 색과 숫자는 accepted activity 양입니다.
        </p>
      </article>
      <article class="info-card">
        <p class="eyebrow">Chart Guide</p>
        <h3>4. Reference Model Depth Trend</h3>
        <p class="card-copy">
          x축은 sample index, y축은 transaction 이후의 reference model depth입니다.
        </p>
      </article>
      <article class="info-card">
        <p class="eyebrow">Chart Guide</p>
        <h3>5. Depth Histogram</h3>
        <p class="card-copy">
          x축은 depth 값, y축은 해당 depth가 등장한 빈도입니다.
        </p>
      </article>
    """

    html = f"""<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>SystemVerilog Python Visual Report</title>
  <style>
    :root {{
      --bg: #f6f8fb;
      --panel: rgba(255,255,255,0.88);
      --panel-strong: #ffffff;
      --text: #191f28;
      --muted: #6b7684;
      --line: #e5e8eb;
      --blue: #3182f6;
      --green: #08b47f;
      --orange: #ffb020;
      --red: #f04452;
      --shadow: 0 24px 60px rgba(15, 23, 42, 0.08);
      --radius-xl: 32px;
      --radius-lg: 24px;
      --radius-md: 18px;
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
      max-width: 1240px;
      margin: 0 auto;
      padding: 48px 24px 72px;
    }}
    .hero {{
      background: linear-gradient(180deg, rgba(255,255,255,0.94), rgba(255,255,255,0.82));
      border: 1px solid rgba(255,255,255,0.8);
      box-shadow: var(--shadow);
      border-radius: var(--radius-xl);
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
      max-width: 840px;
      color: var(--muted);
      font-size: 16px;
    }}
    .hero ul {{
      margin: 0;
      padding-left: 18px;
      color: var(--text);
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
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 18px;
    }}
    .metric-card, .chart-card, .info-card {{
      background: var(--panel);
      border: 1px solid rgba(255,255,255,0.9);
      box-shadow: var(--shadow);
      border-radius: var(--radius-lg);
      padding: 24px;
      backdrop-filter: blur(16px);
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
    }}
    .status-pass {{
      color: #016b4a;
      background: rgba(8,180,127,0.12);
    }}
    .status-fail {{
      color: #b42318;
      background: rgba(240,68,82,0.12);
    }}
    .chart-stack {{
      display: grid;
      gap: 18px;
    }}
    .chart-card img {{
      width: 100%;
      display: block;
      border-radius: 18px;
      margin-top: 18px;
      border: 1px solid var(--line);
      background: var(--panel-strong);
    }}
    .card-head {{
      display: flex;
      justify-content: space-between;
      align-items: start;
      gap: 20px;
    }}
    .table-wrap {{
      overflow-x: auto;
      border-radius: var(--radius-lg);
      background: var(--panel);
      border: 1px solid rgba(255,255,255,0.9);
      box-shadow: var(--shadow);
      padding: 12px;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 14px;
      background: transparent;
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
    @page {{
      size: A4 landscape;
      margin: 10mm;
    }}
    @media print {{
      :root {{
        --bg: #ffffff;
        --panel: #ffffff;
        --panel-strong: #ffffff;
        --text: #111111;
        --muted: #555555;
        --line: #d7dbe0;
        --shadow: none;
      }}
      body {{
        background: #ffffff;
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
      }}
      .page {{
        max-width: none;
        padding: 0;
      }}
      .hero,
      .section,
      .metric-card,
      .info-card,
      .table-wrap,
      .path-item {{
        break-inside: avoid;
        page-break-inside: avoid;
        box-shadow: none;
        backdrop-filter: none;
      }}
      .hero,
      .metric-card,
      .chart-card,
      .info-card,
      .table-wrap {{
        background: #ffffff;
        border: 1px solid var(--line);
      }}
      .section {{
        margin-top: 16px;
      }}
      .section-title {{
        font-size: 22px;
        margin-bottom: 10px;
      }}
      h1 {{
        font-size: 30px;
        margin-bottom: 10px;
      }}
      .hero-copy,
      .card-copy,
      table {{
        font-size: 12px;
      }}
      .card-grid {{
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 12px;
      }}
      .chart-stack {{
        gap: 12px;
      }}
      .chart-card {{
        break-inside: auto;
        page-break-inside: auto;
        padding: 18px;
      }}
      .card-head {{
        display: block;
      }}
      .card-copy {{
        margin-top: 6px;
      }}
      .chart-card img {{
        width: 92%;
        display: block;
        margin: 12px auto 0;
        margin-top: 12px;
        max-height: 95mm;
        object-fit: contain;
        break-inside: avoid;
        page-break-inside: avoid;
      }}
      .metric-grid {{
        grid-template-columns: repeat(3, minmax(0, 1fr));
        gap: 10px 8px;
      }}
      .metric-grid dd {{
        font-size: 16px;
      }}
      .table-wrap {{
        overflow: visible;
        padding: 8px;
      }}
      th, td {{
        padding: 8px 6px;
        white-space: normal;
        word-break: break-word;
      }}
      .path-item {{
        font-size: 11px;
        padding: 10px 12px;
      }}
    }}
    @media (max-width: 1024px) {{
      .card-grid {{
        grid-template-columns: 1fr;
      }}
      .card-head {{
        flex-direction: column;
      }}
    }}
  </style>
</head>
<body>
  <main class="page">
    <section class="hero">
      <p class="eyebrow">SystemVerilog Portfolio</p>
      <h1>Python 시각화 검증 보고서</h1>
      <p class="hero-copy">
        TB scoreboard가 생성한 CSV를 Python으로 다시 시각화한 보고서입니다.
        scenario별 activity, accepted/blocked path, depth 변화를 함께 확인할 수 있습니다.
      </p>
      <ul>
        {hero_points}
      </ul>
    </section>

    <section class="section">
      <h2 class="section-title">모듈 요약 카드</h2>
      <div class="card-grid">
        {summary_cards}
      </div>
    </section>

    <section class="section chart-stack">
      <h2 class="section-title">차트</h2>
      {chart_card("Verification Dashboard", "python_dashboard.png", "핵심 차트 4개를 한 화면에 모은 대시보드입니다.")}
      {chart_card("Module Transfer Overview", "python_module_overview.png", "모듈별 accepted와 blocked count를 비교해 검증 범위를 설명합니다.")}
      {chart_card("Scenario Activity Heatmap", "python_scenario_heatmap.png", "시나리오별 activity 분포를 통해 pressure path와 정상 path가 모두 발생했는지 보여줍니다.")}
      {chart_card("Reference Model Depth Trend", "python_trace_timeseries.png", "trace CSV를 기준으로 queue depth의 시계열 변화를 시각화했습니다.")}
      {chart_card("Depth Histogram", "python_depth_histogram.png", "depth 분포를 통해 경계 상태와 중간 상태가 어떻게 나타났는지 확인할 수 있습니다.")}
    </section>

    <section class="section">
      <h2 class="section-title">그래프 해석 가이드</h2>
      <div class="card-grid">
        {chart_explanations}
      </div>
    </section>

    <section class="section">
      <h2 class="section-title">시나리오 집계</h2>
      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>모듈</th>
              <th>시나리오</th>
              <th>샘플</th>
              <th>WR Acc</th>
              <th>RD Acc</th>
              <th>WR Block</th>
              <th>RD Block</th>
              <th>Activity</th>
            </tr>
          </thead>
          <tbody>
            {''.join(scenario_rows)}
          </tbody>
        </table>
      </div>
    </section>

    <section class="section card-grid">
      <article class="info-card">
        <p class="eyebrow">Timing Note</p>
        <h3>Clocking Block 기반 샘플링</h3>
        <p class="card-copy">
          driver는 `negedge` 기반 clocking block으로 입력을 인가하고, monitor는 `pre_cb`와 `mon_cb`를 분리해
          acceptance 판정 근거와 post-update 결과를 각각 수집합니다.
        </p>
      </article>
      <article class="info-card">
        <p class="eyebrow">Coverage Note</p>
        <h3>숫자보다 관측 범위를 설명</h3>
        <p class="card-copy">
          covergroup 항목과 scoreboard summary를 함께 사용해 scenario hit, accepted/blocked path, flag state를 확인할 수 있습니다.
        </p>
      </article>
      <article class="info-card">
        <p class="eyebrow">Report Files</p>
        <h3>관련 파일</h3>
        <p class="card-copy">
          HTML, Markdown, 차트 PNG, 통합 CSV를 같은 폴더 아래에 두었습니다.
        </p>
      </article>
    </section>

    <section class="section">
      <h2 class="section-title">자료 경로</h2>
      <div class="path-list">
        <div class="path-item">{escape(rel_to(paths.project_root, paths.package_html_path))}</div>
        <div class="path-item">{escape(rel_to(paths.project_root, paths.package_md_path))}</div>
        <div class="path-item">{escape(rel_to(paths.project_root, paths.package_assets_dir))}</div>
        <div class="path-item">{escape(rel_to(paths.project_root, paths.package_data_dir))}</div>
      </div>
    </section>
  </main>
</body>
</html>
"""
    return html


def build_markdown_report(summary_df: pd.DataFrame, scenario_df: pd.DataFrame, root: Path, report_dir: Path) -> str:
    assets_dir = report_dir / "assets"
    data_dir = root / "evidence" / "csv"
    markdown_path = root / "reports" / "markdown" / "overview" / "systemverilog_python_visual_report_ko.md"
    lines = [
        "# SystemVerilog Python 시각화 보고서",
        "",
        "> Python으로 생성한 검증 결과 시각화 보고서입니다.",
        "",
        "## 요약",
        "",
        "- TB scoreboard가 직접 만든 CSV를 Python(`pandas`, `matplotlib`)으로 시각화했습니다.",
        "- accepted path와 blocked path를 함께 보여줘 boundary condition 검증 범위를 설명할 수 있습니다.",
        "- `clocking block`을 drive / pre-sample / post-sample 단계로 분리해 안정적인 타이밍을 유지했습니다.",
        "",
        "## 핵심 산출물",
        "",
        f"- 대시보드: `{rel_to(root, assets_dir / 'python_dashboard.png')}`",
        f"- 모듈 비교 차트: `{rel_to(root, assets_dir / 'python_module_overview.png')}`",
        f"- 시나리오 heatmap: `{rel_to(root, assets_dir / 'python_scenario_heatmap.png')}`",
        f"- depth 추세: `{rel_to(root, assets_dir / 'python_trace_timeseries.png')}`",
        f"- depth histogram: `{rel_to(root, assets_dir / 'python_depth_histogram.png')}`",
        "",
        "## 그래프 해석 가이드",
        "",
        "### 1. Verification Dashboard",
        "",
        "- 의미: 4개 핵심 그래프를 한 화면에 모은 요약판입니다.",
        "- 설명: 전체 결과를 한 화면에서 확인할 수 있습니다.",
        "",
        "### 2. Module Transfer Overview",
        "",
        "- x축: 모듈",
        "- y축: 횟수(count)",
        "- 의미: WR/RD accepted와 WR/RD blocked를 함께 비교합니다.",
        "- 설명: 정상 경로와 경계 조건을 함께 비교할 수 있습니다.",
        "",
        "### 3. Scenario Activity Heatmap",
        "",
        "- x축: 시나리오",
        "- y축: 모듈",
        "- 색/숫자: `wr_acc + rd_acc` 기준 activity",
        "- 의미: 어떤 시나리오가 실제로 활발히 수행됐는지 보여줍니다.",
        "- 설명: 시나리오별 activity 분포를 확인할 수 있습니다.",
        "",
        "### 4. Reference Model Depth Trend",
        "",
        "- x축: sample index",
        "- y축: transaction 이후 reference model depth",
        "- 의미: 시간 순서에 따라 FIFO가 차고 비는 흐름을 보여줍니다.",
        "- 설명: 시간 순서에 따른 depth 변화를 확인할 수 있습니다.",
        "",
        "### 5. Depth Histogram",
        "",
        "- x축: depth 값",
        "- y축: 빈도(frequency)",
        "- 의미: 특정 depth 구간이 얼마나 자주 관찰됐는지 보여줍니다.",
        "- 설명: depth 분포를 구간별로 확인할 수 있습니다.",
        "",
        "## 모듈 요약",
        "",
        build_summary_table(summary_df),
        "",
        "## 시나리오 요약",
        "",
        build_scenario_table(scenario_df),
        "",
        "## 시나리오 해석",
        "",
        "- `fill_burst`: queue를 채워 full과 write blocked path를 확인합니다.",
        "- `mixed_stress`: read/write가 혼재된 일반 운용 구간에서 ordering을 검증합니다.",
        "- `drain_burst`: queue를 비워 empty와 read blocked path를 확인합니다.",
        "- `full_pressure`: 꽉 찬 상태에서 backpressure를 확인합니다.",
        "- `empty_pressure`: 비어 있는 상태에서 underflow protection을 확인합니다.",
        "- `simul_stress`, `balanced_stream`: sync FIFO의 동시 read/write 정책과 steady-state traffic을 설명합니다.",
        "",
        "## Coverage 해석",
        "",
        "- summary CSV는 pass/fail만이 아니라 `wr_acc`, `rd_acc`, `wr_block`, `rd_block`를 함께 남깁니다.",
        "- scenario CSV는 어떤 phase에서 accepted path와 blocked path가 얼마나 발생했는지 보여줍니다.",
        "- trace CSV는 sample 단위 depth 변화를 남겨 time-series plot과 histogram의 근거가 됩니다.",
        "",
        "## 타이밍 메모",
        "",
        "- async FIFO는 driver clocking block이 `negedge`에서 요청을 인가하고, `pre_cb`가 `posedge #1step`, `mon_cb`가 다음 `negedge #1step`으로 샘플합니다.",
        "- sync FIFO도 같은 discipline을 유지하되 single-clock 정책에 맞춰 pre-count 기반 scoreboard를 사용합니다.",
        "- 따라서 그래프에 보이는 depth 변화는 DUT가 실제로 받아들인 transaction 흐름과 정합됩니다.",
        "",
        "## 관련 경로",
        "",
        f"- PDF: `{rel_to(root, root / 'reports' / 'pdf' / 'systemverilog_python_visual_report_ko.pdf')}`",
        f"- HTML: `{rel_to(root, report_dir / 'systemverilog_python_visual_report_ko.html')}`",
        f"- Markdown: `{rel_to(root, markdown_path)}`",
        f"- 차트 폴더: `{rel_to(root, assets_dir)}`",
        f"- 데이터 폴더: `{rel_to(root, data_dir)}`",
    ]
    return "\n".join(lines) + "\n"


def copy_outputs(analytics_dir: Path, paths: ReportPaths) -> None:
    ensure_dir(paths.package_assets_dir)
    ensure_dir(paths.package_data_dir)
    for file_name in CHART_FILES:
        shutil.copy2(analytics_dir / file_name, paths.package_assets_dir / file_name)
    for file_name in CSV_FILES:
        shutil.copy2(analytics_dir / file_name, paths.package_data_dir / file_name)


def build_start_here(root: Path, paths: ReportPaths) -> str:
    return "\n".join(
        [
            "# START HERE",
            "",
            "이 폴더는 Python 시각화 보고서를 포함한 SystemVerilog 검증 결과 폴더입니다.",
            "",
            "## 가장 먼저 볼 파일",
            "",
            f"- PDF 보고서: `reports/pdf/systemverilog_python_visual_report_ko.pdf`",
            f"- 메인 HTML: `{rel_to(root, paths.package_html_path)}`",
            f"- 메인 Markdown: `{rel_to(root, paths.package_md_path)}`",
            f"- 대시보드 PNG: `{rel_to(root, paths.package_assets_dir / 'python_dashboard.png')}`",
            "",
            "## 폴더 구성",
            "",
            f"- `assets/`: Python 시각화 차트 PNG",
            f"- `../../evidence/csv/`: TB CSV를 통합한 summary/scenario/trace CSV",
            f"- `../markdown/`: 검증 개요와 상세 보고서",
            "",
            "## 추천 확인 순서",
            "",
            "1. PDF 보고서로 전체 결과를 먼저 확인",
            "2. HTML 보고서로 원본 레이아웃과 시각화를 확인",
            "3. dashboard PNG와 heatmap PNG로 핵심 그래프를 빠르게 확인",
            "4. overview/module_reports 문서로 시나리오, coverage, timing 설명 확인",
            "",
            "## 참고",
            "",
            "- 그래프는 `TB scoreboard -> CSV -> Python(pandas, matplotlib)` 흐름으로 생성했습니다.",
        ]
    ) + "\n"


def write_reports(summary_df: pd.DataFrame, scenario_df: pd.DataFrame, paths: ReportPaths) -> None:
    markdown = build_markdown_report(summary_df, scenario_df, paths.project_root, paths.package_dir)
    html = build_html_report(summary_df, scenario_df, paths)
    start_here = build_start_here(paths.project_root, paths)

    paths.package_md_path.write_text(markdown, encoding="utf-8")
    paths.package_html_path.write_text(html, encoding="utf-8")
    paths.package_index_html_path.write_text(html, encoding="utf-8")
    paths.package_start_md_path.write_text(start_here, encoding="utf-8")


def main() -> None:
    project_root = Path(__file__).resolve().parents[1]
    csv_dir = project_root / "evidence" / "csv"
    analytics_dir = project_root / ".tmp_python_plots"
    package_dir = project_root / "reports" / "html"
    package_assets_dir = package_dir / "assets"
    package_data_dir = project_root / "evidence" / "csv"
    ensure_dir(analytics_dir)
    ensure_dir(package_dir)

    paths = ReportPaths(
        project_root=project_root,
        package_dir=package_dir,
        package_assets_dir=package_assets_dir,
        package_data_dir=package_data_dir,
        package_md_path=project_root / "reports" / "markdown" / "overview" / "systemverilog_python_visual_report_ko.md",
        package_html_path=package_dir / "systemverilog_python_visual_report_ko.html",
        package_index_html_path=package_dir / "index.html",
        package_start_md_path=package_dir / "START_HERE_ko.md",
    )

    summary_df, scenario_df, trace_df = load_csvs(csv_dir)
    summary_df.to_csv(analytics_dir / "combined_summary.csv", index=False)
    scenario_df.to_csv(analytics_dir / "combined_scenarios.csv", index=False)
    trace_df.to_csv(analytics_dir / "combined_trace.csv", index=False)

    save_bar_chart(summary_df, analytics_dir / "python_module_overview.png")
    save_heatmap(scenario_df, analytics_dir / "python_scenario_heatmap.png")
    save_trace_plot(trace_df, analytics_dir / "python_trace_timeseries.png")
    save_histogram(trace_df, analytics_dir / "python_depth_histogram.png")
    save_dashboard(summary_df, scenario_df, trace_df, analytics_dir / "python_dashboard.png")

    copy_outputs(analytics_dir, paths)
    write_reports(summary_df, scenario_df, paths)


if __name__ == "__main__":
    main()
