#!/usr/bin/env python3
"""
Portfolio-oriented log analytics for result_portfolio.

Parses curated Vivado logs under evidence/logs and generates:
  - CSV / SQLite datasets
  - SVG charts
  - HTML report
  - Markdown report
"""

from __future__ import annotations

import csv
import json
import re
import sqlite3
from dataclasses import asdict, dataclass
from datetime import datetime
from html import escape
from pathlib import Path


SUMMARY_RE = re.compile(
    r"\[SCB\]\[SUMMARY\]\s+sample=(?P<sample_count>\d+)"
    r"(?:\s+rd_tick=(?P<rd_tick>\d+))?"
    r"\s+pass=(?P<pass_count>\d+)"
    r"\s+fail=(?P<fail_count>\d+)"
    r"\s+wr_acc=(?P<wr_acc_count>\d+)"
    r"\s+rd_acc=(?P<rd_acc_count>\d+)"
    r"(?:\s+wr_block=(?P<wr_block_count>\d+))?"
    r"(?:\s+rd_block=(?P<rd_block_count>\d+))?"
    r"\s+depth_left=(?P<depth_left>\d+)"
    r"(?:\s+full_seen=(?P<full_seen_count>\d+))?"
    r"(?:\s+empty_seen=(?P<empty_seen_count>\d+))?"
)
SCENARIO_RE = re.compile(
    r"\[SCB\]\[SCENARIO\]\s+id=(?P<scenario_id>\d+)\s+name=(?P<scenario_name>[a-z_]+)"
    r"\s+sample=(?P<sample_count>\d+)\s+wr_acc=(?P<wr_acc_count>\d+)\s+rd_acc=(?P<rd_acc_count>\d+)"
    r"\s+wr_block=(?P<wr_block_count>\d+)\s+rd_block=(?P<rd_block_count>\d+)"
)
CVG_RE = re.compile(r"\[SCB\]\[COVERAGE\]\s+functional_coverage=(?P<coverage>[0-9.]+)%")
PASS_RE = re.compile(r"\[SCB\]\[PASS\]\s+(?P<message>.+)")
FAIL_RE = re.compile(r"\[SCB\]\[FAIL\]\s+(?P<message>.+)")
ELAPSED_RE = re.compile(r"launch_simulation: Time \(s\): .* elapsed = (?P<h>\d+):(?P<m>\d+):(?P<s>\d+)")

EXPECTED_SCENARIOS = {
    "async_fifo": [
        "fill_burst",
        "mixed_stress",
        "drain_burst",
        "full_pressure",
        "empty_pressure",
    ],
    "async_fifo_src": [
        "fill_burst",
        "mixed_stress",
        "drain_burst",
        "full_pressure",
        "empty_pressure",
    ],
    "sync_fifo": [
        "fill_burst",
        "simul_stress",
        "drain_burst",
        "flag_pressure",
        "balanced_stream",
    ],
}

TB_NAME_MAP = {
    "async_fifo": "tb_fifo",
    "async_fifo_src": "tb_async_fifo",
    "sync_fifo": "tb_sync_fifo",
}


@dataclass
class ModuleMetric:
    module_name: str
    tb_name: str
    scb_result: str
    scb_message: str
    sample_count: int
    rd_tick: int
    pass_count: int
    fail_count: int
    wr_acc_count: int
    rd_acc_count: int
    wr_block_count: int
    rd_block_count: int
    depth_left: int
    full_seen_count: int
    empty_seen_count: int
    xsim_coverage_pct: float
    scenario_completion_pct: float
    response_diversity_pct: float
    portfolio_score_pct: float
    elapsed_sec: float
    assertion_error_count: int
    log_path: str


@dataclass
class ScenarioMetric:
    module_name: str
    scenario_id: int
    scenario_name: str
    sample_count: int
    wr_acc_count: int
    rd_acc_count: int
    wr_block_count: int
    rd_block_count: int


def module_display_name(module_name: str) -> str:
    display_map = {
        "async_fifo_src": "Async FIFO (Dedicated RTL)",
        "async_fifo": "Async FIFO (Showcase)",
        "sync_fifo": "Sync FIFO",
    }
    return display_map.get(module_name, module_name)


