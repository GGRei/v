#ifndef V_MULTIWINDOW_WIN32_SERVICE_NATIVE_H
#define V_MULTIWINDOW_WIN32_SERVICE_NATIVE_H

#if defined(_WIN32)
#include <windows.h>
#include <stdint.h>
#include <stdlib.h>
#include <wchar.h>

#if defined(V_MULTIWINDOW_WIN32_SERVICE_TEST)
#include "testdata/win32_monitor_enumeration_test_seam.h"
#endif

#define V_MULTIWINDOW_WIN32_SERVICE_OK 1
#define V_MULTIWINDOW_WIN32_SERVICE_UNAVAILABLE 0
#define V_MULTIWINDOW_WIN32_SERVICE_WRONG_THREAD -1
#define V_MULTIWINDOW_WIN32_SERVICE_INVALID -2

#define V_MULTIWINDOW_WIN32_SERVICE_TEST_FAIL_NONE 0
#define V_MULTIWINDOW_WIN32_SERVICE_TEST_FAIL_EXIT_EXSTYLE 1
#define V_MULTIWINDOW_WIN32_SERVICE_TEST_FAIL_EXIT_PLACEMENT 2
#define V_MULTIWINDOW_WIN32_SERVICE_TEST_FAIL_EXIT_POSITION 3

#define V_MULTIWINDOW_WIN32_SERVICE_TEST_ROLLBACK_STYLE 1
#define V_MULTIWINDOW_WIN32_SERVICE_TEST_ROLLBACK_EXSTYLE 2
#define V_MULTIWINDOW_WIN32_SERVICE_TEST_ROLLBACK_PLACEMENT 4
#define V_MULTIWINDOW_WIN32_SERVICE_TEST_ROLLBACK_POSITION 8

typedef struct VMultiwindowWin32ServiceState {
	HWND hwnd;
	void *record_data;
	DWORD owner_thread;
	DWORD owner_process;
	int fullscreen;
	int fullscreen_known;
	int restore_valid;
	int windowed_visible;
	LONG_PTR windowed_style;
	LONG_PTR windowed_ex_style;
	WINDOWPLACEMENT windowed_placement;
	int requested_width;
	int requested_height;
	int resizable;
	int borderless;
} VMultiwindowWin32ServiceState;

typedef struct VMultiwindowWin32NativeWindowSnapshot {
	LONG_PTR style;
	LONG_PTR ex_style;
	WINDOWPLACEMENT placement;
	RECT rect;
	int visible;
} VMultiwindowWin32NativeWindowSnapshot;

#define V_MULTIWINDOW_WIN32_SERVICE_MONITOR_INITIAL_CAPACITY 8
#define V_MULTIWINDOW_WIN32_SERVICE_MONITOR_MAX_CAPACITY 4096

typedef struct VMultiwindowWin32ServiceMonitor {
	HMONITOR native_id;
	wchar_t name[CCHDEVICENAME];
	RECT geometry;
	RECT work;
	UINT dpi;
	int primary;
} VMultiwindowWin32ServiceMonitor;

typedef struct VMultiwindowWin32ServiceMonitorSnapshot {
	VMultiwindowWin32ServiceMonitor *monitors;
	int count;
	int capacity;
	int failed;
} VMultiwindowWin32ServiceMonitorSnapshot;

typedef HRESULT(WINAPI *VMultiwindowWin32GetDpiForMonitor)(
	HMONITOR, int, UINT *, UINT *);
typedef UINT(WINAPI *VMultiwindowWin32GetDpiForWindow)(HWND);

static inline UINT v_multiwindow_win32_service_monitor_dpi(HMONITOR monitor) {
	HMODULE shcore = LoadLibraryW(L"shcore.dll");
	if (shcore) {
		VMultiwindowWin32GetDpiForMonitor get_dpi_for_monitor =
			(VMultiwindowWin32GetDpiForMonitor)GetProcAddress(shcore,
				"GetDpiForMonitor");
		if (get_dpi_for_monitor) {
			UINT dpi_x = 0;
			UINT dpi_y = 0;
			HRESULT result = get_dpi_for_monitor(monitor, 0, &dpi_x, &dpi_y);
			FreeLibrary(shcore);
			if (SUCCEEDED(result) && dpi_x > 0) {
				return dpi_x;
			}
		} else {
			FreeLibrary(shcore);
		}
	}
	HDC dc = GetDC(NULL);
	int dpi = dc ? GetDeviceCaps(dc, LOGPIXELSX) : 96;
	if (dc) {
		ReleaseDC(NULL, dc);
	}
	return dpi > 0 ? (UINT)dpi : 96;
}

