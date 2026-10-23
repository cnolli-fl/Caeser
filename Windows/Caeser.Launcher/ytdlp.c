#include <windows.h>
#include <strsafe.h>
#include <stdlib.h>
#include <wchar.h>

int wmain(void)
{
    wchar_t executable[32768];
    DWORD length = GetModuleFileNameW(NULL, executable, ARRAYSIZE(executable));
    if (!length || length >= ARRAYSIZE(executable)) return 1;
    wchar_t *separator = wcsrchr(executable, L'\\');
    if (!separator) return 1;
    separator[1] = L'\0';
    if (FAILED(StringCchCatW(executable, ARRAYSIZE(executable), L"spotdl.exe"))) return 1;
    const wchar_t *arguments = GetCommandLineW();
    if (*arguments == L'"') { ++arguments; while (*arguments && *arguments != L'"') ++arguments; if (*arguments) ++arguments; }
    else while (*arguments && *arguments != L' ' && *arguments != L'\t') ++arguments;
    while (*arguments == L' ' || *arguments == L'\t') ++arguments;
    size_t capacity = wcslen(executable) + wcslen(arguments) + 32;
    wchar_t *command = (wchar_t *)malloc(capacity * sizeof(wchar_t));
    if (!command) return 1;
    if (FAILED(StringCchPrintfW(command, capacity, L"\"%s\" --caeser-ytdlp %s", executable, arguments))) { free(command); return 1; }
    STARTUPINFOW startup = {0}; PROCESS_INFORMATION child = {0};
    startup.cb = sizeof(startup); startup.dwFlags = STARTF_USESTDHANDLES;
    startup.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
    startup.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
    startup.hStdError = GetStdHandle(STD_ERROR_HANDLE);
    BOOL started = CreateProcessW(executable, command, NULL, NULL, TRUE, CREATE_NO_WINDOW, NULL, NULL, &startup, &child);
    free(command);
    if (!started) return 1;
    CloseHandle(child.hThread); WaitForSingleObject(child.hProcess, INFINITE);
    DWORD result = 1; GetExitCodeProcess(child.hProcess, &result); CloseHandle(child.hProcess);
    return (int)result;
}
