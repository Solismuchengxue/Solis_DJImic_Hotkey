# 便携版发布约定

[发布清单](manifest.json) 固定项目版本、上游 AutoHotkey 标签、运行时与对应源码的归档地址及 SHA256，以及候选包输出目录。打包时先校验上游归档哈希，再解包使用。上游许可及来源见[第三方声明](../THIRD_PARTY_NOTICES.md)。

候选包输出到 `release/<version>/<short-commit>/`。`<version>` 取发布清单，`<short-commit>` 取实际打包源码提交的 Git 短哈希。包从干净的指定源码提交构建，输出和本地运行数据由 Git 忽略。[v0.1.0 发布说明](v0.1.0.md)

按清单下载 AutoHotkey 运行时 ZIP 和对应源码 ZIP，保存到 `tmp/portable_upstream/`。也可用 `-UpstreamDirectory` 指定归档目录。构建机需要 Visual Studio 或 Build Tools 的 MSVC x64 工具和 Windows SDK。提交项目源码后，在项目根用 PowerShell 7 构建。

```powershell
$candidateCommit = git rev-parse HEAD
./tools/build_portable.ps1 -Commit $candidateCommit
```

输出包含 Windows x64 ZIP、匹配的 AHK 源码 ZIP 和 `SHA256SUMS.txt`。同一提交的现有输出会保留。交付前按 `SHA256SUMS.txt` 核对两个 ZIP，并核对便携 ZIP 中 `resources/build.json` 的提交。

从 `v0.1.1` 起，便携包根目录的唯一文件是原生启动器 `DJI 听写.exe`。脚本在 `app/`，官方 AutoHotkey x64 解释器和 Dash 在 `runtime/`，配置在 `config/`，说明在 `docs/`，许可在 `LICENSES/`。解压后可离线启动，升级时保留 `config/DJI_Mic_Hotkey.ini`。操作步骤见[使用与维护手册](../docs/MANUAL.md)。

候选包通过[路线图](../docs/ROADMAP.md)规定的真机验收后再发布。包体、Git 提交与公开 Release 分别核对。