static BOOL CALLBACK v_multiwindow_win32_service_monitor_snapshot_callback(
	HMONITOR monitor, HDC dc, LPRECT rect, LPARAM data) {
	(void)dc;
	(void)rect;
	VMultiwindowWin32ServiceMonitorSnapshot *snapshot =
		(VMultiwindowWin32ServiceMonitorSnapshot *)(uintptr_t)data;
	if (!snapshot) {
		return FALSE;
	}
	if (snapshot->count >= snapshot->capacity) {
		if (snapshot->capacity >=
				V_MULTIWINDOW_WIN32_SERVICE_MONITOR_MAX_CAPACITY) {
			snapshot->failed = 1;
			return FALSE;
		}
		int next_capacity = snapshot->capacity > 0
			? snapshot->capacity * 2
			: V_MULTIWINDOW_WIN32_SERVICE_MONITOR_INITIAL_CAPACITY;
		if (next_capacity >
				V_MULTIWINDOW_WIN32_SERVICE_MONITOR_MAX_CAPACITY) {
			next_capacity =
				V_MULTIWINDOW_WIN32_SERVICE_MONITOR_MAX_CAPACITY;
		}
		VMultiwindowWin32ServiceMonitor *grown =
			(VMultiwindowWin32ServiceMonitor *)realloc(snapshot->monitors,
				(size_t)next_capacity *
					sizeof(VMultiwindowWin32ServiceMonitor));
		if (!grown) {
			snapshot->failed = 1;
			return FALSE;
		}
		snapshot->monitors = grown;
		snapshot->capacity = next_capacity;
	}
	MONITORINFOEXW info;
	ZeroMemory(&info, sizeof(info));
	LPMONITORINFO base = (LPMONITORINFO)&info;
	base->cbSize = sizeof(info);
	if (!GetMonitorInfoW(monitor, base)) {
		snapshot->failed = 1;
		return FALSE;
	}
	int index = snapshot->count++;
	VMultiwindowWin32ServiceMonitor *item = &snapshot->monitors[index];
	item->native_id = monitor;
	item->geometry = base->rcMonitor;
	item->work = base->rcWork;
	item->dpi = v_multiwindow_win32_service_monitor_dpi(monitor);
	item->primary = (base->dwFlags & MONITORINFOF_PRIMARY) != 0;
	wcsncpy(item->name, info.szDevice, CCHDEVICENAME - 1);
	item->name[CCHDEVICENAME - 1] = L'\0';
	return TRUE;
}

static inline void *v_multiwindow_win32_service_monitor_snapshot_new(void) {
	VMultiwindowWin32ServiceMonitorSnapshot *snapshot =
		(VMultiwindowWin32ServiceMonitorSnapshot *)calloc(1,
			sizeof(VMultiwindowWin32ServiceMonitorSnapshot));
	if (!snapshot) {
		return NULL;
	}
	snapshot->capacity =
		V_MULTIWINDOW_WIN32_SERVICE_MONITOR_INITIAL_CAPACITY;
	snapshot->monitors = (VMultiwindowWin32ServiceMonitor *)calloc(
		(size_t)snapshot->capacity,
		sizeof(VMultiwindowWin32ServiceMonitor));
	if (!snapshot->monitors) {
		free(snapshot);
		return NULL;
	}
#if defined(V_MULTIWINDOW_WIN32_SERVICE_TEST)
	BOOL enumerated = v_multiwindow_win32_service_test_enum_display_monitors(
		NULL, NULL, v_multiwindow_win32_service_monitor_snapshot_callback,
		(LPARAM)(uintptr_t)snapshot);
#else
	BOOL enumerated = EnumDisplayMonitors(NULL, NULL,
		v_multiwindow_win32_service_monitor_snapshot_callback,
		(LPARAM)(uintptr_t)snapshot);
#endif
	if (!enumerated || snapshot->failed) {
		free(snapshot->monitors);
		free(snapshot);
		return NULL;
	}
	return snapshot;
}

static inline void v_multiwindow_win32_service_monitor_snapshot_free(
		void *snapshot) {
	VMultiwindowWin32ServiceMonitorSnapshot *typed =
		(VMultiwindowWin32ServiceMonitorSnapshot *)snapshot;
	if (typed) {
		free(typed->monitors);
		free(typed);
	}
}

static inline int v_multiwindow_win32_service_monitor_snapshot_count(
	const VMultiwindowWin32ServiceMonitorSnapshot *snapshot) {
	return snapshot ? snapshot->count : -1;
}

static inline uint64_t v_multiwindow_win32_service_monitor_snapshot_native_id(
	const VMultiwindowWin32ServiceMonitorSnapshot *snapshot, int index) {
	if (!snapshot || index < 0 || index >= snapshot->count) {
		return 0;
	}
	return (uint64_t)(uintptr_t)snapshot->monitors[index].native_id;
}

static inline const wchar_t *
v_multiwindow_win32_service_monitor_snapshot_name(
	const VMultiwindowWin32ServiceMonitorSnapshot *snapshot, int index) {
	if (!snapshot || index < 0 || index >= snapshot->count) {
		return NULL;
	}
	return snapshot->monitors[index].name;
}

static inline int v_multiwindow_win32_service_monitor_snapshot_info(
	const VMultiwindowWin32ServiceMonitorSnapshot *snapshot, int index,
	int *x, int *y, int *width, int *height, int *work_x, int *work_y,
	int *work_width, int *work_height, UINT *dpi, int *primary) {
	if (!snapshot || index < 0 || index >= snapshot->count) {
		return 0;
	}
	const VMultiwindowWin32ServiceMonitor *item = &snapshot->monitors[index];
	if (x) *x = item->geometry.left;
	if (y) *y = item->geometry.top;
	if (width) *width = item->geometry.right - item->geometry.left;
	if (height) *height = item->geometry.bottom - item->geometry.top;
	if (work_x) *work_x = item->work.left;
	if (work_y) *work_y = item->work.top;
	if (work_width) *work_width = item->work.right - item->work.left;
	if (work_height) *work_height = item->work.bottom - item->work.top;
	if (dpi) *dpi = item->dpi;
	if (primary) *primary = item->primary;
	return 1;
}

