# Tier A Static Design Assets

This directory contains **static typographic placeholder assets** for n0vel promotion.
These are NOT real app screenshots. They are design mock-ups produced programmatically.

## Truthfulness Labels

| Label | Meaning |
|-------|---------|
| MOCK PLACEHOLDER | Typographic design graphic, not a real app screenshot |
| STATIC DESIGN ASSET | Video overlay card, not claiming to show app UI |
| REAL APP SCREENSHOT | Authentically captured from running app (none in this set) |

**No asset in this directory is a real app screenshot.** Tier B real screenshots remain blocked on app-code stabilization (three-pane branch uncommitted).

## Asset List (10 files)

| File | Dimensions | Size | Purpose | Truthfulness |
|------|-----------|------|---------|--------------|
| `social-preview.png` | 1280x640 | ~48 KB | GitHub social preview card | MOCK PLACEHOLDER |
| `novel-writer-preview.png` | 1440x900 | ~61 KB | README hero image | MOCK PLACEHOLDER |
| `title-card.png` | 1920x1080 | ~40 KB | Video title card overlay | STATIC DESIGN ASSET |
| `cta-card.png` | 1920x1080 | ~37 KB | Video CTA card overlay | STATIC DESIGN ASSET |
| `summary-card.png` | 1920x1080 | ~57 KB | Video summary card overlay | STATIC DESIGN ASSET |
| `section-overlay-01.png` | 1920x1080 | ~25 KB | "01 安装与启动" section card | STATIC DESIGN ASSET |
| `section-overlay-02.png` | 1920x1080 | ~28 KB | "02 项目与角色" section card | STATIC DESIGN ASSET |
| `section-overlay-03.png` | 1920x1080 | ~26 KB | "03 章节与正文" section card | STATIC DESIGN ASSET |
| `section-overlay-04.png` | 1920x1080 | ~31 KB | "04 AI 候选与确认" section card | STATIC DESIGN ASSET |
| `section-overlay-05.png` | 1920x1080 | ~23 KB | "05 总结" section card | STATIC DESIGN ASSET |

## Source / Reproducibility

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
