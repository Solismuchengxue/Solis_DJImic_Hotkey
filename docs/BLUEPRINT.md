# Solis_DJImic_Hotkey 项目蓝图

更新日期为 2026-11-19。DJI 听写使用便携版，安装版 AutoHotkey 的汉化独立维护。行为与验收见 [PRD.md](PRD.md)。

## 两个目标

1. **汉化 AutoHotkey。** 针对本机 `D:\AutoHotkey` 的实际界面、菜单和设置进行简体中文汉化，保持原功能。
2. **绑定 DJI 按钮。** 复用 AutoHotkey，让 DJI Mic Mini 2S 发射器按钮可以绑定本机与 RDP 的听写快捷键。提供便携版 Windows 程序，方便新用户启用绑定、改键、测试按钮和管理登录自启。

## 使用场景

当前实测设备是 DJI Mic Mini 2S。用户在 Acer 本机和 HP Z6 G4 的 mstsc RDP 之间切换，通过发射器按钮启动对应位置的 ChatGPT 听写，将语音转成输入框文字。两端的快捷键见 [PRD.md](PRD.md)。

## 实施原则

便携版沿用 AHK v2 脚本的设备识别、去抖和本机/RDP 分流。解压后由启动器调用包内运行时，当前界面见 [README 界面预览](../README.md#界面预览)。

## 范围

本项目维护汉化和 DJI 听写绑定。便携界面围绕绑定操作，听写由本机或远端应用负责。

用户上手与维护说明集中于 [MANUAL.md](MANUAL.md)，覆盖从官方软件下载到日常使用、维护和恢复的完整路径；操作说明不代表已经修改系统设置。