static inline uint64_t v_multiwindow_win32_service_window_monitor(
	void *hwnd_ptr) {
	HWND hwnd = (HWND)hwnd_ptr;
	if (!hwnd || !IsWindow(hwnd)) {
		return 0;
	}
	return (uint64_t)(uintptr_t)MonitorFromWindow(hwnd,
		MONITOR_DEFAULTTONEAREST);
}

static inline UINT v_multiwindow_win32_service_window_dpi(void *hwnd_ptr) {
	HWND hwnd = (HWND)hwnd_ptr;
	if (!hwnd || !IsWindow(hwnd)) {
		return 0;
	}
	HMODULE user32 = GetModuleHandleW(L"user32.dll");
	VMultiwindowWin32GetDpiForWindow get_dpi_for_window = user32 ?
		(VMultiwindowWin32GetDpiForWindow)GetProcAddress(user32,
			"GetDpiForWindow") : NULL;
	UINT dpi = get_dpi_for_window ? get_dpi_for_window(hwnd) : 0;
	if (dpi > 0) {
		return dpi;
	}
	HDC dc = GetDC(hwnd);
	int fallback = dc ? GetDeviceCaps(dc, LOGPIXELSX) : 96;
	if (dc) {
		ReleaseDC(hwnd, dc);
	}
	return fallback > 0 ? (UINT)fallback : 96;
}

#if defined(V_MULTIWINDOW_WIN32_SERVICE_TEST)
static int v_multiwindow_win32_service_test_focus_refused;
static int v_multiwindow_win32_service_test_show_failure;
static int v_multiwindow_win32_service_test_fullscreen_exit_failure;
static int v_multiwindow_win32_service_test_fullscreen_rollback_failure_mask;
static int v_multiwindow_win32_service_test_fullscreen_rollback_attempt_mask;

static inline void v_multiwindow_win32_service_test_set_focus_refused(int refused) {
	v_multiwindow_win32_service_test_focus_refused = refused != 0;
}

static inline void v_multiwindow_win32_service_test_set_show_failure(int fail) {
	v_multiwindow_win32_service_test_show_failure = fail != 0;
}

static inline void v_multiwindow_win32_service_test_set_fullscreen_exit_failure(
	int failure) {
	v_multiwindow_win32_service_test_fullscreen_exit_failure = failure;
}

static inline void v_multiwindow_win32_service_test_set_fullscreen_rollback_failure(
	int failure_mask) {
	v_multiwindow_win32_service_test_fullscreen_rollback_failure_mask = failure_mask;
	v_multiwindow_win32_service_test_fullscreen_rollback_attempt_mask = 0;
}

static inline int v_multiwindow_win32_service_test_fullscreen_rollback_attempts(void) {
	return v_multiwindow_win32_service_test_fullscreen_rollback_attempt_mask;
}
#endif

static inline DWORD v_multiwindow_win32_service_windowed_style(int resizable,
	int borderless) {
	if (borderless) {
		return WS_POPUP | WS_CLIPSIBLINGS | WS_CLIPCHILDREN;
	}
	DWORD style = WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | WS_CLIPSIBLINGS
		| WS_CLIPCHILDREN;
	if (resizable) {
		style |= WS_SIZEBOX | WS_MAXIMIZEBOX;
	}
	return style;
}

static inline DWORD v_multiwindow_win32_service_windowed_ex_style(int borderless) {
	return borderless ? WS_EX_APPWINDOW : WS_EX_APPWINDOW | WS_EX_WINDOWEDGE;
}

static inline int v_multiwindow_win32_service_set_long_ptr(HWND hwnd, int index,
	LONG_PTR value) {
	SetLastError(ERROR_SUCCESS);
	LONG_PTR previous = SetWindowLongPtrW(hwnd, index, value);
	return previous != 0 || GetLastError() == ERROR_SUCCESS;
}

static inline int v_multiwindow_win32_service_capture_native_snapshot(HWND hwnd,
	VMultiwindowWin32NativeWindowSnapshot *snapshot) {
	if (!hwnd || !snapshot || !IsWindow(hwnd)) {
		return 0;
	}
	ZeroMemory(snapshot, sizeof(*snapshot));
	snapshot->placement.length = sizeof(snapshot->placement);
	if (!GetWindowPlacement(hwnd, &snapshot->placement)
		|| !GetWindowRect(hwnd, &snapshot->rect)) {
		return 0;
	}
	snapshot->style = GetWindowLongPtrW(hwnd, GWL_STYLE);
	snapshot->ex_style = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
	snapshot->visible = IsWindowVisible(hwnd) != 0;
	return 1;
}

