# 使用与维护手册

更新：2026-10-29。适用版本：AutoHotkey v2.0.31。原部署机器已安装、汉化并启用；自启动由用户添加，重新登录效果待确认。新电脑从第 5 节开始。

<a id="overview"></a>
<a id="daily-use"></a>
## 1. 日常使用

1. 接好 DJI 接收器，确认发射器配对。
2. 点进本机或 RDP 里的 ChatGPT 输入框。
3. DJI 按一次开始听写，再按一次结束；检查文字后发送。

本机用 `Alt+C`，远端用 `Alt+X`。本机、RDP 窗口/全屏、拔插和重连已实测通过。

**当前会屏蔽所有设备的音量加键。** 需要恢复键盘音量加，暂停或退出绑定；也可用 Windows 音量滑块调节。

<a id="run"></a>
## 2. 启停和改配置

手动启动：双击 `D:\AutoHotkey\DJI_Mic_Hotkey.ahk`。关联有问题时，按 `Win+R` 输入：

```text
"D:\AutoHotkey\v2\AutoHotkey64.exe" "D:\AutoHotkey\DJI_Mic_Hotkey.ahk"
```

右下角托盘找到“DJI 听写绑定”，右键操作：

| 操作 | 用法 |
| --- | --- |
| 打开快捷键配置 | 编辑当前实际使用的 INI |
| 重新读取配置 | 保存 INI 后生效 |
| 暂停绑定 | 暂停按钮并释放音量加拦截；再点一次恢复 |
| 退出 | 停止脚本；以后需重新启动 |

实际配置：`D:\AutoHotkey\DJI_Mic_Hotkey.ini`。常改项如下，设备字段保留原值：

```ini
[Hotkeys]
Local=!c
Remote=!x
[Behavior]
DebounceMs=250
BlockVolumeUp=1
```

`!`=Alt，`^`=Ctrl，`+`=Shift，`#`=Win。改键时，ChatGPT 设置和 INI 必须一起改。

`BlockVolumeUp=1` 拦截所有音量加键；`0` 恢复原生音量，DJI 也可能重新增加音量。

**改 INI：保存后重新读取。改 `.ahk`：先退出，再启动。** 再次双击已运行脚本不会加载新代码。只运行 D 盘正式副本，避免与项目源代码或诊断脚本重复监听。

<a id="autostart"></a>
## 3. 自启动

原部署机器已添加，无需重复创建。新电脑可在下面的启动文件夹中，为正式 DJI 脚本创建快捷方式。登录后检查托盘，并完成一次 DJI 听写确认。

使用启动文件夹方式时：按 `Win+R` 输入 `shell:startup`，编辑对应快捷方式。

- 目标：第 2 节的完整运行命令。
- 起始位置：`D:\AutoHotkey`。
- 取消自启动：删除该快捷方式；当前运行实例仍需从托盘退出。

