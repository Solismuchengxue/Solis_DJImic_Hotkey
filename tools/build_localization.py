"""Build a Chinese UX patch from the verified original installation backup."""
# Includes AutoHotkeyUX source fragments; GNU GPL v2. See THIRD_PARTY_NOTICES.md.
from pathlib import Path
import hashlib
import json
import difflib

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = ROOT / 'backups' / '20261029_before_changes' / 'UX'
OUTPUT = ROOT / 'localization' / 'UX'
NOTICE = (
    '; Based on AutoHotkeyUX bundled with AutoHotkey v2.0.31.\n'
    '; Modified by Solis_DJImic_Hotkey on 2026-10-29: Chinese UI and stable action/control IDs.\n'
    '; GNU GPL v2; provided without warranty. See ../../LICENSES/GPL-2.0.txt\n'
    '; and ../../THIRD_PARTY_NOTICES.md in the source distribution.\n'
)
manifest = []
diffs = []

def build(name, translations, changes=()):
    source = ORIGINAL / name
    text = source.read_text(encoding='utf-8-sig')
    original = text
    for old, new in changes:
        if text.count(old) != 1:
            raise ValueError(f'{name}: expected one structural anchor: {old[:65]!r}')
        text = text.replace(old, new)
    for old, new in translations.items():
        if old not in text:
            raise ValueError(f'{name}: missing text: {old!r}')
        text = text.replace(old, new)
    destination = OUTPUT / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    text = NOTICE + text
    destination.write_text(text, encoding='utf-8-sig', newline='\r\n')
    manifest.append(dict(path='UX/' + name, original_sha256=hashlib.sha256(source.read_bytes()).hexdigest(), localized_sha256=hashlib.sha256(destination.read_bytes()).hexdigest()))
    diffs.extend(difflib.unified_diff(original.splitlines(True), text.splitlines(True), fromfile='original/UX/'+name, tofile='zh-CN/UX/'+name))

build('ui-dash.ahk', {
    '"AutoHotkey Dash"': '"AutoHotkey 控制面板"',
    '["Name", "Desc"]': '["名称", "说明"]',
    '"New script", "Create a script or manage templates"': '"新建脚本", "创建脚本或管理模板"',
    '"Compile", "Open Ahk2Exe - convert .ahk to .exe"': '"编译脚本", "使用 Ahk2Exe 将 .ahk 转为 .exe"',
    '"Help files (F1)"': '"帮助文档 (F1)"',
    '"Window spy"': '"窗口探查"',
    '"Launch settings", "Configure how .ahk files are opened"': '"启动设置", "设置 .ahk 文件的启动方式"',
    '"Editor settings", "Set your default script editor"': '"编辑器设置", "设置默认脚本编辑器"',
    '"Welcome!"': '"欢迎使用！"',
    '"This is the Dash. It provides access to tools, settings and help files."': '"在这里打开工具、设置和帮助文档。"',
    '"To learn how to use AutoHotkey, refer to:"': '"了解 AutoHotkey 的用法："',
    '>Using the Program<': '>使用程序<', '>How to Write Hotkeys<': '>编写热键<',
    '>How to Send Keystrokes<': '>发送按键<', '>How to Run Programs<': '>运行程序<',
    '>How to Manage Windows<': '>管理窗口<', '>Quick Reference<': '>快速参考<',
    '"Show this info next time"': '"下次仍显示此说明"',
    '<a>Update available to: {}</a>': '<a>有可用更新：{}</a>',
    '"Window Spy ahk_class AutoHotkeyGUI"': '"窗口探查 ahk_class AutoHotkeyGUI"',
    '"Offline help"': '"离线帮助"', '"Online help"': '"在线帮助"',
    '"Other files"': '"其他帮助文件"', '"More"': '"更多版本"',
}, [
    ("switch item && RegExReplace(lv.GetText(item), ' .*') {", 'switch item {'),
    ('case "New":', 'case 1:'), ('case "Compile":', 'case 2:'),
    ('case "Help":', 'case 3:'), ('case "Window":', 'case 4:'),
    ('case "Launch":', 'case 5:'), ('case "Editor":', 'case 6:'),
])