static inline int v_multiwindow_win32_service_native_snapshot_matches(HWND hwnd,
	const VMultiwindowWin32NativeWindowSnapshot *snapshot) {
	if (!hwnd || !snapshot || !IsWindow(hwnd)
		|| GetWindowLongPtrW(hwnd, GWL_STYLE) != snapshot->style
		|| GetWindowLongPtrW(hwnd, GWL_EXSTYLE) != snapshot->ex_style) {
		return 0;
	}
	WINDOWPLACEMENT placement;
	RECT rect;
	ZeroMemory(&placement, sizeof(placement));
	ZeroMemory(&rect, sizeof(rect));
	placement.length = sizeof(placement);
	if (!GetWindowPlacement(hwnd, &placement) || !GetWindowRect(hwnd, &rect)) {
		return 0;
	}
	return placement.flags == snapshot->placement.flags
		&& placement.showCmd == snapshot->placement.showCmd
		&& placement.ptMinPosition.x == snapshot->placement.ptMinPosition.x
		&& placement.ptMinPosition.y == snapshot->placement.ptMinPosition.y
		&& placement.ptMaxPosition.x == snapshot->placement.ptMaxPosition.x
		&& placement.ptMaxPosition.y == snapshot->placement.ptMaxPosition.y
		&& EqualRect(&placement.rcNormalPosition,
			&snapshot->placement.rcNormalPosition)
		&& EqualRect(&rect, &snapshot->rect)
		&& (IsWindowVisible(hwnd) != 0) == snapshot->visible;
}

static inline int v_multiwindow_win32_service_restore_visibility(HWND hwnd,
	int visible, UINT show_command) {
	if (visible) {
		if (!IsWindowVisible(hwnd)) {
			ShowWindow(hwnd,
				show_command == SW_HIDE ? SW_SHOWNOACTIVATE : (int)show_command);
		}
	} else if (IsWindowVisible(hwnd)) {
		ShowWindow(hwnd, SW_HIDE);
	}
	return (IsWindowVisible(hwnd) != 0) == (visible != 0);
}

static inline int v_multiwindow_win32_service_restore_native_snapshot(HWND hwnd,
	const VMultiwindowWin32NativeWindowSnapshot *snapshot) {
	if (!hwnd || !snapshot) {
		return 0;
	}
	int restored = 1;
#if defined(V_MULTIWINDOW_WIN32_SERVICE_TEST)
	v_multiwindow_win32_service_test_fullscreen_rollback_attempt_mask
		|= V_MULTIWINDOW_WIN32_SERVICE_TEST_ROLLBACK_STYLE;
	if ((v_multiwindow_win32_service_test_fullscreen_rollback_failure_mask
		& V_MULTIWINDOW_WIN32_SERVICE_TEST_ROLLBACK_STYLE)
		|| !v_multiwindow_win32_service_set_long_ptr(hwnd, GWL_STYLE,
			snapshot->style)) {
		restored = 0;
	}
	v_multiwindow_win32_service_test_fullscreen_rollback_attempt_mask
		|= V_MULTIWINDOW_WIN32_SERVICE_TEST_ROLLBACK_EXSTYLE;
	if ((v_multiwindow_win32_service_test_fullscreen_rollback_failure_mask
		& V_MULTIWINDOW_WIN32_SERVICE_TEST_ROLLBACK_EXSTYLE)
		|| !v_multiwindow_win32_service_set_long_ptr(hwnd, GWL_EXSTYLE,
			snapshot->ex_style)) {
		restored = 0;
	}
	v_multiwindow_win32_service_test_fullscreen_rollback_attempt_mask
		|= V_MULTIWINDOW_WIN32_SERVICE_TEST_ROLLBACK_PLACEMENT;
	if ((v_multiwindow_win32_service_test_fullscreen_rollback_failure_mask
		& V_MULTIWINDOW_WIN32_SERVICE_TEST_ROLLBACK_PLACEMENT)
		|| !SetWindowPlacement(hwnd, &snapshot->placement)) {
		restored = 0;
	}
	v_multiwindow_win32_service_test_fullscreen_rollback_attempt_mask
		|= V_MULTIWINDOW_WIN32_SERVICE_TEST_ROLLBACK_POSITION;
	if ((v_multiwindow_win32_service_test_fullscreen_rollback_failure_mask
		& V_MULTIWINDOW_WIN32_SERVICE_TEST_ROLLBACK_POSITION)
		|| !SetWindowPos(hwnd, NULL, snapshot->rect.left, snapshot->rect.top,
			snapshot->rect.right - snapshot->rect.left,
			snapshot->rect.bottom - snapshot->rect.top,
			SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOOWNERZORDER
				| SWP_FRAMECHANGED)) {
		restored = 0;
	}
#else
	if (!v_multiwindow_win32_service_set_long_ptr(hwnd, GWL_STYLE,
		snapshot->style)) {
		restored = 0;
	}
	if (!v_multiwindow_win32_service_set_long_ptr(hwnd, GWL_EXSTYLE,
		snapshot->ex_style)) {
		restored = 0;
	}
	if (!SetWindowPlacement(hwnd, &snapshot->placement)) {
		restored = 0;
	}
	if (!SetWindowPos(hwnd, NULL, snapshot->rect.left, snapshot->rect.top,
		snapshot->rect.right - snapshot->rect.left,
		snapshot->rect.bottom - snapshot->rect.top,
		SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_FRAMECHANGED)) {
		restored = 0;
	}
#endif
	if (!v_multiwindow_win32_service_restore_visibility(hwnd, snapshot->visible,
		snapshot->placement.showCmd)) {
		restored = 0;
	}
	return restored
		&& v_multiwindow_win32_service_native_snapshot_matches(hwnd, snapshot);
}

