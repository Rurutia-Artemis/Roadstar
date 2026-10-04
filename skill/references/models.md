# 型号表（查证 2026-10-04）

调度时在主席定的方向里从这两张表挑型号和强度。派给谁的规则见 `division-of-labor.md`。

## Claude 侧

| 型号 | 用途 | 强度 | 注意点 |
|---|---|---|---|
| Fable 5.1 | 主会话：判断、取舍、任务书、裁定 | 跟会话设置走 | 判断最强；Max 套餐里最多占周额度一半，主会话是 Fable 时更要省，不派子任务给它 |
| Opus 5.5 | 实现主力；跨家验收（`roadstar-checker`） | high / xhigh | Claude Code 里默认强度是 medium，所以子代理定义里钉成 high（`roadstar-builder`、`roadstar-checker`）或 xhigh（`roadstar-builder-hard`） |
| Sonnet 5.5 | 机械活、取证、轻验收（`roadstar-builder-light`） | medium | 难活不给它 |
| Haiku 4.5 | 只做一句话查询 | 默认 | 不派实现和验收 |

## Codex 侧

| 型号 | 用途 | 强度 | 相对消耗 | 注意点 |
|---|---|---|---|---|
| `gpt-6-astra` | 最强：难活和审稿 | low / medium / high / xhigh / max / ultra | 基准 | ultra 会自动拆子任务，慢；max 和 ultra 主席点名才用 |
| `gpt-6.1-sol` | 常规实现、机械批量、只读取证、复核 Astra 写的活 | low / medium / high / xhigh / max / ultra | 约 Astra 的五分之一 | 要 codex-cli 0.160 以上：0.158 调它会 400「not supported when using Codex with a ChatGPT account」，升到 0.160 就通（2026-10-04 实测）。调用一律显式传 `--effort`（缓存里默认 low） |
| `gpt-6-luna` | 不派活 | low – max，没有 ultra | 约 6.1 Sol 的二十分之一 | 主席 2026-10-04 判它太差；只在冒烟测试里跑一句话 |
| `gpt-6-sol` / `gpt-5.6-*` | 旧款 | — | — | 不用 |
| `gpt-5.5` | 旧款 | — | — | 2026-10-14 退役 |

## 两条注意

Fast 档按 2.5 倍扣订阅额度，圆桌脚本一律带 `--disable fast_mode`。

型号会变，缓存里有也不等于当前 CLI 能调。开场核对 `codex --version`（≥ 0.160）和 `~/.codex/models_cache.json` 的 slug 列表，和这张表不一致时在纪要里提一句；第一次用某个型号先拿 `codex exec --skip-git-repo-check -s read-only -m <型号> --ephemeral "只回复两个字：正常"` 探一下，400 先 `codex update` 再试，还不行就换型号并记进账本。Codex 的付费 credits 余额动的是真钱，要用先有主席授权。
