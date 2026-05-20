#!/usr/bin/env python3
"""Verify Qidian main-site category sample chapters.

Checks structure, body length, forbidden patterns, and README links.
Uses only stdlib — no third-party dependencies.
"""

import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

EXPECTED_FILES = [
    ("01_xuanhuan.md", "玄幻"),
    ("02_qihuan.md", "奇幻"),
    ("03_wuxia.md", "武侠"),
    ("04_xianxia.md", "仙侠"),
    ("05_dushi.md", "都市"),
    ("06_xianshi.md", "现实"),
    ("07_junshi.md", "军事"),
    ("08_lishi.md", "历史"),
    ("09_youxi.md", "游戏"),
    ("10_tiyu.md", "体育"),
    ("11_kehuan.md", "科幻"),
    ("12_zhutian_wuxian.md", "诸天无限"),
    ("13_xuanyi.md", "悬疑"),
    ("14_qingxiaoshuo.md", "轻小说"),
    ("15_duanpian.md", "短篇"),
]

REQUIRED_SECTIONS = [
    "分类:",
    "标题:",
    "一句话钩子:",
    "卖点/读者承诺:",
    "核心人物:",
    "世界/设定快照:",
    "## 第一章正文",
    "## 章末钩子",
    "## 质量自评",
]

FORBIDDEN = [
    "叶尘",
    "苏瑶",
    "心中一凛",
    "TODO",
    "待补充",
    "占位",
    "作为一个AI",
    "本文由AI生成",
    "以下是为您",
]

CJK_RANGE = re.compile(r"[一-鿿㐀-䶿豈-﫿]")


def count_cjk(text: str) -> int:
    return len(CJK_RANGE.findall(text))


def extract_body(content: str) -> str:
    """Extract text between ## 第一章正文 and the next ## heading."""
    pattern = r"## 第一章正文\s*\n(.*?)(?=\n## )"
    m = re.search(pattern, content, re.DOTALL)
    if not m:
        return ""
    return m.group(1)


def check_sample(filepath: str) -> dict:
    result = {"file": filepath, "errors": [], "warnings": [], "body_len": 0}

    if not os.path.exists(filepath):
        result["errors"].append("FILE MISSING")
        return result

    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # Check required sections
    for section in REQUIRED_SECTIONS:
        if section not in content:
            result["errors"].append(f"Missing section: {section}")

    # Check body length
    body = extract_body(content)
    cjk_count = count_cjk(body)
    result["body_len"] = cjk_count
    if cjk_count < 3000:
        result["errors"].append(f"Body too short: {cjk_count} chars (min 3000)")
    elif cjk_count > 5000:
        result["errors"].append(f"Body too long: {cjk_count} chars (max 5000)")

    # Check forbidden patterns
    for word in FORBIDDEN:
        if word in content:
            result["errors"].append(f"Forbidden pattern: '{word}'")

    return result


def check_readme(readme_path: str) -> dict:
    result = {"file": readme_path, "errors": [], "warnings": []}

    if not os.path.exists(readme_path):
        result["errors"].append("README MISSING")
        return result

    with open(readme_path, "r", encoding="utf-8") as f:
        content = f.read()

    for fname, _ in EXPECTED_FILES:
        if fname not in content:
            result["errors"].append(f"Missing link to {fname}")

    return result


def main():
    all_pass = True
    results = []

    # Check each sample
    for fname, category in EXPECTED_FILES:
        filepath = os.path.join(SCRIPT_DIR, fname)
        r = check_sample(filepath)
        r["category"] = category
        results.append(r)
        if r["errors"]:
            all_pass = False

    # Check file coverage
    actual_files = {
        f for f in os.listdir(SCRIPT_DIR) if f.endswith(".md") and f != "README.md"
    }
    expected_set = {fname for fname, _ in EXPECTED_FILES}
    missing = expected_set - actual_files
    extra = actual_files - expected_set
    if missing:
        all_pass = False

    # Check README
    readme_path = os.path.join(SCRIPT_DIR, "README.md")
    readme_result = check_readme(readme_path)
    if readme_result["errors"]:
        all_pass = False

    # Print results
    print("=" * 70)
    print("QIDIAN MAIN-SITE SAMPLE VERIFICATION")
    print("=" * 70)

    # Coverage
    print(f"\nFile Coverage: {len(actual_files)}/{len(expected_set)} samples")
    if missing:
        print(f"  MISSING: {', '.join(sorted(missing))}")
    if extra:
        print(f"  EXTRA: {', '.join(sorted(extra))}")

    # Per-sample results
    print(f"\n{'Category':<10} {'File':<28} {'Body CJK':>8} {'Status'}")
    print("-" * 70)
    for r in results:
        status = "PASS" if not r["errors"] else "FAIL"
        print(
            f"{r.get('category', '?'):<10} {r['file'].split('/')[-1]:<28} {r['body_len']:>8} {status}"
        )
        for e in r["errors"]:
            print(f"           -> {e}")

    # README
    readme_status = "PASS" if not readme_result["errors"] else "FAIL"
    print(f"\n{'README':<10} {'README.md':<28} {'':>8} {readme_status}")
    for e in readme_result["errors"]:
        print(f"           -> {e}")

    # Summary
    print("-" * 70)
    total = len(results)
    passed = sum(1 for r in results if not r["errors"])
    print(f"Samples: {passed}/{total} passed")
    print(f"README:  {readme_status}")
    print(f"Overall: {'PASS' if all_pass else 'FAIL'}")
    print("=" * 70)

    sys.exit(0 if all_pass else 1)


if __name__ == "__main__":
    main()