static inline int v_multiwindow_win32_service_authority(void *state_ptr) {
	const VMultiwindowWin32ServiceState *state =
		(const VMultiwindowWin32ServiceState *)state_ptr;
	if (!state || !state->hwnd || !IsWindow(state->hwnd)) {
		return V_MULTIWINDOW_WIN32_SERVICE_INVALID;
	}
	DWORD window_process = 0;
	DWORD window_thread = GetWindowThreadProcessId(state->hwnd, &window_process);
	if (!window_thread || window_thread != state->owner_thread || !window_process
		|| window_process != state->owner_process
		|| state->owner_process != GetCurrentProcessId()
		|| (void *)GetWindowLongPtrW(state->hwnd, GWLP_USERDATA) != state->record_data) {
		return V_MULTIWINDOW_WIN32_SERVICE_INVALID;
	}
	if (GetCurrentThreadId() != state->owner_thread) {
		return V_MULTIWINDOW_WIN32_SERVICE_WRONG_THREAD;
	}
	return V_MULTIWINDOW_WIN32_SERVICE_OK;
}

static inline int v_multiwindow_win32_service_capture_restore(
	VMultiwindowWin32ServiceState *state) {
	if (v_multiwindow_win32_service_authority(state)
		!= V_MULTIWINDOW_WIN32_SERVICE_OK) {
		return 0;
	}
	WINDOWPLACEMENT placement;
	ZeroMemory(&placement, sizeof(placement));
	placement.length = sizeof(placement);
	if (!GetWindowPlacement(state->hwnd, &placement)) {
		return 0;
	}
	state->windowed_style = GetWindowLongPtrW(state->hwnd, GWL_STYLE);
	state->windowed_ex_style = GetWindowLongPtrW(state->hwnd, GWL_EXSTYLE);
	state->windowed_placement = placement;
	state->windowed_visible = IsWindowVisible(state->hwnd) != 0;
	state->restore_valid = 1;
	return 1;
}

static inline int v_multiwindow_win32_service_synthesize_restore(
	VMultiwindowWin32ServiceState *state) {
	if (v_multiwindow_win32_service_authority(state)
		!= V_MULTIWINDOW_WIN32_SERVICE_OK) {
		return 0;
	}
	DWORD style = v_multiwindow_win32_service_windowed_style(state->resizable,
		state->borderless);
	DWORD ex_style = v_multiwindow_win32_service_windowed_ex_style(state->borderless);
	RECT frame = {0, 0, state->requested_width > 0 ? state->requested_width : 1,
		state->requested_height > 0 ? state->requested_height : 1};
	if (!AdjustWindowRectEx(&frame, style, FALSE, ex_style)) {
		return 0;
	}
	HMONITOR monitor = MonitorFromWindow(state->hwnd, MONITOR_DEFAULTTONEAREST);
	MONITORINFO monitor_info;
	ZeroMemory(&monitor_info, sizeof(monitor_info));
	monitor_info.cbSize = sizeof(monitor_info);
	if (!monitor || !GetMonitorInfoW(monitor, &monitor_info)) {
		return 0;
	}
	WINDOWPLACEMENT current;
	ZeroMemory(&current, sizeof(current));
	current.length = sizeof(current);
	if (!GetWindowPlacement(state->hwnd, &current)) {
		return 0;
	}
	int width = frame.right - frame.left;
	int height = frame.bottom - frame.top;
	int work_width = monitor_info.rcWork.right - monitor_info.rcWork.left;
	int work_height = monitor_info.rcWork.bottom - monitor_info.rcWork.top;
	int screen_x = monitor_info.rcWork.left + (work_width - width) / 2;
	int screen_y = monitor_info.rcWork.top + (work_height - height) / 2;
	int workspace_x =
		screen_x + monitor_info.rcMonitor.left - monitor_info.rcWork.left;
	int workspace_y =
		screen_y + monitor_info.rcMonitor.top - monitor_info.rcWork.top;
	WINDOWPLACEMENT placement;
	ZeroMemory(&placement, sizeof(placement));
	placement.length = sizeof(placement);
	placement.showCmd = current.showCmd;
	placement.rcNormalPosition.left = workspace_x;
	placement.rcNormalPosition.top = workspace_y;
	placement.rcNormalPosition.right = workspace_x + width;
	placement.rcNormalPosition.bottom = workspace_y + height;
	state->windowed_style = (LONG_PTR)style;
	state->windowed_ex_style = (LONG_PTR)ex_style;
	state->windowed_placement = placement;
	state->windowed_visible = IsWindowVisible(state->hwnd) != 0;
	state->restore_valid = 1;
	return 1;
}

