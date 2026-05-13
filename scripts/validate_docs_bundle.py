#!/usr/bin/env python3

from __future__ import annotations

import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parent.parent
DOCS_DIR = ROOT / "docs"
PRD = DOCS_DIR / "prd.md"
ARCH = DOCS_DIR / "architecture.md"
UI = ROOT / "editor.pen"


def fail(message: str) -> None:
    print(f"Docs bundle validation: FAILED\n- {message}")
    sys.exit(1)


def expect_contains(text: str, expected: str, label: str) -> None:
    if expected not in text:
        fail(f"{label} missing required text: {expected}")


def main() -> None:
    if not PRD.is_file():
        fail("docs/prd.md is missing")
    if not ARCH.is_file():
        fail("docs/architecture.md is missing")
    if not UI.is_file():
        fail("editor.pen is missing")

    top_level_docs = sorted(
        p.name for p in DOCS_DIR.iterdir() if not p.name.startswith(".")
    )
    if top_level_docs != ["architecture.md", "prd.md"]:
        fail(
            "docs/ directory must contain only architecture.md and prd.md; "
            f"found {top_level_docs}"
        )

    prd_text = PRD.read_text(encoding="utf-8")
    arch_text = ARCH.read_text(encoding="utf-8")

    for section in (
        "## 1. 产品定位",
        "## 4. 产品范围",
        "## 5. 核心业务流程",
        "### 5.4 工作流边界与状态",
        "### 5.5 数据隔离与持久化",
        "## 8. 视觉与交互基线",
    ):
        expect_contains(prd_text, section, "docs/prd.md")

    for module_name in (
        "项目与资料",
        "写作主线",
        "AI 运行",
        "反馈与检查",
        "设置与导出",
    ):
        expect_contains(prd_text, module_name, "docs/prd.md")

    for route_name in (
        "`shelf`",
        "`workbench`",
        "`characters`",
        "`worldbuilding`",
        "`scenes`",
        "`style`",
        "`audit`",
        "`versions`",
        "`import_export`",
        "`settings`",
        "`work_settings_hub`",
        "`revision_hub`",
        "`production_board`",
        "`review_tasks`",
        "`reading`",
        "`sandbox`",
    ):
        expect_contains(arch_text, route_name, "docs/architecture.md")

    for section in (
        "## 1. 总览",
        "## 2. Route Surface Catalog",
        "## 3. 主数据流",
        "## 4. 边界规则",
        "## 5. 工作流运行合约",
        "### 5.2 持久化模型",
        "### 5.3 数据隔离模型",
        "### 5.4 边界情况处理",
    ):
        expect_contains(arch_text, section, "docs/architecture.md")

    if "```mermaid" not in arch_text:
        fail("docs/architecture.md must include a mermaid diagram")

    try:
        ui_json = json.loads(UI.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"editor.pen is not valid JSON: {exc}")

    if not isinstance(ui_json.get("children"), list) or not ui_json["children"]:
        fail("editor.pen must contain at least one top-level frame")

    ui_text = UI.read_text(encoding="utf-8")
    expect_contains(ui_text, "编辑页 - 纯净写作", "editor.pen")
    expect_contains(ui_text, "写作助手工作流 - 规则检查", "editor.pen")
    expect_contains(ui_text, "设置页", "editor.pen")
    expect_contains(ui_text, "导入导出页", "editor.pen")
    expect_contains(ui_text, "用户反馈对话", "editor.pen")
    expect_contains(ui_text, "发起一次规则检查", "editor.pen")
    expect_contains(ui_text, "状态：可恢复运行", "editor.pen")
    expect_contains(ui_text, "规则检查失败", "editor.pen")
    expect_contains(ui_text, "源内容已变更", "editor.pen")
    expect_contains(ui_text, "运行内候选", "editor.pen")
    expect_contains(ui_text, "继续运行", "editor.pen")
    expect_contains(ui_text, "丢弃运行", "editor.pen")
    expect_contains(ui_text, "监控记录", "editor.pen")
    expect_contains(ui_text, "Navigation", "editor.pen")
    expect_contains(ui_text, "纯净编辑工作区", "editor.pen")

    print("Docs bundle validation: PASSED")
    print(f"- docs/: {top_level_docs}")
    print("- required artifacts: docs/prd.md, docs/architecture.md, editor.pen")


if __name__ == "__main__":
    main()
