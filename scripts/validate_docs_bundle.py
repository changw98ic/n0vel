#!/usr/bin/env python3

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
DOCS_DIR = ROOT / "docs"
PRD = DOCS_DIR / "prd.md"
ARCH = DOCS_DIR / "architecture.md"
AGENT_EVAL_SPEC = DOCS_DIR / "agent-engineering-evaluation-spec.md"
UI = ROOT / "editor.pen"


def fail(message: str) -> None:
    print(f"Docs bundle validation: FAILED\n- {message}")
    sys.exit(1)


def expect_contains(text: str, expected: str, label: str) -> None:
    if expected not in text:
        fail(f"{label} missing required text: {expected}")


def validate_local_markdown_links(path: Path, text: str) -> None:
    for raw_target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", text):
        target = raw_target.strip().strip("<>")
        if (
            not target
            or target.startswith(("http://", "https://", "mailto:", "#"))
        ):
            continue
        relative_target = target.split("#", maxsplit=1)[0]
        resolved = (path.parent / relative_target).resolve()
        if not resolved.exists():
            fail(f"{path.relative_to(ROOT)} has broken local link: {raw_target}")


def main() -> None:
    if not PRD.is_file():
        fail("docs/prd.md is missing")
    if not ARCH.is_file():
        fail("docs/architecture.md is missing")
    if not AGENT_EVAL_SPEC.is_file():
        fail("docs/agent-engineering-evaluation-spec.md is missing")
    if not UI.is_file():
        fail("editor.pen is missing")

    top_level_docs = sorted(
        p.name for p in DOCS_DIR.iterdir() if not p.name.startswith(".")
    )

    prd_text = PRD.read_text(encoding="utf-8")
    arch_text = ARCH.read_text(encoding="utf-8")
    agent_eval_spec_text = AGENT_EVAL_SPEC.read_text(encoding="utf-8")

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
        "`story_arc`",
        "`fulltext_search`",
        "`writing_stats`",
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

    for required_text in (
        "状态：V26 本地实现已进入最终复核；真实发布矩阵登记为外部条件",
        "真实发布矩阵登记为外部条件",
        "不代表功能已经完成",
        "provider-execution-and-pass3-smoke",
        "releaseEligible = false",
        "截至 2026-07-14 的结论：V26 仓库内实现",
        "authoring schema V27",
        "Runner authority 在 `prepared`、`accepted`、`outboxCompleted`、`finalPersisted` 四个边界",
        "## 14. 机械验收标准",
        "## 19. 对抗性复核记录",
    ):
        expect_contains(
            agent_eval_spec_text,
            required_text,
            "docs/agent-engineering-evaluation-spec.md",
        )
    validate_local_markdown_links(AGENT_EVAL_SPEC, agent_eval_spec_text)

    try:
        ui_json = json.loads(UI.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"editor.pen is not valid JSON: {exc}")

    if not isinstance(ui_json.get("children"), list) or not ui_json["children"]:
        fail("editor.pen must contain at least one top-level frame")

    ui_text = UI.read_text(encoding="utf-8")
    expect_contains(ui_text, "编辑页 - 纯净写作", "editor.pen")
    expect_contains(ui_text, "书架页", "editor.pen")
    expect_contains(ui_text, "作品资料页", "editor.pen")
    expect_contains(ui_text, "新建作品页", "editor.pen")
    expect_contains(ui_text, "设定资料页", "editor.pen")
    expect_contains(ui_text, "写作助手工作流", "editor.pen")
    expect_contains(ui_text, "用户反馈对话", "editor.pen")
    expect_contains(ui_text, "发起一次规则检查", "editor.pen")
    expect_contains(ui_text, "状态：等待作者反馈", "editor.pen")
    expect_contains(ui_text, "源内容检测", "editor.pen")
    expect_contains(ui_text, "候选正文预览", "editor.pen")
    expect_contains(ui_text, "可恢复", "editor.pen")
    expect_contains(ui_text, "上次运行未完成 · 可继续或丢弃", "editor.pen")
    expect_contains(ui_text, "恢复上次运行", "editor.pen")
    expect_contains(ui_text, "监控记录", "editor.pen")
    expect_contains(ui_text, "Navigation", "editor.pen")
    expect_contains(ui_text, "纯净编辑工作区", "editor.pen")

    print("Docs bundle validation: PASSED")
    print(f"- docs/: {top_level_docs}")
    print(
        "- required artifacts: docs/prd.md, docs/architecture.md, "
        "docs/agent-engineering-evaluation-spec.md, editor.pen"
    )


if __name__ == "__main__":
    main()
