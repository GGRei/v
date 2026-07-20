#ifndef V_MULTIWINDOW_WIN32_NONREADBACK_TEST_ORACLE_H
#define V_MULTIWINDOW_WIN32_NONREADBACK_TEST_ORACLE_H

#if defined(_WIN32)
#include <windows.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

typedef HRESULT(WINAPI *VMultiwindowTestDwmGetWindowAttribute)(HWND, DWORD, PVOID, DWORD);
typedef UINT(WINAPI *VMultiwindowTestGetDpiForWindow)(HWND);
typedef UINT(WINAPI *VMultiwindowTestGetRegisteredRawInputDevices)(
	PRAWINPUTDEVICE, PUINT, UINT);

typedef struct VMultiwindowTestMonitorSnapshot {
	HMONITOR handles[32];
	RECT geometry[32];
	RECT work[32];
	int primary[32];
	int count;
} VMultiwindowTestMonitorSnapshot;

static HANDLE v_multiwindow_test_clipboard_ready;
static HANDLE v_multiwindow_test_clipboard_release;
static HANDLE v_multiwindow_test_clipboard_thread;
static volatile LONG v_multiwindow_test_clipboard_held;

static inline int v_multiwindow_test_win32_is_window(void *hwnd) {
	return hwnd && IsWindow((HWND)hwnd) ? 1 : 0;
}

static inline int v_multiwindow_test_win32_is_visible(void *hwnd) {
	return hwnd && IsWindowVisible((HWND)hwnd) ? 1 : 0;
}

static inline int v_multiwindow_test_win32_is_enabled(void *hwnd) {
	return hwnd && IsWindowEnabled((HWND)hwnd) ? 1 : 0;
}

static inline int v_multiwindow_test_win32_is_iconic(void *hwnd) {
	return hwnd && IsIconic((HWND)hwnd) ? 1 : 0;
}

static inline int v_multiwindow_test_win32_is_zoomed(void *hwnd) {
	return hwnd && IsZoomed((HWND)hwnd) ? 1 : 0;
}

static inline void *v_multiwindow_test_win32_foreground(void) {
	return (void *)GetForegroundWindow();
}

static inline void *v_multiwindow_test_win32_owner(void *hwnd) {
	return hwnd ? (void *)GetWindow((HWND)hwnd, GW_OWNER) : NULL;
}

static inline uint64_t v_multiwindow_test_win32_style(void *hwnd) {
	return hwnd ? (uint64_t)(uintptr_t)GetWindowLongPtrW((HWND)hwnd, GWL_STYLE) : 0;
}

static inline uint64_t v_multiwindow_test_win32_ex_style(void *hwnd) {
	return hwnd ? (uint64_t)(uintptr_t)GetWindowLongPtrW((HWND)hwnd, GWL_EXSTYLE) : 0;
}

static inline int v_multiwindow_test_win32_rect(void *hwnd, int *left, int *top,
	int *right, int *bottom) {
	RECT rect = {0};
	if (!hwnd || !GetWindowRect((HWND)hwnd, &rect)) {
		return 0;
	}
	if (left) *left = rect.left;
	if (top) *top = rect.top;
	if (right) *right = rect.right;
	if (bottom) *bottom = rect.bottom;
	return 1;
}

static inline int v_multiwindow_test_win32_is_above(void *upper, void *lower) {
	if (!upper || !lower || upper == lower) {
		return 0;
	}
	HWND cursor = (HWND)upper;
	while ((cursor = GetWindow(cursor, GW_HWNDNEXT)) != NULL) {
		if (cursor == (HWND)lower) {
			return 1;
		}
	}
	return 0;
}

static inline UINT v_multiwindow_test_win32_dpi(void *hwnd) {
	HMODULE user32 = GetModuleHandleW(L"user32.dll");
	VMultiwindowTestGetDpiForWindow get_dpi = user32 ?
		(VMultiwindowTestGetDpiForWindow)GetProcAddress(user32, "GetDpiForWindow") : NULL;
	if (get_dpi && hwnd) {
		UINT dpi = get_dpi((HWND)hwnd);
		if (dpi) {
			return dpi;
		}
	}
	HDC dc = GetDC((HWND)hwnd);
	int dpi = dc ? GetDeviceCaps(dc, LOGPIXELSX) : 96;
	if (dc) {
		ReleaseDC((HWND)hwnd, dc);
	}
	return dpi > 0 ? (UINT)dpi : 96;
}

