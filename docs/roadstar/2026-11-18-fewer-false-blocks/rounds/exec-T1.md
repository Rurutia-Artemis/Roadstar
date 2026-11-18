🛠 Karina · 工程

五处误拦已收窄，手工复现确认该放行的放行、该拦的仍拦。全量回归退出 0，**437 项通过，比基线多 5 项**。五次逐文件回退均让对应新用例失败，恢复后全部通过；旧断言未改。

[执行报告](/Users/rurutia/Documents/RuruCode/运行数据/任务临时/RFB1/repo/docs/roadstar/2026-11-18-fewer-false-blocks/rounds/exec-T1.md)记录了各套件计数、变异输出、沙箱下的验证调整，以及请 Argo 在「降标准五查」中点名的文件。临时产物已清理，未安装、未提交、未推送。