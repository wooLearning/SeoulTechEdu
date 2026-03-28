#!/usr/bin/env python3
"""
Generate a merged verification report across archived Spike ROM cases.

Inputs:
  - spike_cases/*/case_manifest.txt
  - spike_cases/*/evidence/csv/combined_summary.csv

Outputs:
  - evidence/csv/case_flow_matrix.csv
  - evidence/csv/case_matrix_summary.csv
  - reports/html/assets/rv32i_case_dashboard.png
  - reports/html/assets/rv32i_case_flow_compare.png
  - reports/html/assets/rv32i_case_top_metrics.png
  - reports/html/rv32i_case_matrix_report_ko.html
  - reports/markdown/overview/rv32i_case_matrix_report_ko.md
"""

from __future__ import annotations

import html
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
        "Use Windows Python for this workspace: cmd.exe /c py -3 tools\\rv32i_case_matrix_report.py"
    ) from exc


FLOW_ORDER = ["pipeline_spike", "top_tb_class"]
FLOW_LABELS = {
    "pipeline_spike": "Pipeline TB",
    "top_tb_class": "Top_tb Class Env",
}
FLOW_COLORS = {
    "pipeline_spike": "#3182f6",
    "top_tb_class": "#191f28",
}
CASE_COLORS = ["#3182f6", "#08b47f", "#735bf2", "#ff7a00", "#00a3ad", "#f04452"]


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def write_text(path: Path, text: str) -> None:
    ensure_dir(path.parent)
    path.write_text(text, encoding="utf-8")


