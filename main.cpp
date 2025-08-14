#include <Windows.h>                     // Windows API 核心头文件
#include <shellapi.h>                    // Shell_NotifyIcon 等托盘相关 API
#include "resource.h"                    // 资源头文件（包含 IDI_ICON1 等）

#define WM_TRAYICON   (WM_USER + 1)       // 自定义托盘消息 ID
#define TRAY_ID       1                   // 托盘图标唯一 ID
#define MENU_EXIT     1001                // 菜单命令 ID：退出

HWND           g_hWnd = NULL;             // 隐藏窗口句柄（消息循环用）
HMENU          g_hMenu = NULL;            // 右键菜单句柄
HHOOK          g_mouseHook = NULL;        // 鼠标钩子句柄
NOTIFYICONDATA g_nid = {};                 // 托盘图标数据结构

// 发送 Ctrl+Win+Left 组合键（扩展键标志）实现向左切换虚拟桌面
void SwitchDesktopLeft() {
    INPUT inputs[6] = {};                 // 最多 6 个输入事件
    int i = 0;                             // 当前事件下标

    // 按下 Ctrl
    inputs[i].type = INPUT_KEYBOARD;
    inputs[i].ki.wVk = VK_CONTROL;
    i++;

    // 按下左 Win
    inputs[i].type = INPUT_KEYBOARD;
    inputs[i].ki.wVk = VK_LWIN;
    i++;

    // 按下 Left（扩展键）
    inputs[i].type = INPUT_KEYBOARD;
    inputs[i].ki.wVk = VK_LEFT;
    inputs[i].ki.dwFlags = KEYEVENTF_EXTENDEDKEY;
    i++;

    // 抬起 Left
    inputs[i].type = INPUT_KEYBOARD;
    inputs[i].ki.wVk = VK_LEFT;
    inputs[i].ki.dwFlags = KEYEVENTF_KEYUP | KEYEVENTF_EXTENDEDKEY;
    i++;

    // 抬起左 Win
    inputs[i].type = INPUT_KEYBOARD;
    inputs[i].ki.wVk = VK_LWIN;
    inputs[i].ki.dwFlags = KEYEVENTF_KEYUP;
    i++;

    // 抬起 Ctrl
    inputs[i].type = INPUT_KEYBOARD;
    inputs[i].ki.wVk = VK_CONTROL;
    inputs[i].ki.dwFlags = KEYEVENTF_KEYUP;
    i++;

    // 一次性发送
    SendInput(i, inputs, sizeof(INPUT));
}

// 鼠标钩子回调：捕获中键点击
LRESULT CALLBACK LowLevelMouseProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode >= 0 && wParam == WM_MBUTTONDOWN) { // 中键按下
        SwitchDesktopLeft();                     // 调用切换函数
    }
    return CallNextHookEx(g_mouseHook, nCode, wParam, lParam); // 传递给下一个钩子
}

// 创建托盘图标
void CreateTrayIcon() {
    g_nid.cbSize = sizeof(NOTIFYICONDATA);
    g_nid.hWnd = g_hWnd;
    g_nid.uID = TRAY_ID;
    g_nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    g_nid.uCallbackMessage = WM_TRAYICON;
    g_nid.hIcon = (HICON)LoadImage(
        GetModuleHandle(NULL),
        MAKEINTRESOURCE(IDI_ICON1),
        IMAGE_ICON, 16, 16, LR_DEFAULTCOLOR | LR_SHARED); // 共享图标句柄
    wcscpy_s(g_nid.szTip, 128, L"MiddleSwitchCpp");

    Shell_NotifyIcon(NIM_DELETE, &g_nid);       // 删除旧图标
    Shell_NotifyIcon(NIM_ADD, &g_nid);          // 添加托盘
    g_nid.uVersion = NOTIFYICON_VERSION_4;      // 托盘协议版本
    Shell_NotifyIcon(NIM_SETVERSION, &g_nid);   // 设置版本
}

// 删除托盘图标
void RemoveTrayIcon() {
    Shell_NotifyIcon(NIM_DELETE, &g_nid);
}

// 创建右键菜单
void CreateContextMenu() {
    if (g_hMenu) { DestroyMenu(g_hMenu); g_hMenu = NULL; } // 释放旧菜单
    g_hMenu = CreatePopupMenu();                          // 新建菜单
    AppendMenu(g_hMenu, MF_STRING, MENU_EXIT, L"退出");   // 添加退出项
}

// 窗口过程：处理托盘/菜单消息
LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    if (msg == WM_TRAYICON) {                              // 托盘回调
        if (lParam == WM_RBUTTONUP) {                      // 右键抬起
            POINT pt; GetCursorPos(&pt);                   // 鼠标位置
            SetForegroundWindow(hwnd);                     // 确保菜单可用
            int cmd = TrackPopupMenu(
                g_hMenu, TPM_RETURNCMD | TPM_RIGHTBUTTON,
                pt.x, pt.y, 0, hwnd, NULL);
            PostMessage(hwnd, WM_NULL, 0, 0);               // 确保菜单关闭
            if (cmd == MENU_EXIT) {                         // 菜单退出
                RemoveTrayIcon();                           // 删托盘
                if (g_mouseHook) { UnhookWindowsHookEx(g_mouseHook); g_mouseHook = NULL; } // 卸钩子
                if (g_hMenu) { DestroyMenu(g_hMenu); g_hMenu = NULL; }                     // 释放菜单
                PostQuitMessage(0);                        // 退出消息循环
            }
        }
        return 0;
    }
    else if (msg == WM_COMMAND) {                          // 菜单命令
        if (LOWORD(wParam) == MENU_EXIT) {
            RemoveTrayIcon();
            if (g_mouseHook) { UnhookWindowsHookEx(g_mouseHook); g_mouseHook = NULL; }
            if (g_hMenu) { DestroyMenu(g_hMenu); g_hMenu = NULL; }
            PostQuitMessage(0);
            return 0;
        }
    }
    else if (msg == WM_DESTROY) {                          // 窗口销毁
        RemoveTrayIcon();
        if (g_mouseHook) { UnhookWindowsHookEx(g_mouseHook); g_mouseHook = NULL; }
        if (g_hMenu) { DestroyMenu(g_hMenu); g_hMenu = NULL; }
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hwnd, msg, wParam, lParam);       // 默认处理
}

// 程序入口（Windows 子系统）
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE, LPSTR, int) {
    const wchar_t kClassName[] = L"MiddleSwitchTrayClass"; // 类名

    WNDCLASS wc = {};
    wc.lpfnWndProc = WndProc;                              // 窗口过程
    wc.hInstance = hInstance;                              // 实例
    wc.lpszClassName = kClassName;                         // 类名
    RegisterClass(&wc);                                    // 注册类

    g_hWnd = CreateWindow(
        kClassName, L"", WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        CW_USEDEFAULT, CW_USEDEFAULT,
        NULL, NULL, hInstance, NULL);
    ShowWindow(g_hWnd, SW_HIDE);                           // 隐藏窗口

    CreateTrayIcon();                                      // 创建托盘
    CreateContextMenu();                                   // 创建菜单

    g_mouseHook = SetWindowsHookEx(                        // 安装鼠标钩子
        WH_MOUSE_LL, LowLevelMouseProc,
        GetModuleHandle(NULL), 0);

    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0)) {                 // 消息循环
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return 0;                                              // 程序退出
}
