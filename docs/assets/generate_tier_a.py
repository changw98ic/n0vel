#!/usr/bin/env python3
"""Generate all 10 Tier A static typographic design assets for n0vel promotion."""

from PIL import Image, ImageDraw, ImageFont
import os

# ── Color palette ──────────────────────────────────────────────
BG         = (0x1A, 0x1B, 0x2E)
BG_END     = (0x2D, 0x2E, 0x45)
WHITE      = (0xFF, 0xFF, 0xFF)
TEXT_SEC   = (0xE0, 0xE0, 0xE0)
ACCENT     = (0x7C, 0x8C, 0xF8)
MUTED      = (0x9E, 0x9E, 0x9E)

# ── Font paths (macOS) ────────────────────────────────────────
CJK_FONT = "/System/Library/Fonts/STHeiti Light.ttc"
LATIN_FONT = "/System/Library/Fonts/Helvetica.ttc"
MONO_FONT = "/Library/Fonts/Arial Unicode.ttf"

OUT = os.path.dirname(os.path.abspath(__file__))

def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()

def gradient_bg(w, h):
    """Create vertical gradient from BG to BG_END."""
    img = Image.new("RGB", (w, h), BG)
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = y / h
        r = int(BG[0] + (BG_END[0] - BG[0]) * t)
        g = int(BG[1] + (BG_END[1] - BG[1]) * t)
        b = int(BG[2] + (BG_END[2] - BG[2]) * t)
        draw.line([(0, y), (w, y)], fill=(r, g, b))
    return img, draw

