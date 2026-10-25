## 改了哪些文件

- 新增：`guard.py`、`install-guard.sh`、`tests/guard-tests.sh`。
- 修改：`dex-exec.sh`（仅 C10）、`tests/run.sh`（末尾一行）、`docs/模块地图.md`。
- 已保存[交付报告](/Users/rurutia/Documents/RuruCode/Roadstar/docs/roadstar/2026-10-25-guards/rounds/exec-T2.md)和进度记录。未提交、未推送。

## 验证命令及输出

| 命令 | 最后输出原文 | 退出码 |
|---|---|---:|
| `python3 -m py_compile skill/scripts/guard.py && bash -n skill/scripts/install-guard.sh && bash -n skill/scripts/dex-exec.sh` | 无输出 | 0 |
| `bash skill/scripts/tests/guard-tests.sh` | `PASS 41` | 0 |
| `/bin/bash skill/scripts/tests/guard-tests.sh` | `PASS 41` | 0 |
| `bash skill/scripts/dex-exec.sh /tmp/x T9 --model m --effort low --brief /dev/null --write --dry-run` | `brief 文件不存在：/dev/null` | 2 |
| `echo '{"tool_name":"Read","tool_input":{}}' \| python3 skill/scripts/guard.py claude-pretool; echo $?` | `0` | 0 |

## 没做成的和原因

**尚不能报全部完成：第 4 条验收未通过。** 未改动 HEAD 执行同一命令也返回 2：原脚本的 `-f` 校验不接受 `/dev/null`。按“只加 C10”的边界保留，未擅改。

临时仓库已清理；编译缓存 `skill/scripts/__pycache__/guard.cpython-314.pyc` 移入废纸篓被权限拒绝，仍在原处。

## 我做了哪些设计取舍

- 地图读取优先用暂存版本，防止未暂存修改误放行。
- 重命名同时检查旧、新路径。
- 补上真实 Git 钩子执行时 `MERGE_HEAD` 尚未生成的路径。
- 安装保留旧钩子；Claude 命令只解析、不执行。已做补漏复查并加入对应测试。