build('ui-editor.ahk', {
    '"Select an editor"': '"选择脚本编辑器"', '["Editor"]': '["编辑器"]',
    '"Command line"': '"命令行"', '<a>Editors with AutoHotkey support</a>': '<a>支持 AutoHotkey 的编辑器</a>',
    '"&Browse"': '"浏览(&B)"', '"&OK"': '"确定(&O)"', '"&Cancel"': '"取消(&C)"',
    '"Apps (*.exe; *.ahk)"': '"应用程序 (*.exe; *.ahk)"',
}, [("this.AddButton('Default yp w80 x'", "this.AddButton('vOK Default yp w80 x'")])

build('ui-launcherconfig.ahk', {
    '"AutoHotkey Launch Config"': '"AutoHotkey 启动设置"',
    '"Auto-detect version when launching script"': '"启动脚本时自动识别版本"',
    '"Run all scripts with a specific interpreter"': '"使用指定解释器运行所有脚本"',
    '["Launcher", "Specific"]': '["自动识别", "指定解释器"]',
    '"Preferred interpreter by major version"': '"各主版本优先使用的解释器"',
    '"Latest 1.x"': '"最新 1.x"', '"Latest 2.x"': '"最新 2.x"',
    '["Unicode 64-bit", "Unicode 32-bit", "ANSI 32-bit"]': '["Unicode 64 位", "Unicode 32 位", "ANSI 32 位"]',
    '["64-bit", "32-bit"]': '["64 位", "32 位"]',
    '"UI Access"': '"UI 访问"', '"When detection fails"': '"无法识别版本时"',
    '["Use v1.x", "Use v2.x", "Ask the user"]': '["使用 v1.x", "使用 v2.x", "询问用户"]',
    '"Try to identify version based on syntax"': '"尝试通过语法识别版本"',
    '"Default to UTF-8 even for v1 scripts"': '"v1 脚本也默认使用 UTF-8"',
    '"Default to UTF-8"': '"默认使用 UTF-8"',
    '"&Browse"': '"浏览(&B)"', '"&Close"': '"关闭(&C)"',
    '"The selected EXE appears to be invalid.`n`nSpecifically: "': '"所选 EXE 文件无效：`n`n"',
    '"Select an AutoHotkey.exe"': '"选择 AutoHotkey 解释器"',
    "v || 'Latest ' A_Index '.x'": "v || '最新 ' A_Index '.x'",
}, [
    ("this['Build' A_Index].Text := ConfigRead(section, 'Build', '')", "this['Build' A_Index].Text := LauncherConfigGui.BuildText(ConfigRead(section, 'Build', ''))"),
    ("ConfigWrite(ctrl.Text, 'Launcher\\v' SubStr(ctrl.Name, -1), 'Build')", "ConfigWrite(LauncherConfigGui.BuildText(ctrl.Text, false), 'Launcher\\v' SubStr(ctrl.Name, -1), 'Build')"),
    ("    ChangedUIA(ctrl, *) =>", '''    ; Display Chinese labels while preserving the launcher's existing config values.
    static BuildText(value, display:=true) {
        static names := Map('Unicode 64-bit', 'Unicode 64 位', 'Unicode 32-bit', 'Unicode 32 位', 'ANSI 32-bit', 'ANSI 32 位', '64-bit', '64 位', '32-bit', '32 位')
        if display
            return names.Get(value, value)
        for canonical, label in names
            if value = label
                return canonical
        return value
    }

    ChangedUIA(ctrl, *) =>'''),
])

build('ui-newscript.ahk', {
    '"New Script"': '"新建脚本"', 'StrPtr("Untitled")': 'StrPtr("未命名")',
    '"&Browse"': '"浏览(&B)"', '["Name", "Desc", "Path", "Exec"]': '["名称", "说明", "路径", "执行"]',
    '"Empty", "Clean slate"': '"空白脚本", "不包含任何内容"',
    '"&Defaults"': '"默认选项(&D)"', '"&Create"': '"创建(&C)"', '"&Edit"': '"编辑(&E)"',
    '"Script Files (*.ahk)"': '"脚本文件 (*.ahk)"',
    '"Default to Create"': '"默认创建"', '"Default to Edit"': '"默认编辑"',
    '"Stay open"': '"完成后保持窗口打开"', '"Set folder as default"': '"设为默认文件夹"',
    '"Open templates folder"': '"打开模板文件夹"',
    '"You need to select a template first."': '"请先选择一个模板。"',
    'basename := "Untitled"': 'basename := "未命名"',
    '"&Edit template"': '"编辑模板(&E)"', '"&Hide template"': '"隐藏模板(&H)"',
    '"Set as &default"': '"设为默认模板(&D)"',
    '"User-created templates should be placed in the following folder, "': '"自定义模板应放在以下文件夹中，"',
    '"which does not yet exist:`n`n"': '"该文件夹尚不存在：`n`n"',
    '"`n`nCreate it now?"': '"`n`n现在创建吗？"',
}, [("itemname := SubStr(itemname, 12)", "itemname := itempos = 1 ? 'Create' : 'Edit'")])

