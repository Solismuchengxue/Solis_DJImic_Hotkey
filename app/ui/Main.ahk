#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\PortableBinding.ahk
#Include %A_LineFile%\..\StartupLink.ahk
; The original standalone script uses Ignore. Here, a second launch must be
; allowed to ask the existing GUI to show itself, including from another copy.
#SingleInstance Off

class PortableApp {
    static WindowProperty := 'Solis.DJI.Dictation.Portable.Window'
    static ManualURL := 'https://github.com/Solismuchengxue/Solis_DJImic_Hotkey/blob/main/docs/MANUAL.md'

    static Launch() {
        trayOnly := A_Args.Length && A_Args[1] = '--tray'
        mutex := DllCall('CreateMutexW', 'ptr', 0, 'int', false, 'str', 'Local\Solis.DJI.Dictation.Portable', 'ptr')
        alreadyOpen := A_LastError = 183
        if !mutex
            throw OSError()
        message := DllCall('RegisterWindowMessageW', 'str', this.WindowProperty, 'uint')
        if !message
            throw OSError()
        if alreadyOpen {
            if !trayOnly
                this.ShowExisting(message)
            ExitApp
        }
        SplitPath A_LineFile,, &uiDir
        SplitPath uiDir,, &appDir
        SplitPath appDir,, &root
        app := this(root)
        OnMessage(message, ObjBindMethod(app, 'Show'))
        if !DllCall('SetPropW', 'ptr', app.Window.Hwnd, 'str', this.WindowProperty, 'ptr', 1)
            throw OSError()
        if trayOnly
            app.StartFromTray()
        else
            app.Show()
        Persistent()
    }

    static ShowExisting(message) {
        DetectHiddenWindows true
        loop 100 {
            for hwnd in WinGetList('ahk_class AutoHotkeyGUI') {
                if !DllCall('GetPropW', 'ptr', hwnd, 'str', this.WindowProperty, 'ptr')
                    continue
                DllCall('AllowSetForegroundWindow', 'uint', WinGetPID('ahk_id ' hwnd))
                PostMessage message, 0, 0,, 'ahk_id ' hwnd
                return
            }
            Sleep 50
        }
        throw Error('已有便携实例正在启动或关闭，请稍后再打开。')
    }

    __New(root) {
        this.Root := root
        this.Binding := PortableBinding(root '\config\DJI_Mic_Hotkey.ini')
        this.Binding.OnLegacyConflict := ObjBindMethod(this, 'PauseForLegacy')
        launcher := root '\DJI 听写.exe'
        this.Login := FileExist(launcher)
            ? StartupLink(A_Startup, launcher, '--tray', root)
            : StartupLink(A_Startup, A_AhkPath, '"' A_ScriptFullPath '" --tray', root)
        this.Paused := false
        this.Dialog := false
        icon := this.Resource('logo.ico')
        TraySetIcon icon
        this.Window := Gui('-MaximizeBox', 'DJI 听写')
        this.Window.BackColor := 'FAFBFC'
        this.Window.SetFont('s10', 'Microsoft YaHei UI')
        this.Window.OnEvent('Close', ObjBindMethod(this, 'CloseMain'))
        this.Window.OnEvent('Escape', ObjBindMethod(this, 'CloseMain'))
        this.BuildWindow()
        this.BuildTray()
        this.Refresh()
    }

    Resource(name) {
        packaged := this.Root '\resources\' name
        return FileExist(packaged) ? packaged : this.Root '\assets\' name
    }