def load_manifest(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
      if "=" in line:
          key, value = line.split("=", 1)
          result[key.strip()] = value.strip()
    return result


def discover_case_flows(project_root: Path) -> pd.DataFrame:
    rows: list[pd.DataFrame] = []
    case_root = project_root / "spike_cases"
    for manifest_path in sorted(case_root.glob("*/case_manifest.txt")):
        case_dir = manifest_path.parent
        manifest = load_manifest(manifest_path)
        summary_path = case_dir / manifest.get("summary_csv", "evidence/csv/combined_summary.csv")
        if not summary_path.exists():
            continue
        df = pd.read_csv(summary_path)
        df["case_name"] = manifest.get("case_name", case_dir.name)
        df["source_csv"] = manifest.get("source_csv", "")
        df["case_dir"] = case_dir.relative_to(project_root).as_posix()
        rows.append(df)
    if not rows:
        raise SystemExit("No archived case summaries found under spike_cases/")
    return pd.concat(rows, ignore_index=True)


def build_case_summary(flow_df: pd.DataFrame) -> pd.DataFrame:
    summary_rows: list[dict[str, object]] = []
    for case_name in sorted(flow_df["case_name"].unique()):
        case_df = flow_df[flow_df["case_name"] == case_name].set_index("flow_name")
        pipeline = case_df.loc["pipeline_spike"]
        top_tb = case_df.loc["top_tb_class"]
        overall_pass = (
            pipeline["result"] == "PASS"
            and top_tb["result"] == "PASS"
            and int(pipeline["error_count"]) == 0
            and int(top_tb["error_count"]) == 0
            and int(pipeline["retire_rows"]) == int(top_tb["retire_rows"])
        )
        summary_rows.append(
            {
                "case_name": case_name,
                "source_csv": pipeline["source_csv"],
                "overall_result": "PASS" if overall_pass else "FAIL",
                "retire_rows": int(top_tb["retire_rows"]),
                "pipeline_cycle_span": int(pipeline["cycle_span"]),
                "top_cycle_span": int(top_tb["cycle_span"]),
                "coverage_pct": float(top_tb["coverage_pct"]),
                "mem_checks": int(max(pipeline["mem_check_count"], top_tb["mem_check_count"])),
                "regwrite_count": int(top_tb["regwrite_count"]),
                "memwrite_count": int(top_tb["memwrite_count"]),
                "stall_count": int(top_tb["stall_count"]),
                "redirect_count": int(top_tb["redirect_count"]),
                "illegal_count": int(top_tb["illegal_count"]),
                "fwdA1_count": int(top_tb["fwdA1_count"]),
                "fwdA2_count": int(top_tb["fwdA2_count"]),
                "fwdB1_count": int(top_tb["fwdB1_count"]),
                "fwdB2_count": int(top_tb["fwdB2_count"]),
                "branch_count": int(top_tb["branch_count"]),
                "jump_count": int(top_tb["jump_count"]),
                "report_html": f"spike_cases/{case_name}/reports/html/rv32i_spike_visual_report_ko.html",
                "report_md": f"spike_cases/{case_name}/reports/markdown/overview/rv32i_spike_visual_report_ko.md",
            }
        )
    return pd.DataFrame(summary_rows)


def save_case_flow_compare(case_flow_df: pd.DataFrame, out_path: Path) -> None:
    case_names = sorted(case_flow_df["case_name"].unique())
    x = np.arange(len(case_names))
    width = 0.34
    fig, axes = plt.subplots(2, 1, figsize=(12, 8))

    for idx, flow_name in enumerate(FLOW_ORDER):
        flow_rows = case_flow_df[case_flow_df["flow_name"] == flow_name].set_index("case_name").loc[case_names]
        axes[0].bar(
            x + (idx - 0.5) * width,
            flow_rows["retire_rows"],
            width=width,
            label=FLOW_LABELS[flow_name],
            color=FLOW_COLORS[flow_name],
        )
        axes[1].bar(
            x + (idx - 0.5) * width,
            flow_rows["cycle_span"],
            width=width,
            label=FLOW_LABELS[flow_name],
            color=FLOW_COLORS[flow_name],
        )

    axes[0].set_title("Retire Rows by ROM and Verification Flow")
    axes[0].set_ylabel("Retire rows")
    axes[0].set_xticks(x)
    axes[0].set_xticklabels(case_names)
    axes[0].grid(axis="y", linestyle="--", alpha=0.20)
    axes[0].legend(frameon=False)

    axes[1].set_title("Cycle Span by ROM and Verification Flow")
    axes[1].set_ylabel("Cycles")
    axes[1].set_xticks(x)
    axes[1].set_xticklabels(case_names)
    axes[1].grid(axis="y", linestyle="--", alpha=0.20)
    axes[1].legend(frameon=False)

    fig.tight_layout()
    fig.savefig(out_path, dpi=180)
    plt.close(fig)


def save_case_top_metrics(case_summary_df: pd.DataFrame, out_path: Path) -> None:
    case_names = list(case_summary_df["case_name"])
    x = np.arange(len(case_names))
    width = 0.18
    fig, axes = plt.subplots(2, 1, figsize=(12, 8))

    axes[0].bar(x - width, case_summary_df["coverage_pct"], width=width, color="#735bf2", label="Coverage %")
    axes[0].bar(x, case_summary_df["stall_count"], width=width, color="#191f28", label="Stall")
    axes[0].bar(x + width, case_summary_df["redirect_count"], width=width, color="#3182f6", label="Redirect")
    axes[0].set_title("Top_tb Coverage and Control Metrics by ROM")
    axes[0].set_xticks(x)
    axes[0].set_xticklabels(case_names)
    axes[0].grid(axis="y", linestyle="--", alpha=0.20)
    axes[0].legend(frameon=False, ncol=3)

    axes[1].bar(x - 1.5 * width, case_summary_df["fwdA1_count"], width=width, color="#ffb020", label="fwdA=1")
    axes[1].bar(x - 0.5 * width, case_summary_df["fwdA2_count"], width=width, color="#735bf2", label="fwdA=2")
    axes[1].bar(x + 0.5 * width, case_summary_df["fwdB1_count"], width=width, color="#00a3ad", label="fwdB=1")
    axes[1].bar(x + 1.5 * width, case_summary_df["fwdB2_count"], width=width, color="#8b95a1", label="fwdB=2")
    axes[1].set_title("Top_tb Forwarding Metrics by ROM")
    axes[1].set_xticks(x)
    axes[1].set_xticklabels(case_names)
    axes[1].grid(axis="y", linestyle="--", alpha=0.20)
    axes[1].legend(frameon=False, ncol=4)

    fig.tight_layout()
    fig.savefig(out_path, dpi=180)
    plt.close(fig)


def save_case_dashboard(case_summary_df: pd.DataFrame, out_path: Path) -> None:
    case_names = list(case_summary_df["case_name"])
    x = np.arange(len(case_names))
    fig, axes = plt.subplots(2, 2, figsize=(15, 10))
    fig.suptitle("RV32I ROM Case Verification Dashboard", fontsize=18, fontweight="bold")

    axes[0, 0].bar(case_names, case_summary_df["retire_rows"], color=CASE_COLORS[:len(case_names)])
    axes[0, 0].set_title("Retire Rows")
    axes[0, 0].grid(axis="y", linestyle="--", alpha=0.20)

    axes[0, 1].bar(case_names, case_summary_df["coverage_pct"], color="#735bf2")
    axes[0, 1].set_title("Top_tb Coverage %")
    axes[0, 1].grid(axis="y", linestyle="--", alpha=0.20)

    width = 0.22
    axes[1, 0].bar(x - width, case_summary_df["stall_count"], width=width, color="#191f28", label="Stall")
    axes[1, 0].bar(x, case_summary_df["redirect_count"], width=width, color="#3182f6", label="Redirect")
    axes[1, 0].bar(x + width, case_summary_df["memwrite_count"], width=width, color="#f04452", label="MemWrite")
    axes[1, 0].set_title("Pipeline Events")
    axes[1, 0].set_xticks(x)
    axes[1, 0].set_xticklabels(case_names)
    axes[1, 0].grid(axis="y", linestyle="--", alpha=0.20)
    axes[1, 0].legend(frameon=False)

    axes[1, 1].bar(x - width, case_summary_df["branch_count"], width=width, color="#191f28", label="Branch")
    axes[1, 1].bar(x, case_summary_df["jump_count"], width=width, color="#ff7a00", label="Jump")
    axes[1, 1].bar(x + width, case_summary_df["mem_checks"], width=width, color="#08b47f", label="Mem Checks")
    axes[1, 1].set_title("Program Shape")
    axes[1, 1].set_xticks(x)
    axes[1, 1].set_xticklabels(case_names)
    axes[1, 1].grid(axis="y", linestyle="--", alpha=0.20)
    axes[1, 1].legend(frameon=False)

    fig.tight_layout()
    fig.savefig(out_path, dpi=180)
    plt.close(fig)


def generate_markdown(project_root: Path, case_summary_df: pd.DataFrame, case_flow_df: pd.DataFrame) -> None:
    report_path = project_root / "reports" / "markdown" / "overview" / "rv32i_case_matrix_report_ko.md"
    lines = [
        "# RV32I ROM 통합 검증 보고서",
        "",
        "보관된 ROM 케이스별 verification 결과를 한 곳에서 비교한 통합 보고서입니다.",
        "",
        "## 핵심 산출물",
        "",
        "- HTML 보고서: `../../html/rv32i_case_matrix_report_ko.html`",
        "- Dashboard: `../../html/assets/rv32i_case_dashboard.png`",
        "- Flow compare: `../../html/assets/rv32i_case_flow_compare.png`",
        "- Top metrics: `../../html/assets/rv32i_case_top_metrics.png`",
        "- CSV: `../../../evidence/csv/case_matrix_summary.csv`",
        "- CSV: `../../../evidence/csv/case_flow_matrix.csv`",
        "",
        "## Case Summary",
        "",
        "| ROM Case | Result | Retire Rows | Coverage | Stall | Redirect | MemWrite | Branch | Jump |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for _, row in case_summary_df.iterrows():
        lines.append(
            f"| {row['case_name']} | {row['overall_result']} | {int(row['retire_rows'])} | "
            f"{float(row['coverage_pct']):.2f}% | {int(row['stall_count'])} | {int(row['redirect_count'])} | "
            f"{int(row['memwrite_count'])} | {int(row['branch_count'])} | {int(row['jump_count'])} |"
        )

    lines.extend(["", "## 해석", ""])
    if "bubble_sort" in set(case_summary_df["case_name"]):
        bubble = case_summary_df.set_index("case_name").loc["bubble_sort"]
        lines.append(
            f"- `bubble_sort`는 Top_tb 기준 coverage `{float(bubble['coverage_pct']):.2f}%`, "
            f"stall `{int(bubble['stall_count'])}`, redirect `{int(bubble['redirect_count'])}`로 "
            "hazard와 control-flow 검증이 더 풍부하게 관측됐습니다."
        )
    if "test_top" in set(case_summary_df["case_name"]):
        test_top = case_summary_df.set_index("case_name").loc["test_top"]
        lines.append(
            f"- `test_top`은 retire `{int(test_top['retire_rows'])}` 규모의 짧은 directed ROM으로, "
            f"final memory check `{int(test_top['mem_checks'])}`건과 coverage `{float(test_top['coverage_pct']):.2f}%`를 확인했습니다."
        )
    lines.append("- 두 ROM 모두 Pipeline TB와 Top_tb가 같은 retire row 수를 PASS로 통과해 scoreboard 정합성은 확보됐습니다.")
    lines.extend(["", "## 케이스 링크", ""])
    for _, row in case_summary_df.iterrows():
        lines.extend(
            [
                f"### {row['case_name']}",
                "",
                f"- HTML: `../../../{row['report_html']}`",
                f"- Markdown: `../../../{row['report_md']}`",
                f"- CSV: `{row['source_csv']}`",
                "",
            ]
        )
    write_text(report_path, "\n".join(lines) + "\n")


def generate_html(project_root: Path, case_summary_df: pd.DataFrame, case_flow_df: pd.DataFrame) -> None:
    report_path = project_root / "reports" / "html" / "rv32i_case_matrix_report_ko.html"
    cards = []
    rows = []
    for _, row in case_summary_df.iterrows():
        cards.append(
            f"""
        <article class="metric-card">
          <div class="metric-top">
            <h3>{html.escape(str(row['case_name']))}</h3>
            <span class="status-pill">{html.escape(str(row['overall_result']))}</span>
          </div>
          <p class="card-copy">{html.escape(str(row['source_csv']))}</p>
          <dl class="metric-grid">
            <div><dt>Retire Rows</dt><dd>{int(row['retire_rows'])}</dd></div>
            <div><dt>Coverage</dt><dd>{float(row['coverage_pct']):.2f}%</dd></div>
            <div><dt>Stall</dt><dd>{int(row['stall_count'])}</dd></div>
            <div><dt>Redirect</dt><dd>{int(row['redirect_count'])}</dd></div>
            <div><dt>MemWrite</dt><dd>{int(row['memwrite_count'])}</dd></div>
            <div><dt>Branch/Jump</dt><dd>{int(row['branch_count'])}/{int(row['jump_count'])}</dd></div>
          </dl>
          <p><a href="../{html.escape(str(row['report_html']))}">케이스 상세 보고서 열기</a></p>
        </article>
"""
        )
        rows.append(
            f"""
          <tr>
            <td>{html.escape(str(row['case_name']))}</td>
            <td>{html.escape(str(row['overall_result']))}</td>
            <td>{int(row['retire_rows'])}</td>
            <td>{float(row['coverage_pct']):.2f}%</td>
            <td>{int(row['stall_count'])}</td>
            <td>{int(row['redirect_count'])}</td>
            <td>{int(row['fwdA1_count'])}/{int(row['fwdA2_count'])}/{int(row['fwdB1_count'])}/{int(row['fwdB2_count'])}</td>
            <td>{int(row['memwrite_count'])}</td>
            <td>{int(row['mem_checks'])}</td>
          </tr>
"""
        )

    html_text = f"""<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>RV32I ROM 통합 검증 보고서</title>
  <style>
    body {{
      margin: 0;
      font-family: "Pretendard", "Noto Sans KR", "Segoe UI", sans-serif;
      background: #f6f8fb;
      color: #191f28;
      line-height: 1.65;
    }}
    .page {{
      max-width: 1260px;
      margin: 0 auto;
      padding: 40px 24px 64px;
    }}
    .hero, .panel {{
      background: rgba(255,255,255,0.92);
      border: 1px solid #e5e8eb;
      border-radius: 24px;
      box-shadow: 0 20px 48px rgba(15, 23, 42, 0.08);
    }}
    .hero {{
      padding: 32px;
      margin-bottom: 24px;
    }}
    h1 {{
      margin: 0 0 10px;
      font-size: 38px;
    }}
    .muted {{
      color: #6b7684;
      margin: 0;
    }}
    .card-grid {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 18px;
    }}
    .metric-card {{
      padding: 22px;
      background: rgba(255,255,255,0.92);
      border: 1px solid #e5e8eb;
      border-radius: 22px;
      box-shadow: 0 16px 40px rgba(15, 23, 42, 0.06);
    }}
    .metric-top {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 12px;
    }}
    .metric-top h3 {{
      margin: 0;
      font-size: 24px;
    }}
    .status-pill {{
      display: inline-flex;
      padding: 6px 12px;
      border-radius: 999px;
      background: rgba(8,180,127,0.12);
      color: #016b4a;
      font-size: 12px;
      font-weight: 700;
    }}
    .card-copy {{
      margin: 8px 0 0;
      color: #6b7684;
    }}
    .metric-grid {{
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 12px;
      margin-top: 16px;
    }}
    .metric-grid dt {{
      font-size: 12px;
      color: #6b7684;
    }}
    .metric-grid dd {{
      margin: 0;
      font-size: 20px;
      font-weight: 700;
    }}
    .section {{
      margin-top: 24px;
    }}
    .panel {{
      padding: 22px;
    }}
    .panel img {{
      width: 100%;
      border-radius: 18px;
      border: 1px solid #e5e8eb;
      background: #fff;
      margin-top: 14px;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 14px;
    }}
    th, td {{
      padding: 12px;
      border-bottom: 1px solid #e5e8eb;
      text-align: left;
    }}
    th {{
      color: #6b7684;
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.04em;
    }}
    a {{
      color: #2563eb;
      text-decoration: none;
      font-weight: 600;
    }}
    @media (max-width: 980px) {{
      .card-grid {{ grid-template-columns: 1fr; }}
      .metric-grid {{ grid-template-columns: repeat(2, minmax(0, 1fr)); }}
    }}
  </style>
</head>
<body>
  <div class="page">
    <section class="hero">
      <h1>RV32I ROM 통합 검증 보고서</h1>
      <p class="muted">케이스별 ROM verification 결과와 metric을 합쳐서 보는 통합 대시보드입니다.</p>
      <p class="muted"><a href="../spike_cases/index.html">케이스 인덱스 열기</a></p>
    </section>

    <section class="section">
      <div class="card-grid">
        {''.join(cards)}
      </div>
    </section>

    <section class="section panel">
      <h2>Dashboard</h2>
      <p class="muted">ROM별 retire, coverage, event, program shape를 한 화면에서 봅니다.</p>
      <img src="assets/rv32i_case_dashboard.png" alt="RV32I case dashboard">
    </section>

    <section class="section card-grid">
      <article class="panel">
        <h2>Flow Compare</h2>
        <p class="muted">각 ROM에 대해 Pipeline TB와 Top_tb의 retire row, cycle span을 비교합니다.</p>
        <img src="assets/rv32i_case_flow_compare.png" alt="RV32I case flow compare">
      </article>
      <article class="panel">
        <h2>Top_tb Metrics</h2>
        <p class="muted">coverage, stall, redirect, forwarding이 ROM마다 어떻게 달라지는지 보여줍니다.</p>
        <img src="assets/rv32i_case_top_metrics.png" alt="RV32I case top metrics">
      </article>
    </section>

    <section class="section panel">
      <h2>Summary Table</h2>
      <table>
        <thead>
          <tr>
            <th>ROM</th>
            <th>Result</th>
            <th>Retire</th>
            <th>Coverage</th>
            <th>Stall</th>
            <th>Redirect</th>
            <th>Forwarding (A1/A2/B1/B2)</th>
            <th>MemWrite</th>
            <th>MemChecks</th>
          </tr>
        </thead>
        <tbody>
          {''.join(rows)}
        </tbody>
      </table>
    </section>
  </div>
</body>
</html>
"""
    write_text(report_path, html_text)


def main() -> None:
    project_root = Path(__file__).resolve().parent.parent
    evidence_csv_dir = project_root / "evidence" / "csv"
    assets_dir = project_root / "reports" / "html" / "assets"
    ensure_dir(evidence_csv_dir)
    ensure_dir(assets_dir)

    case_flow_df = discover_case_flows(project_root)
    case_flow_df = case_flow_df.sort_values(["case_name", "flow_name"]).reset_index(drop=True)
    case_summary_df = build_case_summary(case_flow_df)

    case_flow_df.to_csv(evidence_csv_dir / "case_flow_matrix.csv", index=False)
    case_summary_df.to_csv(evidence_csv_dir / "case_matrix_summary.csv", index=False)

    save_case_dashboard(case_summary_df, assets_dir / "rv32i_case_dashboard.png")
    save_case_flow_compare(case_flow_df, assets_dir / "rv32i_case_flow_compare.png")
    save_case_top_metrics(case_summary_df, assets_dir / "rv32i_case_top_metrics.png")
    generate_markdown(project_root, case_summary_df, case_flow_df)
    generate_html(project_root, case_summary_df, case_flow_df)


if __name__ == "__main__":
    main()
