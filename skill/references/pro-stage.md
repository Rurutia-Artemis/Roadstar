# Pro 的两个用法：起草与终审

Pro 指网页端 GPT 的 Pro 思考模式。它是主席手里 GPT 这边最强的推理，但一趟要切到网页、几分钟起步，也读不到本地仓库（除非走 Codex 的 C2C 桥）。所以只放在两头，不进内环：

- 起草：规模「大」的项目，让 Pro 先出第一版 plan，Argo 和 Dex 都当审稿人。审别人的稿比审自己的狠。
- 终审：定稿候选交 Pro 看最后一遍，只收阻塞项和建议项。
- 兜底：Codex 空、又需要另一家审时，终审那一步可由 Pro 顶上，要主席动手。

规模「中」默认只终审，「小」不参与。主席在 brief 里可改。

## 三条通道，按顺序选

1. 主席在 Codex 应用里用已连接的 `codex-with-chatgpt`（说「用 Pro 规划」或「用 Pro 复查」）。ChatGPT 通过 C2C 桥只读工作区，能直接读 `docs/roadstar/<dir>/` 下的文件，主席让 Codex 把 Pro 的答复写进 `rounds/pro-draft.md` 或 `rounds/pro-review.md`。发送前 Codex 会核对对话真的在 Pro 模式。
2. 主席手动：Argo 把 `rounds/pro-request.md` 写好，主席贴进网页 Pro，把回答贴回 `rounds/pro-*.md`。
3. 主席点名 `pro-orchestrator`：走该 skill 的 ZIP 交接流程，交接包解出来后 Argo 把 `plan.md` 或 `review.md` 摘进圆桌文件。

通道 1 和 2 里 Argo 都不碰网页；Argo 只准备请求、等主席说「Pro 写完了」、读文件、入账。

## 请求模板

`rounds/pro-request.md`，Argo 生成，主席可改：

```markdown
# 圆桌 · <slug> · Pro <起草 / 终审>

你是第三位参与者 Pro。主席（用户）、Argo（Claude）、Dex（Codex）已经把材料放在下面。

## 你要做的
<起草：按「方案模板」写第一版 plan，每个槽位都写，写不出的标「待定：缺什么」。>
<终审：按「审稿清单」逐项打勾，只列阻塞项和建议项，每条给依据和改法。已在账本里解决或主席裁决过的不重提。>

## 回复格式
<起草：直接输出 plan.md 全文。>
<终审：verdict（PASS / NO_PASS）、checklist（逐项 ok / weak / missing）、issues（severity / scope / title / evidence / suggestion）、questions_for_chair。用 markdown 列表即可。>

## brief
<brief.md 全文>

## plan（终审时）
<plan.md 全文>

## 账本（终审时）
<ledger.md 的议题表与主席指令>

## 方案模板 / 审稿清单
<plan-template.md 的槽位列表，或 dex-review-prompt.md 的清单段>
```

发出去的内容等于发给外部服务：密钥、个人数据、未授权的私有代码不进请求。需要 Pro 看代码时列出具体文件和用途，确认在授权范围内再附。

## 入账

- Pro 起草稿：Argo 整理进 `plan.md`（保留 Pro 的结构和决定，改格式不改内容），版本标 `v1（Pro 起草）`。第一轮 Argo 自己先按清单审一遍，议题以 `A` 号入账；再跑 `dex-review.sh`，Dex 的以 `D` 号入账。
- Pro 终审：每条以 `P` 号入账，走同一套处置。Pro 与 Argo 或 Dex 意见相左，同样按事实类 / 取舍类处理；Pro 的话记进账本标 `Pro：`，纪要按纪要规矩写。

## 什么时候不值得

改动一天内能做完、方案已经很明确、或主席当下没有 Pro 额度，都跳过。跳过要在 brief 参与配置里写「Pro：不参与」，而不是留空。
