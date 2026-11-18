# 使用与维护手册

DJI 听写通过便携版运行。单独安装 AutoHotkey 的用户可查看[汉化步骤](#install)。

<a id="portable"></a>
## 便携版

1. 从 [GitHub Releases](https://github.com/Solismuchengxue/Solis_DJImic_Hotkey/releases) 下载 Windows x64 便携 ZIP，完整解压到有写入权限的目录。
2. 双击 `DJI 听写.exe`。先按[麦克风和 ChatGPT 设置](#chatgpt)验证两端的 `Ctrl+Shift+D`。已有旧脚本正在监听时，先在它自己的托盘退出。
3. 点「启动绑定」，在聊天输入框短按 DJI 开始听写，再短按结束。可以用「测试 DJI 按钮」查看是否收到按键信号，再回输入框验证转写。
4. 改键后同步 ChatGPT 的「单击快捷键」。高级设置可调整防重复触发间隔，默认 `250` 毫秒。按需打开「音量加拦截」，开启后键盘音量加也会被拦截。
5. 主窗口与托盘均可切换「开机自启」，默认关闭。切换后可注销并重新登录，检查托盘状态和按钮听写。移动前先退出，移动后打开程序检查并修复开机自启。

从 `v0.1.1` 起，双击根目录的 `DJI 听写.exe`，启动器会调用 `runtime/` 中的官方 AutoHotkey。点「开发者模式」可打开原版 AutoHotkey Dash。产品离线说明在 `docs/使用说明.html`，Dash 的编程帮助使用官方网页。

关闭窗口时，运行或暂停中的程序留在托盘。要结束程序，从托盘退出。升级时把旧包 `config/DJI_Mic_Hotkey.ini` 复制到新版对应位置，再启动新版并验证两端听写。

<a id="overview"></a>
<a id="daily-use"></a>
## 1. 日常使用

1. 接好 DJI 接收器，确认发射器配对。
2. 点进本机或 RDP 里的 ChatGPT 输入框。
3. DJI 按一次开始听写，再按一次结束；检查文字后发送。

本机和 RDP 都发送 `Ctrl+Shift+D`。

启用音量加拦截后，暂停或退出绑定可恢复键盘的音量加。

<a id="run"></a>
## 2. 启停和改配置

双击便携目录里的 `DJI 听写.exe`。从主窗口启动、停止或改键。从托盘暂停、恢复或退出绑定。

| 操作 | 用法 |
| --- | --- |
| 更改 | 分别修改本机和 RDP 的快捷键，同时同步 ChatGPT 设置 |
| 高级设置 | 设置防重复触发和全局音量加拦截 |
| 暂停绑定 | 暂停按钮并释放音量加拦截；再点一次恢复 |
| 退出 | 停止脚本；以后需重新启动 |

实际配置保存在便携目录的 `config/DJI_Mic_Hotkey.ini`。默认值如下：

```ini
[Hotkeys]
Local=^+d
Remote=^+d
[Behavior]
DebounceMs=250
BlockVolumeUp=0
```

`!`=Alt，`^`=Ctrl，`+`=Shift，`#`=Win。改键时，ChatGPT 设置和 INI 必须一起改。

`BlockVolumeUp=1` 拦截所有音量加键；`0` 恢复原生音量，DJI 也可能重新增加音量。

手动编辑 INI 前先退出程序，保存后重新启动。

<a id="autostart"></a>
## 3. 自启动

勾选主窗口的「登录时自动启动」。重新登录后，在托盘确认程序已启动并测试听写。移动目录后，重新打开程序并点击「路径已变，点击修复」。取消勾选即可移除程序创建的快捷方式。

<a id="verify"></a>
## 4. 改动后怎么测

依次测试：**手动快捷键 → 本机 DJI → RDP 窗口 → RDP 全屏 → 接收器重插 → RDP 重连**。

通过标准是目标输入框能开始及结束听写并出现文字。开启音量加拦截时，另检查短按不增加音量，暂停后键盘音量加恢复。

<a id="install"></a>
## 5. AutoHotkey 安装版汉化

### 下载与安装

1. 从 [AHK 官方 v2.0.31 发布页](https://github.com/AutoHotkey/AutoHotkey/releases/tag/v2.0.31)下载 `AutoHotkey_2.0.31_setup.exe`。
2. 运行安装程序，安装到 `D:\AutoHotkey`；按需要选 Current user 或 All users，点击 Install。
3. 确认有 `v2\AutoHotkey64.exe` 和 `UX\ui-dash.ahk`。
4. 从 [本项目 GitHub](https://github.com/Solismuchengxue/Solis_DJImic_Hotkey) 下载 ZIP 并解压。以下命令需替换为你的项目目录。

<a id="localize"></a>
### 备份与汉化

1. 将该版本未汉化的安装目录复制到自选的恢复位置，保留原目录结构。
2. 使用完整项目文件，在 PowerShell 7 中执行：

```powershell
& ./tools/apply_localization.ps1 -BackupDirectory 'D:\AutoHotkey_original'
```

3. 重新打开 AutoHotkey 控制面板，检查中文菜单和设置。

工具只应用清单中的 7 个 UX 文件，原版备份、当前安装和清单哈希必须一致。缺备份、已汉化或版本不匹配时，工具会拒绝覆盖。离线帮助可单独[安装中文版](#chinese-help)。

<a id="chatgpt"></a>
### ChatGPT 与麦克风

- 本机和 RDP 的 ChatGPT 都用 `Ctrl+Shift+D`。如果仍绑定着旧键，在“设置 → 语音 → 听写 → 单击快捷键”调整。上方按住/双击入口“听写快捷键”保持“关闭”。
- 返回聊天输入框，先用键盘验证一次开始、结束和转写。这项是[输入框听写](https://learn.chatgpt.com/docs/prompting#use-voice-dictation)。
- 本机 Windows 输入和 ChatGPT 麦克风选择 `Wireless Mic Rx`，或指向它的系统默认输入。
- mstsc 连接前：“本地资源 → 远程音频 → 设置 → 远程音频录制”，选“从此计算机录制”，再连接；远端选择重定向的麦克风。

<a id="patch"></a>
### 听写部署

在接有 DJI 接收器的电脑使用[便携版](#portable)，远端配置 ChatGPT 和麦克风即可。

<a id="ahk-basics"></a>
## 6. AutoHotkey 基本用法

开始菜单打开 AutoHotkey 控制面板。新建脚本用于创建 `.ahk`，编辑器设置用于选择编辑工具，启动设置用于选择解释器。

控制面板入口是 `D:\AutoHotkey\UX\ui-dash.ahk`，可在资源管理器中双击它。`AutoHotkey64.exe` 与 `AutoHotkeyUX.exe` 都是脚本解释器；单独双击 EXE 可能提示找不到同名 `.ahk`，不表示程序损坏。控制面板不负责启停 DJI 绑定，DJI 从自己的托盘菜单操作。

`v2\AutoHotkey64.exe` 用来运行用户脚本；`UX\AutoHotkeyUX.exe` 是供控制面板、版本启动器等界面脚本使用的独立副本。本机两者当前内容相同，后续升级时可能不同，不必互相替换。

练习：新建一个单独的 `.ahk`，保存为 UTF-8 带 BOM，然后双击运行：

```ahk
#Requires AutoHotkey v2.0
F8::MsgBox "这是我的第一个 AHK 脚本。"
```

按 F8 弹窗。结束练习时退出这个练习脚本的托盘实例，保留 DJI 实例。更多见 [AHK 官方入门](https://github.com/AutoHotkey/AutoHotkeyDocs/blob/v2/docs/howto/WriteHotkeys.htm)。

<a id="chinese-help"></a>
### 安装中文离线帮助

wyagd001 的社区译本为 **2.0.19**，适合查阅 v2 常用用法。对于解释器 **2.0.31** 的较新变化，请查同版本英文帮助。[译者主页](https://wyagd001.github.io/)

1. 从 [帮助文件清单](../localization/help_manifest.json) 的 `source_url` 下载固定版本的 CHM，用 `Get-FileHash -Algorithm SHA256` 核对下载文件与清单的 `sha256`。
2. 关闭已打开的帮助窗口，把 `D:\AutoHotkey\v2\AutoHotkey.chm` 复制到单独的备份目录，再把中文文件复制到原路径并命名为 `AutoHotkey.chm`。
3. 打开 `D:\AutoHotkey\v2\AutoHotkey.chm`，确认目录和正文显示中文，首页版本为 `2.0.19`。恢复英文时，关闭帮助窗口并将同一安装版本的原文件复制回原路径。

<a id="maintenance"></a>
## 7. 后续维护

| 变更 | 操作顺序 |
| --- | --- |
| 改听写键 | 改 ChatGPT → 手动验证 → 在主界面更改匹配的快捷键 → DJI 测试 |
| 更新 DJI 听写 | 退出绑定 → 解压新版 → 复制原 INI → 启动测试 |
| 更新 AHK | 备份整个安装目录 → 退出相关脚本/面板 → 官方升级 → 核对汉化兼容 → 重新测试 |
| 换设备 | 重新确认设备标识，再测本机和 RDP |

维护源码在 `app/`，默认配置在 `config/`，安装版汉化文件在 `localization/UX`。

新版 AHK 可能覆盖汉化。先对比新版 UX、更新翻译和哈希清单再应用，不能直接覆盖旧 UX。工具报告文件被修改时，保留当前文件，核对差异后更新记录；不要用示例 INI 覆盖个人配置。

<a id="mechanism"></a>
## 8. 实现原理

- 接收器按钮产生音量加事件；脚本用 Raw Input 按设备标识只选 DJI 触发听写，并做去抖。
- 前台是 `mstsc.exe` 就发远端快捷键，否则发本机快捷键；输入框由你提前点选。
- 声音走 USB 麦克风和 RDP 音频重定向，ChatGPT 负责录音转写。
- 原生音量由系统热键和键盘钩子拦截；切入 RDP 或改变窗口状态后重装钩子，覆盖全屏路径。退出/暂停会释放。

<a id="troubleshooting"></a>
<a id="rollback"></a>
## 9. 排错与恢复

| 现象 | 处理 |
| --- | --- |
| 完全不听写 | 先试键盘快捷键，再查托盘是否启用、实际 INI 是否正确 |
| 只出现全局听写浮窗 | 点进真正的聊天输入框再试 |
| 短按后录音立刻结束或取消 | 快捷键应设在“单击快捷键”；上方按住/双击入口保持关闭 |
| 听写界面出现却没有文字 | 检查麦克风输入、应用权限及 RDP 录音重定向 |
| 能听写但还加音量 | 查看高级设置中的音量加拦截 |
| 改代码后仍是旧行为 | 从托盘退出，再运行新版便携程序 |
| 按一次像立即开始又结束 | 检查有无其他实例或脚本同时监听 |
| 键盘音量加失效 | 当前方案的已知影响；暂停/退出或改为 BlockVolumeUp=0 |

文件回滚前先退出绑定，备份当前 INI：

- 汉化：从同版本备份还原 7 个 UX 文件，重新打开面板。
- 便携版：解压对应版本后，复制需要保留的个人 INI。
- 不把旧版整目录直接覆盖到新版安装。

需求与验收见 [PRD](PRD.md)。备份、日志和本机部署记录不随公开仓库分发。
