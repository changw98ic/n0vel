# Qidian Main-Site Category Sample Chapters

> 15 original first-chapter samples, one per Qidian main-site category, for use as durable promotion artifacts.

## Index

| # | 分类 | 标题 | 文件 | 正文字数 | 类型信号 (前500字) | 质量备注 |
|---|------|------|------|---------|-------------------|---------|
| 01 | 玄幻 | 碎星诀 | [01_xuanhuan.md](01_xuanhuan.md) | 3441 | 炼气/筑基/金丹体系、宗门制度、外门弟子 | ★★★ Reader-reviewed |
| 02 | 奇幻 | 第七誓约 | [02_qihuan.md](02_qihuan.md) | 3558 | 西方魔法体系、契约制度、魔法学院 | Original world, clean |
| 03 | 武侠 | 半把刀 | [03_wuxia.md](03_wuxia.md) | 4973 | 江湖、门派、内力、刀法、风信铺 | Longest sample, strong voice |
| 04 | 仙侠 | 劫种 | [04_xianxia.md](04_xianxia.md) | 3030 | 道基、结丹、劫数、宗主阴谋 | Near minimum length |
| 05 | 都市 | 深夜诊所 | [05_dushi.md](05_dushi.md) | 4226 | 现代城市、医疗场景、前神外主任 | Strong professional detail |
| 06 | 现实 | 早餐铺 | [06_xianshi.md](06_xianshi.md) | 4072 | 北方工厂小镇、早餐铺、下岗潮 | ★★★ Reader-reviewed |
| 07 | 军事 | 夜渡寒江 | [07_junshi.md](07_junshi.md) | 3464 | 夜视仪、九五式、排级战术、演习 | Authentic military detail |
| 08 | 历史 | 银痕 | [08_lishi.md](08_lishi.md) | 3644 | 户部清吏司、品级体系、赈灾核销 | Court intrigue, original dynasty |
| 09 | 游戏 | 深渊纪元 | [09_youxi.md](09_youxi.md) | 3212 | VR系统面板、GM工具、副本机制 | Game-dev perspective |
| 10 | 体育 | 水面之下 | [10_tiyu.md](10_tiyu.md) | 3105 | 泳池、计时、训练、复出 | Near minimum length |
| 11 | 科幻 | 熵减纪元 | [11_kehuan.md](11_kehuan.md) | 3552 | 深空站、熵减场、量子工程 | ★★★ Reader-reviewed |
| 12 | 诸天无限 | 无限攻略 | [12_zhutian_wuxian.md](12_zhutian_wuxian.md) | 3955 | 白色房间、倒计时、任务面板 | Original worlds only |
| 13 | 悬疑 | 七封未拆的信 | [13_xuanyi.md](13_xuanyi.md) | 3007 | 刑侦调查、证物、笔录、小镇 | Near minimum, tight plot |
| 14 | 轻小说 | 我的室友不是人 | [14_qingxiaoshuo.md](14_qingxiaoshuo.md) | 3032 | 第一人称毒舌、龙室友、校园喜剧 | Strong comic voice |
| 15 | 短篇 | 最后一渡 | [15_duanpian.md](15_duanpian.md) | 3553 | 文学笔触、渡口、老船工、告别 | Standalone literary feel |

## Verification

### Commands Run

```bash
# Structure and length verification (all 15 pass)
python3 artifacts/sample_chapters/qidian_main/verify_samples.py

# Placeholder-name, filler-marker, and AI-meta checks
# Result: clean across the 15 sample chapter Markdown files.

# Dart analyze (no new errors)
dart analyze
# → "No issues found!"

# Git status check
git status --short
git diff --name-only
```

### Results Summary

- **Sample verification**: 15/15 PASS (all bodies within 3000–5000 CJK chars)
- **Forbidden patterns**: CLEAN (zero matches)
- **AI meta text**: CLEAN (zero matches)
- **dart analyze**: No issues found
- **File coverage**: 15/15 expected files present

