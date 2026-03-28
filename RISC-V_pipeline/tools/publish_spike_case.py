#!/usr/bin/env python3
"""
Copy the active Spike verification outputs into a case-specific archive tree.

The case archive mirrors the active project layout so copied HTML/Markdown
reports keep their relative links working:

  spike_cases/<case_name>/
    reports/...
    evidence/...
    tb/...
    src/...
"""

from __future__ import annotations

import argparse
import html
import shutil
from pathlib import Path


ACTIVE_FILES = [
    "tb/spike_trace_pkg.sv",
    "src/mem/InstructionSpikeTop.mem",
    "evidence/logs/pipeline_spike_xsim.log",
    "evidence/logs/top_tb_class_xsim.log",
    "evidence/csv/pipeline_spike_trace.csv",
    "evidence/csv/top_tb_class_trace.csv",
    "evidence/csv/combined_summary.csv",
    "evidence/csv/combined_instruction_mix.csv",
    "evidence/csv/top_tb_event_summary.csv",
    "reports/html/rv32i_spike_visual_report_ko.html",
    "reports/markdown/overview/rv32i_spike_visual_report_ko.md",
    "reports/markdown/overview/artifact_index.md",
]

ASSET_GLOBS = [
    "reports/html/assets/*.png",
]


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def copy_file(src: Path, dst: Path) -> None:
    ensure_dir(dst.parent)
    shutil.copyfile(src, dst)


def case_root(project_root: Path, case_name: str) -> Path:
    return project_root / "spike_cases" / case_name


def publish_case(project_root: Path, case_name: str, csv_path: Path | None) -> Path:
    dst_root = case_root(project_root, case_name)
    ensure_dir(dst_root)

    for rel_path in ACTIVE_FILES:
        src = project_root / rel_path
        if not src.exists():
            raise SystemExit(f"Required active artifact not found: {src}")
        copy_file(src, dst_root / rel_path)

    for pattern in ASSET_GLOBS:
        for src in sorted(project_root.glob(pattern)):
            rel_path = src.relative_to(project_root)
            copy_file(src, dst_root / rel_path)

    if csv_path is not None:
        src_csv = csv_path if csv_path.is_absolute() else project_root / csv_path
        if not src_csv.exists():
            raise SystemExit(f"CSV trace not found: {src_csv}")
        copy_file(src_csv, dst_root / "tb" / src_csv.name)

    manifest_lines = [
        f"case_name={case_name}",
        f"report_html=reports/html/rv32i_spike_visual_report_ko.html",
        f"report_md=reports/markdown/overview/rv32i_spike_visual_report_ko.md",
        f"summary_csv=evidence/csv/combined_summary.csv",
    ]
    if csv_path is not None:
        manifest_lines.append(f"source_csv=tb/{Path(csv_path).name}")
    (dst_root / "case_manifest.txt").write_text("\n".join(manifest_lines) + "\n", encoding="utf-8")
    return dst_root


