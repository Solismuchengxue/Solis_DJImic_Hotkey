# 便携版发布约定

[发布清单](manifest.json) 固定项目版本、上游 AutoHotkey 标签、运行时与对应源码的归档地址及 SHA256，以及候选包输出目录。打包时先校验上游归档哈希，再解包使用。上游许可及来源见[第三方声明](../THIRD_PARTY_NOTICES.md)。

候选包输出到 `release/<version>/<short-commit>/`。`<version>` 取清单中的 `v0.1.0`，`<short-commit>` 取实际打包源码提交的 Git 短哈希。包从干净的指定源码提交构建，输出和本地运行数据由 Git 忽略。此目录中只跟踪本说明和清单。

便携包应包含用户双击入口、绑定脚本、包内 AutoHotkey v2 运行时、程序资源和相应许可。新用户在 Windows 解压后可离线启动，配置存放在该便携目录。升级时保留原 INI。具体使用与恢复步骤随实现更新到[使用与维护手册](../docs/MANUAL.md)。

候选包通过[路线图](../docs/ROADMAP.md)规定的真机验收后再发布。包体、Git 提交与公开 Release 分别核对。
