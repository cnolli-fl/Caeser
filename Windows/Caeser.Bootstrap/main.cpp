// Small, self-contained Windows installer downloader. Payload URL, size and
// SHA-256 are pinned at build time, not supplied by a mutable remote manifest.
#include <windows.h>
#include <commctrl.h>
#include <winhttp.h>
#include <bcrypt.h>
#include <shlobj.h>
#include <shellapi.h>
#include <strsafe.h>
#include <string>
#include <vector>
#include <cwchar>
#include "payload.h"

struct Failure { DWORD code; std::wstring message; };
static void Require(bool okay, const wchar_t* message) {
    if (!okay) throw Failure{GetLastError() ? GetLastError() : ERROR_INVALID_DATA, message};
}
struct Internet {
    HINTERNET value;
    explicit Internet(HINTERNET h) : value(h) {}
    ~Internet() { if (value) WinHttpCloseHandle(value); }
    Internet(const Internet&) = delete;
    operator HINTERNET() const { return value; }
};
struct File {
    HANDLE value = INVALID_HANDLE_VALUE;
    ~File() { close(); }
    void close() { if (value != INVALID_HANDLE_VALUE) { CloseHandle(value); value = INVALID_HANDLE_VALUE; } }
};
struct State {
    volatile LONG cancel = 0, done = 0, progress = 0, phase = 0;
    DWORD result = 0;
    HANDLE thread = nullptr;
    std::wstring message, url = PAYLOAD_URL, directory, file, installDirectory;
    bool test = false, downloadOnly = false, autoCancel = false;
};
static LONG Read(volatile LONG& value) { return InterlockedCompareExchange(&value, 0, 0); }
static void CheckCancel(State& state) {
    if (Read(state.cancel)) throw Failure{ERROR_CANCELLED, L"Download cancelado. Nada foi instalado."};
}
static bool Trusted(const std::wstring& url, bool test) {
    URL_COMPONENTS parts = {}; parts.dwStructSize = sizeof(parts);
    parts.dwHostNameLength = parts.dwUserNameLength = parts.dwPasswordLength = static_cast<DWORD>(-1);
    if (url.size() > 8192 || !WinHttpCrackUrl(url.c_str(), 0, 0, &parts) || parts.dwUserNameLength || parts.dwPasswordLength) return false;
    std::wstring host(parts.lpszHostName, parts.dwHostNameLength);
#ifdef CAESER_BOOTSTRAP_TEST
    if (test && parts.nScheme == INTERNET_SCHEME_HTTP && host == L"127.0.0.1") return true;
#else
    (void)test;
#endif
    return parts.nScheme == INTERNET_SCHEME_HTTPS && parts.nPort == 443 &&
        (!_wcsicmp(host.c_str(), L"github.com") || !_wcsicmp(host.c_str(), L"release-assets.githubusercontent.com") || !_wcsicmp(host.c_str(), L"objects.githubusercontent.com"));
}
static void VerifyFile(HANDLE file, State& state) {
    LARGE_INTEGER length = {}, origin = {};
    Require(GetFileSizeEx(file, &length) && static_cast<ULONGLONG>(length.QuadPart) == PAYLOAD_BYTES, L"O tamanho do instalador não corresponde à versão publicada.");
    Require(SetFilePointerEx(file, origin, nullptr, FILE_BEGIN) != FALSE, L"Não consegui conferir o instalador.");
    BCRYPT_ALG_HANDLE algorithm = nullptr; BCRYPT_HASH_HANDLE hash = nullptr;
    Require(BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0) >= 0, L"Não consegui iniciar a conferência de integridade.");
    try {
        DWORD objectSize = 0, returned = 0;
        Require(BCryptGetProperty(algorithm, BCRYPT_OBJECT_LENGTH, reinterpret_cast<PUCHAR>(&objectSize), sizeof(objectSize), &returned, 0) >= 0, L"Falha no verificador SHA-256.");
        std::vector<BYTE> object(objectSize), buffer(1024 * 1024);
        Require(BCryptCreateHash(algorithm, &hash, object.data(), objectSize, nullptr, 0, 0) >= 0, L"Falha no verificador SHA-256.");
        DWORD count = 0;
        for (;;) {
            CheckCancel(state);
            Require(ReadFile(file, buffer.data(), static_cast<DWORD>(buffer.size()), &count, nullptr) != FALSE, L"Não consegui ler o instalador.");
            if (!count) break;
            Require(BCryptHashData(hash, buffer.data(), count, 0) >= 0, L"Falha na conferência do instalador.");
        }
        BYTE digest[32] = {};
        Require(BCryptFinishHash(hash, digest, sizeof(digest), 0) >= 0, L"Falha na conferência do instalador.");
        wchar_t hexadecimal[65] = {};
        for (size_t index = 0; index < 32; ++index) StringCchPrintfW(hexadecimal + index * 2, 65 - index * 2, L"%02x", static_cast<unsigned>(digest[index]));
        if (_wcsicmp(hexadecimal, PAYLOAD_SHA256)) throw Failure{ERROR_CRC, L"O arquivo recebido está incompleto ou alterado. Nada foi instalado. Tente novamente ou use o instalador completo da release."};
    } catch (...) { if (hash) BCryptDestroyHash(hash); BCryptCloseAlgorithmProvider(algorithm, 0); throw; }
    BCryptDestroyHash(hash); BCryptCloseAlgorithmProvider(algorithm, 0);
}
static void MakeCache(State& state) {
    PWSTR local = nullptr;
    Require(SUCCEEDED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &local)), L"Não consegui localizar sua pasta temporária.");
    std::wstring root(local); CoTaskMemFree(local);
    root += L"\\Caeser"; Require(CreateDirectoryW(root.c_str(), nullptr) || GetLastError() == ERROR_ALREADY_EXISTS, L"Não consegui criar a pasta do instalador.");
    root += L"\\InstallerCache"; Require(CreateDirectoryW(root.c_str(), nullptr) || GetLastError() == ERROR_ALREADY_EXISTS, L"Não consegui criar a pasta do instalador.");
    GUID id = {}; wchar_t name[64] = {};
    Require(SUCCEEDED(CoCreateGuid(&id)) && StringFromGUID2(id, name, 64), L"Não consegui preparar o download.");
    state.directory = root + L"\\" + name;
    Require(CreateDirectoryW(state.directory.c_str(), nullptr) != FALSE, L"Não consegui criar uma pasta exclusiva para o download.");
    state.file = state.directory + L"\\Caeser-" PAYLOAD_VERSION L"-Setup.exe";
}
static void MarkInternet(const State& state) {
#ifdef CAESER_BOOTSTRAP_TEST
    // A locally compiled installer served over loopback is not an Internet
    // download. This fixture-only build is never shipped. Production always
    // writes ZoneId=3 and launches through ShellExecute with normal OS checks.
    if (state.test && !state.downloadOnly) return;
#endif
    File stream;
    stream.value = CreateFileW((state.file + L":Zone.Identifier").c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
    Require(stream.value != INVALID_HANDLE_VALUE, L"Não consegui preservar os controles de segurança do Windows.");
    const char marker[] = "[ZoneTransfer]\r\nZoneId=3\r\nHostUrl=https://github.com/cnolli-fl/Caeser\r\n";
    DWORD written = 0;
    Require(WriteFile(stream.value, marker, sizeof(marker) - 1, &written, nullptr) && written == sizeof(marker) - 1, L"Não consegui preservar os controles de segurança do Windows.");
}
static void Download(State& state) {
    MakeCache(state);
    Internet session(WinHttpOpen(L"Caeser-Online-Installer/" PAYLOAD_VERSION, WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY, WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0));
    Require(session.value != nullptr, L"Não consegui iniciar a conexão. Verifique sua internet.");
    Require(WinHttpSetTimeouts(session, 10000, 15000, 15000, 15000) != FALSE, L"Não consegui configurar a conexão.");
    DWORD policy = WINHTTP_OPTION_REDIRECT_POLICY_NEVER;
    Require(WinHttpSetOption(session, WINHTTP_OPTION_REDIRECT_POLICY, &policy, sizeof(policy)) != FALSE, L"Não consegui proteger os redirecionamentos do download.");
    std::wstring url = state.url;
    ULONGLONG started = GetTickCount64();
    for (unsigned redirect = 0; redirect <= 5; ++redirect) {
        CheckCancel(state);
        if (!Trusted(url, state.test)) throw Failure{ERROR_ACCESS_DENIED, L"O download saiu dos servidores oficiais. Nada foi instalado."};
        URL_COMPONENTS parts = {}; parts.dwStructSize = sizeof(parts);
        parts.dwHostNameLength = parts.dwUrlPathLength = parts.dwExtraInfoLength = static_cast<DWORD>(-1);
        Require(WinHttpCrackUrl(url.c_str(), 0, 0, &parts) != FALSE, L"Endereço de download inválido.");
        std::wstring host(parts.lpszHostName, parts.dwHostNameLength), path(parts.lpszUrlPath, parts.dwUrlPathLength);
        if (parts.dwExtraInfoLength) path.append(parts.lpszExtraInfo, parts.dwExtraInfoLength);
        Internet connection(WinHttpConnect(session, host.c_str(), parts.nPort, 0));
        Require(connection.value != nullptr, L"Não consegui conectar ao GitHub. Verifique sua internet.");
        Internet request(WinHttpOpenRequest(connection, L"GET", path.c_str(), nullptr, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, parts.nScheme == INTERNET_SCHEME_HTTPS ? WINHTTP_FLAG_SECURE : 0));
        Require(request.value != nullptr, L"Não consegui preparar o download.");
        Require(WinHttpSendRequest(request, WINHTTP_NO_ADDITIONAL_HEADERS, 0, WINHTTP_NO_REQUEST_DATA, 0, 0, 0) && WinHttpReceiveResponse(request, nullptr), L"A conexão falhou. Verifique a internet e tente novamente.");
        DWORD status = 0, size = sizeof(status);
        Require(WinHttpQueryHeaders(request, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER, WINHTTP_HEADER_NAME_BY_INDEX, &status, &size, WINHTTP_NO_HEADER_INDEX) != FALSE, L"O servidor não informou o resultado do download.");
        if (status == 301 || status == 302 || status == 303 || status == 307 || status == 308) {
            wchar_t location[8192] = {}; size = sizeof(location);
            Require(WinHttpQueryHeaders(request, WINHTTP_QUERY_LOCATION, WINHTTP_HEADER_NAME_BY_INDEX, location, &size, WINHTTP_NO_HEADER_INDEX) != FALSE, L"Redirecionamento inválido.");
            url = location; continue;
        }
        if (status != 200) throw Failure{ERROR_FILE_NOT_FOUND, L"Não consegui baixar esta versão. Tente novamente ou baixe o instalador completo na release oficial."};
        DWORD contentLength = 0; size = sizeof(contentLength);
        if (WinHttpQueryHeaders(request, WINHTTP_QUERY_CONTENT_LENGTH | WINHTTP_QUERY_FLAG_NUMBER, WINHTTP_HEADER_NAME_BY_INDEX, &contentLength, &size, WINHTTP_NO_HEADER_INDEX) && contentLength != PAYLOAD_BYTES)
            throw Failure{ERROR_INVALID_DATA, L"O tamanho informado pelo servidor é diferente do esperado. Nada foi instalado."};
        File output;
        output.value = CreateFileW(state.file.c_str(), GENERIC_WRITE | GENERIC_READ, FILE_SHARE_READ, nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
        Require(output.value != INVALID_HANDLE_VALUE, L"Não consegui salvar o instalador. Confira o espaço disponível no disco.");
        BYTE buffer[65536]; ULONGLONG received = 0; DWORD count = 0;
        for (;;) {
            CheckCancel(state);
            if (GetTickCount64() - started > 15 * 60 * 1000) throw Failure{ERROR_TIMEOUT, L"O download demorou demais. Tente novamente com uma conexão melhor."};
            Require(WinHttpReadData(request, buffer, sizeof(buffer), &count) != FALSE, L"A transferência foi interrompida. Nada foi instalado. Tente novamente.");
            if (!count) break;
            received += count;
            if (received > PAYLOAD_BYTES) throw Failure{ERROR_INVALID_DATA, L"O arquivo recebido é maior que o esperado. Nada foi instalado."};
            DWORD written = 0;
            Require(WriteFile(output.value, buffer, count, &written, nullptr) && written == count, L"Não consegui salvar o download. Confira o espaço em disco.");
            InterlockedExchange(&state.progress, static_cast<LONG>(received * 1000 / PAYLOAD_BYTES));
        }
        if (received != PAYLOAD_BYTES) throw Failure{ERROR_INVALID_DATA, L"O download ficou incompleto. Nada foi instalado. Tente novamente."};
        InterlockedExchange(&state.phase, 1); VerifyFile(output.value, state);
        output.close(); MarkInternet(state); return;
    }
    throw Failure{ERROR_WINHTTP_REDIRECT_FAILED, L"Muitos redirecionamentos no download. Nada foi instalado."};
}
static DWORD WINAPI Worker(void* pointer) {
    State& state = *static_cast<State*>(pointer);
    try { Download(state); }
    catch (const Failure& failure) { state.result = failure.code; state.message = failure.message; }
    catch (...) { state.result = ERROR_GEN_FAILURE; state.message = L"Não consegui concluir o download. Nada foi instalado."; }
    InterlockedExchange(&state.done, 1); return 0;
}
static HRESULT CALLBACK Progress(HWND window, UINT notification, WPARAM button, LPARAM, LONG_PTR data) {
    State& state = *reinterpret_cast<State*>(data);
    if (notification == TDN_CREATED) {
        SendMessageW(window, TDM_SET_PROGRESS_BAR_RANGE, 0, MAKELPARAM(0, 1000));
        state.thread = CreateThread(nullptr, 0, Worker, &state, 0, nullptr);
        if (!state.thread) { state.result = GetLastError(); state.message = L"Não consegui iniciar o download."; InterlockedExchange(&state.done, 1); }
    } else if (notification == TDN_BUTTON_CLICKED && button == IDCANCEL && !Read(state.done)) {
        InterlockedExchange(&state.cancel, 1);
        SendMessageW(window, TDM_ENABLE_BUTTON, IDCANCEL, FALSE);
        return S_FALSE;
    } else if (notification == TDN_TIMER) {
#ifdef CAESER_BOOTSTRAP_TEST
        if (state.autoCancel && button > 350 && !Read(state.cancel)) SendMessageW(window, TDM_CLICK_BUTTON, IDCANCEL, 0);
#endif
        wchar_t text[256] = {}; LONG value = Read(state.progress);
        if (Read(state.cancel)) StringCchCopyW(text, 256, L"Cancelando o download…");
        else if (Read(state.phase)) StringCchCopyW(text, 256, L"Conferindo a integridade do instalador…");
        else StringCchPrintfW(text, 256, L"Baixando o Caeser · %ld%%\n%.1f de %.1f MB", value / 10, static_cast<double>(PAYLOAD_BYTES) * value / 1000 / 1000000, static_cast<double>(PAYLOAD_BYTES) / 1000000);
        SendMessageW(window, TDM_SET_ELEMENT_TEXT, TDE_CONTENT, reinterpret_cast<LPARAM>(text));
        SendMessageW(window, TDM_SET_PROGRESS_BAR_POS, value, 0);
        if (Read(state.done)) { SendMessageW(window, TDM_ENABLE_BUTTON, IDCANCEL, TRUE); SendMessageW(window, TDM_CLICK_BUTTON, IDCANCEL, 0); }
    }
    return S_OK;
}
static void Cleanup(const State& state) {
    if (!state.file.empty()) DeleteFileW(state.file.c_str());
    if (!state.directory.empty()) RemoveDirectoryW(state.directory.c_str());
}
int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR arguments, int) {
    State state;
    if (!wcscmp(arguments, L"--self-test"))
        return Trusted(PAYLOAD_URL, false) && !Trusted(L"https://github.com.evil.example/a", false) && !Trusted(L"http://github.com/a", false) && !Trusted(L"https://user@github.com/a", false) && wcslen(PAYLOAD_SHA256) == 64 && PAYLOAD_BYTES > 0 && PAYLOAD_BYTES <= 512ULL * 1024 * 1024 ? 0 : 1;
#ifdef CAESER_BOOTSTRAP_TEST
    int argc = 0; LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (argv && argc >= 3 && (!wcscmp(argv[1], L"--test-download") || !wcscmp(argv[1], L"--test-cancel") || !wcscmp(argv[1], L"--test-install"))) {
        state.test = true; state.url = argv[2]; state.autoCancel = !wcscmp(argv[1], L"--test-cancel");
        if (state.url.rfind(L"http://127.0.0.1:", 0) != 0) { LocalFree(argv); return ERROR_INVALID_PARAMETER; }
        state.downloadOnly = wcscmp(argv[1], L"--test-install") != 0;
        if (!state.downloadOnly && argc == 4) state.installDirectory = argv[3];
        else if (!state.downloadOnly) { LocalFree(argv); return ERROR_INVALID_PARAMETER; }
    }
    if (argv) LocalFree(argv);
#endif
    if (*arguments && !state.test) return ERROR_INVALID_PARAMETER;
    HRESULT initialized = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(initialized)) return ERROR_GEN_FAILURE;
    INITCOMMONCONTROLSEX controls = {sizeof(controls), ICC_STANDARD_CLASSES | ICC_PROGRESS_CLASS}; InitCommonControlsEx(&controls);
    HICON icon = LoadIconW(instance, MAKEINTRESOURCEW(1));
    if (!state.test) {
        wchar_t content[512] = {};
        StringCchPrintfW(content, 512, L"O aplicativo e suas ferramentas (%.1f MB) serão baixados dos servidores oficiais do GitHub.\n\nÉ necessário acesso à internet. Você pode cancelar o download. A instalação é para seu usuário e preserva seus dados. Os avisos normais de segurança do Windows continuam ativos.", static_cast<double>(PAYLOAD_BYTES) / 1000000);
        TASKDIALOG_BUTTON buttons[] = {{100, L"Baixar e instalar"}, {IDCANCEL, L"Cancelar"}};
        TASKDIALOGCONFIG welcome = {}; welcome.cbSize = sizeof(welcome); welcome.hInstance = instance;
        welcome.dwFlags = TDF_USE_HICON_MAIN | TDF_ALLOW_DIALOG_CANCELLATION;
        welcome.hMainIcon = icon; welcome.pszWindowTitle = L"Instalador online do Caeser";
        welcome.pszMainInstruction = L"Instalar Caeser " PAYLOAD_VERSION; welcome.pszContent = content;
        welcome.pButtons = buttons; welcome.cButtons = 2; welcome.nDefaultButton = 100; welcome.cxWidth = 320;
        int selected = IDCANCEL;
        if (FAILED(TaskDialogIndirect(&welcome, &selected, nullptr, nullptr)) || selected != 100) { CoUninitialize(); return ERROR_CANCELLED; }
    }
    TASKDIALOG_BUTTON cancel[] = {{IDCANCEL, L"Cancelar"}};
    TASKDIALOGCONFIG dialog = {}; dialog.cbSize = sizeof(dialog); dialog.hInstance = instance;
    dialog.dwFlags = TDF_USE_HICON_MAIN | TDF_ALLOW_DIALOG_CANCELLATION | TDF_SHOW_PROGRESS_BAR | TDF_CALLBACK_TIMER | TDF_CAN_BE_MINIMIZED;
    dialog.hMainIcon = icon; dialog.pszWindowTitle = L"Instalador online do Caeser";
    dialog.pszMainInstruction = L"Preparando Caeser " PAYLOAD_VERSION; dialog.pszContent = L"Conectando ao GitHub…";
    dialog.pButtons = cancel; dialog.cButtons = 1; dialog.pfCallback = Progress; dialog.lpCallbackData = reinterpret_cast<LONG_PTR>(&state); dialog.cxWidth = 300;
    HRESULT shown = TaskDialogIndirect(&dialog, nullptr, nullptr, nullptr);
    if (FAILED(shown)) { InterlockedExchange(&state.cancel, 1); state.result = ERROR_GEN_FAILURE; state.message = L"Não consegui abrir a janela de progresso."; }
    if (state.thread) { WaitForSingleObject(state.thread, INFINITE); CloseHandle(state.thread); }
    if (SUCCEEDED(shown) && Read(state.cancel)) state.result = ERROR_CANCELLED;
    if (!state.result && !state.downloadOnly) {
        try {
            File lock; lock.value = CreateFileW(state.file.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
            Require(lock.value != INVALID_HANDLE_VALUE, L"Não consegui abrir o instalador verificado."); VerifyFile(lock.value, state);
            std::wstring parameters = L"/SILENT /SP- /NORESTART /NOFORCECLOSEAPPLICATIONS /CAESERUPDATE=1";
#ifdef CAESER_BOOTSTRAP_TEST
            if (state.test && !state.installDirectory.empty()) parameters += L" /DIR=\"" + state.installDirectory + L"\"";
#endif
            SHELLEXECUTEINFOW execute = {}; execute.cbSize = sizeof(execute); execute.fMask = SEE_MASK_NOCLOSEPROCESS;
            execute.lpVerb = L"open"; execute.lpFile = state.file.c_str(); execute.lpParameters = parameters.c_str(); execute.nShow = SW_SHOWNORMAL;
            Require(ShellExecuteExW(&execute) != FALSE, L"Não consegui iniciar a instalação. Se o Windows pedir confirmação, confira o arquivo e autorize somente se confiar no projeto.");
            lock.close();
            if (execute.hProcess) { WaitForSingleObject(execute.hProcess, INFINITE); GetExitCodeProcess(execute.hProcess, &state.result); CloseHandle(execute.hProcess); }
            else throw Failure{ERROR_GEN_FAILURE, L"Não consegui acompanhar a instalação. Abra o Caeser pelo menu Iniciar."};
        } catch (const Failure& failure) { state.result = failure.code; state.message = failure.message; }
        catch (...) { state.result = ERROR_GEN_FAILURE; state.message = L"Não consegui concluir a instalação."; }
    }
    Cleanup(state);
    if (state.result && state.result != ERROR_CANCELLED && !state.test) MessageBoxW(nullptr,
        state.message.empty() ? L"A instalação não foi concluída. Você pode tentar novamente ou usar o instalador completo na release oficial." : state.message.c_str(), L"Caeser", MB_OK | MB_ICONERROR);
    CoUninitialize(); return static_cast<int>(state.result);
}
