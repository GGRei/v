#ifndef V_MULTIWINDOW_WIN32_NONREADBACK_TEST_ORACLE_H
#define V_MULTIWINDOW_WIN32_NONREADBACK_TEST_ORACLE_H

#if defined(_WIN32)
#include <windows.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

#include "../win32_service_native.h"

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

typedef struct VMultiwindowTestWin32WindowSnapshot {
	LONG_PTR style;
	LONG_PTR ex_style;
	WINDOWPLACEMENT placement;
	RECT rect;
	int visible;
} VMultiwindowTestWin32WindowSnapshot;

typedef struct VMultiwindowTestWin32WrongThreadProbe {
	void *service_state;
	int authority;
	int window_state;
	void *native_window;
	volatile LONG references;
} VMultiwindowTestWin32WrongThreadProbe;

static HANDLE v_multiwindow_test_clipboard_ready;
static HANDLE v_multiwindow_test_clipboard_release;
static HANDLE v_multiwindow_test_clipboard_thread;
static volatile LONG v_multiwindow_test_clipboard_held;
static volatile LONG v_multiwindow_test_win32_wrong_thread_active;
static DWORD v_multiwindow_test_win32_wrong_thread_worker_delay;
static DWORD v_multiwindow_test_win32_wrong_thread_wait_timeout = 5000;

static inline int v_multiwindow_test_win32_is_window(void *hwnd) {
	return hwnd && IsWindow((HWND)hwnd) ? 1 : 0;
}

static inline int v_multiwindow_test_win32_is_visible(void *hwnd) {
	return hwnd && IsWindowVisible((HWND)hwnd) ? 1 : 0;
}

static inline int v_multiwindow_test_win32_is_enabled(void *hwnd) {
	return hwnd && IsWindowEnabled((HWND)hwnd) ? 1 : 0;
}

