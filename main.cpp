#include <windows.h>
#include <shellapi.h>
#include <thread>

#define WM_TRAYICON   (WM_USER + 1)
#define WM_MMB_ACTION (WM_USER + 100)
#define TRAY_ID       1
#define MENU_EXIT     1001

HWND g_hWnd = NULL;
HHOOK g_mouseHook = NULL;
HINSTANCE g_hInst = NULL;

// 切换到左边虚拟桌面
void SwitchDesktopLeft() {
    INPUT in[6] = {};
    int i = 0;
    in[i].type = INPUT_KEYBOARD; in[i].ki.wVk = VK_LWIN; i++;
    in[i].type = INPUT_KEYBOARD; in[i].ki.wVk = VK_CONTROL; i++;
    in[i].type = INPUT_KEYBOARD; in[i].ki.wVk = VK_LEFT;
    in[i].ki.dwFlags = KEYEVENTF_EXTENDEDKEY; i++;
    in[i].type = INPUT_KEYBOARD; in[i].ki.wVk = VK_LEFT;
    in[i].ki.dwFlags = KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP; i++;
    in[i].type = INPUT_KEYBOARD; in[i].ki.wVk = VK_CONTROL;
    in[i].ki.dwFlags = KEYEVENTF_KEYUP; i++;
    in[i].type = INPUT_KEYBOARD; in[i].ki.wVk = VK_LWIN;
    in[i].ki.dwFlags = KEYEVENTF_KEYUP; i++;
    SendInput(i, in, sizeof(INPUT));
}

// 鼠标钩子线程
LRESULT CALLBACK LowLevelMouseProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode >= 0 && wParam == WM_MBUTTONDOWN) {
        if (g_hWnd) {
            PostMessage(g_hWnd, WM_MMB_ACTION, 0, 0);
        }
    }
    return CallNextHookEx(NULL, nCode, wParam, lParam);
}
void MouseHookThread() {
    g_mouseHook = SetWindowsHookEx(WH_MOUSE_LL, LowLevelMouseProc, GetModuleHandle(NULL), 0);
    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
    if (g_mouseHook) { UnhookWindowsHookEx(g_mouseHook); g_mouseHook = NULL; }
}

// 托盘图标
void CreateTrayIcon(HWND hwnd) {
    NOTIFYICONDATA nid{};
    nid.cbSize = sizeof(nid);
    nid.hWnd = hwnd;
    nid.uID = TRAY_ID;
    nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    nid.uCallbackMessage = WM_TRAYICON;

    // 使用VS默认的应用程序图标
    nid.hIcon = LoadIcon(NULL, IDI_APPLICATION);

    wcscpy_s(nid.szTip, L"中键切左虚拟桌面");
    Shell_NotifyIcon(NIM_ADD, &nid);
}
void RemoveTrayIcon(HWND hwnd) {
    NOTIFYICONDATA nid{};
    nid.cbSize = sizeof(nid);
    nid.hWnd = hwnd;
    nid.uID = TRAY_ID;
    Shell_NotifyIcon(NIM_DELETE, &nid);
}
void ShowContextMenu(HWND hwnd) {
    HMENU hMenu = CreatePopupMenu();
    AppendMenu(hMenu, MF_STRING, MENU_EXIT, L"退出");
    POINT pt; GetCursorPos(&pt);
    SetForegroundWindow(hwnd);
    TrackPopupMenu(hMenu, TPM_RIGHTBUTTON, pt.x, pt.y, 0, hwnd, NULL);
    DestroyMenu(hMenu);
}

// 主窗口过程
LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_TRAYICON:
        if (wParam == TRAY_ID && LOWORD(lParam) == WM_RBUTTONUP) {
            ShowContextMenu(hwnd);
        }
        break;
    case WM_COMMAND:
        if (LOWORD(wParam) == MENU_EXIT) {
            RemoveTrayIcon(hwnd);
            PostQuitMessage(0);
        }
        break;
    case WM_MMB_ACTION:
        SwitchDesktopLeft();
        break;
    case WM_DESTROY:
        RemoveTrayIcon(hwnd);
        PostQuitMessage(0);
        break;
    }
    return DefWindowProc(hwnd, msg, wParam, lParam);
}

// 程序入口
int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE, LPWSTR, int) {
    g_hInst = hInstance;
    const wchar_t CLASS_NAME[] = L"TrayMainWnd";
    WNDCLASS wc{};
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = CLASS_NAME;
    RegisterClass(&wc);

    g_hWnd = CreateWindow(CLASS_NAME, L"", WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
        NULL, NULL, hInstance, NULL);

    CreateTrayIcon(g_hWnd);
    std::thread(MouseHookThread).detach();

    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
    return 0;
}
