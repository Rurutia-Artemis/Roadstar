# 调度记录 · Grok 派活测试不再靠 2 秒墙钟

来源：11-15 05:00 前后 `skill/scripts/tests/run.sh` 连续两次各挂一项、位置不同，之后又都通过。会话「大脑」要求查清并修（提交检查自己的测试，偶发失败不能放着）。大小：小活（窄回归，两个测试文件），免设计页。

## 记于 11-15

- 调查（Sonnet 只读）：`grok-113.sh` 第 73 行用 2 秒假延迟占住锁，第 77 行断言「上一件还在跑就拒派」，中间几步一慢就超过 2 秒；把延迟改成 0 稳定复现，输出与当时的失败逐字一致。另一条失败（额度读数里 Claude 一侧读成 none）没复现，证据和猜测记成记忆服务待办 mc-2f1b85e8b6，本件不处理。
- T1 写：Codex gpt-6.1-sol high，在 Roadstar 的临时克隆里（任务临时目录下，分支 `flow/grok-test-race`），数字见 `rounds/exec-T1.meta`。
- T1 验收：Sonnet 轻档，通过，见 `rounds/check-T1.md`。
- 停车场：`tests/run.sh` 没把 `HOME` 设到临时目录，codex 额度探测失败时会回退去读真实 `~/.codex/sessions`；额度断言失败时没把 `note` 字段完整打出来。
- 合并没做成：修复已提交在分支 `flow/grok-test-race`（`cf86e89`，已取回 Roadstar 主仓库，和主干 `48fa082` 预合并无冲突）。往 Roadstar 主干合并的命令被自动权限检查拒绝，原话：「Permission for this action was denied by the Claude Code auto mode classifier. Reason: [Destructive or Unwanted Actions].」没有换写法，报给会话「大脑」，等有权限的人来合。
- 会话「大脑」裁定（不是主人的话）：这笔合并不再试。这条线的授权只到 RuruAgent，让它来修 Roadstar 的测试是派活时把范围派大了。修复停在分支 `flow/grok-test-race`，等主人一句话定合不合、谁来合；合并后要跑 `bash skill/scripts/tests/run.sh`。验收记录和台账提交在同一个分支上，不碰主干。