static BOOL CALLBACK v_multiwindow_test_win32_monitor_callback(HMONITOR monitor,
	HDC dc, LPRECT rect, LPARAM data) {
	(void)dc;
	(void)rect;
	VMultiwindowTestMonitorSnapshot *snapshot =
		(VMultiwindowTestMonitorSnapshot *)(uintptr_t)data;
	if (!snapshot || snapshot->count >= 32) {
		return FALSE;
	}
	MONITORINFO info = {0};
	info.cbSize = sizeof(info);
	if (!GetMonitorInfoW(monitor, &info)) {
		return TRUE;
	}
	int index = snapshot->count++;
	snapshot->handles[index] = monitor;
	snapshot->geometry[index] = info.rcMonitor;
	snapshot->work[index] = info.rcWork;
	snapshot->primary[index] = (info.dwFlags & MONITORINFOF_PRIMARY) != 0;
	return TRUE;
}

static inline int v_multiwindow_test_win32_monitor_snapshot(
	VMultiwindowTestMonitorSnapshot *snapshot) {
	if (!snapshot) {
		return 0;
	}
	memset(snapshot, 0, sizeof(*snapshot));
	EnumDisplayMonitors(NULL, NULL, v_multiwindow_test_win32_monitor_callback,
		(LPARAM)(uintptr_t)snapshot);
	return snapshot->count;
}

static inline void *v_multiwindow_test_win32_monitor_snapshot_new(void) {
	VMultiwindowTestMonitorSnapshot *snapshot =
		(VMultiwindowTestMonitorSnapshot *)calloc(1,
			sizeof(VMultiwindowTestMonitorSnapshot));
	if (snapshot) {
		v_multiwindow_test_win32_monitor_snapshot(snapshot);
	}
	return snapshot;
}

static inline void v_multiwindow_test_win32_monitor_snapshot_free(void *snapshot) {
	free(snapshot);
}

static inline uint64_t v_multiwindow_test_win32_monitor_identity(
	VMultiwindowTestMonitorSnapshot *snapshot, int index) {
	if (!snapshot || index < 0 || index >= snapshot->count) {
		return 0;
	}
	return (uint64_t)(uintptr_t)snapshot->handles[index];
}

static inline int v_multiwindow_test_win32_monitor_info(
	VMultiwindowTestMonitorSnapshot *snapshot, int index, int *x, int *y,
	int *width, int *height, int *work_x, int *work_y, int *work_width,
	int *work_height, int *primary) {
	if (!snapshot || index < 0 || index >= snapshot->count) {
		return 0;
	}
	RECT geometry = snapshot->geometry[index];
	RECT work = snapshot->work[index];
	if (x) *x = geometry.left;
	if (y) *y = geometry.top;
	if (width) *width = geometry.right - geometry.left;
	if (height) *height = geometry.bottom - geometry.top;
	if (work_x) *work_x = work.left;
	if (work_y) *work_y = work.top;
	if (work_width) *work_width = work.right - work.left;
	if (work_height) *work_height = work.bottom - work.top;
	if (primary) *primary = snapshot->primary[index];
	return 1;
}

static inline int v_multiwindow_test_win32_emit_display_change(void *hwnd) {
	DWORD_PTR result = 0;
	return hwnd && SendMessageTimeoutW((HWND)hwnd, WM_DISPLAYCHANGE, 32, 0,
		SMTO_ABORTIFHUNG, 1000, &result) != 0;
}

static inline int v_multiwindow_test_win32_clipboard_equals(const wchar_t *expected) {
	if (!OpenClipboard(NULL)) {
		return 0;
	}
	HGLOBAL data = (HGLOBAL)GetClipboardData(CF_UNICODETEXT);
	wchar_t *actual = data ? (wchar_t *)GlobalLock(data) : NULL;
	int equal = actual && expected && wcscmp(actual, expected) == 0;
	if (actual) {
		GlobalUnlock(data);
	}
	CloseClipboard();
	return equal;
}

static inline size_t v_multiwindow_test_win32_clipboard_bytes(void) {
	if (!OpenClipboard(NULL)) {
		return 0;
	}
	HGLOBAL data = (HGLOBAL)GetClipboardData(CF_UNICODETEXT);
	size_t bytes = data ? GlobalSize(data) : 0;
	CloseClipboard();
	return bytes;
}

