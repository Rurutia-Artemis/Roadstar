# T1 · Grok 派活测试里「上一件还在跑就拒派」那条不再靠 2 秒墙钟

## 目标与做完的样子
`skill/scripts/tests/grok-113.sh` 第 73 到 78 行：先用 `FAKE_GROK_DELAY=2` 后台起一个假 grok（T3），查 pid 文件和 `--status`，再派一次 T3，期望因上一件还在跑而退出 2。机器一卡，这几步超过 2 秒，后台那件已经结束，第二次派活成功，断言挂（11-15 05:00 实际发生过，输出「expected exit 2, got 0 / FAIL: line 77」；把延迟改成 0 可稳定复现）。完成线：

K1 假 grok（`skill/scripts/tests/bin/grok`）加一个按文件放行的开关：设了环境变量 `FAKE_GROK_HOLD=<路径>` 时，在原来 `sleep "${FAKE_GROK_DELAY:-0}"` 的位置改为一直等到该路径出现才继续（每 0.1 秒看一次；等满 60 秒还没出现就往 stderr 打一行原因并以非零退出，防止测试挂死）。没设这个变量时行为和现在完全一样。
K2 `grok-113.sh` 第 73 行那次后台派活改用 `FAKE_GROK_HOLD="$TMP/grok-hold-T3"`，不再用 `FAKE_GROK_DELAY=2`；在 `expect_exit 2 grok_task T3` 通过之后才创建放行文件，再 `wait_done`。之后的断言（`cmp`、`class=复核` 等）不动。
K3 证明不再依赖墙钟：在放行文件创建之前临时插入 `sleep 5`（验证完删掉，不留在提交里），这一段仍然通过；报告里写这次验证的输出。
K4 第 67 行和第 83 行两处 `FAKE_GROK_DELAY=6 ROADSTAR_MINUTE_SECONDS=1 … --max-minutes 1` 是测超时的，本来就要靠时间，不改。
K5 `bash skill/scripts/tests/run.sh` 连跑 3 次都退出 0；报告里给每次最后一行和 `ok` 的条数（改动前是 265 条，条数不许少）。
K6 不删用例、不放宽断言、不加 skip、不加重试。
达不到不算完成，如实报差多少。

## 背景
只读调查的结论：这条失败是第 73 行的 2 秒假延迟和第 77 行断言之间的时间竞争，已复现。同一时段另一条失败（`quota-status.py --json` 里 Claude 一侧读成 none）没复现，本件不处理、不加重试。

## 涉及模块
派活脚本的测试（`skill/scripts/tests`）

## 接口签名与文件范围
只改 `skill/scripts/tests/bin/grok` 和 `skill/scripts/tests/grok-113.sh` 两个文件。

## 不许动什么
`skill/scripts/` 下的正式脚本（`grok-exec.sh`、`dex-exec.sh`、`quota-status.py` 等）一行不改；`skill/SKILL.md`、`skill/references/` 不改；`tests/run.sh` 和其它测试文件不改；不读写真实的 `~/.cache/ruru`、`~/.config/roadstar`、`~/.claude`；不联网。

## 执行环境
工作目录 `/Users/rurutia/.claude/jobs/2c63ff8f/tmp/rs-race`（Roadstar 的临时克隆，分支 `flow/grok-test-race`，从 main 起）。测试只用本地假命令和临时目录。沙箱写不了工作目录以外的路径，不要执行会写 `.git` 的命令。

## 验收命令与期望输出
- `bash skill/scripts/tests/run.sh`：退出 0，连跑 3 次，`ok` 条数不少于 265。
- `git diff --stat`：只有上面两个文件。
- `grep -n 'FAKE_GROK_DELAY=2' skill/scripts/tests/grok-113.sh`：无输出。

## 资源上限与止损
预计 20 分钟，上限 40 分钟；单条命令超时 600 秒。同一检查项连续三次失败或到上限就停下交报告。

## 交付物
最后回复只列：K1 到 K6 过没过和证据；跑过的命令和输出结尾；没做成的、没跑的和原因。

## 收尾
删掉自己建的临时文件。

## 不提交
不提交 git，不推送，由调度方提交和合并。
