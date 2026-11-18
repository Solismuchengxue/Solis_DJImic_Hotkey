# 便携版发布约定

[发布清单](manifest.json) 固定项目版本、上游 AutoHotkey 标签、运行时与对应源码的归档地址及 SHA256，以及候选包输出目录。打包时先校验上游归档哈希，再解包使用。上游许可及来源见[第三方声明](../THIRD_PARTY_NOTICES.md)。

候选包输出到 `release/<version>/<short-commit>/`。`<version>` 取清单中的 `v0.1.0`，`<short-commit>` 取实际打包源码提交的 Git 短哈希。包从干净的指定源码提交构建，输出和本地运行数据由 Git 忽略。此目录跟踪本说明、固定输入清单和 [v0.1.0 发布说明](v0.1.0.md)。

按清单下载 AutoHotkey 运行时 ZIP 和对应源码 ZIP，保存到 `tmp/portable_upstream/`。也可用 `-UpstreamDirectory` 指定归档目录。提交项目源码后，在项目根用 PowerShell 7 构建。

```powershell
$candidateCommit = git rev-parse HEAD
./tools/build_portable.ps1 -Commit $candidateCommit
```

输出包含 Windows x64 ZIP、匹配的 AHK 源码 ZIP 和 `SHA256SUMS.txt`。同一提交的现有输出会保留。交付前按 `SHA256SUMS.txt` 核对两个 ZIP，并核对便携 ZIP 中 `resources/build.json` 的提交。

便携包应包含用户双击入口、绑定脚本、包内 AutoHotkey v2 运行时、程序资源和相应许可。新用户在 Windows 解压后可离线启动，配置存放在该便携目录。升级时保留原 INI。具体使用与恢复步骤随实现更新到[使用与维护手册](../docs/MANUAL.md)。

候选包通过[路线图](../docs/ROADMAP.md)规定的真机验收后再发布。包体、Git 提交与公开 Release 分别核对。
