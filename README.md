# Solis_DJImic_Hotkey

汉化 AutoHotkey 常用界面，用 DJI 按钮触发本机或 RDP 的 ChatGPT 输入框听写。

## ✨ 用途与适用范围

原部署机器的本机、RDP 窗口/全屏、接收器拔插和 RDP 重连已实测通过。其他设备请按手册测试。

## 🧰 准备条件

DJI 接收器接入本机，发射器已配对；麦克风选择 `Wireless Mic Rx`。本机快捷键 `Alt+C`，远端 `Alt+X`。

## 🚀 安装或接入

从 [GitHub 仓库](https://github.com/Solismuchengxue/Solis_DJImic_Hotkey) 选择 Code → Download ZIP 并解压。按[安装步骤](docs/MANUAL.md#install)操作：安装 AHK v2.0.31 → 备份汉化 → 配置 ChatGPT → 部署 DJI 脚本 → 测试。原部署机器已配置好，可直接使用。

## 🎬 第一次使用

1. 托盘确认“DJI 听写绑定：已启用”。
2. 点进本机或 RDP 中的 ChatGPT 输入框，DJI 按一次开始，再按一次结束。
3. 检查转写文字后发送。

手动启动：双击 `D:\AutoHotkey\DJI_Mic_Hotkey.ahk`。关联异常时，按 `Win+R` 输入：

```text
"D:\AutoHotkey\v2\AutoHotkey64.exe" "D:\AutoHotkey\DJI_Mic_Hotkey.ahk"
```

## 🛠️ 日常使用与求助

- **改键**：修改两端 ChatGPT 设置和 `D:\AutoHotkey\DJI_Mic_Hotkey.ini`，保存后从托盘“重新读取配置”。
- **改代码**：退出旧实例，再启动；重复双击不会加载新代码。
- **暂停/退出**：从 DJI 托盘菜单操作。
- [自启动维护](docs/MANUAL.md#autostart) · [升级维护](docs/MANUAL.md#maintenance) · [原理](docs/MANUAL.md#mechanism) · [排错恢复](docs/MANUAL.md#troubleshooting)

完整操作见[使用与维护手册](docs/MANUAL.md)；项目目标与验收见 [BLUEPRINT](docs/BLUEPRINT.md) 和 [PRD](docs/PRD.md)。

## 📄 限制与许可

**当前会屏蔽所有设备的音量加键。** 暂停或退出可恢复；也可用 Windows 音量滑块调节。

已验证 AHK v2.0.31；常用 UX 已汉化，内置提示和帮助仍有英文。暂无通用安装包。汉化文件沿用上游 GPL v2；其余文件许可状态见[来源与许可](THIRD_PARTY_NOTICES.md)。
