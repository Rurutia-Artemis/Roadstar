# T1 验收记录

## 结论
通过

## 验收档位
轻档（两个测试文件共 16 行）。写的是 Codex gpt-6.1-sol high，验收换一家：Sonnet 子代理。

## 复跑的验收命令与输出
- `bash skill/scripts/tests/run.sh`：退出 0，最后一行 `PASS 18 checks`，`ok` 265 条。
- 正向改坏：在 `expect_exit 2 grok_task T3` 前临时插 `sleep 5`，整套仍退出 0、265 条 ok。已还原。
- 反向改坏：把放行文件的 `touch` 挪到 `expect_exit 2` 之前并加 `sleep 3`，整套退出 1，输出 `expected exit 2, got 0`、`FAIL: line 79`。已还原。

## 逐项完成线
- K1 过：假 grok 只在设了 `FAKE_GROK_HOLD` 时走新分支（每 0.1 秒查一次，最多 60 秒，超时往 stderr 打原因并退出 1）；没设时仍是原来的 `sleep`。
- K2 过：后台那次派活改用放行文件，`touch` 在 `expect_exit 2` 之后、`wait_done` 之前。
- K3 过：见正向改坏。
- K4 过：两处测超时的 `FAKE_GROK_DELAY=6` 不在改动里。
- K5：执行方报告连跑三次都是退出 0、265 条；验收方复跑一次加正向改坏一次，两次都是退出 0、265 条。
- K6 过：没有删用例、放宽断言、skip 或重试。

## 降标准五查
- 下调门槛：无。
- 跳过或删测试：无。
- 关掉检查：无。
- 留桩或半成品：无。
- 新增例外 / 改检查配置：无。

## 未验证
- 验收方没有独立连跑三次（跑了两次通过的整套）。
- `grep -n 'FAKE_GROK_DELAY=2'` 无输出这条验收方没单独跑，从改动判断只删了那一处。