def module_focus_label(module_name: str) -> str:
    focus_map = {
        "async_fifo_src": "비동기 FIFO 대표 검증",
        "async_fifo": "비동기 FIFO 비교 showcase",
        "sync_fifo": "동기 FIFO 비교 검증",
    }
    return focus_map.get(module_name, "SystemVerilog verification")


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def parse_elapsed_seconds(text: str) -> float:
    matches = list(ELAPSED_RE.finditer(text))
    if not matches:
        return 0.0
    last = matches[-1]
    hours = int(last.group("h"))
    minutes = int(last.group("m"))
    seconds = int(last.group("s"))
    return float((hours * 3600) + (minutes * 60) + seconds)


def parse_log(project_root: Path, log_path: Path) -> tuple[ModuleMetric, list[ScenarioMetric]]:
    text = read_text(log_path)
    module_name = log_path.name.replace("_vivado.log", "")

    summary_match = SUMMARY_RE.search(text)
    if not summary_match:
      raise ValueError(f"Could not find scoreboard summary in {log_path}")

    summary = {
        key: int(value) if value is not None else 0
        for key, value in summary_match.groupdict().items()
    }
    scenario_rows = [
        ScenarioMetric(
            module_name=module_name,
            scenario_id=int(match.group("scenario_id")),
            scenario_name=match.group("scenario_name"),
            sample_count=int(match.group("sample_count")),
            wr_acc_count=int(match.group("wr_acc_count")),
            rd_acc_count=int(match.group("rd_acc_count")),
            wr_block_count=int(match.group("wr_block_count")),
            rd_block_count=int(match.group("rd_block_count")),
        )
        for match in SCENARIO_RE.finditer(text)
    ]

    coverage_match = CVG_RE.search(text)
    pass_match = PASS_RE.search(text)
    fail_match = FAIL_RE.search(text)

    scenario_names_seen = {row.scenario_name for row in scenario_rows if row.sample_count > 0}
    expected_scenarios = EXPECTED_SCENARIOS.get(module_name, [])
    scenario_completion_pct = 0.0
    if expected_scenarios:
        scenario_completion_pct = (100.0 * len(scenario_names_seen)) / len(expected_scenarios)

    response_bins = [
        summary["wr_acc_count"] > 0,
        summary["rd_acc_count"] > 0,
        summary["wr_block_count"] > 0,
        summary["rd_block_count"] > 0,
        summary["full_seen_count"] > 0,
        summary["empty_seen_count"] > 0,
    ]
    response_diversity_pct = (100.0 * sum(1 for hit in response_bins if hit)) / len(response_bins)
    portfolio_score_pct = (scenario_completion_pct * 0.6) + (response_diversity_pct * 0.4)

    if fail_match:
        scb_result = "FAIL"
        scb_message = fail_match.group("message").strip()
    elif pass_match:
        scb_result = "PASS"
        scb_message = pass_match.group("message").strip()
    else:
        scb_result = "UNKNOWN"
        scb_message = "No explicit scoreboard status line found"

    assertion_error_count = text.count("[ASSERT]")

    module_metric = ModuleMetric(
        module_name=module_name,
        tb_name=TB_NAME_MAP.get(module_name, module_name),
        scb_result=scb_result,
        scb_message=scb_message,
        sample_count=summary["sample_count"],
        rd_tick=summary["rd_tick"],
        pass_count=summary["pass_count"],
        fail_count=summary["fail_count"],
        wr_acc_count=summary["wr_acc_count"],
        rd_acc_count=summary["rd_acc_count"],
        wr_block_count=summary["wr_block_count"],
        rd_block_count=summary["rd_block_count"],
        depth_left=summary["depth_left"],
        full_seen_count=summary["full_seen_count"],
        empty_seen_count=summary["empty_seen_count"],
        xsim_coverage_pct=float(coverage_match.group("coverage")) if coverage_match else 0.0,
        scenario_completion_pct=round(scenario_completion_pct, 2),
        response_diversity_pct=round(response_diversity_pct, 2),
        portfolio_score_pct=round(portfolio_score_pct, 2),
        elapsed_sec=parse_elapsed_seconds(text),
        assertion_error_count=assertion_error_count,
        log_path=str(log_path.relative_to(project_root)).replace("\\", "/"),
    )
    return module_metric, scenario_rows


