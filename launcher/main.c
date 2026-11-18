#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <strsafe.h>

static int startup_error(const wchar_t *message)
{
    MessageBoxW(NULL, message, L"DJI 听写未启动", MB_OK | MB_ICONERROR);
    return 1;
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, PWSTR arguments, int show)
{
    wchar_t root[32768];
    wchar_t interpreter[32768];
    wchar_t command[32768];
    STARTUPINFOW startup = { sizeof(startup) };
    PROCESS_INFORMATION child = { 0 };
    UNREFERENCED_PARAMETER(instance);
    UNREFERENCED_PARAMETER(previous);
    UNREFERENCED_PARAMETER(show);

    DWORD length = GetModuleFileNameW(NULL, root, ARRAYSIZE(root));
    if (length == 0 || length >= ARRAYSIZE(root))
        return startup_error(L"无法读取程序目录。");
    while (length && root[length - 1] != L'\\')
        --length;
    if (length == 0)
        return startup_error(L"无法读取程序目录。");
    root[length] = L'\0';

    const wchar_t *mode = lstrcmpW(arguments, L"--tray") == 0 ? L" --tray" : L"";
    if (FAILED(StringCchPrintfW(interpreter, ARRAYSIZE(interpreter), L"%lsruntime\\AutoHotkey64.exe", root)) ||
        FAILED(StringCchPrintfW(command, ARRAYSIZE(command), L"\"%ls\" /script \"%lsapp\\ui\\Main.ahk\"%ls", interpreter, root, mode)))
        return startup_error(L"程序目录过长，请移动到路径较短的目录。");

    if (!CreateProcessW(interpreter, command, NULL, NULL, FALSE, 0, NULL, root, &startup, &child))
        return startup_error(L"无法启动包内 AutoHotkey，请完整解压后重试。");
    CloseHandle(child.hThread);
    CloseHandle(child.hProcess);
    return 0;
}