static inline int v_multiwindow_test_win32_set_clipboard(const wchar_t *text,
	size_t units) {
	if (!text || units == 0 || !OpenClipboard(NULL)) {
		return 0;
	}
	HGLOBAL data = GlobalAlloc(GMEM_MOVEABLE, units * sizeof(wchar_t));
	wchar_t *target = data ? (wchar_t *)GlobalLock(data) : NULL;
	if (!target) {
		if (data) GlobalFree(data);
		CloseClipboard();
		return 0;
	}
	memcpy(target, text, units * sizeof(wchar_t));
	GlobalUnlock(data);
	EmptyClipboard();
	if (!SetClipboardData(CF_UNICODETEXT, data)) {
		GlobalFree(data);
		CloseClipboard();
		return 0;
	}
	CloseClipboard();
	return 1;
}

static DWORD WINAPI v_multiwindow_test_win32_clipboard_holder(void *unused) {
	(void)unused;
	if (!OpenClipboard(NULL)) {
		SetEvent(v_multiwindow_test_clipboard_ready);
		return 1;
	}
	InterlockedExchange(&v_multiwindow_test_clipboard_held, 1);
	SetEvent(v_multiwindow_test_clipboard_ready);
	WaitForSingleObject(v_multiwindow_test_clipboard_release, 10000);
	CloseClipboard();
	InterlockedExchange(&v_multiwindow_test_clipboard_held, 0);
	return 0;
}

static inline int v_multiwindow_test_win32_start_clipboard_occupancy(void) {
	if (v_multiwindow_test_clipboard_thread) {
		return 0;
	}
	v_multiwindow_test_clipboard_ready = CreateEventW(NULL, TRUE, FALSE, NULL);
	v_multiwindow_test_clipboard_release = CreateEventW(NULL, TRUE, FALSE, NULL);
	if (!v_multiwindow_test_clipboard_ready || !v_multiwindow_test_clipboard_release) {
		return 0;
	}
	v_multiwindow_test_clipboard_thread = CreateThread(NULL, 0,
		v_multiwindow_test_win32_clipboard_holder, NULL, 0, NULL);
	if (!v_multiwindow_test_clipboard_thread) {
		return 0;
	}
	if (WaitForSingleObject(v_multiwindow_test_clipboard_ready, 2000) != WAIT_OBJECT_0) {
		return 0;
	}
	return InterlockedCompareExchange(&v_multiwindow_test_clipboard_held, 0, 0) != 0;
}

static inline void v_multiwindow_test_win32_stop_clipboard_occupancy(void) {
	if (v_multiwindow_test_clipboard_release) {
		SetEvent(v_multiwindow_test_clipboard_release);
	}
	if (v_multiwindow_test_clipboard_thread) {
		WaitForSingleObject(v_multiwindow_test_clipboard_thread, 3000);
		CloseHandle(v_multiwindow_test_clipboard_thread);
	}
	if (v_multiwindow_test_clipboard_ready) {
		CloseHandle(v_multiwindow_test_clipboard_ready);
	}
	if (v_multiwindow_test_clipboard_release) {
		CloseHandle(v_multiwindow_test_clipboard_release);
	}
	v_multiwindow_test_clipboard_thread = NULL;
	v_multiwindow_test_clipboard_ready = NULL;
	v_multiwindow_test_clipboard_release = NULL;
	InterlockedExchange(&v_multiwindow_test_clipboard_held, 0);
}

static inline VMultiwindowTestGetRegisteredRawInputDevices
v_multiwindow_test_win32_get_registered_raw_input_devices(void) {
	HMODULE user32 = GetModuleHandleW(L"user32.dll");
	if (!user32) {
		return NULL;
	}
	return (VMultiwindowTestGetRegisteredRawInputDevices)GetProcAddress(
		user32, "GetRegisteredRawInputDevices");
}

