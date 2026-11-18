#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\..\DJI_Mic_Hotkey.ahk

class PortableBinding extends DjiMicHotkey {
    DefaultLocal => '^+d'
    DefaultRemote => '^+d'

    __New(configPath) {
        if !FileExist(configPath)
            throw Error('未找到便携配置。请完整解压程序后重试。')
        super.__New(configPath)
        this.DialogOpen := false
        this.Observer := false
    }

    SetDialogOpen(open) {
        this.DialogOpen := open
        this.Generation += 1
    }

    CanSend(target, generation) {
        if this.DialogOpen || !this.Running || generation != this.Generation
            return false
        if this.LegacyActive() {
            this.Stop()
            if this.HasOwnProp('OnLegacyConflict')
                this.OnLegacyConflict.Call()
            return false
        }
        if !super.CanSend(target, generation)
            return false
        return WinGetPID('ahk_id ' target) != DllCall('GetCurrentProcessId')
    }

    LegacyActive() => PortableBinding.LegacyRunning()

    BeginObservation(callback) {
        if this.Observer
            return
        if this.LegacyActive()
            throw Error('请先从原版托盘退出 DJI 脚本，再测试便携版按钮。')
        this.WasRunning := this.Running
        this.SetEnabled(false)
        this.Observer := callback
        if !this.WasRunning {
            try this.Start(false)
            catch as failure {
                this.Observer := false
                this.SetEnabled(true)
                throw failure
            }
        }
    }

    DispatchReport(handle, pressed, now) {
        if !this.Observer {
            super.DispatchReport(handle, pressed, now)
            return
        }
        ; OnRaw calls this only for the matched HID collection. Observation does
        ; not inspect the foreground application or enqueue a shortcut.
        if this.TakePress(handle, pressed, now, true)
            this.Observer.Call()
    }

    EndObservation() {
        if !this.Observer
            return
        this.Observer := false
        try {
            if !this.WasRunning
                this.Stop()
            else if this.LegacyActive()
                throw Error('原版脚本已启动，便携绑定已停止。请退出原版后再启动绑定。')
            this.SetEnabled(true)
        } catch as failure {
            this.Stop()
            this.Enabled := true
            throw failure
        }
    }

    ; Write and validate a sibling copy. Rename only after native registration
    ; succeeds. Unknown sections and the other shortcut remain in that copy.
    SaveSettings(section, changes) {
        staged := this.ConfigPath '.' DllCall('GetCurrentProcessId') '.' A_TickCount '.tmp'
        FileCopy this.ConfigPath, staged, false
        try {
            for key, value in changes
                IniWrite value, staged, section, key
            candidate := this.ReadSettings(staged)
            previousBlock := this.VolumeRegistered
            if this.Running
                this.SetVolumeBlock(this.Enabled && candidate.BlockVolumeUp)
            try this.ReplaceFile(staged)
            catch as failure {
                if this.Running
                    this.SetVolumeBlock(previousBlock)
                throw failure
            }
            this.ApplySettings(candidate)
            this.Generation += 1
            this.Devices.Clear()
            this.Pressed.Clear()
        } finally {
            if FileExist(staged)
                FileDelete staged
        }
    }

    ReplaceFile(staged) {
        ; Flush the profile API cache before atomically replacing on the same volume.
        DllCall('WritePrivateProfileStringW', 'ptr', 0, 'ptr', 0, 'ptr', 0, 'str', staged)
        if !DllCall('MoveFileExW', 'str', staged, 'str', this.ConfigPath, 'uint', 0x9)
            throw OSError()
    }

    static DisplayKey(value) {
        result := ''
        for pair in [['^','Ctrl'], ['+','Shift'], ['!','Alt'], ['#','Win']]
            if InStr(value, pair[1])
                result .= pair[2] '+'
        return result StrUpper(RegExReplace(value, '^[!^+#]+'))
    }

    static CaptureKey(value, win) {
        shortcut := (win ? '#' : '') StrLower(value)
        if !DjiMicHotkey.ValidShortcut(shortcut)
            throw Error('请录入至少一个修饰键与字母、数字或 F1–F24 的组合。')
        return shortcut
    }

    static LegacyRunning() {
        previous := A_DetectHiddenWindows
        DetectHiddenWindows true
        try {
            for hwnd in WinGetList('ahk_class AutoHotkey') {
                title := WinGetTitle('ahk_id ' hwnd)
                if RegExMatch(title, 'i)\\DJI_Mic_Hotkey\.ahk - AutoHotkey v[0-9.]+$')
                    return true
            }
            return false
        } finally {
            DetectHiddenWindows previous
        }
    }
}