    BuildWindow() {
        w := this.Window
        w.SetFont('s12 bold c193755')
        w.AddText('x22 y16', '绑定状态')
        this.Status := w.AddText('x22 y44 w205 h40', '')
        this.Status.SetFont('s20 bold')
        this.StartButton := w.AddButton('x318 y41 w146 h38', '')
        this.StartButton.OnEvent('Click', (*) => this.ToggleBinding(false))
        this.StartButton.OnNotify(-12, ObjBindMethod(PortableApp, 'PaintPrimary')) ; NM_CUSTOMDRAW
        w.AddText('x22 y92 w442 h1 0x10')
        w.AddText('x22 y104', '听写快捷键')
        w.SetFont('s10 norm c192B3C')
        this.KeyLabels := Map()
        for row, item in [['Local','本机'], ['Remote','RDP']] {
            y := 140 + (row - 1) * 37
            w.AddText('x26 y' y+5 ' w70', item[2])
            this.KeyLabels[item[1]] := w.AddEdit('x96 y' y ' w214 h29 ReadOnly Center', '')
            button := w.AddButton('x376 y' y ' w88 h30', '更改')
            button.OnEvent('Click', ObjBindMethod(this, 'EditShortcut', item[1], item[2]))
        }
        w.AddText('x22 y218 w442 h1 0x10')
        ; BS_LEFTTEXT and BS_LEFT keep the native checkbox and its accessible
        ; name together, with the label at the left and the check at the right.
        this.AutoStart := w.AddCheckbox('x22 y232 w442 h26 +0x120', '登录时自动启动')
        this.AutoStart.OnEvent('Click', ObjBindMethod(this, 'ToggleStartup'))
        this.Advanced := w.AddButton('x22 y272 w144 h33', '⚙ 高级设置')
        this.Advanced.OnEvent('Click', ObjBindMethod(this, 'EditAdvanced'))
        this.TestButton := w.AddButton('x304 y272 w160 h33', '测试 DJI 按钮')
        this.TestButton.OnEvent('Click', ObjBindMethod(this, 'TestDevice'))
        w.AddText('x22 y322 w442 h1 0x10')
        helpIcon := w.AddPicture('x22 y337 w17 h17', this.Resource('github.png'))
        helpIcon.OnEvent('Click', (*) => Run(PortableApp.ManualURL))
        help := w.AddLink('x46 y335 w120 h24', '<a href="' PortableApp.ManualURL '">使用说明</a>')
        developer := w.AddButton('x186 y331 w116 h28', '开发者模式')
        developer.OnEvent('Click', ObjBindMethod(this, 'OpenDeveloperTools'))
        versionFile := this.Root '\resources\release.json'
        if !FileExist(versionFile)
            versionFile := this.Root '\release\manifest.json'
        if !RegExMatch(FileRead(versionFile, 'UTF-8'), '"version"\s*:\s*"(v\d+\.\d+\.\d+)"', &version)
            throw Error('无法读取便携版版本信息。')
        w.AddText('x330 y336 w134 Right c677889', version[1])
    }

    OpenDeveloperTools(*) {
        runtime := this.Root '\runtime\AutoHotkey64.exe'
        dash := this.Root '\runtime\UX\ui-dash.ahk'
        try {
            if !FileExist(runtime) || !FileExist(dash)
                throw Error('请从完整的便携包打开开发者模式。')
            Run Format('"{}" /script "{}"', runtime, dash), this.Root '\runtime'
        } catch as failure {
            this.Warn(failure)
        }
    }

    static PaintPrimary(button, notice) {
        ; Only paint an enabled push button during CDDS_PREPAINT. Let Windows
        ; draw its usual disabled or high-contrast appearance.
        if NumGet(notice, 3 * A_PtrSize, 'uint') != 1 || !button.Enabled
            return 0
        contrast := Buffer(8 + A_PtrSize, 0)
        NumPut('uint', contrast.Size, contrast)
        if !DllCall('SystemParametersInfoW', 'uint', 0x42, 'uint', contrast.Size, 'ptr', contrast, 'uint', 0)
            || (NumGet(contrast, 4, 'uint') & 1)
            return 0
        dc := NumGet(notice, 4 * A_PtrSize, 'ptr')
        saved := DllCall('gdi32\SaveDC', 'ptr', dc)
        if !saved
            return 0
        try {
            rect := Buffer(16, 0)
            DllCall('GetClientRect', 'ptr', button.Hwnd, 'ptr', rect)
            state := SendMessage(0xF2, 0, 0, button) ; BM_GETSTATE, native mouse and keyboard states
            ; GDI COLORREF uses BBGGRR. Darken the teal for pressed and hot states.
            color := state & 4 ? 0x4E5900 : (state & 0x200 ? 0x606E00 : 0x697900)
            DllCall('gdi32\SetDCBrushColor', 'ptr', dc, 'uint', color)
            brush := DllCall('gdi32\GetStockObject', 'int', 18, 'ptr')
            DllCall('FillRect', 'ptr', dc, 'ptr', rect, 'ptr', brush)
            font := SendMessage(0x31, 0, 0, button) ; WM_GETFONT
            if font
                DllCall('gdi32\SelectObject', 'ptr', dc, 'ptr', font)
            DllCall('gdi32\SetBkMode', 'ptr', dc, 'int', 1)
            DllCall('gdi32\SetTextColor', 'ptr', dc, 'uint', 0xFFFFFF)
            DllCall('DrawTextW', 'ptr', dc, 'str', button.Text, 'int', -1, 'ptr', rect, 'uint', 0x825)
            if (state & 8) && !(SendMessage(0x129, 0, 0, button) & 1) { ; focus visible per WM_QUERYUISTATE
                inset := Max(2, Round(3 * A_ScreenDPI / 96))
                DllCall('InflateRect', 'ptr', rect, 'int', -inset, 'int', -inset)
                DllCall('DrawFocusRect', 'ptr', dc, 'ptr', rect)
            }
        } finally {
            DllCall('gdi32\RestoreDC', 'ptr', dc, 'int', saved)
        }
        return 4 ; CDRF_SKIPDEFAULT
    }