static inline int v_multiwindow_test_win32_set_enabled(void *hwnd_ptr,
	int enabled) {
	HWND hwnd = (HWND)hwnd_ptr;
	if (!hwnd || !IsWindow(hwnd)) {
		return 0;
	}
	int target = enabled != 0;
	if ((IsWindowEnabled(hwnd) != 0) != target) {
		(void)EnableWindow(hwnd, target ? TRUE : FALSE);
	}
	return (IsWindowEnabled(hwnd) != 0) == target;
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

static inline void *v_multiwindow_test_win32_focus(void) {
	return (void *)GetFocus();
}

static inline int v_multiwindow_test_win32_establish_foreground_focus(
	void *hwnd_ptr) {
	HWND hwnd = (HWND)hwnd_ptr;
	if (!hwnd || !IsWindow(hwnd)) {
		return 0;
	}
	ShowWindow(hwnd, SW_SHOW);
	SetForegroundWindow(hwnd);
	if (GetForegroundWindow() != hwnd) {
		return 0;
	}
	SetFocus(hwnd);
	return GetForegroundWindow() == hwnd && GetFocus() == hwnd;
}

static inline void *v_multiwindow_test_win32_swap_user_data(void *hwnd_ptr,
	void *replacement) {
	HWND hwnd = (HWND)hwnd_ptr;
	if (!hwnd || !IsWindow(hwnd)) {
		return NULL;
	}
	return (void *)SetWindowLongPtrW(hwnd, GWLP_USERDATA,
		(LONG_PTR)replacement);
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

static inline void *v_multiwindow_test_win32_window_snapshot_new(void *hwnd_ptr) {
	HWND hwnd = (HWND)hwnd_ptr;
	VMultiwindowTestWin32WindowSnapshot *snapshot =
		(VMultiwindowTestWin32WindowSnapshot *)calloc(1, sizeof(*snapshot));
	if (!snapshot || !hwnd || !IsWindow(hwnd)) {
		free(snapshot);
		return NULL;
	}
	snapshot->placement.length = sizeof(snapshot->placement);
	if (!GetWindowPlacement(hwnd, &snapshot->placement)
		|| !GetWindowRect(hwnd, &snapshot->rect)) {
		free(snapshot);
		return NULL;
	}
	snapshot->style = GetWindowLongPtrW(hwnd, GWL_STYLE);
	snapshot->ex_style = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
	snapshot->visible = IsWindowVisible(hwnd) != 0;
	return snapshot;
}

static inline void v_multiwindow_test_win32_window_snapshot_free(
	void *snapshot_ptr) {
	free(snapshot_ptr);
}

static inline int v_multiwindow_test_win32_window_snapshot_matches(
	void *snapshot_ptr, void *hwnd_ptr) {
	const VMultiwindowTestWin32WindowSnapshot *snapshot =
		(const VMultiwindowTestWin32WindowSnapshot *)snapshot_ptr;
	HWND hwnd = (HWND)hwnd_ptr;
	if (!snapshot || !hwnd || !IsWindow(hwnd)
		|| GetWindowLongPtrW(hwnd, GWL_STYLE) != snapshot->style
		|| GetWindowLongPtrW(hwnd, GWL_EXSTYLE) != snapshot->ex_style) {
		return 0;
	}
	WINDOWPLACEMENT current;
	RECT rect;
	ZeroMemory(&current, sizeof(current));
	ZeroMemory(&rect, sizeof(rect));
	current.length = sizeof(current);
	if (!GetWindowPlacement(hwnd, &current) || !GetWindowRect(hwnd, &rect)) {
		return 0;
	}
	return current.flags == snapshot->placement.flags
		&& current.showCmd == snapshot->placement.showCmd
		&& current.ptMinPosition.x == snapshot->placement.ptMinPosition.x
		&& current.ptMinPosition.y == snapshot->placement.ptMinPosition.y
		&& current.ptMaxPosition.x == snapshot->placement.ptMaxPosition.x
		&& current.ptMaxPosition.y == snapshot->placement.ptMaxPosition.y
		&& EqualRect(&current.rcNormalPosition,
			&snapshot->placement.rcNormalPosition)
		&& EqualRect(&rect, &snapshot->rect)
		&& (IsWindowVisible(hwnd) != 0) == snapshot->visible;
}

static inline int v_multiwindow_test_win32_synthesized_windowed_matches(
	void *hwnd_ptr, int resizable, int borderless, int requested_width,
	int requested_height, int expected_visible, UINT expected_show_command) {
	HWND hwnd = (HWND)hwnd_ptr;
	if (!hwnd || !IsWindow(hwnd)) {
		return 0;
	}
	LONG_PTR expected_style = (LONG_PTR)v_multiwindow_win32_service_windowed_style(
		resizable, borderless);
	LONG_PTR expected_ex_style =
		(LONG_PTR)v_multiwindow_win32_service_windowed_ex_style(borderless);
	LONG_PTR style_mask = WS_POPUP | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX
		| WS_SIZEBOX | WS_MAXIMIZEBOX | WS_CLIPSIBLINGS | WS_CLIPCHILDREN;
	LONG_PTR ex_style_mask = WS_EX_APPWINDOW | WS_EX_WINDOWEDGE;
	LONG_PTR style = GetWindowLongPtrW(hwnd, GWL_STYLE);
	LONG_PTR ex_style = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
	WINDOWPLACEMENT placement;
	RECT rect;
	RECT frame = {0, 0, requested_width > 0 ? requested_width : 1,
		requested_height > 0 ? requested_height : 1};
	HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
	MONITORINFO monitor_info;
	ZeroMemory(&placement, sizeof(placement));
	ZeroMemory(&rect, sizeof(rect));
	ZeroMemory(&monitor_info, sizeof(monitor_info));
	placement.length = sizeof(placement);
	monitor_info.cbSize = sizeof(monitor_info);
	if (!AdjustWindowRectEx(&frame, (DWORD)expected_style, FALSE,
		(DWORD)expected_ex_style) || !monitor
		|| !GetMonitorInfoW(monitor, &monitor_info)) {
		return 0;
	}
	int width = frame.right - frame.left;
	int height = frame.bottom - frame.top;
	int screen_x = monitor_info.rcWork.left
		+ ((monitor_info.rcWork.right - monitor_info.rcWork.left) - width) / 2;
	int screen_y = monitor_info.rcWork.top
		+ ((monitor_info.rcWork.bottom - monitor_info.rcWork.top) - height) / 2;
	int workspace_x =
		screen_x + monitor_info.rcMonitor.left - monitor_info.rcWork.left;
	int workspace_y =
		screen_y + monitor_info.rcMonitor.top - monitor_info.rcWork.top;
	return (style & style_mask) == (expected_style & style_mask)
		&& (ex_style & ex_style_mask) == (expected_ex_style & ex_style_mask)
		&& GetWindowPlacement(hwnd, &placement)
		&& placement.showCmd == expected_show_command
		&& placement.rcNormalPosition.left == workspace_x
		&& placement.rcNormalPosition.top == workspace_y
		&& placement.rcNormalPosition.right == workspace_x + width
		&& placement.rcNormalPosition.bottom == workspace_y + height
		&& (IsWindowVisible(hwnd) != 0) == (expected_visible != 0)
		&& GetWindowRect(hwnd, &rect) && rect.right > rect.left
		&& rect.bottom > rect.top;
}

static inline void v_multiwindow_test_win32_wrong_thread_release(
	VMultiwindowTestWin32WrongThreadProbe *context) {
	if (context && InterlockedDecrement(&context->references) == 0) {
		InterlockedDecrement(&v_multiwindow_test_win32_wrong_thread_active);
		free(context);
	}
}

static DWORD WINAPI v_multiwindow_test_win32_service_wrong_thread_worker(
	void *context_ptr) {
	VMultiwindowTestWin32WrongThreadProbe *context =
		(VMultiwindowTestWin32WrongThreadProbe *)context_ptr;
	if (v_multiwindow_test_win32_wrong_thread_worker_delay > 0) {
		Sleep(v_multiwindow_test_win32_wrong_thread_worker_delay);
	}
	context->authority =
		v_multiwindow_win32_service_authority(context->service_state);
	context->window_state = v_multiwindow_win32_service_window_state(
		context->service_state, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		NULL, NULL);
	context->native_window =
		v_multiwindow_win32_service_native_window(context->service_state);
	v_multiwindow_test_win32_wrong_thread_release(context);
	return 0;
}

static inline void v_multiwindow_test_win32_service_wrong_thread_timing(
	DWORD worker_delay, DWORD wait_timeout) {
	v_multiwindow_test_win32_wrong_thread_worker_delay = worker_delay;
	v_multiwindow_test_win32_wrong_thread_wait_timeout = wait_timeout;
}

static inline int v_multiwindow_test_win32_service_wrong_thread_active_count(void) {
	return (int)InterlockedCompareExchange(
		&v_multiwindow_test_win32_wrong_thread_active, 0, 0);
}

static inline int v_multiwindow_test_win32_service_wrong_thread_wait_cleanup(
	DWORD timeout) {
	DWORD waited = 0;
	while (v_multiwindow_test_win32_service_wrong_thread_active_count() != 0
		&& waited < timeout) {
		Sleep(1);
		waited++;
	}
	return v_multiwindow_test_win32_service_wrong_thread_active_count() == 0;
}

static inline int v_multiwindow_test_win32_service_wrong_thread_rejected(
	void *service_state) {
	VMultiwindowTestWin32WrongThreadProbe *context =
		(VMultiwindowTestWin32WrongThreadProbe *)calloc(1, sizeof(*context));
	if (!context) {
		return 0;
	}
	context->service_state = service_state;
	context->references = 2;
	InterlockedIncrement(&v_multiwindow_test_win32_wrong_thread_active);
	HANDLE thread = CreateThread(NULL, 0,
		v_multiwindow_test_win32_service_wrong_thread_worker, context, 0, NULL);
	if (!thread) {
		InterlockedDecrement(&v_multiwindow_test_win32_wrong_thread_active);
		free(context);
		return 0;
	}
	DWORD wait = WaitForSingleObject(thread,
		v_multiwindow_test_win32_wrong_thread_wait_timeout);
	int rejected = wait == WAIT_OBJECT_0
		&& context->authority == V_MULTIWINDOW_WIN32_SERVICE_WRONG_THREAD
		&& context->window_state == V_MULTIWINDOW_WIN32_SERVICE_WRONG_THREAD
		&& context->native_window == NULL;
	CloseHandle(thread);
	v_multiwindow_test_win32_wrong_thread_release(context);
	return rejected;
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