static inline void *v_multiwindow_test_win32_raw_mouse_target(void) {
	VMultiwindowTestGetRegisteredRawInputDevices get_registered_raw_input_devices =
		v_multiwindow_test_win32_get_registered_raw_input_devices();
	if (!get_registered_raw_input_devices) {
		return NULL;
	}
	UINT count = 0;
	if (get_registered_raw_input_devices(NULL, &count, sizeof(RAWINPUTDEVICE)) != 0
		|| count == 0) {
		return NULL;
	}
	RAWINPUTDEVICE *devices = (RAWINPUTDEVICE *)calloc(count, sizeof(RAWINPUTDEVICE));
	if (!devices) {
		return NULL;
	}
	UINT copied = count;
	if (get_registered_raw_input_devices(devices, &copied,
		sizeof(RAWINPUTDEVICE)) == (UINT)-1) {
		free(devices);
		return NULL;
	}
	HWND target = NULL;
	for (UINT index = 0; index < copied; index++) {
		if (devices[index].usUsagePage == 0x01 && devices[index].usUsage == 0x02) {
			target = devices[index].hwndTarget;
			break;
		}
	}
	free(devices);
	return (void *)target;
}

static inline int v_multiwindow_test_win32_raw_mouse_registered_for(void *hwnd) {
	VMultiwindowTestGetRegisteredRawInputDevices get_registered_raw_input_devices =
		v_multiwindow_test_win32_get_registered_raw_input_devices();
	UINT count = 0;
	if (!hwnd || !get_registered_raw_input_devices
		|| get_registered_raw_input_devices(NULL, &count, sizeof(RAWINPUTDEVICE)) != 0
		|| count == 0) {
		return 0;
	}
	RAWINPUTDEVICE *devices = (RAWINPUTDEVICE *)calloc(count, sizeof(RAWINPUTDEVICE));
	if (!devices) {
		return 0;
	}
	UINT copied = count;
	if (get_registered_raw_input_devices(devices, &copied, sizeof(RAWINPUTDEVICE))
		== (UINT)-1) {
		free(devices);
		return 0;
	}
	int registered = 0;
	for (UINT index = 0; index < copied; index++) {
		if (devices[index].usUsagePage == 0x01
			&& devices[index].usUsage == 0x02
			&& devices[index].hwndTarget == (HWND)hwnd) {
			registered = 1;
			break;
		}
	}
	free(devices);
	return registered;
}

static inline int v_multiwindow_test_win32_emit_focus_loss(void *hwnd,
	void *next_hwnd) {
	DWORD_PTR result = 0;
	return hwnd && SendMessageTimeoutW((HWND)hwnd, WM_KILLFOCUS,
		(WPARAM)(HWND)next_hwnd, 0, SMTO_ABORTIFHUNG, 1000, &result) != 0;
}

static inline int v_multiwindow_test_win32_clip_matches_client(void *hwnd) {
	RECT client = {0};
	RECT clip = {0};
	if (!hwnd || !GetClientRect((HWND)hwnd, &client)
		|| !GetClipCursor(&clip)) {
		return 0;
	}
	MapWindowPoints((HWND)hwnd, NULL, (POINT *)&client, 2);
	return EqualRect(&client, &clip) ? 1 : 0;
}

static inline int v_multiwindow_test_win32_clip_is_virtual_screen(void) {
	RECT clip = {0};
	RECT screen = {
		GetSystemMetrics(SM_XVIRTUALSCREEN),
		GetSystemMetrics(SM_YVIRTUALSCREEN),
		GetSystemMetrics(SM_XVIRTUALSCREEN) + GetSystemMetrics(SM_CXVIRTUALSCREEN),
		GetSystemMetrics(SM_YVIRTUALSCREEN) + GetSystemMetrics(SM_CYVIRTUALSCREEN)
	};
	return GetClipCursor(&clip) && EqualRect(&clip, &screen) ? 1 : 0;
}

static inline void *v_multiwindow_test_win32_capture(void) {
	return (void *)GetCapture();
}

static inline int v_multiwindow_test_win32_dwm_dark(void *hwnd, int *value) {
	HMODULE dwmapi = LoadLibraryW(L"dwmapi.dll");
	VMultiwindowTestDwmGetWindowAttribute get_attribute = dwmapi ?
		(VMultiwindowTestDwmGetWindowAttribute)GetProcAddress(dwmapi,
			"DwmGetWindowAttribute") : NULL;
	if (!get_attribute || !hwnd || !value) {
		if (dwmapi) FreeLibrary(dwmapi);
		return 0;
	}
	BOOL dark = FALSE;
	HRESULT result = get_attribute((HWND)hwnd, 20, &dark, sizeof(dark));
	FreeLibrary(dwmapi);
	if (FAILED(result)) {
		return 0;
	}
	*value = dark ? 1 : 0;
	return 1;
}
#endif

#endif