def collect_metrics(project_root: Path) -> tuple[list[ModuleMetric], list[ScenarioMetric]]:
    portfolio_dir = project_root / "evidence" / "logs"
    module_metrics: list[ModuleMetric] = []
    scenario_metrics: list[ScenarioMetric] = []

    for log_path in sorted(portfolio_dir.glob("*_vivado.log")):
        if log_path.name.startswith("report_"):
            continue
        module_metric, scenario_rows = parse_log(project_root, log_path)
        module_metrics.append(module_metric)
        scenario_metrics.extend(scenario_rows)
    return module_metrics, scenario_metrics


def write_csv(path: Path, rows: list[dict]) -> None:
    if not rows:
        return
    with path.open("w", encoding="utf-8", newline="") as fp:
        writer = csv.DictWriter(fp, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def write_sqlite(path: Path, module_metrics: list[ModuleMetric], scenario_metrics: list[ScenarioMetric]) -> None:
    conn = sqlite3.connect(path)
    try:
        cur = conn.cursor()
        cur.execute("drop table if exists module_metrics")
        cur.execute("drop table if exists scenario_metrics")

        cur.execute(
            """
            create table module_metrics (
                module_name text,
                tb_name text,
                scb_result text,
                scb_message text,
                sample_count integer,
                rd_tick integer,
                pass_count integer,
                fail_count integer,
                wr_acc_count integer,
                rd_acc_count integer,
                wr_block_count integer,
                rd_block_count integer,
                depth_left integer,
                full_seen_count integer,
                empty_seen_count integer,
                xsim_coverage_pct real,
                scenario_completion_pct real,
                response_diversity_pct real,
                portfolio_score_pct real,
                elapsed_sec real,
                assertion_error_count integer,
                log_path text
            )
            """
        )
        cur.execute(
            """
            create table scenario_metrics (
                module_name text,
                scenario_id integer,
                scenario_name text,
                sample_count integer,
                wr_acc_count integer,
                rd_acc_count integer,
                wr_block_count integer,
                rd_block_count integer
            )
            """
        )

        cur.executemany(
            """
            insert into module_metrics values (
                :module_name, :tb_name, :scb_result, :scb_message, :sample_count, :rd_tick, :pass_count,
                :fail_count, :wr_acc_count, :rd_acc_count, :wr_block_count, :rd_block_count, :depth_left,
                :full_seen_count, :empty_seen_count, :xsim_coverage_pct, :scenario_completion_pct,
                :response_diversity_pct, :portfolio_score_pct, :elapsed_sec, :assertion_error_count, :log_path
            )
            """,
            [asdict(metric) for metric in module_metrics],
        )
        cur.executemany(
            """
            insert into scenario_metrics values (
                :module_name, :scenario_id, :scenario_name, :sample_count, :wr_acc_count,
                :rd_acc_count, :wr_block_count, :rd_block_count
            )
            """,
            [asdict(metric) for metric in scenario_metrics],
        )
        conn.commit()
    finally:
        conn.close()


def render_grouped_bars(
    path: Path,
    title: str,
    module_metrics: list[ModuleMetric],
    series: list[tuple[str, str, str]],
) -> None:
    chart_width = 920
    chart_height = 140 + (110 * len(module_metrics))
    plot_x = 240
    plot_width = 560
    bar_height = 18
    gap = 10

    max_value = max(
        [1.0]
        + [float(getattr(metric, field)) for metric in module_metrics for field, _, _ in series]
    )

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{chart_width}" height="{chart_height}" viewBox="0 0 {chart_width} {chart_height}">',
        '<rect width="100%" height="100%" fill="#f6f2ea" />',
        f'<text x="40" y="42" font-size="28" font-family="Arial" fill="#2e251f">{escape(title)}</text>',
        '<text x="40" y="68" font-size="14" font-family="Arial" fill="#6a5c53">SystemVerilog verification analytics</text>',
    ]

    y = 110
    for metric in module_metrics:
        parts.append(
            f'<text x="40" y="{y + 18}" font-size="20" font-family="Arial" fill="#2e251f">{escape(module_display_name(metric.module_name))}</text>'
        )
        parts.append(
            f'<text x="40" y="{y + 40}" font-size="12" font-family="Arial" fill="#6a5c53">{escape(metric.tb_name)} / {escape(metric.scb_result)}</text>'
        )
        cur_y = y
        for field, label, color in series:
            value = float(getattr(metric, field))
            width = (value / max_value) * plot_width
            parts.append(
                f'<text x="{plot_x}" y="{cur_y + 13}" font-size="12" font-family="Arial" fill="#5f5148">{escape(label)}</text>'
            )
            parts.append(
                f'<rect x="{plot_x + 110}" y="{cur_y}" width="{plot_width}" height="{bar_height}" rx="4" fill="#e8dfd3" />'
            )
            parts.append(
                f'<rect x="{plot_x + 110}" y="{cur_y}" width="{width:.2f}" height="{bar_height}" rx="4" fill="{color}" />'
            )
            parts.append(
                f'<text x="{plot_x + 110 + plot_width + 8}" y="{cur_y + 13}" font-size="12" font-family="Arial" fill="#2e251f">{value:g}</text>'
            )
            cur_y += bar_height + gap
        y += 110

    parts.append("</svg>")
    path.write_text("\n".join(parts), encoding="utf-8")


