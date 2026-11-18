# RSH1 执行报告

## T1c 返工

基线：`docs/homepage-2x`，`04a6ed8`。

| 图 | 位置 | 脚本旧字 | 译文定稿 |
| --- | --- | --- | --- |
| 英文 `hero.svg` | 左栏主句 3（第一条副句） | `Another vendor's model hunts for errors,` | `Another vendor's model hunts for errors.` |

- **R1 / C1**：改前逐行核对英雄图英日各 10 格，只有上表一处差异；改后再核对，差异为 0。SVG 第三句及其 `desc` 同步使用定稿句号。英雄图表外文字 `CLAUDE CODE SKILL · v2.0.0`、`T1`、`T2`、`✓` 原样保留；其余图（包括改版对照的「开工前」「探讨」行）整图不变。
- **R2**：最左侧示意卡从 `x=528` 起，计入 2 单位描边后左缘为 527。左栏文字从 `x=49` 起，再留 40，可用宽度为 438。英文第三句在原 20 字号下估宽 480，改为 18 后估宽 432，按检查器折算为 13.2 px（下限 11 px）。英文两条副句同为 18，字体不变；三语左栏副句均各占一行，基线为 321、352。
- **R3**：故意把英文第三句加长到三行时，连同下一句的基线依次为 321、345.3、369.6、393.9；相邻行距均为 `18 × 1.35 = 24.3`。
- **R4 / C2 / C4**：15 图逐张与基线 blob 比较，只有 `assets/readme/hero.svg` 变更；另 14 张逐字节相同，包括中文和日文英雄图。中文 SVG 的 `git diff --exit-code` 退出 0。英文 `hero.svg` 的 viewBox 宽高为 `1200 × 472 → 1200 × 472`。在 `git diff --stat -- assets/readme` 中，配图只有 `hero.svg`，源码只有 `source/gen_hero.py`。
- **R5 / C3**：`python3 assets/readme/source/check_assets.py --all` 退出 0，输出 `PASS 15 SVGs; three READMEs; no unreferenced SVGs`。
- **R5 / C5**：三个 `gen_*.py` 各用 `python3` 跑两遍；`shasum -a 256 assets/readme/*.svg` 两次共 15 项，`cmp` 退出 0。`bash skill/scripts/tests/run.sh` 退出 0，九条 `PASS N checks` 依次为 90、20、95、36、42、8、18、40、23；另外两条无 `checks` 后缀的 guard 和 close-check 汇总仍为 `PASS 51`、`PASS 14`。`wc -l assets/readme/source/*.py` 依序为 273、61、135、108、137，均小于 400。
- **R5 / C6**：在临时目录备份生成器，用 Python 把脚本内新的英文第三句替换为同句以空格连接、重复三次（`original.replace(line, b" ".join((line,) * 3), 1)`）。命令及退出码如下。

| 步骤 | 命令 | 退出码 / 输出 |
| --- | --- | --- |
| 变异前取散列 | `shasum -a 256 assets/readme/*.svg` | 0，15 项 |
| 变异后生成 | `python3 assets/readme/source/gen_hero.py` | 0 |
| 变异后检查 | `python3 assets/readme/source/check_assets.py --all` | 1，`hero.svg` 中 `Scripts enforce the rules.` 越过 `intro` |
| 恢复备份后重生成 | `python3 assets/readme/source/gen_hero.py` | 0 |
| 还原后检查 | `python3 assets/readme/source/check_assets.py --all` | 0，15 图和三份 README 通过 |
| 还原后取散列并比对 | `shasum -a 256 assets/readme/*.svg`，`cmp "$temp_dir/c6-before" "$temp_dir/c6-after"` | 均为 0；与变异前 15 图散列一致 |

`CHANGELOG.md` 已补记返工。已清理本次临时文件；本次图面待 Argo 转图复核。按本轮离线要求，未写入 M1 共享记忆。未提交、未推送。

完成状态：全部完成
