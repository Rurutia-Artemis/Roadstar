<p align="center">
  <img src="./assets/readme/hero.zh-CN.svg" width="100%" alt="Roadstar 引路星：Claude 想方案、拆活、验收，Codex 写代码。两边订阅都用上，每份方案都有另一家模型挑错。">
</p>

<p align="center"><a href="./README.md">English</a> · <b>中文</b> · <a href="./README.ja.md">日本語</a></p>

<p align="center">
  <img src="https://img.shields.io/badge/Claude_Code-skill-E07A5F?style=flat-square" alt="Claude Code skill">
  <img src="https://img.shields.io/badge/Codex_CLI-%E2%89%A5%200.160-3E9C9E?style=flat-square" alt="Codex CLI 0.160 以上">
  <img src="https://img.shields.io/badge/version-1.7.0-F2B544?style=flat-square" alt="版本 1.7.0">
  <img src="https://img.shields.io/badge/deps-bash%20%2B%20python%20stdlib-8A8798?style=flat-square" alt="只用 bash 和 Python 标准库">
  <img src="https://img.shields.io/badge/license-MIT-2B2A3D?style=flat-square" alt="MIT 许可">
</p>

Roadstar 是一个 Claude Code 技能，让 Claude 主会话当总调度，带着 Codex 一起干项目。Claude 写方案，把活拆成一件件两小时内能做完的小任务，给每件挑型号，写代码交给 Codex，交回来以后换一个型号验收，过了才给你看。Claude 和 ChatGPT 两边都有订阅的人，两份钱终于都在干活。

## 真跑过

作者从 2026-10-04 起在自己的四个项目里用它（两个 App、一个网站、一个设计工具）：

- **17 场**，从一个想法到发版
- **244 次 Codex 会话**：`gpt-6.1-sol` 130 次，`gpt-6-astra` 114 次
- **31 条规矩**，每条都是某一场真出了事当天写进去的：一条线 7 个半小时烧掉三成周额度，一次合并把 846 个截图提交进了分支，一版测试全过的 App 装到手机上整屏点不动

每一场开头报一行配置和实时额度。额度探针一秒多读完两边，不花额度：

```console
$ python3 skill/scripts/quota-status.py
Claude：5 小时 4%（18:49 重置）｜本周 82%（10-18 12:59 重置）｜Fable 2%（上限是周额度一半） → 紧
Codex：本周 24%（10-20 14:57 重置）｜重置卡 1 张｜credits … → 正常
```

Claude 紧、Codex 正常，所以这周写代码的活往 Codex 派。

## 它解决什么

**两份订阅，以前只有一份在干活。** Claude 整理和指挥更强，就让它专门想方案、拆活、审；实现交给 Codex。Codex 额度紧了，活就顺着 Claude 这边的梯子走：机械批量给 Haiku，规格清楚的给 Sonnet，难活给 Opus。

**方案一遍想不完。** Claude 和 Codex 的盲区不重合。探讨时两家最强的型号围着同一份方案挑错，每条意见必须带文件、行号或命令输出，Claude 逐条接受、写理由驳回、或者交给你定。默认三轮，两边都没新问题就提前停。

**派活和验收太累。** 每件活写清楚能判失败的完成线、型号和强度、脚本强制的时间上限，以及审查人，审查人一定不是写它的那个型号。合并以后 Claude 自己在主干上再跑一遍完整测试，执行方报的「全过」只当参考。

<p align="center">
  <img src="./assets/readme/workflow.zh-CN.svg" width="100%" alt="三种用法，一个入口。探讨：只有一个想法，Claude 写方案、Codex 审，谈三轮出方案和拆分表。复盘：项目已经有了，两家各读一遍交叉审，出不足清单和先做三件事。协同：方案已经有了，拆活、派活、验收，交带证据的完工报告。">
</p>

一小时内能干完的小活不走这套，直接做掉。任何时候一句话就能改它的安排，比如「这个月多用 GPT」，整场都按这句来。

## 安装

```bash
git clone https://github.com/Rurutia-Artemis/Roadstar.git
cd Roadstar && ./install.sh
```

`install.sh` 把 `skill/` 软链到 `~/.claude/skills`、`~/.agents/skills` 和 `~/.codex/skills`。在任意项目里重开一个 Claude Code 会话，说一句「用 skill」或输入 `/roadstar` 就开始。

需要：

- Claude Code（作者用 Max 套餐开发和使用）
- [Codex CLI](https://github.com/openai/codex) 0.160 以上，用 ChatGPT 账号登录：`npm i -g @openai/codex@latest`
- macOS、bash 和 Python 3，脚本只用标准库

没装 Codex 也能跑单家模式：审方案换成 Opus 子代理（纪要里标明同家），执行走 Claude 梯子。这个模式已经写好，还没有完整实跑过一场。

## 目录

```
skill/        SKILL.md、references/、scripts/（额度探针、送审、派活、桩测试）
docs/         这个技能自己每次升级的记录；在别的项目里跑的记录在那些项目的 docs/roadstar/
install.sh    把技能软链给 Claude Code 和 Codex
CHANGELOG.md  每次改动一条，写明验证了什么、没验证什么
```

## 声明

- 个人项目，与 Anthropic、OpenAI 没有关联，也没有得到它们的背书。Claude、Claude Code、Codex、ChatGPT 是各自所有者的商标。
- 它跑在你自己的订阅上，会花你的 Claude 和 Codex 额度。一场探讨一般要两边一起跑 30 到 60 分钟。
- Codex 每次启动都显式指定沙箱：审稿用 `read-only`，执行用工作区可写。唯一的例外是要起模拟器的界面验收，会开全权限，并在任务书里写死边界；批准前请先看一眼任务书。
- 型号名、额度档位和价格按作者 2026 年 10 月的环境写，换成你自己的请改 `skill/references/models.md`。
- 技能正文和记录都是中文。
- 按 [MIT 许可](LICENSE) 原样提供。

---

<p align="center"><sub>README 配图按 <a href="https://github.com/oil-oil/beautify-github-readme">beautify-github-readme</a> 的做法制作。前身叫 roundtable（2026-09-24 至 10-04）。</sub></p>
