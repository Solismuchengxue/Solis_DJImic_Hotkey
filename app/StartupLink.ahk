#Requires AutoHotkey v2.0

class StartupLink {
    static Marker := 'Solis_DJImic_Hotkey portable startup v1'

    __New(folder, interpreter, script, root) {
        this.Path := folder '\DJI 听写.lnk'
        this.Interpreter := interpreter
        this.Arguments := '"' script '" --tray'
        this.Root := root
    }

    Status(path := '') {
        if path = ''
            path := this.Path
        if !FileExist(path)
            return 'missing'
        try FileGetShortcut path, &target, &directory, &arguments, &description
        catch
            return 'foreign'
        if description != StartupLink.Marker
            return 'foreign'
        return target = this.Interpreter && directory = this.Root && arguments = this.Arguments ? 'enabled' : 'stale'
    }

    SetEnabled(enabled) {
        state := this.Status()
        if state = 'foreign'
            throw Error('启动文件夹中已有其他同名快捷方式。请检查“DJI 听写.lnk”后重试。')
        if !enabled {
            if state != 'missing'
                FileDelete this.Path
            return
        }
        if state = 'enabled'
            return
        ; Stage beside the Startup folder on the same volume. A partial link in
        ; the Startup folder itself could run if the user logs in mid-update.
        SplitPath this.Path,, &startupDir
        SplitPath startupDir,, &parent
        staged := parent '\.DJI-startup-' DllCall('GetCurrentProcessId') '-' A_TickCount '.lnk'
        if FileExist(staged)
            throw Error('有未完成的临时启动快捷方式，请稍后重试。')
        try {
            FileCreateShortcut this.Interpreter, staged, this.Root, this.Arguments, StartupLink.Marker
            if this.Status(staged) != 'enabled'
                throw Error('启动快捷方式读回不一致，请检查便携目录。')
            if this.Status() != state
                throw Error('登录启动项刚刚发生变化，请重试。')
            flags := 8 | (state = 'stale' ? 1 : 0)
            if !DllCall('MoveFileExW', 'str', staged, 'str', this.Path, 'uint', flags)
                throw OSError()
            if this.Status() != 'enabled'
                throw Error('无法确认登录启动项，请检查启动文件夹。')
        } finally {
            if FileExist(staged)
                FileDelete staged
        }
    }
}