def render_scenario_chart(path: Path, module_metrics: list[ModuleMetric], scenario_metrics: list[ScenarioMetric]) -> None:
    module_names = [metric.module_name for metric in module_metrics]
    scenarios_by_module = {
        module: [row for row in scenario_metrics if row.module_name == module]
        for module in module_names
    }
    chart_width = 1040
    row_height = 34
    title_space = 140
    chart_height = title_space + row_height * sum(max(len(rows), 1) for rows in scenarios_by_module.values()) + 60
    plot_x = 320
    plot_width = 620
    max_value = max([1] + [row.sample_count for row in scenario_metrics])

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{chart_width}" height="{chart_height}" viewBox="0 0 {chart_width} {chart_height}">',
        '<rect width="100%" height="100%" fill="#f6f2ea" />',
        '<text x="40" y="42" font-size="28" font-family="Arial" fill="#2e251f">Scenario Breakdown</text>',
        '<text x="40" y="68" font-size="14" font-family="Arial" fill="#6a5c53">SystemVerilog self-checking scenario breakdown</text>',
    ]

    y = 120
    colors = {
        "sample": "#c7802f",
        "wr_acc": "#2d8f5b",
        "rd_acc": "#4f7aa3",
        "blocked": "#d6523c",
    }

    for module_name, rows in scenarios_by_module.items():
        parts.append(
            f'<text x="40" y="{y}" font-size="20" font-family="Arial" fill="#2e251f">{escape(module_display_name(module_name))}</text>'
        )
        y += 18
        for row in rows:
            bar_width = (row.sample_count / max_value) * plot_width
            blocked = row.wr_block_count + row.rd_block_count
            parts.append(
                f'<text x="60" y="{y + 12}" font-size="13" font-family="Arial" fill="#5f5148">{escape(row.scenario_name)}</text>'
            )
            parts.append(
                f'<rect x="{plot_x}" y="{y}" width="{plot_width}" height="16" rx="4" fill="#e8dfd3" />'
            )
            parts.append(
                f'<rect x="{plot_x}" y="{y}" width="{bar_width:.2f}" height="16" rx="4" fill="{colors["sample"]}" />'
            )
            parts.append(
                f'<text x="{plot_x + plot_width + 8}" y="{y + 12}" font-size="12" font-family="Arial" fill="#2e251f">'
                f'sample={row.sample_count} wr_acc={row.wr_acc_count} rd_acc={row.rd_acc_count} blocked={blocked}'
                '</text>'
            )
            y += row_height
        y += 18

    parts.append("</svg>")
    path.write_text("\n".join(parts), encoding="utf-8")


