#Requires AutoHotkey v2.0
#SingleInstance Off
#Include ..\DJI_Mic_Hotkey.ahk

Check(value, message) {
    if !value
        throw Error(message)
}
CanRegisterVolume(window) {
    registered := DllCall('RegisterHotKey','ptr',window.Hwnd,'int',0x56B,'uint',0,'uint',0xAF)
    if registered
        DllCall('UnregisterHotKey','ptr',window.Hwnd,'int',0x56B)
    return registered
}
fixture := A_ScriptDir '\..\tmp\volume_lifecycle_' DllCall('GetCurrentProcessId') '.ini'
created := false
exitCode := 0
try {
    if FileExist(fixture)
        throw Error('Refusing to overwrite an existing fixture')
    FileAppend '[Behavior]`nBlockVolumeUp=1`n',fixture,'UTF-8-RAW'
    created := true
    binding := DjiMicHotkey(fixture)
    Check(binding.BlockVolumeUp, 'Fixture must enable interception before native lifecycle checks')
    binding.Host := Gui('+ToolWindow -Caption')
    binding.Running := true
    receiver := Gui('+ToolWindow -Caption')
    Check(CanRegisterVolume(receiver), 'Volume_Up is already owned by another program')
    ; Test only the guard. Do not register Raw Input or send any keys.
    binding.SetVolumeBlock(true)
    Check(binding.VolumeRegistered && !CanRegisterVolume(receiver), 'Enabled guard must own the native hotkey')
    binding.SetEnabled(false)
    Check(!binding.VolumeRegistered && CanRegisterVolume(receiver), 'Pause must release native ownership')
    binding.SetEnabled(true)
    Check(binding.VolumeRegistered && !CanRegisterVolume(receiver), 'Resume must reacquire native ownership')
    binding.Stop()
    Check(!binding.Running && !binding.VolumeRegistered && CanRegisterVolume(receiver), 'Stop must release ownership and running state')
    binding.Stop()
    Check(CanRegisterVolume(receiver), 'Repeated stop must remain safe')
    FileAppend 'PASS: native registration, pause/resume, stop and repeated cleanup; no Raw Input or key sending`n','*'
} catch as failure {
    FileAppend 'FAIL: ' failure.Message '`n','*'
    exitCode := 1
}
if IsSet(binding)
    binding.Stop()
if created
    FileDelete fixture
ExitApp exitCode
