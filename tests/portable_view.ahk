#Requires AutoHotkey v2.0

class ViewFixture extends PortableApp {
    Clicks := 0
    ToggleBinding(*) => this.Clicks++
}

Check(value, message) {
    if !value
        throw Error(message)
}

ButtonPixel(button, x := 8, y := 8) {
    ; Ask this real button HWND to paint into a memory bitmap (no screen grab).
    button.GetPos(,, &width, &height)
    display := DllCall('GetDC', 'ptr', button.Hwnd, 'ptr')
    dc := DllCall('gdi32\CreateCompatibleDC', 'ptr', display, 'ptr')
    bitmap := DllCall('gdi32\CreateCompatibleBitmap', 'ptr', display, 'int', width, 'int', height, 'ptr')
    old := DllCall('gdi32\SelectObject', 'ptr', dc, 'ptr', bitmap, 'ptr')
    try {
        SendMessage 0x318, dc, 0x0C, button ; WM_PRINTCLIENT, PRF_CLIENT | PRF_ERASEBKGND
        return DllCall('gdi32\GetPixel', 'ptr', dc, 'int', x, 'int', y, 'uint')
    } finally {
        DllCall('gdi32\SelectObject', 'ptr', dc, 'ptr', old)
        DllCall('gdi32\DeleteObject', 'ptr', bitmap)
        DllCall('gdi32\DeleteDC', 'ptr', dc)
        DllCall('ReleaseDC', 'ptr', button.Hwnd, 'ptr', display)
    }
}

try {
    SplitPath A_ScriptDir,, &projectRoot
    view := ViewFixture(projectRoot)
    view.Window.Show('x-3000 y-3000 w488 h368 NA')
    button := view.StartButton
    Check(!(WinGetStyle(view.Window) & 0x10000), 'Main window must not advertise WS_MAXIMIZEBOX')
    Check((WinGetStyle(view.AutoStart) & 0x120) = 0x120 && view.AutoStart.Type = 'CheckBox', 'Right-hand native checkbox must retain its label')
    for key, field in view.KeyLabels
        Check(field.Type = 'Edit' && (WinGetStyle(field) & 0x800) && field.Value != '', 'Shortcut fields must be populated read-only edit controls')
    contrast := Buffer(8 + A_PtrSize, 0)
    NumPut('uint', contrast.Size, contrast)
    Check(DllCall('SystemParametersInfoW', 'uint', 0x42, 'uint', contrast.Size, 'ptr', contrast, 'uint', 0), 'Cannot determine system contrast')
    normal := ButtonPixel(button)
    SendMessage 0xF3, 1, 0, button ; BM_SETSTATE
    pressed := ButtonPixel(button)
    SendMessage 0xF3, 0, 0, button
    if !(NumGet(contrast, 4, 'uint') & 1) {
        Check(normal = 0x697900 && pressed = 0x4E5900, Format('Unexpected painted colors {:06X}/{:06X}', normal, pressed))
        SendMessage 0x127, 0x10002, 0,, view.Window ; WM_CHANGEUISTATE: clear UISF_HIDEFOCUS
        button.Focus()
        inset := Max(2, Round(3 * A_ScreenDPI / 96))
        Check(ButtonPixel(button, inset+4, inset) != normal || ButtonPixel(button, inset+5, inset) != normal,
            'Keyboard focus must paint a visible outline')
    }
    button.Enabled := false
    Check(ButtonPixel(button) != 0x697900, 'Disabled button must return to system rendering')
    button.Enabled := true
    ; Space is delivered exclusively to our own native button. Its click handler
    ; is replaced above so no input registration, shortcuts or volume actions run.
    PostMessage 0x100, 0x20, 0, button
    PostMessage 0x101, 0x20, 0, button
    Sleep 150
    Check(view.Clicks = 1, 'Native keyboard activation must still invoke the button action')
    FileAppend Format('PASS: native HWND styles, edit fields, checkbox, painting {:06X}/{:06X}, focus outline, disabled fallback and Space activation.', normal, pressed), '*'
    ExitApp 0
} catch as failure {
    FileAppend 'FAIL: ' failure.Message ' (line ' failure.Line ')', '*'
    ExitApp 1
}

#Include ..\app\Main.ahk
