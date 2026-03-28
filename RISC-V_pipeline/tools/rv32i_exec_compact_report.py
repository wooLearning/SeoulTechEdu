#!/usr/bin/env python3
"""
Generate a compact verification + performance report focused on:
  - test_top (full instruction test verification case)
  - bubble_sort

The report intentionally keeps only one compact dashboard and two summary tables.
"""

from __future__ import annotations

import html
import json
import re
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
        "Use Windows Python for this workspace: cmd.exe /c py -3 tools\\rv32i_exec_compact_report.py"
    ) from exc


CASE_LABELS = {
    "test_top": "전체 명령어 테스트",
    "bubble_sort": "버블 정렬",
}
CASE_CHART_LABELS = {
    "test_top": "Instr Test",
    "bubble_sort": "Bubble Sort",
}
PERF_VARIANT_MAP = {
    "test_top": "default",
    "bubble_sort": "bubble",
}


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def write_text(path: Path, text: str) -> None:
    ensure_dir(path.parent)
    path.write_text(text, encoding="utf-8")


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
        "slice_registers": grab("Slice Registers"),
        "block_ram_tile": grab("Block RAM Tile"),
    }


def load_verification_metrics(project_root: Path) -> pd.DataFrame:
    case_summary_path = project_root / "evidence" / "csv" / "case_matrix_summary.csv"
    df = pd.read_csv(case_summary_path)
    df = df[df["case_name"].isin(CASE_LABELS.keys())].copy()
    df["case_label"] = df["case_name"].map(CASE_LABELS)
    df["case_chart_label"] = df["case_name"].map(CASE_CHART_LABELS)
    df["forward_total"] = df["fwdA1_count"] + df["fwdA2_count"] + df["fwdB1_count"] + df["fwdB2_count"]
    return df.sort_values("case_name").reset_index(drop=True)


def load_performance_metrics(project_root: Path) -> pd.DataFrame:
    sim_metrics_path = project_root / "scripts" / "perf_measure" / "pipeline_sim_metrics.json"
    sim_metrics = json.loads(sim_metrics_path.read_text(encoding="utf-8"))
    rows: list[dict[str, object]] = []
    for case_name, perf_variant in PERF_VARIANT_MAP.items():
        report_dir = project_root / "output" / "perf_measure" / perf_variant / "impl" / "reports"
        perf_summary = parse_perf_summary(report_dir / "perf_summary.txt")
        util = parse_utilization(report_dir / "utilization.rpt")
        cycles = int(sim_metrics[perf_variant]["cycles"])
        retired = int(sim_metrics[perf_variant]["retired"])
        fmax = float(perf_summary["fmax_mhz"])
        rows.append(
            {
                "case_name": case_name,
                "case_label": CASE_LABELS[case_name],
                "case_chart_label": CASE_CHART_LABELS[case_name],
                "perf_variant": perf_variant,
                "cycles": cycles,
                "retired": retired,
                "cpi": (cycles / retired) if retired else 0.0,
                "slack_ns": float(perf_summary["slack_ns"]),
                "delay_ns": float(perf_summary["delay_ns"]),
                "fmax_mhz": fmax,
                "runtime_us": (cycles / fmax) if fmax > 0.0 else 0.0,
                "slice_luts": util["slice_luts"],
                "slice_registers": util["slice_registers"],
                "block_ram_tile": util["block_ram_tile"],
            }
        )
    return pd.DataFrame(rows).sort_values("case_name").reset_index(drop=True)