这是[当前用户登录启动](https://support.microsoft.com/en-gb/windows/experience/startup-boot/configure-startup-applications-in-windows?nochrome=true)，启动对象应为正式 DJI 脚本。

<a id="verify"></a>
## 4. 改动后怎么测

依次测试：**手动快捷键 → 本机 DJI → RDP 窗口 → RDP 全屏 → 接收器重插 → RDP 重连**。

通过标准：目标输入框能开始/结束听写、出现文字，音量不增加。另检查暂停时键盘音量加能恢复。日志出现 `sent` 不等于应用已经生效。

<a id="install"></a>
## 5. 新电脑或重装时

### 下载与安装

1. 从 [AHK 官方 v2.0.31 发布页](https://github.com/AutoHotkey/AutoHotkey/releases/tag/v2.0.31)下载 `AutoHotkey_2.0.31_setup.exe`。
2. 运行安装程序，安装到 `D:\AutoHotkey`；按需要选 Current user 或 All users，点击 Install。
3. 确认有 `v2\AutoHotkey64.exe` 和 `UX\ui-dash.ahk`。
4. 从 [本项目 GitHub](https://github.com/Solismuchengxue/Solis_DJImic_Hotkey) 下载 ZIP 并解压。以下命令需替换为你的项目目录。

<a id="localize"></a>
### 备份与汉化

1. 首次汉化前，把整个未汉化的 `D:\AutoHotkey` 复制到项目 `backups\20261029_before_changes`（工具固定读取的基线目录）。保留原目录结构，不覆盖已有备份；后续维护另建日期目录。
2. 使用完整项目文件，在 PowerShell 7 中执行：

```powershell
& 'F:\60_Infrastructure_and_Operations\Solis_DJImic_Hotkey\tools\apply_localization.ps1'
```

3. 重新打开 AutoHotkey 控制面板，检查中文菜单和设置。

工具只应用清单中的 7 个 UX 文件，原版备份、当前安装和清单哈希必须一致。仓库不含个人备份；缺备份、已汉化或版本不匹配会拒绝覆盖。版本不同应先适配，不能改哈希绕过检查。当前仍有内置提示和帮助为英文。

<a id="chatgpt"></a>
### ChatGPT 与麦克风

- 本机：“设置 → 语音 → 听写 → 单击快捷键”设为 `Alt+C`；远端设为 `Alt+X`。
- 返回聊天输入框，先用键盘验证一次开始、结束和转写。这项是[输入框听写](https://learn.chatgpt.com/docs/prompting#use-voice-dictation)。
- 本机 Windows 输入和 ChatGPT 麦克风选择 `Wireless Mic Rx`，或指向它的系统默认输入。
- mstsc 连接前：“本地资源 → 远程音频 → 设置 → 远程音频录制”，选“从此计算机录制”，再连接；远端选择重定向的麦克风。

<a id="patch"></a>
### 部署 DJI 补丁

1. 脚本只部署在接有 DJI 接收器的本机，远端配置 ChatGPT 和麦克风即可。
2. 首次安装，将项目根 `.ahk` 和 `.ini` 复制到 `D:\AutoHotkey`。已有 INI 时先备份并保留个人设置，仅更新脚本。
3. 接受全局音量加拦截的取舍后，将实际 INI 的 `BlockVolumeUp` 设为 `1`。
4. 按第 2 节启动，再做第 4 节测试。

项目根 INI 是示例，默认拦截关闭。现有 apply/update 工具有本机历史基线前提，不是新电脑通用安装器；不要启动 `tmp` 里的诊断脚本。

<a id="ahk-basics"></a>
## 6. AutoHotkey 基本用法

开始菜单打开 AutoHotkey 控制面板：新建脚本用于创建 `.ahk`；编辑器设置选择编辑工具；启动设置选择解释器。此处“启动设置”与 Windows 登录自启动分别配置。本项目无需编译 EXE。

练习：新建一个单独的 `.ahk`，保存为 UTF-8 带 BOM，然后双击运行：

```ahk
#Requires AutoHotkey v2.0
F8::MsgBox "这是我的第一个 AHK 脚本。"
```

按 F8 弹窗。结束练习时退出这个练习脚本的托盘实例，保留 DJI 实例。更多见 [AHK 官方入门](https://github.com/AutoHotkey/AutoHotkeyDocs/blob/v2/docs/howto/WriteHotkeys.htm)。

<a id="maintenance"></a>
## 7. 后续维护

| 变更 | 操作顺序 |
| --- | --- |
| 改听写键 | 改 ChatGPT → 手动验证 → 改实际 INI → 重新读取 → DJI 测试 |
| 更新 DJI 代码 | 备份脚本和 INI → 退出绑定 → 更新 `.ahk`、保留 INI → 启动测试 |
| 更新 AHK | 备份整个安装目录 → 退出相关脚本/面板 → 官方升级 → 核对汉化兼容 → 重新测试 |
| 换设备 | 重新确认设备标识，再测本机和 RDP |

运行文件在 `D:\AutoHotkey`；维护源码在本项目根；汉化文件在 `localization\UX`；恢复点在 `backups`。更新代码时同步源码和安装副本，避免混用。

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
| 听写界面出现却没有文字 | 检查麦克风输入、应用权限及 RDP 录音重定向 |
| 能听写但还加音量 | 检查 BlockVolumeUp=1，保存后重新读取；检查拦截状态 |
| 改代码后仍是旧行为 | 退出旧实例，再启动 D 盘正式副本 |
| 按一次像立即开始又结束 | 查是否同时运行了安装副本、项目源代码或诊断器 |
| 键盘音量加失效 | 当前方案的已知影响；暂停/退出或改为 BlockVolumeUp=0 |

文件回滚前先退出绑定，备份当前 INI：

- 汉化：从同版本备份还原 7 个 UX 文件，重新打开面板。
- 脚本/配置：还原自己更新前保存的副本；旧脚本可能带回历史问题。原部署的历史恢复点仅保存在本地 `backups`。
- 不把旧版整目录直接覆盖到新版安装。

需求与验收见 [PRD](PRD.md)。备份、日志和本机部署记录不随公开仓库分发。