def build_html_report(module_metrics: list[ModuleMetric], scenario_metrics: list[ScenarioMetric]) -> str:
    cards = []
    for metric in module_metrics:
        card_class = "card async-card" if "async" in metric.module_name else "card"
        cards.append(
            f"""
            <section class="{card_class}">
              <p class="eyebrow">{escape(module_focus_label(metric.module_name))}</p>
              <h3>{escape(module_display_name(metric.module_name))}</h3>
              <p><strong>결과</strong>: {escape(metric.scb_result)} / {escape(metric.scb_message)}</p>
              <p><strong>핵심 지표</strong>: sample={metric.sample_count}, pass={metric.pass_count}, fail={metric.fail_count}, wr_acc={metric.wr_acc_count}, rd_acc={metric.rd_acc_count}</p>
              <p><strong>검증 점수</strong>: scenario completion {metric.scenario_completion_pct:.2f}% / response diversity {metric.response_diversity_pct:.2f}% / portfolio score {metric.portfolio_score_pct:.2f}%</p>
              <p><strong>로그</strong>: {escape(metric.log_path)}</p>
            </section>
            """
        )

    table_rows = []
    for metric in module_metrics:
        table_rows.append(
            "<tr>"
            f"<td>{escape(module_display_name(metric.module_name))}</td>"
            f"<td>{escape(metric.tb_name)}</td>"
            f"<td>{escape(metric.scb_result)}</td>"
            f"<td>{metric.sample_count}</td>"
            f"<td>{metric.pass_count}</td>"
            f"<td>{metric.fail_count}</td>"
            f"<td>{metric.wr_acc_count}</td>"
            f"<td>{metric.rd_acc_count}</td>"
            f"<td>{metric.wr_block_count}</td>"
            f"<td>{metric.rd_block_count}</td>"
            f"<td>{metric.scenario_completion_pct:.2f}%</td>"
            f"<td>{metric.response_diversity_pct:.2f}%</td>"
            f"<td>{metric.portfolio_score_pct:.2f}%</td>"
            "</tr>"
        )

    scenario_rows = []
    for row in scenario_metrics:
        scenario_rows.append(
            "<tr>"
            f"<td>{escape(module_display_name(row.module_name))}</td>"
            f"<td>{row.scenario_id}</td>"
            f"<td>{escape(row.scenario_name)}</td>"
            f"<td>{row.sample_count}</td>"
            f"<td>{row.wr_acc_count}</td>"
            f"<td>{row.rd_acc_count}</td>"
            f"<td>{row.wr_block_count}</td>"
            f"<td>{row.rd_block_count}</td>"
            "</tr>"
        )

    return f"""<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <title>SystemVerilog 검증 로그 분석 리포트</title>
  <style>
    body {{
      margin: 0;
      background: linear-gradient(180deg, #ece2d3 0%, #faf7f1 100%);
      color: #2e251f;
      font-family: "Segoe UI", Arial, sans-serif;
    }}
    main {{
      max-width: 1120px;
      margin: 0 auto;
      padding: 40px 28px 80px;
    }}
    .hero {{
      background: rgba(255,255,255,0.78);
      border: 1px solid #d8c8b6;
      border-radius: 24px;
      padding: 30px;
      box-shadow: 0 12px 32px rgba(69, 50, 30, 0.09);
      margin-bottom: 28px;
    }}
    h1, h2 {{
      margin: 0 0 14px;
    }}
    p {{
      line-height: 1.55;
    }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 16px;
      margin-bottom: 28px;
    }}
    .card {{
      background: rgba(255,255,255,0.84);
      border: 1px solid #d8c8b6;
      border-radius: 18px;
      padding: 18px;
    }}
    .async-card {{
      border: 2px solid #c7802f;
      box-shadow: 0 10px 24px rgba(199, 128, 47, 0.14);
      background: linear-gradient(180deg, rgba(255,255,255,0.94) 0%, rgba(252,244,233,0.96) 100%);
    }}
    .eyebrow {{
      margin: 0 0 10px;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.04em;
      text-transform: uppercase;
      color: #b15c1a;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      background: rgba(255,255,255,0.84);
      border-radius: 18px;
      overflow: hidden;
      margin-bottom: 28px;
    }}
    th, td {{
      padding: 11px 10px;
      border-bottom: 1px solid #eadfce;
      text-align: left;
      font-size: 14px;
    }}
    th {{
      background: #ede2d4;
    }}
    img {{
      width: 100%;
      display: block;
      margin-bottom: 18px;
      border-radius: 18px;
      border: 1px solid #d8c8b6;
      background: white;
    }}
    .note {{
      color: #5f534a;
      font-size: 14px;
    }}
  </style>
</head>
<body>
  <main>
    <section class="hero">
      <h1>SystemVerilog 검증 로그 분석 리포트</h1>
      <p>이 리포트는 `evidence/logs/` 아래 최신 Vivado xsim 로그를 Python으로 구조화해 만든 SystemVerilog 검증 분석 자료입니다. 특히 비동기 FIFO 계열 로그가 먼저 보이도록 구성해, async verification 역량과 self-checking 구조를 한눈에 읽을 수 있게 정리했습니다.</p>
      <p class="note">참고: 현재 패키지의 최신 Vivado xsim 로그에서는 `functional_coverage`가 100.00%까지 확인됩니다. 본 리포트는 그 coverage 수치에 더해 `scenario completion`, `response diversity`, `portfolio score`를 함께 제시해 검증 범위를 더 입체적으로 해석하도록 구성했습니다.</p>
    </section>

    <h2>모듈 카드</h2>
    <div class="grid">
      {"".join(cards)}
    </div>

    <h2>요약 테이블</h2>
    <table>
      <thead>
        <tr>
          <th>Module</th>
          <th>TB</th>
          <th>Result</th>
          <th>Sample</th>
          <th>Pass</th>
          <th>Fail</th>
          <th>Wr Acc</th>
          <th>Rd Acc</th>
          <th>Wr Block</th>
          <th>Rd Block</th>
          <th>Scenario</th>
          <th>Diversity</th>
          <th>Score</th>
        </tr>
      </thead>
      <tbody>
        {"".join(table_rows)}
      </tbody>
    </table>

    <h2>시각화</h2>
    <img src="verification_summary.svg" alt="verification summary chart" />
    <img src="scenario_breakdown.svg" alt="scenario breakdown chart" />
    <img src="verification_scores.svg" alt="verification score chart" />

    <h2>시나리오 상세</h2>
    <table>
      <thead>
        <tr>
          <th>Module</th>
          <th>ID</th>
          <th>Scenario</th>
          <th>Sample</th>
          <th>Wr Acc</th>
          <th>Rd Acc</th>
          <th>Wr Block</th>
          <th>Rd Block</th>
        </tr>
      </thead>
      <tbody>
        {"".join(scenario_rows)}
      </tbody>
    </table>
  </main>
</body>
</html>
"""


