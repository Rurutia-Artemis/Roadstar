改动位于 [skills/roundtable/scripts/](/Users/rurutia/Documents/RuruCode/RuruAgent/skills/roundtable/scripts)：新增 `quota-status.py`、`dex-exec.sh`、`tests/run.sh`、`tests/bin/codex`、`tests/bin/claude`；修改 `dex-review.sh`。

`tests/run.sh` 输出：`PASS 29 checks`。两个脚本的 `bash -n`、Python `py_compile`、`git diff --check` 均通过；已复核并修正进程清理与旧锁竞争问题。

无未完成的脚本项。真机探针未运行，按分工交由 Claude 验收；未提交 Git。