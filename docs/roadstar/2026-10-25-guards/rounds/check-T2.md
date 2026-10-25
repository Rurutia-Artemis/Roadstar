# check-T2 · Argo 验收（2026-10-25）

结论：通过。

- `python3 -m py_compile skill/scripts/guard.py && bash -n skill/scripts/install-guard.sh && bash -n skill/scripts/dex-exec.sh` → 退出码 0。
- `bash skill/scripts/tests/guard-tests.sh`、`/bin/bash skill/scripts/tests/guard-tests.sh` → 末行都是 `PASS 41`。
- 任务书第 4 条写错了（`--brief /dev/null` 在改动前的 HEAD 上同样退出 2，Codex 已在基线上复现）；改用真实 brief 文件 `--write --dry-run`：退出码 0，只打印将执行的命令，临时目录里没有写任何文件或标记。
- `echo '{"tool_name":"Read","tool_input":{}}' | python3 skill/scripts/guard.py claude-pretool` → 无输出，退出码 0。
- dex-exec.sh 的改动只有 C10 那一段（`--write` 时在 ROOT 里 `guard.py mark`，失败只警告）。
- 模块地图「任务执行与验收」一节的入口、对外接口、怎么测三行和模块一览目录栏已更新。
- 真实项目实测另记（Huemo 副本）。