## Reader-Perspective Quality Reviews

### 01 玄幻 — 碎星诀

**Genre signal**: Immediate — "炼气三层"、"外门弟子"、"灵脉" in first paragraph. No ambiguity about category.

**Protagonist motivation**: Clear — 沈岳 wants to prove himself after 3 years stuck at 炼气三层. The forbidden technique creates tension between power and risk.

**Conflict clarity**: External (sect hierarchy) + internal (destroy-and-rebuild method is terrifying). The 7-day cultivation sequence has real stakes.

**Chapter completeness**: Full arc — mundane opener (cleaning duty) → mine tunnel collapse → sealed chamber discovery → forbidden technique download → 7-day cultivation → emergence at sect competition. Each beat advances the plot.

**Freshness**: The "break before build" mechanic is a genuine twist on standard cultivation tropes. No recycled "trash-to-genius" framing — 沈岳's struggle with destroying his own cultivation carries real weight.

**Prose cliche risk**: Low. Varied sentence lengths, specific sensory details (mine dust, cold stone), no generic filler phrases.

**Would click next chapter**: Yes. The emergence at sect competition creates immediate anticipation for the confrontation.

### 06 现实 — 早餐铺

**Genre signal**: Immediate — "四点闹钟"、"揉面"、"化肥厂"、"下岗" in first paragraphs. Unequivocally grounded reality with zero supernatural elements.

**Protagonist motivation**: Deeply relatable — 林素芳's identity is tied to her shop. The factory closure threatens not just income but her sense of purpose and community.

**Conflict clarity**: Economic survival vs. family duty. Stay or leave? The daughter's call at the end crystallizes the dilemma perfectly.

**Chapter completeness**: One day in the life — 4 AM prep → morning rush → factory closure news → regular customer reactions → evening alone → daughter's call. The emotional arc is subtle but complete.

**Freshness**: High. No sentimental manipulation. 林素芳's toughness is shown through action (blisters, flour burns, uncomplaining routine) rather than stated.

**Prose cliche risk**: Very low. Restrained, specific prose. The steam from the stove as recurring motif is effective without being heavy-handed.

**Would click next chapter**: Yes. The mysterious 5万元 transfer at the end is a compelling hook that doesn't break the realistic tone.

### 11 科幻 — 熵减纪元

**Genre signal**: Immediate — "深空站天枢"、"Lagrange点"、"熵减场"、"量子签名" establish hard-SF setting within first paragraph.

**Protagonist motivation**: Professional duty + existential stakes. 韩深's identity is the station — he has nothing else. The discovery threatens everything he's maintained.

**Conflict clarity**: Scientific mystery with ticking clock. The 72-hour projection creates genuine urgency. The problem is technical but the stakes are human.

**Chapter completeness**: Routine check → anomaly discovery → initial investigation → projection calculation → realization of scale. Classic SF first-chapter structure executed cleanly.

**Freshness**: The "entropy reversal causes time reversal" premise is genuinely original — not just entropy manipulation but the consequence of successful entropy reduction. The escalation from 0.003% quantum shift to human-scale time reversal is well-calibrated.

**Prose cliche risk**: Low. Technical vocabulary is used accurately. The quiet horror of watching a clock run backwards is effective.

**Would click next chapter**: Absolutely. The 72-hour countdown and the question of whether to shut down the field (killing the station's life support) create an impossible choice.

## Quality Risks

| Risk | Severity | Notes |
|------|----------|-------|
| 04 仙侠 body length near minimum (3030) | Low | Meets threshold but limited buffer |
| 10 体育 body length near minimum (3105) | Low | Meets threshold but limited buffer |
| 13 悬疑 body length near minimum (3007) | Low | Meets threshold, tight prose compensates |
| 02 奇幻 independent-read cleanup | Resolved | Removed an early cross-sample narrator aside so the chapter reads independently |
