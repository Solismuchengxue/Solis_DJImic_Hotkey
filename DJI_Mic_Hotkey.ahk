#Requires AutoHotkey v2.0
#SingleInstance Ignore

; The observed DJI Consumer Control collection triggers dictation.
; BlockVolumeUp=1 explicitly opts into blocking Volume_Up from every device.
class DjiMicHotkey {
    __New(configPath) {
        this.ConfigPath := configPath
        this.LoadSettings()
        this.Enabled := true
        this.Pressed := Map()
        this.Devices := Map()
        this.LastTrigger := -100000
        this.LogPath := ''
        this.LogCount := 0
        this.Running := false
        this.VolumeRegistered := false
        this.VolumeHotkeyId := 0x56A
        this.VolumeHandler := ObjBindMethod(this,'OnVolumeMessage')
        this.VolumeHookHandler := ObjBindMethod(this,'OnVolumeHook')
        this.VolumeTimer := ObjBindMethod(this,'RefreshRdpHook')
        this.VolumeRearm := ObjBindMethod(this,'ReinstallRdpHook')
        this.LastRdpState := ''
    }

    LoadSettings() {
        localKey := IniRead(this.ConfigPath, 'Hotkeys', 'Local', '!c')
        remoteKey := IniRead(this.ConfigPath, 'Hotkeys', 'Remote', '!x')
        if !DjiMicHotkey.ValidShortcut(localKey) || !DjiMicHotkey.ValidShortcut(remoteKey)
            throw Error('快捷键格式无效。示例：!c 表示 Alt+C，^!c 表示 Ctrl+Alt+C。')
        vid := IniRead(this.ConfigPath, 'Device', 'VID', '2CA3')
        pid := IniRead(this.ConfigPath, 'Device', 'PID', '4011')
        iface := IniRead(this.ConfigPath, 'Device', 'Interface', 'MI_00')
        collection := IniRead(this.ConfigPath, 'Device', 'Collection', 'Col01')
        if !RegExMatch(vid, 'i)^[0-9a-f]{4}$') || !RegExMatch(pid, 'i)^[0-9a-f]{4}$')
            || !RegExMatch(iface, 'i)^MI_[0-9a-f]{2}$') || !RegExMatch(collection, 'i)^Col[0-9a-f]{2}$')
            throw Error('设备标识格式无效。')
        delay := IniRead(this.ConfigPath, 'Behavior', 'DebounceMs', 250)
        if !IsInteger(delay) || delay < 0 || delay > 2000
            throw Error('DebounceMs 必须是 0 到 2000 的整数。')
        blockVolume := IniRead(this.ConfigPath,'Behavior','BlockVolumeUp',0)
        if !IsInteger(blockVolume) || (blockVolume != 0 && blockVolume != 1)
            throw Error('BlockVolumeUp 必须为 0 或 1；1 会拦截所有设备的音量加键。')
        ; Publish all settings together, retaining the old configuration on errors.
        this.LocalKey := localKey
        this.RemoteKey := remoteKey
        this.DeviceToken := 'VID_' vid '&PID_' pid
        this.Interface := iface
        this.Collection := collection
        this.DebounceMs := Integer(delay)
        this.BlockVolumeUp := blockVolume = 1
    }

    static ValidShortcut(value) => RegExMatch(value, 'i)^[!^+#]{1,4}(?:[a-z0-9]|F(?:[1-9]|1[0-9]|2[0-4]))$') != 0

    MatchesDevice(name) => InStr(name, this.DeviceToken) && InStr(name, this.Interface) && InStr(name, this.Collection)

    ProcessPress(handle, pressed, now, processName) {
        wasPressed := this.Pressed.Get(handle, false)
        this.Pressed[handle] := pressed
        if !this.Enabled || !pressed || wasPressed || now - this.LastTrigger < this.DebounceMs
            return ''
        this.LastTrigger := now
        return StrLower(processName) = 'mstsc.exe' ? this.RemoteKey : this.LocalKey
    }

