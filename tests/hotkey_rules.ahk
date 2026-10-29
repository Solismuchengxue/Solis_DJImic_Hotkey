#Requires AutoHotkey v2.0
#SingleInstance Off
#Include *i ..\DJI_Mic_Hotkey.ahk

Check(value, message) {
    if !value
        throw Error(message)
}
if !IsSet(DjiMicHotkey) {
    FileAppend 'FAIL: device-specific dictation binding is not implemented`n', '*'
    ExitApp 1
}
try {
    binding := DjiMicHotkey(A_ScriptDir '\..\DJI_Mic_Hotkey.ini')
    Check(binding.MatchesDevice('HID#VID_2CA3&PID_4011&MI_00&Col01#redacted'), 'Observed DJI collection must match')
    Check(!binding.MatchesDevice('HID#VID_25A7&PID_FA70&MI_01&Col07#redacted'), 'Keyboard must not match')
    Check(!binding.MatchesDevice('HID#VID_2CA3&PID_4011&MI_00&Col02#redacted'), 'Another collection must not match')
    Check(binding.ProcessPress(1,true,1000,'ChatGPT.exe') = '!c', 'Local press must select Alt+C')
    Check(binding.ProcessPress(1,true,1100,'ChatGPT.exe') = '', 'Held press must not repeat')
    Check(binding.ProcessPress(1,false,1101,'ChatGPT.exe') = '', 'Release must not trigger')
    Check(binding.ProcessPress(1,true,1150,'ChatGPT.exe') = '', 'Bounce must not trigger')
    binding.ProcessPress(1,false,1200,'mstsc.exe')
    Check(binding.ProcessPress(1,true,1500,'MSTSC.EXE') = '!x', 'RDP press must select Alt+X case-insensitively')
    binding.Enabled := false
    binding.ProcessPress(1,false,1600,'mstsc.exe')
    Check(binding.ProcessPress(1,true,1800,'mstsc.exe') = '', 'Paused binding must not send')
    Check(!DjiMicHotkey.ValidShortcut('text{Enter}'), 'Arbitrary text or commands must not be accepted as a shortcut')
    Check(DjiMicHotkey.ValidShortcut('^!c'), 'Configured modifier combinations must be accepted')
    FileAppend 'PASS: device filtering, local/RDP selection, press/release, debounce, pause, config validation`n', '*'
    ExitApp 0
} catch as failure {
    FileAppend 'FAIL: ' failure.Message '`n', '*'
    ExitApp 1
}
