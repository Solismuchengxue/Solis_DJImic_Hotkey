#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn All, StdOut
#Include ui-dash.ahk

; Runs against a disposable copy whose configuration writes stay in memory.
Assert(condition, message) {
    if !condition
        throw Error(message)
}
FindGui(guiClass) {
    for hwnd in WinGetList('ahk_pid ' ProcessExist()) {
        guiObject := GuiFromHwnd(hwnd)
        if guiObject && guiObject is guiClass
            return guiObject
    }
    throw Error('Expected GUI was not opened')
}
try {
    dash := FindGui(AutoHotkeyDashGui)
    Assert(dash['LV'].GetText(1) = '新建脚本', 'Dash must display Chinese labels')
    dash.ItemClicked(dash['LV'], 5)
    settings := FindGui(LauncherConfigGui)
    settings.DefineProp('UpdateVerbs', {Call: (this, *) => 0})
    Assert(InStr(settings['UseLauncher'].Text, '自动'), 'Launch settings must be Chinese')
    settings['Build2'].Text := '64 位'
    settings.ChangedBuild(settings['Build2'])
    Assert(ConfigRead('Launcher\v2', 'Build', '') = '64-bit', 'Translated build must preserve canonical config value')
    settings['Version2'].Value := 1
    settings.ChangedVersion(settings['Version2'])
    Assert(ConfigRead('Launcher\v2', 'Version', 'missing') = '', 'Latest version must preserve the default value')
    settings.Destroy()
    LauncherConfigGui.Show()
    settings := FindGui(LauncherConfigGui)
    Assert(settings['Build2'].Text = '64 位', 'Stored interpreter choice must remain visible')
    dash.ItemClicked(dash['LV'], 6)
    editor := FindGui(DefaultEditorGui)
    Assert(InStr(editor['OK'].Text, '确定'), 'Editor confirmation control must retain a stable ID')
    dash.ItemClicked(dash['LV'], 1)
    newScript := FindGui(NewScriptGui)
    Assert(newScript['LV'].GetText(1) = '空白脚本', 'New script must display a Chinese empty template')
    Assert(newScript['Create'].Name = 'Create' && newScript['Edit'].Name = 'Edit', 'Create/Edit internal identities must remain unchanged')
    FileAppend 'PASS: Chinese labels, Dash routing, build persistence, default version, editor ID, template identities`n', '*'
    ExitApp 0
} catch as failure {
    FileAppend 'FAIL: ' failure.Message ' (line ' failure.Line ')`n', '*'
    ExitApp 1
}