    BuildTray() {
        A_TrayMenu.Delete()
        A_TrayMenu.Add('打开主窗口', ObjBindMethod(this, 'Show'))
        A_TrayMenu.Add('恢复绑定', (*) => this.ToggleBinding(true))
        A_TrayMenu.Add('开机自启', ObjBindMethod(this, 'ToggleStartup'))
        A_TrayMenu.Add()
        A_TrayMenu.Add('退出', ObjBindMethod(this, 'Quit'))
        A_TrayMenu.Default := '打开主窗口'
        A_TrayMenu.ClickCount := 2
    }

    Show(*) {
        this.Refresh()
        this.Window.Show('w488 h368 Restore')
        active := this.Dialog ? this.Dialog : this.Window
        WinActivate 'ahk_id ' active.Hwnd
    }

    CloseMain(*) {
        if this.Dialog
            this.CloseDialog()
        else if this.Binding.Running || this.Paused
            this.Window.Hide()
        else
            this.Quit()
        return true
    }

    Quit(*) => ExitApp()

    StartFromTray() {
        try this.StartBinding()
        catch as failure {
            this.Show()
            this.Warn(failure)
        }
        this.Refresh()
    }

    StartBinding() {
        if this.Binding.LegacyActive()
            throw Error('原版 DJI 听写脚本正在运行。请先从原版托盘退出，再启动便携绑定。')
        this.Binding.Start(false)
        this.Paused := false
    }

    PauseForLegacy() {
        this.Paused := true
        this.Refresh()
        TrayTip '检测到原版 DJI 脚本，便携绑定已暂停。', 'DJI 听写'
    }

    ToggleBinding(fromTray) {
        if this.Dialog
            return
        try {
            if this.Binding.Running {
                this.Binding.Stop()
                this.Paused := fromTray
            } else
                this.StartBinding()
        } catch as failure {
            this.Warn(failure)
        }
        this.Refresh()
    }

    Refresh() {
        running := this.Binding.Running && this.Binding.Enabled
        state := this.Binding.Observer ? '测试中' : (running ? '运行中' : (this.Paused ? '已暂停' : '已停止'))
        this.Status.Text := state
        this.Status.SetFont(running ? 'c007B68' : 'c485764')
        this.StartButton.Text := running ? '停止绑定' : (this.Paused ? '恢复绑定' : '启动绑定')
        this.KeyLabels['Local'].Text := PortableBinding.DisplayKey(this.Binding.LocalKey)
        this.KeyLabels['Remote'].Text := PortableBinding.DisplayKey(this.Binding.RemoteKey)
        A_TrayMenu.Rename('2&', running ? '暂停绑定' : (this.Paused ? '恢复绑定' : '启动绑定'))
        startup := this.Login.Status()
        this.AutoStart.Value := startup = 'enabled'
        this.AutoStart.Text := startup = 'stale' ? '登录时自动启动（路径已变，点击修复）' : '登录时自动启动'
        if startup = 'enabled'
            A_TrayMenu.Check('开机自启')
        else
            A_TrayMenu.Uncheck('开机自启')
        A_IconTip := 'DJI 听写 · ' state
    }

    ToggleStartup(*) {
        if this.Dialog
            return
        try this.Login.SetEnabled(this.Login.Status() != 'enabled')
        catch as failure
            this.Warn(failure)
        this.Refresh()
    }

    BeginDialog(title) {
        if this.Dialog {
            this.Show()
            return false
        }
        d := Gui('+Owner' this.Window.Hwnd ' -MinimizeBox -MaximizeBox', title)
        d.BackColor := 'FAFBFC'
        d.SetFont('s10', 'Microsoft YaHei UI')
        this.Binding.SetDialogOpen(true)
        this.Window.Opt('+Disabled')
        this.Dialog := d
        d.OnEvent('Close', ObjBindMethod(this, 'CloseDialog'))
        d.OnEvent('Escape', ObjBindMethod(this, 'CloseDialog'))
        return d
    }

    CloseDialog(*) {
        if !this.Dialog
            return
        restoreError := false
        try this.Binding.EndObservation()
        catch as failure {
            restoreError := failure
            this.Paused := false
        }
        this.Window.Opt('-Disabled')
        this.Dialog.Destroy()
        this.Dialog := false
        this.Binding.SetDialogOpen(false)
        this.Refresh()
        this.Show()
        if restoreError
            this.Warn(restoreError)
    }