def write_index(project_root: Path) -> None:
    root = project_root / "spike_cases"
    ensure_dir(root)
    case_dirs = sorted(path for path in root.iterdir() if path.is_dir())

    items_html: list[str] = []
    items_md: list[str] = ["# Spike Case Index", ""]
    for case_dir in case_dirs:
        case_name = case_dir.name
        report_html = case_dir / "reports" / "html" / "rv32i_spike_visual_report_ko.html"
        report_md = case_dir / "reports" / "markdown" / "overview" / "rv32i_spike_visual_report_ko.md"
        manifest = case_dir / "case_manifest.txt"
        source_csv = ""
        if manifest.exists():
            for line in manifest.read_text(encoding="utf-8").splitlines():
                if line.startswith("source_csv="):
                    source_csv = line.split("=", 1)[1]
                    break

        html_rel = report_html.relative_to(root).as_posix()
        md_rel = report_md.relative_to(root).as_posix()
        csv_text = html.escape(source_csv) if source_csv else "-"
        items_html.append(
            f"""
        <article class="card">
          <h2>{html.escape(case_name)}</h2>
          <p>CSV: <code>{csv_text}</code></p>
          <p><a href="{html.escape(html_rel)}">HTML 보고서 열기</a></p>
          <p><a href="{html.escape(md_rel)}">Markdown 보고서 열기</a></p>
        </article>
"""
        )
        items_md.extend(
            [
                f"## {case_name}",
                "",
                f"- HTML: `{html_rel}`",
                f"- Markdown: `{md_rel}`",
                f"- CSV: `{source_csv or '-'}`",
                "",
            ]
        )

    overview_html_rel = "../reports/html/rv32i_case_matrix_report_ko.html"
    overview_md_rel = "../reports/markdown/overview/rv32i_case_matrix_report_ko.md"
    compact_html_rel = "../reports/html/rv32i_exec_compact_report_ko.html"
    compact_md_rel = "../reports/markdown/overview/rv32i_exec_compact_report_ko.md"

    index_html = f"""<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Spike Case Index</title>
  <style>
    body {{
      margin: 0;
      font-family: "Pretendard", "Noto Sans KR", "Segoe UI", sans-serif;
      background: #f6f8fb;
      color: #191f28;
    }}
    .page {{
      max-width: 1080px;
      margin: 0 auto;
      padding: 40px 20px 56px;
    }}
    .card-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 18px;
    }}
    .card {{
      background: #fff;
      border: 1px solid #e5e8eb;
      border-radius: 20px;
      box-shadow: 0 16px 40px rgba(15, 23, 42, 0.06);
      padding: 22px;
    }}
    h1 {{
      margin: 0 0 10px;
      font-size: 34px;
    }}
    p {{
      margin: 8px 0;
      color: #4b5563;
    }}
    a {{
      color: #2563eb;
      text-decoration: none;
      font-weight: 600;
    }}
    code {{
      font-family: Consolas, monospace;
      background: #f3f4f6;
      padding: 2px 6px;
      border-radius: 8px;
    }}
  </style>
</head>
<body>
  <div class="page">
    <h1>Spike Case Reports</h1>
    <p>케이스별 보고서와 로그를 덮어쓰지 않고 보관한 인덱스입니다.</p>
    <p><a href="{overview_html_rel}">ROM 통합 검증 보고서 열기</a></p>
    <p><a href="{compact_html_rel}">Compact 검증 + 성능 보고서 열기</a></p>
    <div class="card-grid">
      {''.join(items_html)}
    </div>
  </div>
</body>
</html>
"""

    (root / "index.html").write_text(index_html, encoding="utf-8")
    index_md_lines = [
        "# Spike Case Index",
        "",
        f"- 통합 HTML 보고서: `{overview_html_rel}`",
        f"- 통합 Markdown 보고서: `{overview_md_rel}`",
        f"- Compact HTML 보고서: `{compact_html_rel}`",
        f"- Compact Markdown 보고서: `{compact_md_rel}`",
        "",
    ] + items_md[2:]
    (root / "index.md").write_text("\n".join(index_md_lines) + "\n", encoding="utf-8")

    reports_html_index = project_root / "reports" / "html" / "index.html"
    reports_md_index = project_root / "reports" / "markdown" / "overview" / "case_index.md"
    ensure_dir(reports_html_index.parent)
    ensure_dir(reports_md_index.parent)
    reports_html_index.write_text(
        '<meta http-equiv="refresh" content="0; url=../../spike_cases/index.html">\n',
        encoding="utf-8",
    )
    reports_md_index.write_text(
        "# Spike Case Index\n\n- `../../../spike_cases/index.html`\n- `../../../spike_cases/index.md`\n",
        encoding="utf-8",
    )


def main() -> None:
    project_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description="Publish active Spike outputs into a case archive")
    parser.add_argument("--case-name", required=True, help="Archive case name, for example test_top or bubble_sort")
    parser.add_argument("--csv", default="", help="Optional source CSV path to copy into the case archive")
    args = parser.parse_args()

    csv_path = Path(args.csv) if args.csv else None
    dst_root = publish_case(project_root, args.case_name, csv_path)
    write_index(project_root)
    print(f"[INFO] published case : {args.case_name}")
    print(f"[INFO] archive root   : {dst_root}")
    print(f"[INFO] html report    : {dst_root / 'reports' / 'html' / 'rv32i_spike_visual_report_ko.html'}")


if __name__ == "__main__":
    main()