static inline void *v_multiwindow_win32_service_create(void *hwnd_ptr,
	void *record_data, int initial_fullscreen, int width, int height, int resizable,
	int borderless) {
	HWND hwnd = (HWND)hwnd_ptr;
	if (!hwnd || !IsWindow(hwnd)) {
		return NULL;
	}
	DWORD owner_process = 0;
	DWORD owner_thread = GetWindowThreadProcessId(hwnd, &owner_process);
	if (!owner_thread || owner_thread != GetCurrentThreadId() || !owner_process
		|| owner_process != GetCurrentProcessId()
		|| (void *)GetWindowLongPtrW(hwnd, GWLP_USERDATA) != record_data) {
		return NULL;
	}
	VMultiwindowWin32ServiceState *state =
		(VMultiwindowWin32ServiceState *)calloc(1, sizeof(*state));
	if (!state) {
		return NULL;
	}
	state->hwnd = hwnd;
	state->record_data = record_data;
	state->owner_thread = owner_thread;
	state->owner_process = owner_process;
	state->fullscreen = initial_fullscreen != 0;
	state->fullscreen_known = 1;
	state->requested_width = width;
	state->requested_height = height;
	state->resizable = resizable != 0;
	state->borderless = borderless != 0;
	int captured = state->fullscreen ? v_multiwindow_win32_service_synthesize_restore(state)
		: v_multiwindow_win32_service_capture_restore(state);
	if (!captured) {
		free(state);
		return NULL;
	}
	return state;
}

static inline int v_multiwindow_win32_service_release(void *state_ptr) {
	VMultiwindowWin32ServiceState *state =
		(VMultiwindowWin32ServiceState *)state_ptr;
	if (!state) {
		return V_MULTIWINDOW_WIN32_SERVICE_OK;
	}
	if (GetCurrentThreadId() != state->owner_thread) {
		return V_MULTIWINDOW_WIN32_SERVICE_WRONG_THREAD;
	}
	state->hwnd = NULL;
	free(state);
	return V_MULTIWINDOW_WIN32_SERVICE_OK;
}

static inline int v_multiwindow_win32_service_window_state(void *state_ptr,
	int *out_mapping, int *out_visibility, int *out_active, int *out_focused,
	int *out_minimized, int *out_maximized, int *out_fullscreen,
	int *out_position_known, int *out_x, int *out_y) {
	VMultiwindowWin32ServiceState *state =
		(VMultiwindowWin32ServiceState *)state_ptr;
	int authority = v_multiwindow_win32_service_authority(state);
	if (authority != V_MULTIWINDOW_WIN32_SERVICE_OK) {
		return authority;
	}
	RECT rect;
	ZeroMemory(&rect, sizeof(rect));
	int position_known = GetWindowRect(state->hwnd, &rect) != 0;
	int visible = IsWindowVisible(state->hwnd) != 0;
	int active = GetForegroundWindow() == state->hwnd;
	if (out_mapping) *out_mapping = visible ? 2 : 1;
	if (out_visibility) *out_visibility = visible ? 2 : 1;
	if (out_active) *out_active = active ? 2 : 1;
	if (out_focused) *out_focused = active && GetFocus() == state->hwnd ? 2 : 1;
	if (out_minimized) *out_minimized = IsIconic(state->hwnd) ? 2 : 1;
	if (out_maximized) *out_maximized = IsZoomed(state->hwnd) ? 2 : 1;
	if (out_fullscreen) {
		*out_fullscreen = state->fullscreen_known ? (state->fullscreen ? 2 : 1) : 0;
	}
	if (out_position_known) *out_position_known = position_known;
	if (out_x) *out_x = position_known ? rect.left : 0;
	if (out_y) *out_y = position_known ? rect.top : 0;
	return V_MULTIWINDOW_WIN32_SERVICE_OK;
}

static inline int v_multiwindow_win32_service_show_window(void *state_ptr) {
	VMultiwindowWin32ServiceState *state =
		(VMultiwindowWin32ServiceState *)state_ptr;
	int authority = v_multiwindow_win32_service_authority(state);
	if (authority != V_MULTIWINDOW_WIN32_SERVICE_OK) return authority;
#if defined(V_MULTIWINDOW_WIN32_SERVICE_TEST)
	if (v_multiwindow_win32_service_test_show_failure) {
		return V_MULTIWINDOW_WIN32_SERVICE_UNAVAILABLE;
	}
#endif
	ShowWindow(state->hwnd, SW_SHOWNOACTIVATE);
	UpdateWindow(state->hwnd);
	return IsWindowVisible(state->hwnd) ? V_MULTIWINDOW_WIN32_SERVICE_OK
		: V_MULTIWINDOW_WIN32_SERVICE_UNAVAILABLE;
}

static inline int v_multiwindow_win32_service_hide_window(void *state_ptr) {
	VMultiwindowWin32ServiceState *state =
		(VMultiwindowWin32ServiceState *)state_ptr;
	int authority = v_multiwindow_win32_service_authority(state);
	if (authority != V_MULTIWINDOW_WIN32_SERVICE_OK) return authority;
	ShowWindow(state->hwnd, SW_HIDE);
	return !IsWindowVisible(state->hwnd) ? V_MULTIWINDOW_WIN32_SERVICE_OK
		: V_MULTIWINDOW_WIN32_SERVICE_UNAVAILABLE;
}