    EditShortcut(key, label, *) {
        d := this.BeginDialog('更改' label '听写快捷键')
        if !d
            return
        current := key = 'Local' ? this.Binding.LocalKey : this.Binding.RemoteKey
        d.SetFont('s15 bold c193755')
        d.AddText('x20 y16 w356', '请按下新的组合键')
        d.SetFont('s10 norm cDefault')
        d.AddText('x20 y64 w104', '当前快捷键')
        d.AddText('x128 y64 w242', PortableBinding.DisplayKey(current))
        d.AddText('x20 y103 w104', '新快捷键')
        capture := d.AddHotkey('x128 y98 w240 h28')
        winKey := d.AddCheckbox('x128 y134 w240', '加入 Win 键')
        d.AddText('x20 y174 w356 c526272', '请在 ChatGPT 中使用相同的快捷键。')
        cancel := d.AddButton('x178 y210 w90 h32', '取消')
        save := d.AddButton('x278 y210 w90 h32 Default', '保存')
        save.OnNotify(-12, ObjBindMethod(PortableApp, 'PaintPrimary'))
        cancel.OnEvent('Click', ObjBindMethod(this, 'CloseDialog'))
        save.OnEvent('Click', (*) => this.SaveShortcut(key, capture.Value, winKey.Value))
        d.Show('w390 h260')
        capture.Focus()
    }

    SaveShortcut(key, input, win) {
        try {
            shortcut := PortableBinding.CaptureKey(input, win)
            this.Binding.SaveSettings('Hotkeys', Map(key, shortcut))
        } catch as failure {
            this.Warn(failure)
            return
        }
        this.CloseDialog()
    }

    EditAdvanced(*) {
        d := this.BeginDialog('高级设置')
        if !d
            return
        block := d.AddCheckbox('x20 y20 w356 h29', '拦截音量加键')
        block.SetFont('s12 bold c193755')
        block.Value := this.Binding.BlockVolumeUp
        d.AddText('x20 y60 w366 h42', '开启后，键盘和其他设备的音量加键也会被拦截。')
        d.AddText('x20 y110 w364 h1 0x10')
        d.AddText('x20 y130 w154 h25', '防重复触发间隔')
        delay := d.AddEdit('x190 y124 w118 h28', String(this.Binding.DebounceMs))
        d.AddUpDown('Range0-2000 +0x80', this.Binding.DebounceMs)
        d.AddText('x318 y129 w52', '毫秒')
        d.AddText('x20 y167 w360 c526272', '可设 0–2000 毫秒。按一次触发两次时，可适当调大。')
        cancel := d.AddButton('x187 y215 w90 h32', '取消')
        save := d.AddButton('x288 y215 w90 h32 Default', '保存')
        save.OnNotify(-12, ObjBindMethod(PortableApp, 'PaintPrimary'))
        cancel.OnEvent('Click', ObjBindMethod(this, 'CloseDialog'))
        save.OnEvent('Click', (*) => this.SaveAdvanced(block.Value, delay.Value))
        d.Show('w400 h264')
    }

    SaveAdvanced(block, delay) {
        try {
            if !RegExMatch(delay, '^\d{1,4}$') || Integer(delay) > 2000
                throw Error('请输入 0 到 2000 之间的整数毫秒。')
            this.Binding.SaveSettings('Behavior', Map('BlockVolumeUp', block, 'DebounceMs', Integer(delay)))
        } catch as failure {
            this.Warn(failure)
            return
        }
        this.CloseDialog()
    }

    TestDevice(*) {
        d := this.BeginDialog('测试 DJI 按钮')
        if !d
            return
        d.SetFont('s15 bold c193755')
        d.AddText('x20 y20 w375', '请短按一下 DJI 发射器按钮。')
        d.SetFont('s10 norm cDefault')
        signal := d.AddText('x20 y80 w374 h36', '等待按钮信号…')
        signal.SetFont('s13 bold c007B68')
        d.AddText('x20 y137 w374', '请回到 ChatGPT 的输入框验证听写。')
        retry := d.AddButton('x190 y192 w98 h32', '再测一次')
        done := d.AddButton('x300 y192 w90 h32 Default', '完成')
        done.OnNotify(-12, ObjBindMethod(PortableApp, 'PaintPrimary'))
        retry.OnEvent('Click', (*) => signal.Text := '等待按钮信号…')
        done.OnEvent('Click', ObjBindMethod(this, 'CloseDialog'))
        try {
            this.Binding.BeginObservation(() => signal.Text := '✓ 已收到按钮信号')
            this.Refresh()
            d.Show('w412 h245')
        } catch as failure {
            this.CloseDialog()
            this.Warn(failure)
        }
    }

    Warn(failure) {
        owner := this.Dialog ? this.Dialog : this.Window
        MsgBox failure.Message, 'DJI 听写', 'Owner' owner.Hwnd ' Icon!'
    }
}

try PortableApp.Launch()
catch as failure {
    MsgBox failure.Message, 'DJI 听写未启动', 'Icon!'
    ExitApp 1
}
