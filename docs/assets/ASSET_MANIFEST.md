# Promotion Assets

This directory contains one real desktop app screenshot and static typographic
placeholder assets for n0vel promotion. Every asset must keep its truthfulness
label when referenced from README, issue comments, release notes, or social copy.

## Truthfulness Labels

| Label | Meaning |
|-------|---------|
| MOCK PLACEHOLDER | Typographic design graphic, not a real app screenshot |
| STATIC DESIGN ASSET | Video overlay card, not claiming to show app UI |
| REAL APP SCREENSHOT | Authentically captured from the running desktop app |

`real-desktop-ai-review.png` is a real macOS desktop app screenshot captured
from the running app with temporary in-memory demo data and a local demo model
configuration. It does not include private API keys, local file paths, or
personal writing content. Placeholder assets remain labeled as placeholders.

## Asset List (11 files)

| File | Dimensions | Size | Purpose | Truthfulness |
|------|-----------|------|---------|--------------|
| `real-desktop-ai-review.png` | 1440x1024 | ~298 KB | README hero screenshot showing Workbench AI candidate review | REAL APP SCREENSHOT |
| `social-preview.png` | 1280x640 | ~48 KB | GitHub social preview card | MOCK PLACEHOLDER |
| `novel-writer-preview.png` | 1440x900 | ~61 KB | Legacy README preview placeholder | MOCK PLACEHOLDER |
| `title-card.png` | 1920x1080 | ~40 KB | Video title card overlay | STATIC DESIGN ASSET |
| `cta-card.png` | 1920x1080 | ~37 KB | Video CTA card overlay | STATIC DESIGN ASSET |
| `summary-card.png` | 1920x1080 | ~57 KB | Video summary card overlay | STATIC DESIGN ASSET |
| `section-overlay-01.png` | 1920x1080 | ~25 KB | "01 安装与启动" section card | STATIC DESIGN ASSET |
| `section-overlay-02.png` | 1920x1080 | ~28 KB | "02 项目与角色" section card | STATIC DESIGN ASSET |
| `section-overlay-03.png` | 1920x1080 | ~26 KB | "03 章节与正文" section card | STATIC DESIGN ASSET |
| `section-overlay-04.png` | 1920x1080 | ~31 KB | "04 AI 候选与确认" section card | STATIC DESIGN ASSET |
| `section-overlay-05.png` | 1920x1080 | ~23 KB | "05 总结" section card | STATIC DESIGN ASSET |

## Source / Reproducibility

- `real-desktop-ai-review.png` — captured from the macOS desktop app on 2026-05-26 using a temporary in-memory demo registry and local demo endpoint; no private keys or local file paths are visible.
- `generate_tier_a.py` — Python (Pillow) script that generates all 10 assets from scratch
- Fonts: STHeiti Light (CJK), Helvetica (Latin), Arial Unicode (mono) — all macOS system fonts
- Color palette: `#1A1B2E` bg, `#FFFFFF` text, `#7C8CF8` accent, `#E0E0E0` secondary, `#9E9E9E` muted

## Count Note

Prior planning documents referenced "9 Tier A assets" but listed 10 when including the README hero placeholder. This set produces all 10 listed assets. The discrepancy arose because the README hero was sometimes counted separately from the social/video assets.

## Forbidden Claims

These assets must never be described as:
- Real app screenshots
- Fully offline / no internet needed
- One-click generation / fully automated writing
- Any claim that contradicts the author-in-the-loop, local-first-with-configurable-endpoint design