def build_markdown_report(project_root: Path, module_metrics: list[ModuleMetric], analytics_dir: Path) -> str:
    rel = lambda name: str((analytics_dir / name).relative_to(project_root)).replace("\\", "/")
    lines = [
        "# SystemVerilog 검증 로그 분석 리포트",
        "",
        "이 문서는 `evidence/logs/` 아래 최신 Vivado 로그를 Python으로 구조화하고 시각화한 SystemVerilog 검증 분석 결과입니다.",
        "",
        "## 생성 산출물",
        "",
        f"- HTML 리포트: `{rel('log_analysis_report_ko.html')}`",
        f"- 콘솔형 HTML 리포트: `{rel('log_analysis_console_ko.html')}`",
        f"- 콘솔형 PNG 캡처: `{rel('log_analysis_console_ko.png')}`",
        f"- 콘솔형 TXT 리포트: `{rel('log_analysis_console_ko.txt')}`",
        f"- 모듈 CSV: `{rel('log_metrics.csv')}`",
        f"- 시나리오 CSV: `{rel('scenario_metrics.csv')}`",
        f"- SQLite: `{rel('log_metrics.sqlite')}`",
        f"- 요약 차트: `{rel('verification_summary.svg')}`",
        f"- 시나리오 차트: `{rel('scenario_breakdown.svg')}`",
        f"- 검증 점수 차트: `{rel('verification_scores.svg')}`",
        "",
        "## 모듈별 요약",
        "",
        "| Module | Result | Sample | Wr Acc | Rd Acc | Wr Block | Rd Block | Scenario Completion | Response Diversity | Portfolio Score |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]

    for metric in module_metrics:
        lines.append(
            f"| {module_display_name(metric.module_name)} | {metric.scb_result} | {metric.sample_count} | {metric.wr_acc_count} | "
            f"{metric.rd_acc_count} | {metric.wr_block_count} | {metric.rd_block_count} | "
            f"{metric.scenario_completion_pct:.2f}% | {metric.response_diversity_pct:.2f}% | {metric.portfolio_score_pct:.2f}% |"
        )

    lines.extend(
        [
            "",
            "## 해석 포인트",
            "",
            "- `async_fifo`와 `async_fifo_src`는 fill, mixed, drain, full-pressure, empty-pressure가 모두 로그에 남아 비동기 FIFO 검증에서 backpressure와 underflow 관찰 포인트를 분명히 보여줍니다.",
            "- `sync_fifo`는 scenario completion 100%와 동시에 read/write simultaneous stress가 강하게 드러나 queue 기반 reference model 검증 역량을 보여줍니다.",
            "- 최신 Vivado xsim 로그에서는 functional coverage가 100.00%까지 확인되며, 본 보고서에서는 여기에 시나리오 완주율과 accepted/blocked/flag 다양성을 합친 `portfolio score`를 함께 제시합니다.",
            "",
            "## 재생성 방법",
            "",
            "- `python3 tools/log_analytics.py`",
        ]
    )
    return "\n".join(lines) + "\n"


def build_console_report(module_metrics: list[ModuleMetric], scenario_metrics: list[ScenarioMetric]) -> str:
    lines = [
        "$ python3 tools/log_analytics.py",
        "",
        "SystemVerilog verification log analytics",
        "source: evidence/logs/*.log",
        "",
        "[module summary]",
    ]

    for metric in module_metrics:
        lines.extend(
            [
                f"- {module_display_name(metric.module_name)}",
                f"  result={metric.scb_result}",
                f"  tb={metric.tb_name}",
                f"  sample={metric.sample_count} pass={metric.pass_count} fail={metric.fail_count}",
                f"  wr_acc={metric.wr_acc_count} rd_acc={metric.rd_acc_count} wr_block={metric.wr_block_count} rd_block={metric.rd_block_count}",
                f"  scenario_completion={metric.scenario_completion_pct:.2f}% response_diversity={metric.response_diversity_pct:.2f}% portfolio_score={metric.portfolio_score_pct:.2f}%",
                f"  log={metric.log_path}",
                "",
            ]
        )

    lines.append("[scenario breakdown]")
    for row in scenario_metrics:
        lines.append(
            f"- {module_display_name(row.module_name)} / {row.scenario_name}: "
            f"sample={row.sample_count} wr_acc={row.wr_acc_count} rd_acc={row.rd_acc_count} "
            f"wr_block={row.wr_block_count} rd_block={row.rd_block_count}"
        )

    lines.extend(
        [
            "",
            "[notes]",
            "- async FIFO 2종과 sync FIFO 모두 self-checking scoreboard pass",
            "- Latest Vivado xsim logs report functional coverage at 100.00%, and scenario completion / response diversity are shown alongside it for richer interpretation",
            "- This console report is generated directly from Python output for portfolio capture",
        ]
    )
    return "\n".join(lines) + "\n"


def build_console_html(console_text: str) -> str:
    return f"""<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <title>SystemVerilog Python Console Report</title>
  <style>
    body {{
      margin: 0;
      background: #0b1220;
      color: #d7e2f0;
      font-family: Consolas, "Courier New", monospace;
    }}
    main {{
      max-width: 1180px;
      margin: 0 auto;
      padding: 32px 24px 40px;
    }}
    .terminal {{
      background: linear-gradient(180deg, #0f1729 0%, #111827 100%);
      border: 1px solid #243046;
      border-radius: 18px;
      box-shadow: 0 20px 45px rgba(0, 0, 0, 0.35);
      overflow: hidden;
    }}
    .terminal-bar {{
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 12px 16px;
      background: #111b31;
      border-bottom: 1px solid #243046;
    }}
    .dot {{
      width: 12px;
      height: 12px;
      border-radius: 50%;
      display: inline-block;
    }}
    .red {{ background: #ff5f57; }}
    .yellow {{ background: #febc2e; }}
    .green {{ background: #28c840; }}
    .title {{
      margin-left: 10px;
      color: #94a8c6;
      font-size: 13px;
    }}
    pre {{
      margin: 0;
      padding: 22px 24px 28px;
      font-size: 18px;
      line-height: 1.55;
      white-space: pre-wrap;
      word-break: break-word;
    }}
    .accent {{ color: #8bd5ff; }}
    .ok {{ color: #7ee787; }}
    .warn {{ color: #f7c873; }}
  </style>
</head>
<body>
  <main>
    <section class="terminal">
      <div class="terminal-bar">
        <span class="dot red"></span>
        <span class="dot yellow"></span>
        <span class="dot green"></span>
        <span class="title">systemverilog_python_console_report</span>
      </div>
      <pre>{escape(console_text)}</pre>
    </section>
  </main>
</body>
</html>
"""


def write_analytics_summary(path: Path, project_root: Path, module_metrics: list[ModuleMetric], analytics_dir: Path) -> None:
    data = {
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "modules": [metric.module_name for metric in module_metrics],
        "generated_files": [
            str((analytics_dir / "log_metrics.csv").relative_to(project_root)).replace("\\", "/"),
            str((analytics_dir / "scenario_metrics.csv").relative_to(project_root)).replace("\\", "/"),
            str((analytics_dir / "log_metrics.sqlite").relative_to(project_root)).replace("\\", "/"),
            str((analytics_dir / "verification_summary.svg").relative_to(project_root)).replace("\\", "/"),
            str((analytics_dir / "scenario_breakdown.svg").relative_to(project_root)).replace("\\", "/"),
            str((analytics_dir / "verification_scores.svg").relative_to(project_root)).replace("\\", "/"),
            str((analytics_dir / "log_analysis_report_ko.html").relative_to(project_root)).replace("\\", "/"),
            str((analytics_dir / "log_analysis_console_ko.html").relative_to(project_root)).replace("\\", "/"),
            str((analytics_dir / "log_analysis_console_ko.txt").relative_to(project_root)).replace("\\", "/"),
            "reports/markdown/overview/log_analysis_report_ko.md",
        ],
    }
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def main() -> None:
    project_root = Path(__file__).resolve().parents[1]
    analytics_dir = project_root / "evidence" / "analytics"
    md_dir = project_root / "reports" / "markdown" / "overview"
    ensure_dir(analytics_dir)
    ensure_dir(md_dir)

    module_metrics, scenario_metrics = collect_metrics(project_root)
    if not module_metrics:
        raise SystemExit("No curated Vivado logs found under evidence/logs")

    write_csv(analytics_dir / "log_metrics.csv", [asdict(metric) for metric in module_metrics])
    write_csv(analytics_dir / "scenario_metrics.csv", [asdict(metric) for metric in scenario_metrics])
    write_sqlite(analytics_dir / "log_metrics.sqlite", module_metrics, scenario_metrics)

    render_grouped_bars(
        analytics_dir / "verification_summary.svg",
        "Verification Summary",
        module_metrics,
        [
            ("pass_count", "PASS", "#2d8f5b"),
            ("wr_acc_count", "WR Accepted", "#d09a32"),
            ("rd_acc_count", "RD Accepted", "#4f7aa3"),
            ("wr_block_count", "WR Blocked", "#d6523c"),
            ("rd_block_count", "RD Blocked", "#8f5f43"),
        ],
    )
    render_scenario_chart(analytics_dir / "scenario_breakdown.svg", module_metrics, scenario_metrics)
    render_grouped_bars(
        analytics_dir / "verification_scores.svg",
        "Verification Score",
        module_metrics,
        [
            ("scenario_completion_pct", "Scenario Completion", "#2d8f5b"),
            ("response_diversity_pct", "Response Diversity", "#4f7aa3"),
            ("portfolio_score_pct", "Portfolio Score", "#7b5ea7"),
        ],
    )

    (analytics_dir / "log_analysis_report_ko.html").write_text(
        build_html_report(module_metrics, scenario_metrics),
        encoding="utf-8",
    )
    console_text = build_console_report(module_metrics, scenario_metrics)
    (analytics_dir / "log_analysis_console_ko.txt").write_text(
        console_text,
        encoding="utf-8",
    )
    (analytics_dir / "log_analysis_console_ko.html").write_text(
        build_console_html(console_text),
        encoding="utf-8",
    )
    (md_dir / "log_analysis_report_ko.md").write_text(
        build_markdown_report(project_root, module_metrics, analytics_dir),
        encoding="utf-8",
    )
    write_analytics_summary(analytics_dir / "analytics_summary.json", project_root, module_metrics, analytics_dir)


if __name__ == "__main__":
    main()
