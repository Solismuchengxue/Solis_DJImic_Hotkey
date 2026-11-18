#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\PortableBinding.ahk
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
        SplitPath A_LineFile,, &appDir
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
        w.AddText('x22 y92 w442 h1 0x10')
        w.AddText('x22 y104', '听写快捷键')
        w.SetFont('s10 norm c192B3C')
        this.KeyLabels := Map()
        for row, item in [['Local','本机'], ['Remote','RDP']] {
            y := 140 + (row - 1) * 37
            w.AddText('x26 y' y+5 ' w70', item[2])
            this.KeyLabels[item[1]] := w.AddText('x96 y' y+5 ' w208', '')
            button := w.AddButton('x376 y' y ' w88 h30', '更改')
            button.OnEvent('Click', ObjBindMethod(this, 'EditShortcut', item[1], item[2]))
        }
        w.AddText('x22 y218 w442 h1 0x10')
        this.AutoStart := w.AddCheckbox('x22 y232 w264 h26 Disabled', '登录时自动启动')
        this.Advanced := w.AddButton('x22 y272 w144 h33 Disabled', '⚙ 高级设置')
        this.TestButton := w.AddButton('x304 y272 w160 h33 Disabled', '测试 DJI 按钮')
        w.AddText('x22 y322 w442 h1 0x10')
        helpIcon := w.AddPicture('x22 y337 w17 h17', this.Resource('github.png'))
        helpIcon.OnEvent('Click', (*) => Run(PortableApp.ManualURL))
        help := w.AddLink('x46 y335 w120 h24', '<a href="' PortableApp.ManualURL '">使用说明</a>')
        versionFile := this.Root '\resources\release.json'
        if !FileExist(versionFile)
            versionFile := this.Root '\release\manifest.json'
        if !RegExMatch(FileRead(versionFile, 'UTF-8'), '"version"\s*:\s*"(v\d+\.\d+\.\d+)"', &version)
            throw Error('无法读取便携版版本信息。')
        w.AddText('x330 y336 w134 Right c677889', version[1])
    }

    BuildTray() {
        A_TrayMenu.Delete()
        A_TrayMenu.Add('打开主窗口', ObjBindMethod(this, 'Show'))
        A_TrayMenu.Add('恢复绑定', (*) => this.ToggleBinding(true))
        A_TrayMenu.Add('开机自启', (*) => 0)
        A_TrayMenu.Disable('开机自启')
        A_TrayMenu.Add()
        A_TrayMenu.Add('退出', (*) => ExitApp())
        A_TrayMenu.Default := '打开主窗口'
        A_TrayMenu.ClickCount := 2
    }

    Show(*) {
        this.Window.Show('w488 h368 Restore')
        active := this.Dialog ? this.Dialog : this.Window
        WinActivate 'ahk_id ' active.Hwnd
    }

    CloseMain(*) {
        if this.Dialog
            this.CloseDialog()
        else if this.Binding.Running
            this.Window.Hide()
        else
            ExitApp()
        return true
    }

    StartFromTray() {
        try this.StartBinding()
        catch as failure {
            this.Show()
            this.Warn(failure)
        }
        this.Refresh()
    }

    StartBinding() {
        if PortableBinding.LegacyRunning()
            throw Error('原版 DJI 听写脚本正在运行。请先从原版托盘退出，再启动便携绑定。')
        this.Binding.Start(false)
        this.Paused := false
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
        running := this.Binding.Running
        state := running ? '运行中' : (this.Paused ? '已暂停' : '已停止')
        this.Status.Text := state
        this.Status.SetFont(running ? 'c007B68' : 'c485764')
        this.StartButton.Text := running ? '停止绑定' : (this.Paused ? '恢复绑定' : '启动绑定')
        this.KeyLabels['Local'].Text := PortableBinding.DisplayKey(this.Binding.LocalKey)
        this.KeyLabels['Remote'].Text := PortableBinding.DisplayKey(this.Binding.RemoteKey)
        A_TrayMenu.Rename('2&', running ? '暂停绑定' : '恢复绑定')
        A_IconTip := 'DJI 听写 · ' state
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
        this.Window.Opt('-Disabled')
        this.Dialog.Destroy()
        this.Dialog := false
        this.Binding.SetDialogOpen(false)
        this.Refresh()
        this.Show()
    }

    EditShortcut(key, label, *) {
        d := this.BeginDialog('更改' label '听写快捷键')
        if !d
            return
        current := key = 'Local' ? this.Binding.LocalKey : this.Binding.RemoteKey
        title := d.AddText('x20 y16 w356', '请按下新的组合键')
        title.SetFont('s15 bold c193755')
        d.AddText('x20 y64 w104', '当前快捷键')
        d.AddText('x128 y64 w242', PortableBinding.DisplayKey(current))
        d.AddText('x20 y103 w104', '新快捷键')
        capture := d.AddHotkey('x128 y98 w240 h28')
        winKey := d.AddCheckbox('x128 y134 w240', '加入 Win 键')
        d.AddText('x20 y174 w356 c526272', '请在 ChatGPT 中使用相同的快捷键。')
        cancel := d.AddButton('x178 y210 w90 h32', '取消')
        save := d.AddButton('x278 y210 w90 h32 Default', '保存')
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
