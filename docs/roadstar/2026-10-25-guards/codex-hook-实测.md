# Codex 后台跑会不会触发它的 hook（2026-10-25 实测）

结论：不会自动触发。`codex exec`（codex-cli 0.163.0）里配了 PreToolUse hook（`-c hooks.PreToolUse=[…]`，matcher `^Bash$`，脚本写日志并以退出码 2 拦下），Codex 照常执行了 `echo hello-from-codex > out.txt`，日志为空，输出里也没有任何「hook 待审」的提示。

原因（官方文档 learn.chatgpt.com/docs/hooks「Review and trust hooks」）：非托管 hook 要先在 Codex 终端里用 `/hooks` 审过、信任当前定义的哈希才会跑；没信任的会被跳过。一次性跳过信任要加 `--dangerously-bypass-hook-trust`，本机 Claude Code 的安全规则不允许主会话代跑这个参数，没测。

对工作流的影响：Roadstar 派给 Codex 的活约定「不提交，由 Argo 合并」，提交和合并都发生在 Claude 主会话；git 钩子不管是哪家提交都会跑，所以第一版只装 git 钩子和 Claude Code 的合并前检查，Codex 那一层先不装。以后要让 Codex 也自己提交，再请主席在 Codex 终端里 `/hooks` 信任一次。