static inline int v_multiwindow_win32_service_focus_window(void *state_ptr) {
	VMultiwindowWin32ServiceState *state =
		(VMultiwindowWin32ServiceState *)state_ptr;
	int authority = v_multiwindow_win32_service_authority(state);
	if (authority != V_MULTIWINDOW_WIN32_SERVICE_OK) return authority;
	if (IsIconic(state->hwnd)) {
		ShowWindow(state->hwnd, SW_RESTORE);
	}
#if defined(V_MULTIWINDOW_WIN32_SERVICE_TEST)
	if (!v_multiwindow_win32_service_test_focus_refused) {
		SetForegroundWindow(state->hwnd);
	}
#else
	SetForegroundWindow(state->hwnd);
#endif
	if (GetForegroundWindow() == state->hwnd) {
		SetFocus(state->hwnd);
	}
	return V_MULTIWINDOW_WIN32_SERVICE_OK;
}

static inline int v_multiwindow_win32_service_raise_window(void *state_ptr) {
	VMultiwindowWin32ServiceState *state =
		(VMultiwindowWin32ServiceState *)state_ptr;
	int authority = v_multiwindow_win32_service_authority(state);
	if (authority != V_MULTIWINDOW_WIN32_SERVICE_OK) return authority;
	return SetWindowPos(state->hwnd, HWND_TOP, 0, 0, 0, 0,
		SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOOWNERZORDER)
		? V_MULTIWINDOW_WIN32_SERVICE_OK : V_MULTIWINDOW_WIN32_SERVICE_UNAVAILABLE;
}

static inline int v_multiwindow_win32_service_set_window_position(void *state_ptr,
	int x, int y) {
	VMultiwindowWin32ServiceState *state =
		(VMultiwindowWin32ServiceState *)state_ptr;
	int authority = v_multiwindow_win32_service_authority(state);
	if (authority != V_MULTIWINDOW_WIN32_SERVICE_OK) return authority;
	return SetWindowPos(state->hwnd, NULL, x, y, 0, 0,
		SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOOWNERZORDER)
		? V_MULTIWINDOW_WIN32_SERVICE_OK : V_MULTIWINDOW_WIN32_SERVICE_UNAVAILABLE;
}

static inline int v_multiwindow_win32_service_minimize_window(void *state_ptr) {
	VMultiwindowWin32ServiceState *state =
		(VMultiwindowWin32ServiceState *)state_ptr;
	int authority = v_multiwindow_win32_service_authority(state);
	if (authority != V_MULTIWINDOW_WIN32_SERVICE_OK) return authority;
	ShowWindow(state->hwnd, SW_MINIMIZE);
	return IsIconic(state->hwnd) ? V_MULTIWINDOW_WIN32_SERVICE_OK
		: V_MULTIWINDOW_WIN32_SERVICE_UNAVAILABLE;
}

static inline int v_multiwindow_win32_service_maximize_window(void *state_ptr) {
	VMultiwindowWin32ServiceState *state =
		(VMultiwindowWin32ServiceState *)state_ptr;
	int authority = v_multiwindow_win32_service_authority(state);
	if (authority != V_MULTIWINDOW_WIN32_SERVICE_OK) return authority;
	ShowWindow(state->hwnd, SW_MAXIMIZE);
	return IsZoomed(state->hwnd) ? V_MULTIWINDOW_WIN32_SERVICE_OK
		: V_MULTIWINDOW_WIN32_SERVICE_UNAVAILABLE;
}