build('ui-setup.ahk', {
    '"AutoHotkey Setup"': '"AutoHotkey 安装"', "'Install &to:'": "'安装到(&T)：'",
    "'&Browse'": "'浏览(&B)'", '"Install mode:"': '"安装方式："',
    '"&All users"': '"所有用户(&A)"', '"&Current user"': '"当前用户(&C)"',
    '"Portable"': '"便携模式"', '"&Install"': '"安装(&I)"',
    '"Changing the installation directory is not recommended."': '"不建议更改现有安装目录。"',
    '"`n`nThis installation package is designed to allow both v1 and v2 to be associated with .ahk files, but only if they are installed in the same directory."': '"`n`n只有将 v1 和 v2 安装在同一目录，才能共同关联 .ahk 文件。"',
    '"`n`nExisting files will not be moved."': '"`n`n现有文件不会被移动。"',
    '"Select installation directory"': '"选择安装目录"', '"Please enter a valid path."': '"请输入有效的路径。"',
    "'The existing installation in \"' dir '\" will not be moved or integrated with the new installation.`n`n'": "'现有安装目录 \"' dir '\" 中的文件不会移动或合并到新安装。`n`n'",
    "'Enabling UI Access will not be possible because the installation directory is not a sub-directory of Program Files. Without UI Access, non-elevated scripts cannot interact with windows of elevated programs.`n`n'": "'安装目录不在 Program Files 下，无法启用 UI 访问；普通权限脚本将无法操作管理员权限的程序窗口。`n`n'",
    '"Installing..."': '"正在安装……"',
})
build('ui-uninstall.ahk', {
    '"AutoHotkey Setup"': '"AutoHotkey 安装管理"', '"Remove which versions?"': '"请选择要移除的版本："',
    '["Version"]': '["版本"]', '"Remove &all"': '"全部移除(&A)"', '"Remove &checked"': '"移除所选(&C)"',
})
build('WindowSpy.ahk', {
    '"Window Spy for AHKv2"': '"窗口探查（AHK v2）"',
    '"Window Title, Class and Process:"': '"窗口标题、类名与进程："',
    '"Follow Mouse"': '"跟随鼠标"', '"Mouse Position:"': '"鼠标位置："',
    '"Focused Control"': '"焦点控件"', '"Active Window Position:"': '"活动窗口位置："',
    '"Status Bar Text:"': '"状态栏文字："', '"Slow TitleMatchMode"': '"慢速标题匹配模式"',
    '"Visible Text:"': '"可见文字："', '"All Text:"': '"全部文字："',
    '"(Hold Ctrl or Shift to suspend updates)"': '"（按住 Ctrl 或 Shift 暂停更新）"',
    '"(Updates suspended)"': '"（已暂停更新）"', '"Control Under Mouse Position"': '"鼠标指向的控件"',
    '"Screen:`t"': '"屏幕：`t"', '"Window:`t"': '"窗口：`t"', '"Client:`t"': '"客户区：`t"',
    '" (default)`n"': '"（默认）`n"', '"Color:`t"': '"颜色：`t"',
    '" (Red="': '"（红="', '" Green="': '" 绿="', '" Blue="': '" 蓝="',
    '"Text:`t"': '"文字：`t"', '"Screen:`tx: "': '"屏幕：`tx: "', '"Client:`tx: "': '"客户区：`tx: "',
})

(ROOT / 'localization' / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
(ROOT / 'tmp' / 'localization.diff').write_text(''.join(diffs), encoding='utf-8')
print(json.dumps({'files': len(manifest), 'output': str(OUTPUT)}, ensure_ascii=False))
