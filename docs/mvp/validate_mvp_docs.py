#!/usr/bin/env python3

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
REPO_ROOT = ROOT.parents[1]
PRD_DIR = ROOT / "prd"
LOCAL_WORKSPACE_PREFIX = "/Users/chengwen/dev/novel-wirter/"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def extract_backticks(text: str) -> set[str]:
    return set(re.findall(r"`([^`\n]+)`", text))


def extract_frame_ids(text: str) -> set[str]:
    return set(re.findall(r"`([A-Za-z0-9]{5})`", text))


def extract_markdown_links(text: str) -> list[str]:
    return re.findall(r"\[[^\]]+\]\(([^)]+)\)", text)


def extract_markdown_link_pairs(text: str) -> list[tuple[str, str]]:
    return re.findall(r"\[([^\]]+)\]\(([^)]+)\)", text)


def resolve_markdown_link(link: str, source_dir: Path) -> Path | None:
    target = link.split("#", 1)[0]
    if not target or re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target):
        return None
    if target.startswith(LOCAL_WORKSPACE_PREFIX):
        return REPO_ROOT / target[len(LOCAL_WORKSPACE_PREFIX) :]
    path = Path(target)
    if path.is_absolute():
        return path
    return source_dir / path


def is_doc_path_ref(value: str) -> bool:
    return Path(value).suffix in {".md", ".json", ".py"}


def parse_frame_state_coverage_sections(text: str) -> dict[str, list[str]]:
    section_map = {
        "## 核心页面": "core_pages",
        "## 工作台状态": "workbench_states",
        "## AI / 编辑流状态": "ai_editing_states",
        "## 提示 / 轻警告状态": "warning_states",
        "## 成功 / 完成状态": "success_states",
        "## 风格 / 导入阻断状态": "blocking_states",
        "## 阅读与版本状态": "reading_and_version_states",
        "## 空状态": "empty_states",
        "## 错误 / 限制 / 确认状态": "error_limit_confirm_states",
    }
    sections: dict[str, list[str]] = {v: [] for v in section_map.values()}
    current_key: str | None = None
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if line in section_map:
            current_key = section_map[line]
            continue
        if line.startswith("## "):
            current_key = None
            continue
        if current_key and line.startswith("- `") and line.endswith("`"):
            sections[current_key].append(line[3:-1])
    return sections