static inline int v_multiwindow_win32_service_set_fullscreen(void *state_ptr,
	int enabled) {
	VMultiwindowWin32ServiceState *state =
		(VMultiwindowWin32ServiceState *)state_ptr;
	int authority = v_multiwindow_win32_service_authority(state);
	if (authority != V_MULTIWINDOW_WIN32_SERVICE_OK) return authority;
	enabled = enabled != 0;
	if (!state->fullscreen_known) {
		return V_MULTIWINDOW_WIN32_SERVICE_UNAVAILABLE;
	}
	if (state->fullscreen == enabled) {
		return V_MULTIWINDOW_WIN32_SERVICE_OK;
	}
	if (enabled) {
		if (!v_multiwindow_win32_service_capture_restore(state)) {
			return V_MULTIWINDOW_WIN32_SERVICE_UNAVAILABLE;
		}
		HMONITOR monitor = MonitorFromWindow(state->hwnd, MONITOR_DEFAULTTONEAREST);
		MONITORINFO monitor_info;
		ZeroMemory(&monitor_info, sizeof(monitor_info));
		monitor_info.cbSize = sizeof(monitor_info);
		if (!monitor || !GetMonitorInfoW(monitor, &monitor_info)) {
			return V_MULTIWINDOW_WIN32_SERVICE_UNAVAILABLE;
		}
		LONG_PTR fullscreen_style =
			(state->windowed_style & ~(LONG_PTR)WS_OVERLAPPEDWINDOW) | WS_POPUP;
		LONG_PTR fullscreen_ex_style =
			state->windowed_ex_style & ~(LONG_PTR)WS_EX_WINDOWEDGE;
		if (!v_multiwindow_win32_service_set_long_ptr(state->hwnd, GWL_STYLE,
			fullscreen_style)
			|| !v_multiwindow_win32_service_set_long_ptr(state->hwnd, GWL_EXSTYLE,
				fullscreen_ex_style)
			|| !SetWindowPos(state->hwnd, HWND_TOP, monitor_info.rcMonitor.left,
				monitor_info.rcMonitor.top,
				monitor_info.rcMonitor.right - monitor_info.rcMonitor.left,
				monitor_info.rcMonitor.bottom - monitor_info.rcMonitor.top,
				SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_FRAMECHANGED)) {
			v_multiwindow_win32_service_set_long_ptr(state->hwnd, GWL_STYLE,
				state->windowed_style);
			v_multiwindow_win32_service_set_long_ptr(state->hwnd, GWL_EXSTYLE,
				state->windowed_ex_style);
			SetWindowPlacement(state->hwnd, &state->windowed_placement);
			SetWindowPos(state->hwnd, NULL, 0, 0, 0, 0,
				SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE
					| SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
			return V_MULTIWINDOW_WIN32_SERVICE_UNAVAILABLE;
		}
			state->fullscreen = 1;
			state->fullscreen_known = 1;
			return V_MULTIWINDOW_WIN32_SERVICE_OK;
	}
	if (!state->restore_valid) {
		return V_MULTIWINDOW_WIN32_SERVICE_UNAVAILABLE;
	}
	VMultiwindowWin32NativeWindowSnapshot fullscreen_snapshot;
	if (!v_multiwindow_win32_service_capture_native_snapshot(state->hwnd,
		&fullscreen_snapshot)) {
		return V_MULTIWINDOW_WIN32_SERVICE_UNAVAILABLE;
	}
	int restored =
		v_multiwindow_win32_service_set_long_ptr(state->hwnd, GWL_STYLE,
			state->windowed_style);
#if defined(V_MULTIWINDOW_WIN32_SERVICE_TEST)
	if (restored
		&& v_multiwindow_win32_service_test_fullscreen_exit_failure
			== V_MULTIWINDOW_WIN32_SERVICE_TEST_FAIL_EXIT_EXSTYLE) {
		restored = 0;
	}
#endif
	if (restored) {
		restored = v_multiwindow_win32_service_set_long_ptr(state->hwnd,
			GWL_EXSTYLE, state->windowed_ex_style);
	}
#if defined(V_MULTIWINDOW_WIN32_SERVICE_TEST)
	if (restored
		&& v_multiwindow_win32_service_test_fullscreen_exit_failure
			== V_MULTIWINDOW_WIN32_SERVICE_TEST_FAIL_EXIT_PLACEMENT) {
		restored = 0;
	}
#endif
	if (restored) {
		restored = SetWindowPlacement(state->hwnd, &state->windowed_placement);
	}
#if defined(V_MULTIWINDOW_WIN32_SERVICE_TEST)
	if (restored
		&& v_multiwindow_win32_service_test_fullscreen_exit_failure
			== V_MULTIWINDOW_WIN32_SERVICE_TEST_FAIL_EXIT_POSITION) {
		restored = 0;
	}
#endif
	if (restored) {
		restored = SetWindowPos(state->hwnd, NULL, 0, 0, 0, 0,
			SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE
				| SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
	}
	if (restored) {
		restored = v_multiwindow_win32_service_restore_visibility(state->hwnd,
			state->windowed_visible, state->windowed_placement.showCmd);
	}
	if (!restored) {
		if (!v_multiwindow_win32_service_restore_native_snapshot(state->hwnd,
			&fullscreen_snapshot)) {
			state->fullscreen_known = 0;
		}
		return V_MULTIWINDOW_WIN32_SERVICE_UNAVAILABLE;
	}
	state->fullscreen = 0;
	state->fullscreen_known = 1;
	return V_MULTIWINDOW_WIN32_SERVICE_OK;
}

static inline int v_multiwindow_win32_service_restore_window(void *state_ptr) {
	VMultiwindowWin32ServiceState *state =
		(VMultiwindowWin32ServiceState *)state_ptr;
	int authority = v_multiwindow_win32_service_authority(state);
	if (authority != V_MULTIWINDOW_WIN32_SERVICE_OK) return authority;
	if (state->fullscreen) {
		return v_multiwindow_win32_service_set_fullscreen(state, 0);
	}
	ShowWindow(state->hwnd, SW_RESTORE);
	return !IsIconic(state->hwnd) && !IsZoomed(state->hwnd)
		? V_MULTIWINDOW_WIN32_SERVICE_OK : V_MULTIWINDOW_WIN32_SERVICE_UNAVAILABLE;
}

static inline void *v_multiwindow_win32_service_native_window(void *state_ptr) {
	VMultiwindowWin32ServiceState *state =
		(VMultiwindowWin32ServiceState *)state_ptr;
	return v_multiwindow_win32_service_authority(state)
		== V_MULTIWINDOW_WIN32_SERVICE_OK ? (void *)state->hwnd : NULL;
}
#endif

#endif
