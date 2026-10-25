1. **改了哪些文件**

   - `skill/scripts/cleanup.py`：接续前次 `--check` 实现，保留只读 Git、任务 trailer 汇总、未清副本与验收记录检查；补清 `--plan-dir` 在检查模式下的帮助说明。
   - `skill/scripts/tests/close-check-tests.sh`：C2 失败根因是 macOS `mktemp` 返回 `/var/...`，Git 报 `/private/var/...`，直接比较路径字符串产生误报；临时仓库路径改为 `resolve()` 后三条全部通过。删除读取历史进度和累计失败阻止重跑的逻辑；进度仅由可选 `ROADSTAR_CLOSE_CHECK_PROGRESS` 指定追加位置。加强 C7：调用方允许 Git 刷新索引，触碰被检查副本的文件时间，再验证检查自身禁止刷新且全部文件、mtime、mode、目录与 Git 列表不变。
   - `skill/scripts/tests/run.sh`：保留前次紧跟 guard-tests 的 close-check-tests 调用。
   - `docs/模块地图.md`：保留并完善 cleanup 接口、C1–C8 测试与可重复运行说明。
   - `docs/roadstar/2026-10-25-guards/rounds/exec-T3b.progress`：本轮逐项进度；本执行回复更新为当前结果。运行原 guard 测试时，该脚本自行追加了 `exec-T2.progress`，没有修改 guard 测试代码。

   已复查一轮，修正了 C7 的验证盲点。本轮临时仓库与隔离的编译缓存均已删除；前次遗留的 `skill/scripts/__pycache__/cleanup.cpython-314.pyc` 未动。未提交、未推送。

2. **跑了哪些验证命令及输出**

   `python3 -m py_compile skill/scripts/cleanup.py`：无输出，退出码 0。编译缓存通过 `PYTHONPYCACHEPREFIX` 放入本轮临时目录，结束后删除。

   `bash skill/scripts/tests/close-check-tests.sh`：退出码 0，末尾原文：
   ```text
   PASS C7 文本和 JSON 检查前后 worktree、分支、目录及全部文件内容与 mtime 一致
   PASS C8 原 dry-run 及 apply 保持清理与保护规则：只清已合并干净副本和过期中间产物
   PASS 13
   ```

   `/bin/bash skill/scripts/tests/close-check-tests.sh`：退出码 0，末尾原文：
   ```text
   PASS C7 文本和 JSON 检查前后 worktree、分支、目录及全部文件内容与 mtime 一致
   PASS C8 原 dry-run 及 apply 保持清理与保护规则：只清已合并干净副本和过期中间产物
   PASS 13
   ```

   `bash skill/scripts/tests/guard-tests.sh`：退出码 0，末尾原文：
   ```text
   PASS C11 坏标记、坏 trailer 和未知分支都给中文补救，无堆栈
   PASS C12 关闭开关直接放行三种钩子，Claude 静默且不读 stdin
   PASS 43
   ```

   `python3 skill/scripts/cleanup.py --project . --check --apply`：退出码 2，原文：
   ```text
   --check 只查不删，不能和 --apply 一起用
   ```

3. **没做成的和原因**

   指定五项验收均达到期望结果，C1–C8 的 13 条用例全部通过；最终验收留给 Argo。

   全量 `run.sh` 未运行：本任务限定只用列出的五项验证命令。没有修改或重新验证任务书提及的第 1139 行既有失败，不能把本轮定向回归称为全量通过。按本任务范围未运行安装、未写仓库外共享记忆。