    Start() {
        this.Host := Gui('+ToolWindow -Caption', 'DJI 听写绑定')
        this.RawHandler := ObjBindMethod(this, 'OnRaw')
        this.DeviceHandler := ObjBindMethod(this, 'DeviceChanged')
        OnMessage(0xFF, this.RawHandler)
        OnMessage(0xFE, this.DeviceHandler)
        registration := Buffer(8+A_PtrSize,0)
        NumPut('ushort',0x0C,'ushort',1,'uint',0x2100,'ptr',this.Host.Hwnd,registration)
        if !DllCall('RegisterRawInputDevices','ptr',registration,'uint',1,'uint',8+A_PtrSize)
            throw OSError()
        OnExit(ObjBindMethod(this, 'Stop'))
        this.Running := true
        this.SetVolumeBlock(this.Enabled && this.BlockVolumeUp)
        A_TrayMenu.Delete()
        A_TrayMenu.Add('打开快捷键配置', (*) => Run('notepad.exe "' this.ConfigPath '"'))
        A_TrayMenu.Add('重新读取配置', ObjBindMethod(this,'ReloadSettings'))
        A_TrayMenu.Add('暂停绑定', ObjBindMethod(this,'Toggle'))
        A_TrayMenu.Add()
        A_TrayMenu.Add('退出', (*) => ExitApp())
        this.UpdateTip()
        this.Log('started','')
        Persistent(true)
    }

    ReloadSettings(*) {
        previous := Map()
        for name in ['LocalKey','RemoteKey','DeviceToken','Interface','Collection','DebounceMs','BlockVolumeUp']
            previous[name] := this.%name%
        try {
            this.LoadSettings()
            if this.Running
                this.SetVolumeBlock(this.Enabled && this.BlockVolumeUp)
        }
        catch as failure {
            for name, value in previous
                this.%name% := value
            MsgBox failure.Message, '配置未更改', 'Icon!'
            return
        }
        this.Devices.Clear()
        this.Pressed.Clear()
        this.UpdateTip()
    }

    Toggle(*) {
        try this.SetEnabled(!this.Enabled)
        catch as failure {
            MsgBox failure.Message, '绑定状态未更改', 'Icon!'
            return
        }
        if this.Enabled
            A_TrayMenu.Uncheck('暂停绑定')
        else
            A_TrayMenu.Check('暂停绑定')
        this.UpdateTip()
    }

    SetEnabled(enabled) {
        if this.Running
            this.SetVolumeBlock(enabled && this.BlockVolumeUp)
        this.Enabled := enabled
    }

    UpdateTip() => A_IconTip := 'DJI 听写绑定：' (this.Enabled ? '已启用' : '已暂停') '`n本机 ' this.LocalKey ' / RDP ' this.RemoteKey '`n音量加：' (this.VolumeRegistered ? '全部设备已拦截' : '未拦截')

    SetVolumeBlock(enabled) {
        if !enabled {
            SetTimer this.VolumeTimer,0
            SetTimer this.VolumeRearm,0
            if !this.VolumeRegistered
                return
            this.VolumeRegistered := false
            DllCall('UnregisterHotKey','ptr',this.Host.Hwnd,'int',this.VolumeHotkeyId)
            OnMessage(0x312,this.VolumeHandler,0)
            ; Partial startup must still release registration if a hook failed.
            try Hotkey '*Volume_Up','Off'
            try Hotkey '*Volume_Up Up','Off'
            InstallKeybdHook false,true
            this.LastRdpState := ''
            this.Log('volume_block_stopped','')
            return
        }
        if this.VolumeRegistered
            return
        if !DllCall('RegisterHotKey','ptr',this.Host.Hwnd,'int',this.VolumeHotkeyId,'uint',0,'uint',0xAF)
            throw Error('无法接管音量加键，可能已被其他程序占用。错误码：' A_LastError)
        this.VolumeRegistered := true
        try {
            OnMessage(0x312,this.VolumeHandler)
            Hotkey '*Volume_Up',this.VolumeHookHandler,'On'
            Hotkey '*Volume_Up Up',this.VolumeHookHandler,'On'
            InstallKeybdHook true,true
            SetTimer this.VolumeTimer,200
            this.Log('volume_block_started','ALL_DEVICES')
        } catch as failure {
            this.SetVolumeBlock(false)
            throw failure
        }
    }

    OnVolumeMessage(id, *) {
        if this.VolumeRegistered && id = this.VolumeHotkeyId
            this.Log('volume_registered_key','ALL_DEVICES')
    }

    OnVolumeHook(name, *) => this.Log('volume_hook', InStr(name,' Up') ? 'up' : 'down')

    RefreshRdpHook() {
        if !this.VolumeRegistered
            return
        target := WinExist('A')
        state := ''
        try {
            if StrLower(WinGetProcessName('ahk_id ' target)) = 'mstsc.exe' {
                WinGetPos(&x,&y,&width,&height,'ahk_id ' target)
                state := target ':' x ':' y ':' width ':' height
            }
        }
        if state != this.LastRdpState {
            this.LastRdpState := state
            if state != ''
                SetTimer this.VolumeRearm,-250
        }
    }

    ReinstallRdpHook() {
        if this.VolumeRegistered && this.Enabled && WinActive('ahk_exe mstsc.exe') {
            InstallKeybdHook true,true
            this.Log('rdp_hook_refreshed','')
        }
    }

