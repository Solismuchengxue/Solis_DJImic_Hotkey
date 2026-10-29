# 上游来源与许可

`localization/UX/*.ahk` 来自 [AutoHotkeyUX](https://github.com/AutoHotkey/AutoHotkeyUX)，基线为 AutoHotkey v2.0.31 安装包中的 UX 源码。原作者及贡献者保留其著作权。

本项目于 2026-10-29 修改了 7 个文件：简体中文界面文字，以及为保留原功能所需的菜单动作分派、确认控件标识和配置值映射。文件头标明修改日期，`localization/manifest.json` 记录原版与修改版的 SHA256。

这些修改版及包含上游代码片段的 `tools/build_localization.py` 按上游 [GNU GPL v2](https://github.com/AutoHotkey/AutoHotkey/blob/v2.0.31/license.txt) 分发，许可全文见 [LICENSES/GPL-2.0.txt](LICENSES/GPL-2.0.txt)。源码按现状提供，不作担保。本项目不是 AutoHotkey 或 DJI 的官方发行版。

独立的 DJI 绑定脚本、其他工具、测试和文档尚未指定单独的开放许可；公开仓库不自动授予它们额外的再分发许可。AutoHotkey 解释器、依赖 UX 文件及帮助文件由官方安装包提供，不随本仓库分发。