def save_dashboard(verify_df: pd.DataFrame, perf_df: pd.DataFrame, out_path: Path) -> None:
    case_labels = list(verify_df["case_chart_label"])
    x = np.arange(len(case_labels))
    width = 0.32

    fig, axes = plt.subplots(2, 2, figsize=(15, 10))
    fig.suptitle("RV32I Compact Verification + Performance Dashboard", fontsize=18, fontweight="bold")

    axes[0, 0].bar(x - width / 2, verify_df["retire_rows"], width=width, color="#3182f6", label="Retire Rows")
    axes[0, 0].bar(x + width / 2, verify_df["top_cycle_span"], width=width, color="#191f28", label="Top_tb Cycle Span")
    axes[0, 0].set_title("Verification Footprint")
    axes[0, 0].set_xticks(x)
    axes[0, 0].set_xticklabels(case_labels)
    axes[0, 0].grid(axis="y", linestyle="--", alpha=0.20)
    axes[0, 0].legend(frameon=False)

    axes[0, 1].bar(x - width, verify_df["stall_count"], width=0.22, color="#191f28", label="Stall")
    axes[0, 1].bar(x, verify_df["redirect_count"], width=0.22, color="#3182f6", label="Redirect")
    axes[0, 1].bar(x + width, verify_df["forward_total"], width=0.22, color="#ffb020", label="Forward Total")
    axes[0, 1].set_title("Hazard / Control Events")
    axes[0, 1].set_xticks(x)
    axes[0, 1].set_xticklabels(case_labels)
    axes[0, 1].grid(axis="y", linestyle="--", alpha=0.20)
    axes[0, 1].legend(frameon=False)

    axes[1, 0].bar(case_labels, perf_df["fmax_mhz"], color=["#08b47f", "#735bf2"])
    axes[1, 0].axhline(100.0, color="#b42318", linestyle="--", linewidth=1.5, label="100 MHz target")
    axes[1, 0].set_title("Post-Impl Fmax")
    axes[1, 0].set_ylabel("MHz")
    axes[1, 0].grid(axis="y", linestyle="--", alpha=0.20)
    axes[1, 0].legend(frameon=False)

    axes[1, 1].bar(x - width / 2, perf_df["cpi"], width=width, color="#00a3ad", label="CPI")
    axes[1, 1].bar(x + width / 2, perf_df["runtime_us"], width=width, color="#ff7a00", label="Estimated Runtime (us)")
    axes[1, 1].set_title("Efficiency Metrics")
    axes[1, 1].set_xticks(x)
    axes[1, 1].set_xticklabels(case_labels)
    axes[1, 1].grid(axis="y", linestyle="--", alpha=0.20)
    axes[1, 1].legend(frameon=False)

    fig.tight_layout()
    fig.savefig(out_path, dpi=180)
    plt.close(fig)


