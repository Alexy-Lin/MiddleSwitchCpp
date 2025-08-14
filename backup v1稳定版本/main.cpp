#include <Windows.h>                     // Windows API ����ͷ�ļ�
#include <shellapi.h>                    // Shell_NotifyIcon ��������� API
#include "resource.h"                    // ��Դͷ�ļ������� IDI_ICON1 �ȣ�

#define WM_TRAYICON   (WM_USER + 1)       // �Զ���������Ϣ ID
#define TRAY_ID       1                   // ����ͼ��Ψһ ID
#define MENU_EXIT     1001                // �˵����� ID���˳�

HWND           g_hWnd = NULL;             // ���ش��ھ������Ϣѭ���ã�
HMENU          g_hMenu = NULL;            // �Ҽ��˵����
HHOOK          g_mouseHook = NULL;        // ��깳�Ӿ��
NOTIFYICONDATA g_nid = {};                 // ����ͼ�����ݽṹ

// ���� Ctrl+Win+Left ��ϼ�����չ����־��ʵ�������л���������
void SwitchDesktopLeft() {
    INPUT inputs[6] = {};                 // ��� 6 �������¼�
    int i = 0;                             // ��ǰ�¼��±�

    // ���� Ctrl
    inputs[i].type = INPUT_KEYBOARD;
    inputs[i].ki.wVk = VK_CONTROL;
    i++;

    // ������ Win
    inputs[i].type = INPUT_KEYBOARD;
    inputs[i].ki.wVk = VK_LWIN;
    i++;

    // ���� Left����չ����
    inputs[i].type = INPUT_KEYBOARD;
    inputs[i].ki.wVk = VK_LEFT;
    inputs[i].ki.dwFlags = KEYEVENTF_EXTENDEDKEY;
    i++;

    // ̧�� Left
    inputs[i].type = INPUT_KEYBOARD;
    inputs[i].ki.wVk = VK_LEFT;
    inputs[i].ki.dwFlags = KEYEVENTF_KEYUP | KEYEVENTF_EXTENDEDKEY;
    i++;

    // ̧���� Win
    inputs[i].type = INPUT_KEYBOARD;
    inputs[i].ki.wVk = VK_LWIN;
    inputs[i].ki.dwFlags = KEYEVENTF_KEYUP;
    i++;

    // ̧�� Ctrl
    inputs[i].type = INPUT_KEYBOARD;
    inputs[i].ki.wVk = VK_CONTROL;
    inputs[i].ki.dwFlags = KEYEVENTF_KEYUP;
    i++;

    // һ���Է���
    SendInput(i, inputs, sizeof(INPUT));
}

// ��깳�ӻص��������м����
LRESULT CALLBACK LowLevelMouseProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode >= 0 && wParam == WM_MBUTTONDOWN) { // �м�����
        SwitchDesktopLeft();                     // �����л�����
    }
    return CallNextHookEx(g_mouseHook, nCode, wParam, lParam); // ���ݸ���һ������
}

// ��������ͼ��
void CreateTrayIcon() {
    g_nid.cbSize = sizeof(NOTIFYICONDATA);
    g_nid.hWnd = g_hWnd;
    g_nid.uID = TRAY_ID;
    g_nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    g_nid.uCallbackMessage = WM_TRAYICON;
    g_nid.hIcon = (HICON)LoadImage(
        GetModuleHandle(NULL),
        MAKEINTRESOURCE(IDI_ICON1),
        IMAGE_ICON, 16, 16, LR_DEFAULTCOLOR | LR_SHARED); // ����ͼ����
    wcscpy_s(g_nid.szTip, 128, L"MiddleSwitchCpp");

    Shell_NotifyIcon(NIM_DELETE, &g_nid);       // ɾ����ͼ��
    Shell_NotifyIcon(NIM_ADD, &g_nid);          // �������
    g_nid.uVersion = NOTIFYICON_VERSION_4;      // ����Э��汾
    Shell_NotifyIcon(NIM_SETVERSION, &g_nid);   // ���ð汾
}

// ɾ������ͼ��
void RemoveTrayIcon() {
    Shell_NotifyIcon(NIM_DELETE, &g_nid);
}

// �����Ҽ��˵�
void CreateContextMenu() {
    if (g_hMenu) { DestroyMenu(g_hMenu); g_hMenu = NULL; } // �ͷžɲ˵�
    g_hMenu = CreatePopupMenu();                          // �½��˵�
    AppendMenu(g_hMenu, MF_STRING, MENU_EXIT, L"�˳�");   // ����˳���
}

// ���ڹ��̣���������/�˵���Ϣ
LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    if (msg == WM_TRAYICON) {                              // ���̻ص�
        if (lParam == WM_RBUTTONUP) {                      // �Ҽ�̧��
            POINT pt; GetCursorPos(&pt);                   // ���λ��
            SetForegroundWindow(hwnd);                     // ȷ���˵�����
            int cmd = TrackPopupMenu(
                g_hMenu, TPM_RETURNCMD | TPM_RIGHTBUTTON,
                pt.x, pt.y, 0, hwnd, NULL);
            PostMessage(hwnd, WM_NULL, 0, 0);               // ȷ���˵��ر�
            if (cmd == MENU_EXIT) {                         // �˵��˳�
                RemoveTrayIcon();                           // ɾ����
                if (g_mouseHook) { UnhookWindowsHookEx(g_mouseHook); g_mouseHook = NULL; } // ж����
                if (g_hMenu) { DestroyMenu(g_hMenu); g_hMenu = NULL; }                     // �ͷŲ˵�
                PostQuitMessage(0);                        // �˳���Ϣѭ��
            }
        }
        return 0;
    }
    else if (msg == WM_COMMAND) {                          // �˵�����
        if (LOWORD(wParam) == MENU_EXIT) {
            RemoveTrayIcon();
            if (g_mouseHook) { UnhookWindowsHookEx(g_mouseHook); g_mouseHook = NULL; }
            if (g_hMenu) { DestroyMenu(g_hMenu); g_hMenu = NULL; }
            PostQuitMessage(0);
            return 0;
        }
    }
    else if (msg == WM_DESTROY) {                          // ��������
        RemoveTrayIcon();
        if (g_mouseHook) { UnhookWindowsHookEx(g_mouseHook); g_mouseHook = NULL; }
        if (g_hMenu) { DestroyMenu(g_hMenu); g_hMenu = NULL; }
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hwnd, msg, wParam, lParam);       // Ĭ�ϴ���
}

// ������ڣ�Windows ��ϵͳ��
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE, LPSTR, int) {
    const wchar_t kClassName[] = L"MiddleSwitchTrayClass"; // ����

    WNDCLASS wc = {};
    wc.lpfnWndProc = WndProc;                              // ���ڹ���
    wc.hInstance = hInstance;                              // ʵ��
    wc.lpszClassName = kClassName;                         // ����
    RegisterClass(&wc);                                    // ע����

    g_hWnd = CreateWindow(
        kClassName, L"", WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        CW_USEDEFAULT, CW_USEDEFAULT,
        NULL, NULL, hInstance, NULL);
    ShowWindow(g_hWnd, SW_HIDE);                           // ���ش���

    CreateTrayIcon();                                      // ��������
    CreateContextMenu();                                   // �����˵�

    g_mouseHook = SetWindowsHookEx(                        // ��װ��깳��
        WH_MOUSE_LL, LowLevelMouseProc,
        GetModuleHandle(NULL), 0);

    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0)) {                 // ��Ϣѭ��
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return 0;                                              // �����˳�
}
