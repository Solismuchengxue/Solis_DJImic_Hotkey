#Requires AutoHotkey v2.0
#SingleInstance Off
#Include ..\DJI_Mic_Hotkey.ahk

Check(value, message) {
    if !value
        throw Error(message)
}
class FakeVolumeBinding extends DjiMicHotkey {
    __New(path) {
        super.__New(path)
        this.Actions := []
        this.FailEnable := false
    }
    SetVolumeBlock(enabled) {
        if enabled && this.FailEnable
            throw Error('Simulated registration conflict')
        this.Actions.Push(enabled)
        this.VolumeRegistered := enabled
    }
}

fixture := A_ScriptDir '\..\tmp\volume_rules_' DllCall('GetCurrentProcessId') '.ini'
created := false
exitCode := 0
try {
    if FileExist(fixture)
        throw Error('Refusing to overwrite an existing fixture')
    FileAppend '[Behavior]`nDebounceMs=175`n', fixture, 'UTF-8-RAW'
    created := true
    binding := DjiMicHotkey(fixture)
    Check(binding.DebounceMs=175, 'Fixture INI must be read rather than falling back to defaults')
    Check(HasProp(binding,'BlockVolumeUp') && !binding.BlockVolumeUp, 'Global volume interception must be opt-in')
    IniWrite 1,fixture,'Behavior','BlockVolumeUp'
    binding.LoadSettings()
    Check(binding.BlockVolumeUp && !binding.VolumeRegistered, 'Loading configuration alone must not capture volume keys')
    oldKey := binding.LocalKey
    IniWrite '!z',fixture,'Hotkeys','Local'
    IniWrite 'invalid',fixture,'Behavior','BlockVolumeUp'
    rejected := false
    try binding.LoadSettings()
    catch
        rejected := true
    Check(rejected && binding.LocalKey=oldKey && binding.BlockVolumeUp, 'Invalid volume setting must preserve all previous settings')
    IniWrite 1,fixture,'Behavior','BlockVolumeUp'
    fake := FakeVolumeBinding(fixture)
    fake.Running := true
    fake.SetEnabled(false)
    Check(!fake.Enabled && !fake.Actions[-1], 'Pause must release global volume interception')
    fake.SetEnabled(true)
    Check(fake.Enabled && fake.Actions[-1], 'Resume must restore configured interception')
    fake.SetEnabled(false)
    fake.FailEnable := true
    rejected := false
    try fake.SetEnabled(true)
    catch
        rejected := true
    Check(rejected && !fake.Enabled && !fake.VolumeRegistered, 'Failed resume must remain paused with volume keys released')
    FileAppend 'PASS: opt-in setting, atomic validation, pause/resume and conflict handling`n', '*'
} catch as failure {
    FileAppend 'FAIL: ' failure.Message '`n', '*'
    exitCode := 1
}
if created
    FileDelete fixture
ExitApp exitCode
