#Requires AutoHotkey v2.0
#Include ..\app\PortableBinding.ahk
#SingleInstance Off

Check(value, message) {
    if !value
        throw Error(message)
}

class SimulatedDiskFailure extends PortableBinding {
    ReplaceFile(staged) {
        throw Error('Simulated unavailable destination')
    }
}

class LateLegacyBinding extends PortableBinding {
    LegacyActive() => this.OldScriptAppeared

    Stop(*) {
        ; Simulate only our own listener being released. Never register Raw Input.
        this.Running := false
        this.Generation += 1
    }
}

path := A_ScriptDir '\..\tmp\便携 配置 ' DllCall('GetCurrentProcessId') '.ini'
created := false
result := 0
try {
    FileCopy A_ScriptDir '\..\config\DJI_Mic_Hotkey.ini', path, false
    created := true
    IniWrite 'retain me', path, 'Other', 'Unknown'
    binding := PortableBinding(path)
    Check(!binding.Running && !binding.VolumeRegistered, 'New portable binding must be stopped')
    Check(binding.LocalKey = '^+d' && binding.RemoteKey = '^+d', 'Portable defaults')
    Check(!binding.BlockVolumeUp && binding.DebounceMs = 250, 'Portable behavior defaults')
    combo := PortableBinding.CaptureKey('^+F24', true)
    Check(PortableBinding.DisplayKey(combo) = 'Ctrl+Shift+Win+F24', 'Captured Win and F24 combination')
    Check(DjiMicHotkey.SendSequence(combo) = '#^+{f24}', 'Function keys must send one named key')
    binding.SaveSettings('Hotkeys', Map('Remote', combo))
    Check(binding.LocalKey = '^+d' && binding.RemoteKey = combo, 'Only the selected binding changes')
    Check(IniRead(path, 'Other', 'Unknown') = 'retain me', 'Preserve unrelated INI sections')
    Check(PortableBinding(path).RemoteKey = combo, 'Saved shortcut survives reopening')

    before := FileRead(path, 'RAW')
    for faulty in [binding, SimulatedDiskFailure(path)] {
        rejected := false
        try faulty.SaveSettings('Hotkeys', Map('Remote', faulty = binding ? 'invalid' : '!z'))
        catch
            rejected := true
        after := FileRead(path, 'RAW')
        Check(rejected && faulty.RemoteKey = combo, 'Failed edit must retain active settings')
        Check(before.Size = after.Size && DllCall('msvcrt\memcmp', 'ptr', before, 'ptr', after, 'uptr', before.Size) = 0,
            'Failed edit must retain exact INI bytes')
    }

    binding.Running := true ; Pure dispatch checks, no native registration or key send.
    binding.SetDialogOpen(true)
    Check(!binding.CanSend(1, binding.Generation), 'Editing must suppress dispatch')
    generation := binding.Generation
    binding.SetDialogOpen(false)
    Check(!binding.CanSend(1, generation), 'A delayed modal press must remain suppressed after close')
    binding.Running := false
    Check(!binding.CanSend(1, binding.Generation), 'Stopped session must suppress dispatch')

    late := LateLegacyBinding(path)
    late.OldScriptAppeared := false
    Check(!late.LegacyActive(), 'No legacy instance at portable startup')
    late.Running := true
    late.OldScriptAppeared := true
    Check(!late.CanSend(1, late.Generation) && !late.Running && late.OldScriptAppeared,
        'A later legacy instance must block the pending dispatch and stop only the portable listener')

    IniDelete path, 'Hotkeys'
    Check(PortableBinding(path).RemoteKey = '^+d' && DjiMicHotkey(path).RemoteKey = '!x', 'Portable and original omission defaults')
    FileAppend 'PASS: portable save/reopen, Win/function keys, transactional failure, modal and stop dispatch, legacy defaults.', '*'
} catch as failure {
    FileAppend 'FAIL: ' failure.Message ' (line ' failure.Line ')', '*'
    result := 1
} finally {
    if created
        FileDelete path
}
ExitApp result
