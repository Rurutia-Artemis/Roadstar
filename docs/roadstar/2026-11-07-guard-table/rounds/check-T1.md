# check-T1（2026-11-09 03:55，Argo 沙箱外复跑）

通过。

- `bash skill/scripts/tests/run.sh`（Roadstar-slots/s1）：退出 0，guard PASS 50、close-check PASS 13；跑完 `docs/roadstar/2026-10-25-guards/rounds/exec-T2.progress` 被改，已 `git checkout` 还原。
- `guard.py modules`：Mia 37、RuruAgent 23、RUVO 开发线 25、Roadstar 8；RuruAgent `记忆服务（M1）` → `tools/memory/`，`中文写作、声线与语料` → `skills/, Puppis/`（反引号外说明已丢）。
- 读 diff：`modules_from` 认 模块/名称/工具 + 目录/路径/位置/正本；表前 `X`=`路径` 缩写展开；外部地址与含空格非路径丢弃；`requested_modules` 先整行匹配、再去尾部括号匹配；入口检查与两个放行尾注未改。
- 影响：合入后 Mia、RuruAgent 的范围检查不再被跳过，写错模块名或改出范围的提交会被拦（可用 Roadstar-Scope 放行）。
