#Requires AutoHotkey v2.0
#Include ..\app\PortableBinding.ahk
#Include ..\app\StartupLink.ahk
#SingleInstance Off

Check(value, message) {
    if !value
        throw Error(message)
}

class ObserverFixture extends PortableBinding {
    Conflict := false
    FailStart := false
    FailVolume := false

    LegacyActive() => this.Conflict

    Start(legacyTray := true) {
        if this.FailStart
            throw Error('Simulated registration failure')
        this.Running := true
        this.SetVolumeBlock(this.Enabled && this.BlockVolumeUp)
    }

    Stop(*) {
        this.Running := false
        this.VolumeRegistered := false
        this.Generation += 1
        this.Pressed.Clear()
        this.LastTrigger := -100000
    }

    SetVolumeBlock(enabled) {
        if enabled && this.FailVolume
            throw Error('Simulated native hotkey conflict')
        this.VolumeRegistered := enabled
    }
}

SplitPath A_ScriptDir,, &projectRoot
fixture := projectRoot '\tmp\便携 测试 ' DllCall('GetCurrentProcessId')
exitCode := 0
created := false
try {
    if FileExist(fixture)
        throw Error('Refusing to reuse a previous fixture')
    DirCreate fixture
    created := true
    config := fixture '\DJI_Mic_Hotkey.ini'
    FileCopy A_ScriptDir '\..\config\DJI_Mic_Hotkey.ini', config
    binding := ObserverFixture(config)
    for delay in [0, 2000] {
        binding.SaveSettings('Behavior', Map('BlockVolumeUp', 1, 'DebounceMs', delay))
        Check(binding.DebounceMs = delay && binding.BlockVolumeUp, 'Advanced settings boundaries')
    }
    for invalid in [-1, 2001, 'abc', '1.5'] {
        rejected := false
        try binding.SaveSettings('Behavior', Map('BlockVolumeUp', 0, 'DebounceMs', invalid))
        catch
            rejected := true
        Check(rejected && binding.DebounceMs = 2000 && binding.BlockVolumeUp, 'Invalid edit must retain active settings')
        Check(IniRead(config, 'Behavior', 'BlockVolumeUp') = 1, 'Invalid edit must retain saved settings')
    }
    binding.SaveSettings('Behavior', Map('BlockVolumeUp', 1, 'DebounceMs', 250))
    for running in [false, true] {
        if running
            binding.Start(false)
        count := [0]
        binding.BeginObservation(() => count[1]++)
        Check(binding.Observer && binding.Running && !binding.Enabled && !binding.VolumeRegistered, 'Observation must inhibit dispatch and volume capture')
        binding.DispatchReport(1, true, 500)
        binding.DispatchReport(1, true, 540)
        binding.DispatchReport(1, false, 570)
        binding.DispatchReport(1, true, 610)
        binding.DispatchReport(1, false, 700)
        binding.DispatchReport(1, true, 850)
        Check(count[1] = 2, 'Only debounced fresh press edges may reach the observer')
        binding.EndObservation()
        Check(!binding.Observer && binding.Enabled && binding.Running = running && binding.VolumeRegistered = running,
            'Closing test must restore the preceding state and optional volume guard')
        binding.EndObservation()
        binding.Stop()
    }
    binding.FailStart := true
    rejected := false
    try binding.BeginObservation(() => 0)
    catch
        rejected := true
    Check(rejected && !binding.Running && !binding.Observer && binding.Enabled, 'Failed open must leave the stopped state intact')
    binding.FailStart := false
    binding.Start(false)
    binding.BeginObservation(() => 0)
    binding.FailVolume := true
    rejected := false
    try binding.EndObservation()
    catch
        rejected := true
    Check(rejected && !binding.Running && !binding.Observer && !binding.VolumeRegistered, 'Failed restoration must leave a released stopped state')

    ; Fixture directory and script never execute, and no real Startup path is used.
    isolatedStartup := fixture '\Startup'
    DirCreate isolatedStartup
    script := fixture '\DJI 听写.ahk'
    FileAppend '', script
    root := fixture
    target := StartupLink(root '\Startup', A_AhkPath, '"' script '" --tray', root)
    Check(target.Status() = 'missing', 'Isolated Startup begins empty')
    target.SetEnabled(true)
    target.SetEnabled(true)
    Check(target.Status() = 'enabled', 'Shortcut must resolve the interpreter, exact script, --tray, directory and owner')
    moved := StartupLink(root '\Startup', A_AhkPath, '--tray', root)
    Check(moved.Status() = 'stale', 'A moved installation must detect its stale managed shortcut')
    moved.SetEnabled(true)
    Check(moved.Status() = 'enabled' && target.Status() = 'stale', 'An explicit enable repairs stale owned links')
    moved.SetEnabled(false)
    Check(moved.Status() = 'missing', 'Disable removes only the managed shortcut')
    FileCreateShortcut A_AhkPath, target.Path, root,, 'Unrelated application'
    for enable in [true, false] {
        rejected := false
        try target.SetEnabled(enable)
        catch
            rejected := true
        Check(rejected && target.Status() = 'foreign', 'A foreign link must survive enable and disable unchanged')
    }
    FileAppend 'PASS: advanced settings; observer lifecycle, debounce and recovery; isolated login shortcut identity, readback, repair and removal.', '*'
} catch as failure {
    FileAppend 'FAIL: ' failure.Message ' (line ' failure.Line ')', '*'
    exitCode := 1
} finally {
    if created {
        ; Remove only the known fixtures created by this invocation.
        for fixtureName in ['Startup\DJI 听写.lnk', 'DJI 听写.ahk', 'DJI_Mic_Hotkey.ini']
            if FileExist(fixture '\' fixtureName)
                FileDelete fixture '\' fixtureName
        if DirExist(fixture '\Startup')
            DirDelete fixture '\Startup'
        DirDelete fixture
    }
}
ExitApp exitCode
