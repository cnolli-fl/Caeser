#include <windows.h>
#include <strsafe.h>
#include <stdlib.h>
#include <wchar.h>

// Tiny native entry point. All WinUI/.NET files stay together in Aplicativo,
// with their original loader paths; no DLL is relocated independently.
int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, PWSTR arguments, int show)
{
    (void)instance; (void)previous;
    wchar_t application[32768];
    DWORD length = GetModuleFileNameW(NULL, application, ARRAYSIZE(application));
    if (!length || length >= ARRAYSIZE(application)) return 1;
    wchar_t *separator = wcsrchr(application, L'\\');
    if (!separator) return 1;
    separator[1] = L'\0';
    if (FAILED(StringCchCatW(application, ARRAYSIZE(application), L"Aplicativo\\Caeser.exe"))) return 1;
    size_t capacity = wcslen(application) + wcslen(arguments) + 4;
    wchar_t *command = (wchar_t *)malloc(capacity * sizeof(wchar_t));
    if (!command) return 1;
    if (FAILED(StringCchPrintfW(command, capacity, L"\"%s\" %s", application, arguments))) {
        free(command); return 1;
    }
    STARTUPINFOW startup = { 0 };
    PROCESS_INFORMATION process = { 0 };
    startup.cb = sizeof(startup);
    startup.dwFlags = STARTF_USESHOWWINDOW;
    startup.wShowWindow = (WORD)show;
    // An explicit executable path prevents PATH lookup and command injection.
    BOOL started = CreateProcessW(application, command, NULL, NULL, FALSE, 0, NULL, NULL, &startup, &process);
    DWORD error = GetLastError();
    free(command);
    if (!started) {
        wchar_t message[512];
        StringCchPrintfW(message, ARRAYSIZE(message),
            L"N\x00e3o foi poss\x00edvel abrir o Caeser (erro %lu).\n\nExtraia o ZIP inteiro e mantenha a pasta Aplicativo ao lado de Caeser.exe.", error);
        MessageBoxW(NULL, message, L"Caeser", MB_OK | MB_ICONERROR);
        return 1;
    }
    CloseHandle(process.hThread);
    WaitForSingleObject(process.hProcess, INFINITE);
    DWORD result = 1;
    GetExitCodeProcess(process.hProcess, &result);
    CloseHandle(process.hProcess);
    return (int)result;
}
