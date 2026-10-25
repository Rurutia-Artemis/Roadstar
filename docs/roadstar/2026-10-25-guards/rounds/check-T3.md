# check-T3 · Argo 验收（2026-10-25，T3 与改派的 T3b 合并验收）

结论：通过。T3（gpt-6.1-sol）卡在 C2 三次后止损；改派 T3b（gpt-6-astra）定位到是用例把 `/var` 与 `/private/var` 当成不同路径误报，修好并删掉了测试里的「三次失败就拒跑」逻辑，补完 C3–C8。

- `python3 -m py_compile skill/scripts/cleanup.py` → 退出码 0。
- `bash` 和 `/bin/bash` 跑 `skill/scripts/tests/close-check-tests.sh` → 末行都是 `PASS 13`。
- `bash skill/scripts/tests/guard-tests.sh` → `PASS 43`（T2 的测试没被弄坏）。
- `python3 skill/scripts/cleanup.py --project . --check --apply` → 「--check 只查不删，不能和 --apply 一起用」，退出码 2。
- 真 Huemo 只读实跑：列出 2 个没合并的工作副本（feat/ruru-liquid-vessel 领先 3、claude/happy-goodall-2c1d71 领先 1），和 `git worktree list` 对得上。
