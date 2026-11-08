🛠 Karina · 工程

## 改了哪些文件

- `skill/scripts/guard.py`：支持表头别名、表前缩写、路径说明清洗、括号名称匹配，新增只读 `modules` 命令。
- `skill/scripts/tests/guard-tests.sh`：新增 6 条模块表用例。
- `skill/references/project-map.md`：补一句表头和缩写规则。
- `docs/模块地图.md`：同步命令接口与测试覆盖。
- `CHANGELOG.md`：记录改动、验证和未验证项。

另按要求追加 `exec-T1.progress`。已复核一轮，入口检查及两种放行尾注未改；测试临时目录由脚本清理。

## 验证命令及输出

- `bash skill/scripts/tests/guard-tests.sh`：退出 **0**，`PASS 50`，包含全部新增用例。
- `bash skill/scripts/tests/run.sh`：退出 **0**，`PASS 110 checks`、guard `PASS 50`、close-check `PASS 13`。
- 指定四仓库 `modules | wc -l`：依次 **37、23、23、8**，均达标。
- 指定终端模块 `grep`：命中展开后的两个 Core 路径。
- `git diff --stat main`：仅上述 **5 个文件**，178 行新增、7 行删除。
- `exec-T2.progress` 已恢复，最终 `git status --short` 中没有该文件。指定 `git checkout` 因沙箱禁止创建 `index.lock` 退出 128，随后用 `git show HEAD:<路径>` 的原文恢复。

四仓库各 3 行实际输出样例：

**Mia：37**
```text
主机 Web 与鉴权	agent/src/web/
App 终端工作台	app/Workstation/Sources/WorkstationCore/Views/Terminal/, app/Workstation/Sources/WorkstationCore/Models/
脚本 scripts	scripts/
```

**RuruAgent：23**
```text
技能治理与账本	SKILLS.md, config/, skills/absorb/
Claude 规则与安装	global/, install.sh
Codex 规则与安装	Codex专用/
```

**RUVO-wt-feat-r1-integ：23**
```text
采集-スニダン	02_数据接入包/scripts/
采集-X买取	02_数据接入包/scripts/lib/
采集-店铺官网买取	02_数据接入包/scripts/sources/store-web/
```

**Roadstar：8**
```text
流程与调度契约	skill/SKILL.md, skill/references/
额度探针	skill/scripts/quota-status.py, skill/scripts/tests/bin/, skill/references/providers.json
额度面板与排期	skill/scripts/quota-estimate.py, panel.py, schedule.py, quota-config.py, rs_tasks.py, skill/references/strategies.json, estimates.json
```

## 没做成的和原因

C1–C7 无未完成项。未验证真实项目挂钩提交；按任务边界未安装、未提交、未推送。共享记忆未写回，本任务禁止联网。