    DeviceChanged(wParam, handle, *) {
        if this.Devices.Has(handle)
            this.Devices.Delete(handle)
        if this.Pressed.Has(handle)
            this.Pressed.Delete(handle)
    }

    Device(handle) {
        if this.Devices.Has(handle)
            return this.Devices[handle]
        size := 0
        DllCall('GetRawInputDeviceInfoW','ptr',handle,'uint',0x20000007,'ptr',0,'uint*',&size)
        if !size
            return false
        name := Buffer((size+1)*2,0)
        if DllCall('GetRawInputDeviceInfoW','ptr',handle,'uint',0x20000007,'ptr',name,'uint*',&size) = 0xFFFFFFFF
            return false
        if !this.MatchesDevice(StrGet(name))
            return this.Devices[handle] := false
        parsedSize := 0
        DllCall('GetRawInputDeviceInfoW','ptr',handle,'uint',0x20000005,'ptr',0,'uint*',&parsedSize)
        if !parsedSize
            return false
        parsed := Buffer(parsedSize)
        if DllCall('GetRawInputDeviceInfoW','ptr',handle,'uint',0x20000005,'ptr',parsed,'uint*',&parsedSize) = 0xFFFFFFFF
            return false
        return this.Devices[handle] := parsed
    }

    OnRaw(wParam, lParam, *) {
        header := 8+2*A_PtrSize
        size := 0
        DllCall('GetRawInputData','ptr',lParam,'uint',0x10000003,'ptr',0,'uint*',&size,'uint',header)
        if size < header+8
            return
        packet := Buffer(size)
        if DllCall('GetRawInputData','ptr',lParam,'uint',0x10000003,'ptr',packet,'uint*',&size,'uint',header) = 0xFFFFFFFF
            || NumGet(packet,0,'uint') != 2
            return
        handle := NumGet(packet,8,'ptr')
        parsed := this.Device(handle)
        if !parsed
            return
        length := NumGet(packet,header,'uint')
        reports := NumGet(packet,header+4,'uint')
        if !length || length > 128 || reports > 16 || header+8+length*reports > size
            return
        loop reports {
            usages := Buffer(128,0)
            count := 64
            result := DllCall('hid\HidP_GetUsages','int',0,'ushort',0x0C,'ushort',0,'ptr',usages,'uint*',&count,'ptr',parsed,'ptr',packet.Ptr+header+8+(A_Index-1)*length,'uint',length,'uint')
            if result != 0x110000 || count > 64
                continue
            pressed := false
            loop count
                if NumGet(usages,(A_Index-1)*2,'ushort') = 0xE9
                    pressed := true
            target := WinExist('A')
            processName := ''
            try processName := WinGetProcessName('ahk_id ' target)
            shortcut := this.ProcessPress(handle,pressed,A_TickCount,processName)
            if shortcut != '' {
                this.Log('detected', StrLower(processName) = 'mstsc.exe' ? 'rdp' : 'local')
                SetTimer(ObjBindMethod(this,'SendShortcut',shortcut,target),-1)
            }
        }
    }

    SendShortcut(shortcut, target) {
        if !this.Enabled || WinExist('A') != target {
            this.Log('skipped_focus_changed','')
            return
        }
        SetKeyDelay 30,30
        SendEvent shortcut
        this.Log('sent', shortcut)
    }

    Log(event, detail) {
        if this.LogPath != '' && this.LogCount < 300 {
            FileAppend A_TickCount '`t' event '`t' detail '`n', this.LogPath, 'UTF-8'
            this.LogCount += 1
        }
    }

    Stop(*) {
        this.SetVolumeBlock(false)
        if !this.Running
            return
        this.Running := false
        registration := Buffer(8+A_PtrSize,0)
        NumPut('ushort',0x0C,'ushort',1,'uint',1,'ptr',0,registration)
        DllCall('RegisterRawInputDevices','ptr',registration,'uint',1,'uint',8+A_PtrSize)
        if HasProp(this,'RawHandler')
            OnMessage(0xFF,this.RawHandler,0)
        if HasProp(this,'DeviceHandler')
            OnMessage(0xFE,this.DeviceHandler,0)
        this.Log('stopped','')
    }
}

if A_LineFile = A_ScriptFullPath {
    try {
        Binding := DjiMicHotkey(A_ScriptDir '\DJI_Mic_Hotkey.ini')
        for arg in A_Args
            if SubStr(arg,1,6) = '--log='
                Binding.LogPath := SubStr(arg,7)
        Binding.Start()
    } catch as failure {
        MsgBox failure.Message, 'DJI 听写绑定未启动', 'Icon!'
        ExitApp 1
    }
}
