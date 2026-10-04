# T1 · 圆桌脚本：quota-status.py、dex-exec.sh、dex-review.sh 改动、桩测试

你是 Codex，被派来做圆桌 skill 升级里的脚本部分。只做本任务书的事，改动限于「要做的」里列出的文件，不提交 git，不改 `~/.codex`、`~/.claude` 下任何文件。

## 背景

仓库 `/Users/rurutia/Documents/RuruCode/RuruAgent`，skill 在 `skills/roundtable/`。现有 `scripts/dex-review.sh`（把方案送给 Codex 审稿）和 `scripts/render-review.py`。本任务新增两个脚本、改一个，并配一套不联网的桩测试。
现成参考（Swift，照它的协议写 Python）：`/Users/rurutia/Documents/RuruCode/Reverie/app/Sources/Quota/UsageProbe.swift`、`QuotaSnapshot.swift` 第 86–153 行。
真实日志样例：`docs/roundtable/2026-09-24-audit-usage/rounds/r1-dex-stdout.log`（头部有 `model:` / `reasoning effort:` / `session id:` 行，末尾 `tokens used` 下一行是数字）。

## 已验证的事实（2026-10-04 在本机实测，直接用）

1. Claude 额度探针。起 `claude -p --input-format stream-json --output-format stream-json --verbose --strict-mcp-config --no-session-persistence --settings '{"remoteControlAtStartup":false}'`，环境加 `DISABLE_AUTOUPDATER=1`，cwd 用临时目录。stdin 每行一个 JSON：先发 `{"type":"control_request","request_id":"i1","request":{"subtype":"initialize"}}`，等 stdout 里 `type=control_response` 且 `response.request_id=i1`、`response.subtype=success`；再发 `{"type":"control_request","request_id":"u1","request":{"subtype":"get_usage","skip_behaviors":true}}`，等对应回复。`response.response` 里有：`subscription_type`（"max"）、`rate_limits_available`、`rate_limits.five_hour {utilization, resets_at(ISO)}`、`rate_limits.seven_day {utilization, resets_at}`、`rate_limits.model_scoped[] {display_name:"Fable", utilization, resets_at}`、`rate_limits.limits[] {kind: session|weekly_all|weekly_scoped, percent, resets_at, severity, scope.model.display_name}`。全程约 1.2 秒，不花额度。读完关 stdin、terminate 进程。
2. Codex 额度探针。起 `codex -s read-only -a never app-server`，stdin 按行 JSON-RPC：`{"id":1,"method":"initialize","params":{"clientInfo":{"name":"roundtable","version":"0.3"}}}` 等 id=1 回复；发 `{"method":"initialized"}`；发 `{"id":2,"method":"account/rateLimits/read"}` 等 id=2。`result.rateLimits`：`primary {usedPercent, windowDurationMins(10080=周, 300=5小时), resetsAt(unix 秒)}`、`secondary`（可能 null）、`planType`（"pro"）、`credits {hasCredits, balance(字符串)}`、`rateLimitReachedType`；`result.rateLimitResetCredits {availableCount, credits[] {status, title, expiresAt}}` 就是「重置卡」。约 1.8 秒。`result.accountId` 不要打印。
3. 退路：`~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` 里 `token_count` 事件带 `rate_limits`（`primary.used_percent` / `window_minutes` / `resets_at`），命令行不在或超时时取最新一条，标「N 小时前的记录」。
4. `codex exec`（0.158.0）参数：`-m`、`-c model_reasoning_effort=…`、`-s read-only|workspace-write`、`-C DIR`、`--skip-git-repo-check`、`--disable <feature>`、`-o FILE`（最后回复落文件）、`--output-schema`，提示用 `-` 从 stdin 读；`codex exec resume <SESSION_ID> -` 续会话（resume 不接 `-m`/`-s`/`-C`，沿用原会话设置）。

## 要做的

### A. 新建 `skills/roundtable/scripts/quota-status.py`（python3，只用标准库）

- 读两边额度（事实 1、2），每边超时 15 秒；失败走事实 3 的退路；都失败就说读不到，退出码 2。
- 分档。每边算 `elapsed` = 窗口已过比例（周窗按 `resetsAt − 7 天` 起算；5 小时窗按 `resetsAt − 5 小时`），`used` = 已用百分比。空：`used ≥ 95` 且距重置 > 6 小时；紧：`used ≥ 85` 或 `used − elapsed×100 ≥ 15`；宽：`used − elapsed×100 ≤ −15` 且 `used < 70`，或距重置 ≤ 12 小时且 `used < 80`；其余正常。Claude 取 5 小时窗、周窗、Fable 单列（有 `model_scoped` 才算）三项里最差的一档；Codex 取周窗（有 5 小时窗也一起算，取最差）。
- 滞回：可选 `--prev FILE` 读上一次 `--json` 的输出，只有当某一边的档位连着两次都算出同一个新档才换档，否则沿用上一次的档，并在 note 里写「沿用上次档位」；没有 `--prev` 直接用本次算出的档。
- 默认输出中文人话，格式照这个样子（时间用 JST，24 小时制）：

```
Claude：5 小时 13%（18:09 重置）｜本周 4%（10-11 13:00 重置）｜Fable 6%（上限是周额度一半）→ 宽
Codex：本周 1%（10-11 10:08 重置）｜重置卡 2 张｜credits 62500 → 宽
读数：2026-10-04 13:40 JST，两边都是实时读数
读不到：（没有就不打这行）
```

- `--json` 输出：`{"claude":{"five_hour":{"used":13,"resets_at":"…"},"seven_day":{…},"fable":{…}|null,"tier":"宽","plan":"max","source":"live|rollout|none","fetched_at":"ISO"},"codex":{"weekly":{…},"five_hour":{…}|null,"reset_cards":2,"credits":"62500","plan":"pro","tier":"宽","source":"live|rollout|none","fetched_at":"ISO"},"note":["…"]}`。
- 退出码：0 正常；2 两边都读不到。