def centered(draw, text, y, fnt, fill, w):
    bbox = draw.textbbox((0, 0), text, font=fnt)
    tw = bbox[2] - bbox[0]
    draw.text(((w - tw) // 2, y), text, font=fnt, fill=fill)

def divider(draw, y, w, length=200):
    x0 = (w - length) // 2
    draw.line([(x0, y), (x0 + length, y)], fill=ACCENT, width=2)

def watermark(draw, w, h, text="MOCK PLACEHOLDER"):
    fnt = font(MONO_FONT, 14)
    bbox = draw.textbbox((0, 0), text, font=fnt)
    tw = bbox[2] - bbox[0]
    draw.text((w - tw - 16, h - 24), text, font=fnt, fill=(0x55, 0x55, 0x66))

# ══════════════════════════════════════════════════════════════
# 1. Social Preview — 1280x640
# ══════════════════════════════════════════════════════════════
def social_preview():
    W, H = 1280, 640
    img, draw = gradient_bg(W, H)

    # Product name
    f_name = font(LATIN_FONT, 88)
    centered(draw, "n0vel", 100, f_name, WHITE, W)

    # Divider
    divider(draw, 210, W, 240)

    # Tagline
    f_tag = font(CJK_FONT, 34)
    centered(draw, "本地优先 · AI 辅助 · 长篇小说工作台", 230, f_tag, TEXT_SEC, W)

    # Proof points
    f_pp = font(CJK_FONT, 22)
    proofs = [
        "• 结构化创作               • AI 候选稿逐段确认               • 本地优先",
        "   角色/世界观/场景               不是一键替代                    AI 按需连接",
    ]
    y = 320
    for line in proofs:
        centered(draw, line, y, f_pp, ACCENT if "•" in line else MUTED, W)
        y += 32

    # CTA
    f_cta = font(MONO_FONT, 18)
    centered(draw, "github.com/changw98ic/n0vel", H - 80, f_cta, MUTED, W)

    watermark(draw, W, H)
    img.save(os.path.join(OUT, "social-preview.png"), "PNG")
    print(f"social-preview.png  {W}x{H}")

# ══════════════════════════════════════════════════════════════
# 2. README Hero — 1440x900
# ══════════════════════════════════════════════════════════════
def readme_hero():
    W, H = 1440, 900
    img, draw = gradient_bg(W, H)

    # Product name — large
    f_name = font(LATIN_FONT, 120)
    centered(draw, "n0vel", 200, f_name, WHITE, W)

    # Divider
    divider(draw, 360, W, 300)

    # Tagline
    f_tag = font(CJK_FONT, 44)
    centered(draw, "本地优先 · AI 辅助 · 长篇小说工作台", 390, f_tag, TEXT_SEC, W)

    # Subtitle
    f_sub = font(CJK_FONT, 26)
    centered(draw, "给长篇作者的结构化创作工具", 470, f_sub, MUTED, W)

    # Proof points in a row
    f_pp = font(CJK_FONT, 24)
    proofs_row = "结构化创作        AI 候选稿逐段确认        本地优先"
    centered(draw, proofs_row, 560, f_pp, ACCENT, W)

    # CTA
    f_cta = font(MONO_FONT, 22)
    centered(draw, "github.com/changw98ic/n0vel", 680, f_cta, MUTED, W)

    # Placeholders label
    f_label = font(CJK_FONT, 20)
    centered(draw, "TYPOGRAPHIC PLACEHOLDER — 不是真实应用截图", 760, f_label, (0x55, 0x55, 0x66), W)

    img.save(os.path.join(OUT, "novel-writer-preview.png"), "PNG")
    print(f"novel-writer-preview.png  {W}x{H}")

# ══════════════════════════════════════════════════════════════
# 3. Title Card — 1920x1080
# ══════════════════════════════════════════════════════════════
def title_card():
    W, H = 1920, 1080
    img, draw = gradient_bg(W, H)

    # Product name
    f_name = font(LATIN_FONT, 120)
    centered(draw, "n0vel", 340, f_name, WHITE, W)

    # Tagline
    f_tag = font(CJK_FONT, 40)
    centered(draw, "本地优先 · AI 辅助 · 长篇工作台", 490, f_tag, TEXT_SEC, W)

    # Divider
    divider(draw, 560, W, 200)

    # Subtitle
    f_sub = font(CJK_FONT, 24)
    centered(draw, "给长篇作者的结构化创作工具", 590, f_sub, MUTED, W)

    watermark(draw, W, H, "STATIC DESIGN ASSET — MOCK PLACEHOLDER")
    img.save(os.path.join(OUT, "title-card.png"), "PNG")
    print(f"title-card.png  {W}x{H}")

# ══════════════════════════════════════════════════════════════
# 4. CTA Card — 1920x1080
# ══════════════════════════════════════════════════════════════
def cta_card():
    W, H = 1920, 1080
    img, draw = gradient_bg(W, H)

    # CTA primary
    f_cta = font(LATIN_FONT, 52)
    centered(draw, "Star → Clone → See README", 380, f_cta, WHITE, W)

    # URL
    f_url = font(MONO_FONT, 34)
    centered(draw, "github.com/changw98ic/n0vel", 470, f_url, ACCENT, W)

    # Tagline
    f_tag = font(CJK_FONT, 26)
    centered(draw, "本地优先，开源，作者确认", 550, f_tag, MUTED, W)

    watermark(draw, W, H, "STATIC DESIGN ASSET — MOCK PLACEHOLDER")
    img.save(os.path.join(OUT, "cta-card.png"), "PNG")
    print(f"cta-card.png  {W}x{H}")

# ══════════════════════════════════════════════════════════════
# 5. Summary Card — 1920x1080
# ══════════════════════════════════════════════════════════════
def summary_card():
    W, H = 1920, 1080
    img, draw = gradient_bg(W, H)

    # Header
    f_hdr = font(CJK_FONT, 44)
    centered(draw, "n0vel 能做什么？", 200, f_hdr, WHITE, W)

    # Divider
    divider(draw, 270, W, 300)

    # Three columns
    cols = [
        ("结构化创作", "角色/世界观/场景\n章节树管理"),
        ("AI 候选稿", "逐段确认\n不是一键替代"),
        ("本地优先", "项目资料本地管理\nAI 请求发到配置端点"),
    ]

    col_w = W // 3
    f_col_hdr = font(CJK_FONT, 30)
    f_col_body = font(CJK_FONT, 22)

    for i, (hdr, body) in enumerate(cols):
        cx = col_w * i + col_w // 2
        # Header
        bbox = draw.textbbox((0, 0), hdr, font=f_col_hdr)
        tw = bbox[2] - bbox[0]
        draw.text((cx - tw // 2, 360), hdr, font=f_col_hdr, fill=ACCENT)

        # Body lines
        y = 420
        for line in body.split("\n"):
            bbox = draw.textbbox((0, 0), line, font=f_col_body)
            tw = bbox[2] - bbox[0]
            draw.text((cx - tw // 2, y), line, font=f_col_body, fill=TEXT_SEC)
            y += 34

    watermark(draw, W, H, "STATIC DESIGN ASSET — MOCK PLACEHOLDER")
    img.save(os.path.join(OUT, "summary-card.png"), "PNG")
    print(f"summary-card.png  {W}x{H}")

# ══════════════════════════════════════════════════════════════
# 6–10. Section Overlays — 1920x1080 each
# ══════════════════════════════════════════════════════════════
def section_overlay(num, title, subtitle):
    W, H = 1920, 1080
    img, draw = gradient_bg(W, H)

    # Semi-transparent overlay effect (lighten slightly)
    for y in range(H):
        t = y / H
        r = int(BG[0] + (BG_END[0] - BG[0]) * t)
        g = int(BG[1] + (BG_END[1] - BG[1]) * t)
        b = int(BG[2] + (BG_END[2] - BG[2]) * t)
        # Slightly lighter to simulate semi-transparency
        r = min(255, r + 15)
        g = min(255, g + 15)
        b = min(255, b + 15)
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    # Section number — large, left-aligned
    f_num = font(LATIN_FONT, 72)
    draw.text((320, 400), num, font=f_num, fill=ACCENT)

    # Section title — right of number
    f_title = font(CJK_FONT, 52)
    draw.text((440, 415), title, font=f_title, fill=WHITE)

    # Section subtitle
    f_sub = font(CJK_FONT, 26)
    draw.text((440, 490), subtitle, font=f_sub, fill=MUTED)

    watermark(draw, W, H, "STATIC DESIGN ASSET — MOCK PLACEHOLDER")
    fname = f"section-overlay-{num}.png"
    img.save(os.path.join(OUT, fname), "PNG")
    print(f"{fname}  {W}x{H}")

def main():
    os.makedirs(OUT, exist_ok=True)

    print("Generating Tier A assets...")
    social_preview()
    readme_hero()
    title_card()
    cta_card()
    summary_card()

    sections = [
        ("01", "安装与启动", "Clone → pub get → run"),
        ("02", "项目与角色", "创建项目，添加角色和世界观"),
        ("03", "章节与正文", "章节树 + 正文编辑器"),
        ("04", "AI 候选与确认", "触发 AI → 逐段确认 → 导出"),
        ("05", "总结", "Star → Clone → See README"),
    ]
    for num, title, sub in sections:
        section_overlay(num, title, sub)

    print("\nAll 10 Tier A assets generated.")

if __name__ == "__main__":
    main()