def main() -> int:
    errors: list[str] = []

    readme = read(ROOT / "README.md")
    readme_json = json.loads(read(ROOT / "README.json"))
    coverage = read(ROOT / "frame-state-coverage.md")
    coverage_json = json.loads(read(ROOT / "frame-state-coverage.json"))
    manifest = json.loads(read(ROOT / "doc-manifest.json"))
    handoff = read(ROOT / "implementation-handoff.md")
    milestones = read(ROOT / "milestone-verification-checklist.md")
    milestones_json = json.loads(read(ROOT / "milestone-verification-checklist.json"))
    release = read(ROOT / "release-readiness.md")
    legacy = read(ROOT / "legacy-frame-audit.md")
    behavior = read(ROOT / "behavior-gap-audit.md")
    runtime = read(ROOT / "runtime-smoke-tests.md")
    runtime_json = json.loads(read(ROOT / "runtime-smoke-tests.json"))
    trace_md = read(ROOT / "traceability-matrix.md")
    trace_json = json.loads(read(ROOT / "traceability-matrix.json"))
    readiness_json = json.loads(read(ROOT / "release-readiness.json"))
    canonical = json.loads(read(ROOT / "canonical-frame-map.json"))

    top_level_doc_count = len([p for p in ROOT.iterdir() if p.is_file()])
    prd_count = len([p for p in PRD_DIR.iterdir() if p.is_file() and p.suffix == ".md"])

    if f"顶层 MVP 文档与资产：`{top_level_doc_count}` 份" not in release:
        errors.append(
            f"release-readiness.md doc count mismatch: expected {top_level_doc_count}"
        )
    if f"页面级 PRD：`{prd_count}` 份" not in release:
        errors.append(f"release-readiness.md PRD count mismatch: expected {prd_count}")

    if readiness_json.get("status") != "ready_for_implementation":
        errors.append("release-readiness.json status should be ready_for_implementation")
    if readiness_json.get("top_level_docs_and_assets") != top_level_doc_count:
        errors.append(
            f"release-readiness.json top_level_docs_and_assets mismatch: expected {top_level_doc_count}"
        )
    if readiness_json.get("prd_docs") != prd_count:
        errors.append(f"release-readiness.json prd_docs mismatch: expected {prd_count}")

    known_doc_paths = {p.name for p in ROOT.glob("*.md")}
    known_doc_paths.update(p.name for p in ROOT.glob("*.json"))
    known_doc_paths.update(p.name for p in ROOT.glob("*.py"))
    known_doc_paths.update(p.name for p in PRD_DIR.glob("*.md"))

    if readme_json.get("title") != "MVP 文档集总览":
        errors.append("README.json title should be MVP 文档集总览")
    if readme_json.get("status") != "active":
        errors.append("README.json status should be active")

    required_readme_links = {
        "readme_markdown",
        "doc_manifest",
        "canonical_frame_map",
        "implementation_handoff",
        "milestone_checklist",
        "runtime_smoke_tests",
        "traceability_matrix",
        "release_readiness",
    }
    readme_json_links = readme_json.get("primary_links", {})
    missing_readme_json_links = sorted(required_readme_links - set(readme_json_links.keys()))
    if missing_readme_json_links:
        errors.append(
            f"README.json missing primary_links keys: {missing_readme_json_links}"
        )

    missing_readme_json_targets = sorted(
        v for v in readme_json_links.values() if v not in known_doc_paths
    )
    if missing_readme_json_targets:
        errors.append(
            "README.json points to missing docs: "
            f"{missing_readme_json_targets}"
        )

    required_entrypoints = {"engineering", "qa", "smoke", "traceability"}
    readiness_entrypoints = readiness_json.get("primary_entrypoints", {})
    missing_entrypoints = sorted(k for k in required_entrypoints if k not in readiness_entrypoints)
    if missing_entrypoints:
        errors.append(
            f"release-readiness.json missing primary_entrypoints keys: {missing_entrypoints}"
        )

    missing_readiness_entrypoints = sorted(
        v for v in readiness_entrypoints.values() if v not in known_doc_paths
    )
    if missing_readiness_entrypoints:
        errors.append(
            "release-readiness.json points to missing primary entrypoint docs: "
            f"{missing_readiness_entrypoints}"
        )

    manifest_paths = [item.get("path") for item in manifest.get("assets", [])]
    expected_manifest_paths = sorted(p.name for p in ROOT.iterdir() if p.is_file())
    if sorted(manifest_paths) != expected_manifest_paths:
        errors.append(
            "doc-manifest.json asset paths mismatch: "
            f"expected {expected_manifest_paths}, got {sorted(manifest_paths)}"
        )

    for source_name, content in {
        "README.md": readme,
        "release-readiness.md": release,
        "implementation-handoff.md": handoff,
        "milestone-verification-checklist.md": milestones,
        "runtime-smoke-tests.md": runtime,
        "traceability-matrix.md": trace_md,
        "legacy-frame-audit.md": legacy,
    }.items():
        for link in extract_markdown_links(content):
            resolved = resolve_markdown_link(link, ROOT)
            if resolved is not None and not resolved.exists():
                errors.append(f"{source_name} contains broken markdown link: {link}")

    readme_local_links = {
        resolved.name
        for link in extract_markdown_links(readme)
        if (resolved := resolve_markdown_link(link, ROOT)) is not None
        and resolved.parent == ROOT
    }
    expected_readme_targets = {
        p.name
        for p in ROOT.iterdir()
        if p.is_file() and p.name != "README.md" and p.suffix in {".md", ".json", ".py"}
    }
    missing_readme_targets = sorted(expected_readme_targets - readme_local_links)
    if missing_readme_targets:
        errors.append(
            "README.md is missing links to top-level MVP assets: "
            f"{missing_readme_targets}"
        )

    readme_link_pairs = {
        resolved.name: label
        for label, path in extract_markdown_link_pairs(readme)
        if (resolved := resolve_markdown_link(path, ROOT)) is not None
        and resolved.parent == ROOT
    }
    for asset in manifest.get("assets", []):
        path = asset.get("path")
        title = asset.get("title")
        if path == "README.md":
            continue
        if path in readme_link_pairs and readme_link_pairs[path] != title:
            errors.append(
                "README.md link label does not match doc-manifest title for "
                f"{path}: expected {title}, got {readme_link_pairs[path]}"
            )

    canonical_names: set[str] = set()
    canonical_ids: set[str] = set()
    for key, value in canonical.items():
        if key == "legacy_replaced":
            canonical_names.update(value.keys())
            for mapping in value.values():
                canonical_ids.add(mapping["canonical"])
                canonical_ids.add(mapping["legacy"])
            continue
        if isinstance(value, dict):
            canonical_names.update(value.keys())
            canonical_ids.update(value.values())

    coverage_names = extract_backticks(coverage)
    coverage_json_names: set[str] = set()
    for value in coverage_json.values():
        if isinstance(value, list):
            coverage_json_names.update(value)
    coverage_md_sections = parse_frame_state_coverage_sections(coverage)
    handoff_names = extract_backticks(handoff)
    handoff_ids = extract_frame_ids(handoff)
    trace_md_ids = extract_frame_ids(trace_md)

    allowed_non_frame_handoff = {
        "menu drawer",
        "breadcrumb",
        "menu",
    }
    handoff_names = {n for n in handoff_names if n not in allowed_non_frame_handoff}

    missing_in_coverage = sorted(name for name in canonical_names if name not in coverage_names)
    if missing_in_coverage:
        errors.append(f"canonical names missing in frame-state-coverage.md: {missing_in_coverage}")

    missing_in_coverage_json = sorted(
        name for name in canonical_names if name not in coverage_json_names
    )
    if missing_in_coverage_json:
        errors.append(
            f"canonical names missing in frame-state-coverage.json: {missing_in_coverage_json}"
        )

    extra_in_coverage_json = sorted(
        name for name in coverage_json_names if name not in canonical_names
    )
    if extra_in_coverage_json:
        errors.append(
            "frame-state-coverage.json contains names not present in canonical-frame-map.json: "
            f"{extra_in_coverage_json}"
        )

    for key, md_items in coverage_md_sections.items():
        json_items = coverage_json.get(key, [])
        if set(md_items) != set(json_items):
            missing_in_json = sorted(set(md_items) - set(json_items))
            missing_in_md = sorted(set(json_items) - set(md_items))
            if missing_in_json:
                errors.append(
                    f"frame-state-coverage.json section {key} is missing markdown items: {missing_in_json}"
                )
            if missing_in_md:
                errors.append(
                    f"frame-state-coverage.md section {key} is missing json items: {missing_in_md}"
                )

    missing_in_handoff = sorted(name for name in canonical_names if name not in handoff_names)
    if missing_in_handoff:
        errors.append(f"canonical names missing in implementation-handoff.md: {missing_in_handoff}")

    invalid_handoff_ids = sorted(i for i in handoff_ids if i not in canonical_ids)
    if invalid_handoff_ids:
        errors.append(
            "implementation-handoff.md contains frame ids not present in canonical-frame-map.json: "
            f"{invalid_handoff_ids}"
        )

    legacy_replaced = canonical["legacy_replaced"]
    for frame_name, mapping in legacy_replaced.items():
        canonical_id = mapping["canonical"]
        legacy_id = mapping["legacy"]
        if canonical_id not in legacy or legacy_id not in legacy or frame_name not in legacy:
            errors.append(
                f"legacy-frame-audit.md missing legacy mapping details for {frame_name}"
            )

    expected_readme_links = [
        "Frame / State Coverage (JSON)",
        "Canonical Frame Map (JSON)",
        "MVP 文档清单 (JSON)",
        "Legacy Frame 审计",
        "MVP 行为缺口审计",
        "MVP 实现交接稿",
        "MVP 里程碑验收清单",
        "MVP 里程碑验收清单 (JSON)",
        "MVP 运行时 Smoke Test 清单",
        "MVP 运行时 Smoke Test 清单 (JSON)",
        "MVP 追踪矩阵",
        "MVP 追踪矩阵 (JSON)",
        "MVP 设计交付完成度",
        "MVP 设计交付完成度 (JSON)",
        "MVP 文档校验脚本",
    ]
    for label in expected_readme_links:
        if label not in readme:
            errors.append(f"README.md missing link label: {label}")

    if "高优先级行为缺口已收口" not in behavior:
        errors.append("behavior-gap-audit.md should state that high-priority gaps are closed")

    expected_milestones = [f"M{i}" for i in range(1, 6)]
    for milestone in expected_milestones:
        if f"## {milestone} " not in milestones:
            errors.append(f"milestone-verification-checklist.md missing section {milestone}")

    milestone_json_ids = [item.get("id") for item in milestones_json.get("milestones", [])]
    if milestone_json_ids != expected_milestones:
        errors.append(
            "milestone-verification-checklist.json milestone ids mismatch: "
            f"expected {expected_milestones}, got {milestone_json_ids}"
        )

    milestone_json_frame_ids: set[str] = set()
    for item in milestones_json.get("milestones", []):
        milestone_json_frame_ids.update(item.get("related_frames", []))

    invalid_milestone_json_ids = sorted(
        i for i in milestone_json_frame_ids if i not in canonical_ids
    )
    if invalid_milestone_json_ids:
        errors.append(
            "milestone-verification-checklist.json contains frame ids not present in canonical-frame-map.json: "
            f"{invalid_milestone_json_ids}"
        )

    milestone_md_pairs = re.findall(r"## (M\d)\s+([^\n]+)", milestones)
    milestone_json_pairs = [
        (item.get("id"), item.get("title")) for item in milestones_json.get("milestones", [])
    ]
    if milestone_md_pairs != milestone_json_pairs:
        errors.append(
            "milestone-verification-checklist.md and milestone-verification-checklist.json mismatch: "
            f"md={milestone_md_pairs}, json={milestone_json_pairs}"
        )

    expected_handoff_milestones = [f"M{i}" for i in range(1, 5)]
    for milestone in expected_handoff_milestones:
        if f"### {milestone} " not in handoff:
            errors.append(f"implementation-handoff.md missing milestone block {milestone}")

    if "## Legacy 注意项" not in handoff:
        errors.append("implementation-handoff.md missing Legacy 注意项 section")

    expected_smokes = [f"Smoke {i:02d}" for i in range(1, 13)]
    for smoke in expected_smokes:
        if smoke not in runtime:
            errors.append(f"runtime-smoke-tests.md missing {smoke}")

    runtime_json_ids = [item.get("id") for item in runtime_json.get("smoke_tests", [])]
    if len(runtime_json_ids) != len(expected_smokes):
        errors.append(
            "runtime-smoke-tests.json smoke count mismatch: "
            f"expected {len(expected_smokes)}, got {len(runtime_json_ids)}"
        )

    expected_runtime_json_ids = [f"smoke_{i:02d}" for i in range(1, 13)]
    if runtime_json_ids != expected_runtime_json_ids:
        errors.append(
            "runtime-smoke-tests.json smoke ids mismatch: "
            f"expected {expected_runtime_json_ids}, got {runtime_json_ids}"
        )

    runtime_labels = {f"Smoke {i:02d}" for i in range(1, 13)}

    runtime_json_frame_ids: set[str] = set()
    for item in runtime_json.get("smoke_tests", []):
        runtime_json_frame_ids.update(item.get("related_frames", []))

    invalid_runtime_json_ids = sorted(i for i in runtime_json_frame_ids if i not in canonical_ids)
    if invalid_runtime_json_ids:
        errors.append(
            "runtime-smoke-tests.json contains frame ids not present in canonical-frame-map.json: "
            f"{invalid_runtime_json_ids}"
        )

    smoke_md_pairs = re.findall(r"## (Smoke \d{2})\s+([^\n]+)", runtime)
    smoke_json_pairs = []
    for item in runtime_json.get("smoke_tests", []):
        smoke_id = item.get("id", "")
        smoke_title = item.get("title", "")
        smoke_num = smoke_id.split("_")[-1] if "_" in smoke_id else smoke_id
        smoke_json_pairs.append((f"Smoke {smoke_num}", smoke_title))
    if smoke_md_pairs != smoke_json_pairs:
        errors.append(
            "runtime-smoke-tests.md and runtime-smoke-tests.json mismatch: "
            f"md={smoke_md_pairs}, json={smoke_json_pairs}"
        )

    runtime_json_doc_refs: set[str] = set()
    for item in runtime_json.get("smoke_tests", []):
        runtime_json_doc_refs.update(item.get("related_docs", []))

    missing_runtime_json_docs = sorted(d for d in runtime_json_doc_refs if d not in known_doc_paths)
    if missing_runtime_json_docs:
        errors.append(
            "runtime-smoke-tests.json contains related docs that do not exist: "
            f"{missing_runtime_json_docs}"
        )

    required_page_keys = {
        "writing_workbench",
        "project_import_export",
        "settings_byok",
        "reading_mode",
    }
    missing_page_keys = sorted(k for k in required_page_keys if k not in trace_json["pages"])
    if missing_page_keys:
        errors.append(f"traceability-matrix.json missing page keys: {missing_page_keys}")

    required_all_page_keys = {
        "project_list",
        "writing_workbench",
        "sandbox_monitor",
        "character_library",
        "worldbuilding",
        "style_panel",
        "audit_center",
        "chapter_versions",
        "project_import_export",
        "settings_byok",
        "reading_mode",
    }
    missing_all_page_keys = sorted(
        k for k in required_all_page_keys if k not in trace_json["pages"]
    )
    if missing_all_page_keys:
        errors.append(
            f"traceability-matrix.json missing required page mappings: {missing_all_page_keys}"
        )

    required_track_keys = {
        "ai_edit_confirm_restore",
        "simulation_roundtrip",
        "import_and_overwrite_success",
        "settings_save_effective_next_request",
        "reference_invalidation_recovery",
    }
    missing_track_keys = sorted(
        k for k in required_track_keys if k not in trace_json["interaction_tracks"]
    )
    if missing_track_keys:
        errors.append(f"traceability-matrix.json missing interaction track keys: {missing_track_keys}")

    for heading in ("## 页面级追踪", "## 交互专项追踪"):
        if heading not in trace_md:
            errors.append(f"traceability-matrix.md missing heading {heading}")

    invalid_trace_md_ids = sorted(i for i in trace_md_ids if i not in canonical_ids)
    if invalid_trace_md_ids:
        errors.append(
            "traceability-matrix.md contains frame ids not present in canonical-frame-map.json: "
            f"{invalid_trace_md_ids}"
        )

    trace_json_frame_ids: set[str] = set()
    trace_json_smokes: set[str] = set()
    for page in trace_json.get("pages", {}).values():
        trace_json_frame_ids.add(page["primary_frame"])
        trace_json_frame_ids.update(page.get("related_frames", []))
        trace_json_smokes.update(page.get("smoke_tests", []))
    for track in trace_json.get("interaction_tracks", {}).values():
        trace_json_frame_ids.update(track.get("frames", []))
        trace_json_smokes.update(track.get("smoke_tests", []))

    invalid_trace_json_ids = sorted(i for i in trace_json_frame_ids if i not in canonical_ids)
    if invalid_trace_json_ids:
        errors.append(
            "traceability-matrix.json contains frame ids not present in canonical-frame-map.json: "
            f"{invalid_trace_json_ids}"
        )

    trace_json_doc_refs: set[str] = set()
    for page in trace_json.get("pages", {}).values():
        trace_json_doc_refs.add(page["prd"])
    for track in trace_json.get("interaction_tracks", {}).values():
        trace_json_doc_refs.update(track.get("prds", []))

    missing_trace_json_docs = sorted(
        d
        for d in trace_json_doc_refs
        if is_doc_path_ref(d) and d not in known_doc_paths
    )
    if missing_trace_json_docs:
        errors.append(
            "traceability-matrix.json contains related docs that do not exist: "
            f"{missing_trace_json_docs}"
        )

    frame_id_pattern = re.compile(r"`([A-Za-z0-9]{5})`\s+`[^`]+`")
    milestone_ids = set(frame_id_pattern.findall(milestones))
    smoke_ids = set(frame_id_pattern.findall(runtime))

    missing_milestone_ids = sorted(i for i in milestone_ids if i not in canonical_ids)
    if missing_milestone_ids:
        errors.append(
            "milestone-verification-checklist.md contains frame ids not present in canonical-frame-map.json: "
            f"{missing_milestone_ids}"
        )

    missing_smoke_ids = sorted(i for i in smoke_ids if i not in canonical_ids)
    if missing_smoke_ids:
        errors.append(
            "runtime-smoke-tests.md contains frame ids not present in canonical-frame-map.json: "
            f"{missing_smoke_ids}"
        )

    invalid_trace_json_smokes = sorted(s for s in trace_json_smokes if s not in expected_smokes)
    if invalid_trace_json_smokes:
        errors.append(
            "traceability-matrix.json contains smoke test labels not present in runtime-smoke-tests.md: "
            f"{invalid_trace_json_smokes}"
        )

    if trace_json_smokes != runtime_labels:
        missing_in_trace = sorted(runtime_labels - trace_json_smokes)
        extra_in_trace = sorted(trace_json_smokes - runtime_labels)
        if missing_in_trace:
            errors.append(
                "traceability-matrix.json is missing smoke labels present in runtime-smoke-tests.json: "
                f"{missing_in_trace}"
            )
        if extra_in_trace:
            errors.append(
                "traceability-matrix.json contains extra smoke labels not present in runtime-smoke-tests.json: "
                f"{extra_in_trace}"
            )

    trace_md_smokes = set(re.findall(r"Smoke \d{2}", trace_md))
    invalid_trace_md_smokes = sorted(s for s in trace_md_smokes if s not in runtime_labels)
    if invalid_trace_md_smokes:
        errors.append(
            "traceability-matrix.md contains smoke labels not present in runtime-smoke-tests.md: "
            f"{invalid_trace_md_smokes}"
        )

    runtime_md_smokes = set(re.findall(r"Smoke \d{2}", runtime))
    if runtime_md_smokes != trace_md_smokes:
        missing_in_trace_md = sorted(runtime_md_smokes - trace_md_smokes)
        missing_in_runtime_md = sorted(trace_md_smokes - runtime_md_smokes)
        if missing_in_trace_md:
            errors.append(
                "traceability-matrix.md is missing smoke labels present in runtime-smoke-tests.md: "
                f"{missing_in_trace_md}"
            )
        if missing_in_runtime_md:
            errors.append(
                "runtime-smoke-tests.md is missing smoke labels present in traceability-matrix.md: "
                f"{missing_in_runtime_md}"
            )

    release_required_links = [
        "implementation-handoff.md",
        "milestone-verification-checklist.md",
        "runtime-smoke-tests.md",
        "traceability-matrix.md",
    ]
    for link in release_required_links:
        if link not in release:
            errors.append(f"release-readiness.md missing link to {link}")

    if errors:
        print("MVP doc validation: FAILED")
        for error in errors:
            print(f"- {error}")
        return 1

    print("MVP doc validation: PASSED")
    print(f"- top_level_docs: {top_level_doc_count}")
    print(f"- prd_docs: {prd_count}")
    print(f"- canonical_frame_names: {len(canonical_names)}")
    print(f"- canonical_frame_ids: {len(canonical_ids)}")
    print(f"- smoke_tests: {len(expected_smokes)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