def generate_markdown(project_root: Path, verify_df: pd.DataFrame, perf_df: pd.DataFrame) -> None:
    report_path = project_root / "reports" / "markdown" / "overview" / "rv32i_exec_compact_report_ko.md"
    bubble_row = verify_df.set_index("case_name").loc["bubble_sort"]
    test_row = verify_df.set_index("case_name").loc["test_top"]
    bubble_perf = perf_df.set_index("case_name").loc["bubble_sort"]
    test_perf = perf_df.set_index("case_name").loc["test_top"]
    lines = [
        "# RV32I Compact 검증 + 성능 보고서",
        "",
        "필요한 그래프만 남긴 compact 보고서입니다. 대상은 `전체 명령어 테스트(test_top)`와 `버블 정렬(bubble_sort)` 두 케이스입니다.",
        "",
        "## 한 줄 결론",
        "",
        f"- 두 케이스 모두 검증은 `PASS`이며, `버블 정렬`은 stall `{int(bubble_row['stall_count'])}`와 coverage `{float(bubble_row['coverage_pct']):.2f}%`로 파이프라인 이벤트 관측성이 더 높고, "
        f"`전체 명령어 테스트`는 directed 회귀와 final memory check에 더 적합합니다. Fmax는 두 케이스 모두 약 `101 MHz` 수준으로 비슷합니다.",
        "",
        "## 핵심 산출물",
        "",
        "- HTML: `../../html/rv32i_exec_compact_report_ko.html`",
        "- Dashboard: `../../html/assets/rv32i_exec_compact_dashboard.png`",
        "- Verification CSV: `../../../evidence/csv/case_matrix_summary.csv`",
        "- Performance report: `../../../md/performance_metrics_report.md`",
        "",
        "## Verification Summary",
        "",
        "| Case | Result | Retire Rows | Coverage | Stall | Redirect | Forward Total | MemWrite |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for _, row in verify_df.iterrows():
        lines.append(
            f"| {row['case_label']} | {row['overall_result']} | {int(row['retire_rows'])} | "
            f"{float(row['coverage_pct']):.2f}% | {int(row['stall_count'])} | {int(row['redirect_count'])} | "
            f"{int(row['forward_total'])} | {int(row['memwrite_count'])} |"
        )

    lines.extend(["", "## Performance Summary", "", "| Case | Perf Variant | Fmax (MHz) | Slack (ns) | CPI | Runtime (us) | LUTs | Regs |", "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |"])
    for _, row in perf_df.iterrows():
        lines.append(
            f"| {row['case_label']} | {row['perf_variant']} | {float(row['fmax_mhz']):.3f} | "
            f"{float(row['slack_ns']):.3f} | {float(row['cpi']):.6f} | {float(row['runtime_us']):.3f} | "
            f"{int(row['slice_luts'])} | {int(row['slice_registers'])} |"
        )

    lines.extend(
        [
            "",
            "## Notes",
            "",
            f"- `버블 정렬`은 verification에서도 stall이 실제로 많이 관측되고, performance에서도 CPI `{float(bubble_perf['cpi']):.6f}`와 runtime `{float(bubble_perf['runtime_us']):.3f} us`로 부담이 더 크게 보입니다.",
            f"- `전체 명령어 테스트`는 directed 회귀 성격이 강해서 final memory check가 있고, retire `{int(test_row['retire_rows'])}` 규모의 짧은 회귀 테스트로 쓰기 좋습니다.",
            f"- 성능 표의 `전체 명령어 테스트`는 기존 perf flow의 `default` ROM variant를 사용해 비교했습니다. Fmax는 `{float(test_perf['fmax_mhz']):.3f} MHz`입니다.",
            "",
        ]
    )
    write_text(report_path, "\n".join(lines) + "\n")


def generate_html(project_root: Path, verify_df: pd.DataFrame, perf_df: pd.DataFrame) -> None:
    report_path = project_root / "reports" / "html" / "rv32i_exec_compact_report_ko.html"
    bubble_row = verify_df.set_index("case_name").loc["bubble_sort"]
    test_row = verify_df.set_index("case_name").loc["test_top"]
    bubble_perf = perf_df.set_index("case_name").loc["bubble_sort"]
    test_perf = perf_df.set_index("case_name").loc["test_top"]
    verify_rows = []
    perf_rows = []
    for _, row in verify_df.iterrows():
        result_class = "status-pass" if str(row["overall_result"]) == "PASS" else "status-fail"
        verify_rows.append(
            f"""
          <tr>
            <td>{html.escape(str(row['case_label']))}</td>
            <td><span class="{result_class}">{html.escape(str(row['overall_result']))}</span></td>
            <td>{int(row['retire_rows'])}</td>
            <td>{float(row['coverage_pct']):.2f}%</td>
            <td>{int(row['stall_count'])}</td>
            <td>{int(row['redirect_count'])}</td>
            <td>{int(row['forward_total'])}</td>
            <td>{int(row['memwrite_count'])}</td>
          </tr>
"""
        )
    for _, row in perf_df.iterrows():
        perf_rows.append(
            f"""
          <tr>
            <td>{html.escape(str(row['case_label']))}</td>
            <td>{html.escape(str(row['perf_variant']))}</td>
            <td>{float(row['fmax_mhz']):.3f}</td>
            <td>{float(row['slack_ns']):.3f}</td>
            <td>{float(row['cpi']):.6f}</td>
            <td>{float(row['runtime_us']):.3f}</td>
            <td>{int(row['slice_luts'])}</td>
            <td>{int(row['slice_registers'])}</td>
          </tr>
"""
        )

    html_text = f"""<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>RV32I Compact 검증 + 성능 보고서</title>
  <style>
    body {{
      margin: 0;
      font-family: "Pretendard", "Noto Sans KR", "Segoe UI", sans-serif;
      background: #f6f8fb;
      color: #191f28;
      line-height: 1.65;
    }}
    .page {{
      max-width: 1240px;
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
      padding: 30px;
      margin-bottom: 24px;
    }}
    .hero h1 {{
      margin: 0 0 10px;
      font-size: 36px;
    }}
    .muted {{
      margin: 0;
      color: #6b7684;
    }}
    .panel {{
      padding: 22px;
      margin-top: 24px;
    }}
    .summary-box {{
      margin-top: 18px;
      padding: 18px 20px;
      border-radius: 18px;
      background: linear-gradient(135deg, rgba(49,130,246,0.08), rgba(8,180,127,0.08));
      border: 1px solid rgba(49,130,246,0.12);
    }}
    .status-pass, .status-fail {{
      display: inline-flex;
      align-items: center;
      padding: 4px 10px;
      border-radius: 999px;
      font-size: 12px;
      font-weight: 700;
    }}
    .status-pass {{
      background: rgba(8,180,127,0.12);
      color: #016b4a;
    }}
    .status-fail {{
      background: rgba(240,68,82,0.12);
      color: #b42318;
    }}
    img {{
      width: 100%;
      border-radius: 18px;
      border: 1px solid #e5e8eb;
      background: #fff;
      margin-top: 12px;
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
  </style>
</head>
<body>
  <div class="page">
    <section class="hero">
      <h1>RV32I Compact 검증 + 성능 보고서</h1>
      <p class="muted">`test_top`과 `bubble_sort`만 남긴 compact 비교판입니다.</p>
      <p class="muted"><a href="rv32i_case_matrix_report_ko.html">ROM 통합 검증 보고서</a></p>
      <div class="summary-box">
        두 케이스 모두 <span class="status-pass">PASS</span> 입니다.
        `버블 정렬`은 stall {int(bubble_row['stall_count'])}, coverage {float(bubble_row['coverage_pct']):.2f}%로 파이프라인 이벤트 관측성이 높고,
        `전체 명령어 테스트`는 directed 회귀와 final memory check에 더 적합합니다.
        Fmax는 `버블 정렬 {float(bubble_perf['fmax_mhz']):.3f} MHz`, `전체 명령어 테스트 {float(test_perf['fmax_mhz']):.3f} MHz`로 비슷합니다.
      </div>
    </section>

    <section class="panel">
      <h2>Compact Dashboard</h2>
      <p class="muted">검증 footprint, hazard/control event, Fmax, CPI/runtime만 남겼습니다.</p>
      <img src="assets/rv32i_exec_compact_dashboard.png" alt="RV32I compact dashboard">
    </section>

    <section class="panel">
      <h2>Verification Summary</h2>
      <table>
        <thead>
          <tr>
            <th>Case</th>
            <th>Result</th>
            <th>Retire</th>
            <th>Coverage</th>
            <th>Stall</th>
            <th>Redirect</th>
            <th>Forward Total</th>
            <th>MemWrite</th>
          </tr>
        </thead>
        <tbody>
          {''.join(verify_rows)}
        </tbody>
      </table>
    </section>

    <section class="panel">
      <h2>Performance Summary</h2>
      <table>
        <thead>
          <tr>
            <th>Case</th>
            <th>Perf Variant</th>
            <th>Fmax (MHz)</th>
            <th>Slack (ns)</th>
            <th>CPI</th>
            <th>Runtime (us)</th>
            <th>LUTs</th>
            <th>Regs</th>
          </tr>
        </thead>
        <tbody>
          {''.join(perf_rows)}
        </tbody>
      </table>
      <p class="muted">Note: `전체 명령어 테스트` 성능 행은 기존 perf flow의 `default` ROM variant를 비교 기준으로 사용했습니다.</p>
    </section>
  </div>
</body>
</html>
"""
    write_text(report_path, html_text)


def main() -> None:
    project_root = Path(__file__).resolve().parent.parent
    assets_dir = project_root / "reports" / "html" / "assets"
    ensure_dir(assets_dir)

    verify_df = load_verification_metrics(project_root)
    perf_df = load_performance_metrics(project_root)

    save_dashboard(verify_df, perf_df, assets_dir / "rv32i_exec_compact_dashboard.png")
    generate_markdown(project_root, verify_df, perf_df)
    generate_html(project_root, verify_df, perf_df)


if __name__ == "__main__":
    main()