### B. 新建 `skills/roundtable/scripts/dex-exec.sh`（bash）

用法：`dex-exec.sh <plan-dir> <T#> --model M --effort E --brief FILE [--root DIR] [--write] [--resume SESSION_ID] [--detach] [--status] [--force] [--dry-run]`

- 校验 plan-dir 存在、brief 文件存在；`rounds/` 自动建；T# 形如 `T3`、`T3b`。`--status` 不需要 `--model/--effort/--brief`。
- 命令：`codex exec --skip-git-repo-check -C ROOT -s read-only -m M -c model_reasoning_effort=E --disable fast_mode -o rounds/exec-T#.md - < brief`；`--write` 把 `-s read-only` 换成 `-s workspace-write`；`--resume ID` 时改为 `codex exec resume ID -c model_reasoning_effort=E -o rounds/exec-T#.md - < brief`（注释里写明 resume 不接 -m/-s/-C）。ROOT 默认 plan-dir 的 git 根，找不到用 plan-dir 的上级。
- 产物都在 `rounds/`：`exec-T#-request.md`（brief 的副本；已存在就写成 `exec-T#-request-r2.md`、`-r3`…表示第几次派）、`exec-T#.md`（最后回复）、`exec-T#-stdout.log`、`exec-T#.meta`（每行 `key=value`：`model, effort, sandbox, root, started, finished, exit, session_id, tokens_used, resumed_from, attempt`）。`session_id` 从 stdout 日志里 `session id:` 那行抓，`tokens_used` 从 `tokens used` 下一行抓；抓不到写空。
- 派活前读额度：调用同目录 `quota-status.py --json`；Codex 档位是「空」且没 `--force` → 打印原因、退出码 3；quota 脚本本身失败只警告不拦。
- `--detach`：用 `nohup` 起 codex 并后台化，写 `rounds/exec-T#.pid`，进程结束后写 `rounds/exec-T#.exit`（退出码）和补全 meta；脚本立即返回并打印「查状态用 --status」。`--status` 打印该任务是运行中还是已结束、退出码、meta 内容。
- `--dry-run` 只打印将执行的命令和产物路径，不调 codex、不读额度。
- 失败（退出码非 0）时打印日志路径和最后 20 行，不生成替代结果。

### C. 改 `skills/roundtable/scripts/dex-review.sh`

- `--model` 默认 `gpt-6-astra`，`--effort` 默认 `high`；开头打印「模型 M / 强度 E」。
- codex 命令加 `--disable fast_mode`；两份数组合并成一份（模型总是传 `-m`）。
- `--dry-run` 不留下 `rounds/rN-plan.md`、`rN-plan.diff`、`rN-dex-request.md`（写到临时目录并打印路径，或退出前删除），这样下一轮轮号不变。
- 用法注释补 `--full` 和新默认值。
- 其余行为不变（请求拼装、精简模式、JSON 校验、用时打印）。

### D. 桩测试 `skills/roundtable/scripts/tests/`

- `tests/bin/codex`（bash 桩）：模仿 `codex exec`：打印类似真日志的头部（含 `model: …`、`reasoning effort: …`、`session id: <uuid>` 行），把 stdin 的提示写进 `-o` 指定的文件，末尾打印 `tokens used` 和下一行一个数字；支持 `exec resume <id>` 子命令（日志里写 `resumed: <id>`）；支持 `app-server` 子命令，按行回 JSON-RPC（结构同事实 2），`usedPercent` 可用环境变量 `FAKE_CODEX_USED` 控制，重置卡数用 `FAKE_CODEX_CARDS`。`tests/bin/claude`（bash 桩）：回 `control_response`（结构同事实 1），`utilization` 用 `FAKE_CLAUDE_USED` 控制。
- `tests/run.sh`：把 `tests/bin` 放到 PATH 最前面，依次验：quota-status.py 人话和 `--json` 都能出，档位算对（`FAKE_CODEX_USED=97` 时 Codex 是「空」）；`--prev` 的滞回生效；dex-exec.sh `--dry-run` 命令拼对；真跑桩后 `exec-T9.md`、`.meta`（`session_id`、`tokens_used` 和桩一致）、request 副本都在，第二次跑出现 `-r2` 后缀；`--resume` 走 resume 子命令；`--detach` 后 `.pid` / `.exit` 出现且 `--status` 能读；`FAKE_CODEX_USED=97` 时 dex-exec.sh 退出码 3，加 `--force` 放行；dex-review.sh `--dry-run` 跑两次后 `rounds/` 下没有残留文件；dex-review.sh 真跑桩一次后 `r1-dex-review.json` 是桩写的合法 JSON（桩读到 `--output-schema` 时输出一份符合 `references/dex-review.schema.json` 的最小 JSON）。全部通过打印 `PASS` 和条数，任一条失败退出码非 0。测试用的 plan-dir 在 `mktemp -d` 里建，跑完删。

## 不许动

`skills/roundtable/SKILL.md`、`skills/roundtable/references/` 下任何文件、`scripts/render-review.py`、仓库其他目录。不提交 git。

## 验收

- `bash skills/roundtable/scripts/tests/run.sh` 全过（沙箱里能跑，不联网）。
- `bash -n` 两个 .sh 通过；`python3 -m py_compile scripts/quota-status.py` 通过。
- 真机探针由派活方（Claude）在你交回后跑。

## 交付

最后回复只写三段：改了哪些文件（路径）；`tests/run.sh` 的输出摘要；没做成的和原因。不复述任务书。
