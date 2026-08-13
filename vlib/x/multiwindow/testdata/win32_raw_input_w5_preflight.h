#ifndef V_MULTIWINDOW_WIN32_RAW_INPUT_W5_PREFLIGHT_H
#define V_MULTIWINDOW_WIN32_RAW_INPUT_W5_PREFLIGHT_H

#if defined(_WIN32)

#include <windows.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifndef MOUSEEVENTF_MOVE_NOCOALESCE
#define MOUSEEVENTF_MOVE_NOCOALESCE 0x2000
#endif

#ifndef RIDEV_REMOVE
#define RIDEV_REMOVE 0x00000001
#endif

#ifndef RIDEV_PAGEONLY
#define RIDEV_PAGEONLY 0x00000020
#endif

enum VMultiwindowW5PreflightStage {
	V_MULTIWINDOW_W5_STAGE_NONE = 0,
	V_MULTIWINDOW_W5_STAGE_ARGUMENTS = 1,
	V_MULTIWINDOW_W5_STAGE_APIS = 2,
	V_MULTIWINDOW_W5_STAGE_INITIAL_REGISTRATIONS = 3,
	V_MULTIWINDOW_W5_STAGE_SNAPSHOT = 4,
	V_MULTIWINDOW_W5_STAGE_CLASS = 5,
	V_MULTIWINDOW_W5_STAGE_WINDOW = 6,
	V_MULTIWINDOW_W5_STAGE_FOREGROUND = 7,
	V_MULTIWINDOW_W5_STAGE_REGISTER = 8,
	V_MULTIWINDOW_W5_STAGE_REGISTER_READBACK = 9,
	V_MULTIWINDOW_W5_STAGE_QUIET = 10,
	V_MULTIWINDOW_W5_STAGE_SEND_INPUT = 11,
	V_MULTIWINDOW_W5_STAGE_WAIT_INPUT = 12,
	V_MULTIWINDOW_W5_STAGE_DECODE_INPUT = 13,
	V_MULTIWINDOW_W5_STAGE_COMPLETE = 14
};

enum VMultiwindowW5PreflightProof {
	V_MULTIWINDOW_W5_PROOF_APIS = 1u << 0,
	V_MULTIWINDOW_W5_PROOF_INITIAL_RAW_CLEAN = 1u << 1,
	V_MULTIWINDOW_W5_PROOF_SNAPSHOT = 1u << 2,
	V_MULTIWINDOW_W5_PROOF_WINDOW = 1u << 3,
	V_MULTIWINDOW_W5_PROOF_FOREGROUND = 1u << 4,
	V_MULTIWINDOW_W5_PROOF_REGISTERED = 1u << 5,
	V_MULTIWINDOW_W5_PROOF_SEND_INPUT = 1u << 6,
	V_MULTIWINDOW_W5_PROOF_WM_INPUT = 1u << 7,
	V_MULTIWINDOW_W5_PROOF_SOURCE = 1u << 8,
	V_MULTIWINDOW_W5_PROOF_EXTRA_TAG = 1u << 9,
	V_MULTIWINDOW_W5_PROOF_HRAWINPUT = 1u << 10,
	V_MULTIWINDOW_W5_PROOF_RAW_MOUSE = 1u << 11,
	V_MULTIWINDOW_W5_PROOF_RELATIVE_NONZERO = 1u << 12,
	V_MULTIWINDOW_W5_PROOF_ALL = 0x1fffu
};

enum VMultiwindowW5PreflightCleanup {
	V_MULTIWINDOW_W5_CLEANUP_QUIET = 1u << 0,
	V_MULTIWINDOW_W5_CLEANUP_RAW_REMOVE = 1u << 1,
	V_MULTIWINDOW_W5_CLEANUP_INVENTORY = 1u << 2,
	V_MULTIWINDOW_W5_CLEANUP_CURSOR = 1u << 3,
	V_MULTIWINDOW_W5_CLEANUP_DESKTOP_STATE = 1u << 4,
	V_MULTIWINDOW_W5_CLEANUP_WINDOW = 1u << 5,
	V_MULTIWINDOW_W5_CLEANUP_CLASS = 1u << 6,
	V_MULTIWINDOW_W5_CLEANUP_ALL = 0x7fu
};

enum VMultiwindowW5InputMessageDeviceType {
	V_MULTIWINDOW_W5_IMDT_UNAVAILABLE = 0,
	V_MULTIWINDOW_W5_IMDT_KEYBOARD = 1,
	V_MULTIWINDOW_W5_IMDT_MOUSE = 2,
	V_MULTIWINDOW_W5_IMDT_TOUCH = 4,
	V_MULTIWINDOW_W5_IMDT_PEN = 8
};

enum VMultiwindowW5InputMessageOriginId {
	V_MULTIWINDOW_W5_IMO_UNAVAILABLE = 0,
	V_MULTIWINDOW_W5_IMO_HARDWARE = 1,
	V_MULTIWINDOW_W5_IMO_INJECTED = 2,
	V_MULTIWINDOW_W5_IMO_SYSTEM = 4
};

typedef struct VMultiwindowW5InputMessageSource {
	DWORD device_type;
	DWORD origin_id;
} VMultiwindowW5InputMessageSource;

typedef UINT(WINAPI *VMultiwindowW5GetRegisteredRawInputDevices)(
	PRAWINPUTDEVICE, PUINT, UINT);
typedef BOOL(WINAPI *VMultiwindowW5RegisterRawInputDevices)(
	const RAWINPUTDEVICE *, UINT, UINT);
typedef UINT(WINAPI *VMultiwindowW5GetRawInputData)(
	HRAWINPUT, UINT, LPVOID, PUINT, UINT);
typedef UINT(WINAPI *VMultiwindowW5SendInput)(UINT, LPINPUT, int);
typedef BOOL(WINAPI *VMultiwindowW5GetCurrentInputMessageSource)(
	VMultiwindowW5InputMessageSource *);
typedef LPARAM(WINAPI *VMultiwindowW5GetMessageExtraInfo)(void);

typedef struct VMultiwindowW5Apis {
	VMultiwindowW5GetRegisteredRawInputDevices get_registered_raw_input_devices;
	VMultiwindowW5RegisterRawInputDevices register_raw_input_devices;
	VMultiwindowW5GetRawInputData get_raw_input_data;
	VMultiwindowW5SendInput send_input;
	VMultiwindowW5GetCurrentInputMessageSource get_current_input_message_source;
	VMultiwindowW5GetMessageExtraInfo get_message_extra_info;
} VMultiwindowW5Apis;

typedef struct VMultiwindowW5RawInventory {
	RAWINPUTDEVICE *items;
	UINT count;
} VMultiwindowW5RawInventory;

typedef struct VMultiwindowW5Snapshot {
	VMultiwindowW5RawInventory registrations;
	RECT clip;
	POINT cursor;
	CURSORINFO cursor_info;
	HWND capture;
	HWND foreground;
	HWND focus;
	int registrations_valid;
	int clip_valid;
	int cursor_valid;
	int cursor_info_valid;
} VMultiwindowW5Snapshot;

typedef struct VMultiwindowW5Context {
	VMultiwindowW5Apis apis;
	VMultiwindowW5Snapshot snapshot;
	HINSTANCE instance;
	const wchar_t *class_name;
	HWND window;
	ATOM class_atom;
	uint32_t proof;
	uint32_t cleanup;
	uint32_t primary_stage;
	uint32_t primary_error;
	uint32_t cleanup_error;
	ULONG_PTR expected_tag;
	LONG raw_dx;
	LONG raw_dy;
	int armed;
	int exact_raw_inputs;
	int unexpected_raw_inputs;
	int raw_registered;
	int destroying;
	int saw_quit;
	int quit_code;
} VMultiwindowW5Context;

static VMultiwindowW5Context *v_multiwindow_w5_preflight_context = NULL;

static void v_multiwindow_w5_set_primary(VMultiwindowW5Context *context,
	uint32_t stage, uint32_t error_code) {
	if (context && context->primary_stage == V_MULTIWINDOW_W5_STAGE_NONE) {
		context->primary_stage = stage;
		context->primary_error = error_code;
	}
}

static void v_multiwindow_w5_set_cleanup_error(
	VMultiwindowW5Context *context, uint32_t error_code) {
	if (context && context->cleanup_error == 0) {
		context->cleanup_error = error_code ? error_code : ERROR_INVALID_DATA;
	}
}

static int v_multiwindow_w5_resolve_apis(VMultiwindowW5Apis *apis) {
	HMODULE user32;
	if (!apis) {
		return 0;
	}
	memset(apis, 0, sizeof(*apis));
	user32 = GetModuleHandleW(L"user32.dll");
	if (!user32) {
		return 0;
	}
	apis->get_registered_raw_input_devices =
		(VMultiwindowW5GetRegisteredRawInputDevices)GetProcAddress(user32,
			"GetRegisteredRawInputDevices");
	apis->register_raw_input_devices =
		(VMultiwindowW5RegisterRawInputDevices)GetProcAddress(user32,
			"RegisterRawInputDevices");
	apis->get_raw_input_data =
		(VMultiwindowW5GetRawInputData)GetProcAddress(user32,
			"GetRawInputData");
	apis->send_input = (VMultiwindowW5SendInput)GetProcAddress(user32,
		"SendInput");
	apis->get_current_input_message_source =
		(VMultiwindowW5GetCurrentInputMessageSource)GetProcAddress(user32,
			"GetCurrentInputMessageSource");
	apis->get_message_extra_info =
		(VMultiwindowW5GetMessageExtraInfo)GetProcAddress(user32,
			"GetMessageExtraInfo");
	return apis->get_registered_raw_input_devices
		&& apis->register_raw_input_devices && apis->get_raw_input_data
		&& apis->send_input && apis->get_current_input_message_source
		&& apis->get_message_extra_info;
}

static void v_multiwindow_w5_free_inventory(
	VMultiwindowW5RawInventory *inventory) {
	if (!inventory) {
		return;
	}
	free(inventory->items);
	inventory->items = NULL;
	inventory->count = 0;
}

static int v_multiwindow_w5_query_inventory(
	VMultiwindowW5GetRegisteredRawInputDevices query,
	VMultiwindowW5RawInventory *inventory, uint32_t *error_code) {
	UINT count = 0;
	UINT copied;
	UINT result;
	RAWINPUTDEVICE *items;
	if (!query || !inventory) {
		if (error_code) {
			*error_code = ERROR_INVALID_PARAMETER;
		}
		return 0;
	}
	memset(inventory, 0, sizeof(*inventory));
	SetLastError(ERROR_SUCCESS);
	result = query(NULL, &count, sizeof(RAWINPUTDEVICE));
	if (result != 0) {
		if (error_code) {
			*error_code = GetLastError() ? GetLastError() : ERROR_INVALID_DATA;
		}
		return 0;
	}
	if (count == 0) {
		return 1;
	}
	items = (RAWINPUTDEVICE *)calloc((size_t)count, sizeof(RAWINPUTDEVICE));
	if (!items) {
		if (error_code) {
			*error_code = ERROR_NOT_ENOUGH_MEMORY;
		}
		return 0;
	}
	copied = count;
	SetLastError(ERROR_SUCCESS);
	result = query(items, &copied, sizeof(RAWINPUTDEVICE));
	if (result == (UINT)-1 || result != copied || copied > count) {
		if (error_code) {
			*error_code = GetLastError() ? GetLastError() : ERROR_INVALID_DATA;
		}
		free(items);
		return 0;
	}
	inventory->items = items;
	inventory->count = copied;
	return 1;
}

static int v_multiwindow_w5_registration_equal(const RAWINPUTDEVICE *left,
	const RAWINPUTDEVICE *right) {
	return left && right && left->usUsagePage == right->usUsagePage
		&& left->usUsage == right->usUsage && left->dwFlags == right->dwFlags
		&& left->hwndTarget == right->hwndTarget;
}

static int v_multiwindow_w5_inventory_equal(
	const VMultiwindowW5RawInventory *left,
	const VMultiwindowW5RawInventory *right) {
	unsigned char *matched;
	UINT left_index;
	if (!left || !right || left->count != right->count) {
		return 0;
	}
	if (left->count == 0) {
		return 1;
	}
	matched = (unsigned char *)calloc((size_t)right->count,
		sizeof(unsigned char));
	if (!matched) {
		return 0;
	}
	for (left_index = 0; left_index < left->count; left_index++) {
		UINT right_index;
		int found = 0;
		for (right_index = 0; right_index < right->count; right_index++) {
			if (!matched[right_index]
				&& v_multiwindow_w5_registration_equal(
					&left->items[left_index], &right->items[right_index])) {
				matched[right_index] = 1;
				found = 1;
				break;
			}
		}
		if (!found) {
			free(matched);
			return 0;
		}
	}
	free(matched);
	return 1;
}

static int v_multiwindow_w5_inventory_has_forbidden_raw_mouse(
	const VMultiwindowW5RawInventory *inventory) {
	UINT index;
	if (!inventory) {
		return 1;
	}
	for (index = 0; index < inventory->count; index++) {
		const RAWINPUTDEVICE *item = &inventory->items[index];
		if (item->usUsagePage == 0x01 && item->usUsage == 0x02) {
			return 1;
		}
		if (item->usUsagePage == 0x01 && item->usUsage == 0
			&& (item->dwFlags & RIDEV_PAGEONLY) != 0) {
			return 1;
		}
	}
	return 0;
}

static int v_multiwindow_w5_inventory_matches_registered_mouse(
	const VMultiwindowW5RawInventory *initial,
	const VMultiwindowW5RawInventory *current, HWND target) {
	VMultiwindowW5RawInventory without_mouse;
	RAWINPUTDEVICE *items;
	UINT source_index;
	UINT target_index = 0;
	int exact_mouse_count = 0;
	if (!initial || !current || !target || current->count != initial->count + 1) {
		return 0;
	}
	memset(&without_mouse, 0, sizeof(without_mouse));
	if (initial->count > 0) {
		items = (RAWINPUTDEVICE *)calloc((size_t)initial->count,
			sizeof(RAWINPUTDEVICE));
		if (!items) {
			return 0;
		}
		without_mouse.items = items;
	}
	without_mouse.count = initial->count;
	for (source_index = 0; source_index < current->count; source_index++) {
		const RAWINPUTDEVICE *item = &current->items[source_index];
		if (item->usUsagePage == 0x01 && item->usUsage == 0x02
			&& item->dwFlags == 0 && item->hwndTarget == target) {
			exact_mouse_count++;
			continue;
		}
		if (target_index >= without_mouse.count) {
			v_multiwindow_w5_free_inventory(&without_mouse);
			return 0;
		}
		without_mouse.items[target_index++] = *item;
	}
	if (exact_mouse_count != 1 || target_index != without_mouse.count
		|| !v_multiwindow_w5_inventory_equal(initial, &without_mouse)) {
		v_multiwindow_w5_free_inventory(&without_mouse);
		return 0;
	}
	v_multiwindow_w5_free_inventory(&without_mouse);
	return 1;
}

static RECT v_multiwindow_w5_virtual_screen(void) {
	RECT screen;
	screen.left = GetSystemMetrics(SM_XVIRTUALSCREEN);
	screen.top = GetSystemMetrics(SM_YVIRTUALSCREEN);
	screen.right = screen.left + GetSystemMetrics(SM_CXVIRTUALSCREEN);
	screen.bottom = screen.top + GetSystemMetrics(SM_CYVIRTUALSCREEN);
	return screen;
}

static int v_multiwindow_w5_cursor_info_equal(const CURSORINFO *left,
	const CURSORINFO *right) {
	return left && right && left->flags == right->flags
		&& left->hCursor == right->hCursor
		&& left->ptScreenPos.x == right->ptScreenPos.x
		&& left->ptScreenPos.y == right->ptScreenPos.y;
}

static void v_multiwindow_w5_observe_raw_input(
	VMultiwindowW5Context *context, WPARAM wparam, LPARAM lparam) {
	VMultiwindowW5InputMessageSource source;
	LPARAM message_extra;
	UINT size = 0;
	UINT copied;
	UINT read;
	unsigned char *bytes = NULL;
	RAWINPUT *raw;
	uint32_t error_code = ERROR_INVALID_DATA;
	if (!context || !context->armed || context->exact_raw_inputs != 0) {
		if (context) {
			context->unexpected_raw_inputs++;
			v_multiwindow_w5_set_primary(context,
				V_MULTIWINDOW_W5_STAGE_WAIT_INPUT, ERROR_BUSY);
		}
		return;
	}
	memset(&source, 0, sizeof(source));
	SetLastError(ERROR_SUCCESS);
	if (!context->apis.get_current_input_message_source(&source)) {
		error_code = GetLastError() ? GetLastError() : ERROR_INVALID_DATA;
		goto invalid;
	}
	message_extra = context->apis.get_message_extra_info();
	if ((UINT)(wparam & 0xffu) != RIM_INPUT) {
		goto invalid;
	}
	context->proof |= V_MULTIWINDOW_W5_PROOF_WM_INPUT;
	if (source.device_type != V_MULTIWINDOW_W5_IMDT_MOUSE
		|| source.origin_id != V_MULTIWINDOW_W5_IMO_INJECTED) {
		goto invalid;
	}
	context->proof |= V_MULTIWINDOW_W5_PROOF_SOURCE;
	if ((ULONG_PTR)message_extra != context->expected_tag) {
		goto invalid;
	}
	context->proof |= V_MULTIWINDOW_W5_PROOF_EXTRA_TAG;
	SetLastError(ERROR_SUCCESS);
	if (context->apis.get_raw_input_data((HRAWINPUT)lparam, RID_INPUT, NULL,
		&size, sizeof(RAWINPUTHEADER)) != 0
		|| size < sizeof(RAWINPUTHEADER) || size > 64u * 1024u) {
		error_code = GetLastError() ? GetLastError() : ERROR_INVALID_DATA;
		goto invalid;
	}
	bytes = (unsigned char *)malloc((size_t)size);
	if (!bytes) {
		error_code = ERROR_NOT_ENOUGH_MEMORY;
		goto invalid;
	}
	copied = size;
	SetLastError(ERROR_SUCCESS);
	read = context->apis.get_raw_input_data((HRAWINPUT)lparam, RID_INPUT,
		bytes, &copied, sizeof(RAWINPUTHEADER));
	if (read == (UINT)-1 || read != size || copied != size) {
		error_code = GetLastError() ? GetLastError() : ERROR_INVALID_DATA;
		goto invalid;
	}
	context->proof |= V_MULTIWINDOW_W5_PROOF_HRAWINPUT;
	raw = (RAWINPUT *)bytes;
	if (raw->header.dwSize != size || size < sizeof(RAWINPUT)
		|| raw->header.dwType != RIM_TYPEMOUSE) {
		goto invalid;
	}
	context->proof |= V_MULTIWINDOW_W5_PROOF_RAW_MOUSE;
	context->raw_dx = raw->data.mouse.lLastX;
	context->raw_dy = raw->data.mouse.lLastY;
	if ((raw->data.mouse.usFlags & MOUSE_MOVE_ABSOLUTE) != 0
		|| (context->raw_dx == 0 && context->raw_dy == 0)) {
		goto invalid;
	}
	context->proof |= V_MULTIWINDOW_W5_PROOF_RELATIVE_NONZERO;
	context->exact_raw_inputs = 1;
	free(bytes);
	return;

invalid:
	free(bytes);
	context->unexpected_raw_inputs++;
	v_multiwindow_w5_set_primary(context,
		V_MULTIWINDOW_W5_STAGE_DECODE_INPUT, error_code);
}

static LRESULT CALLBACK v_multiwindow_w5_preflight_window_proc(HWND window,
	UINT message, WPARAM wparam, LPARAM lparam) {
	VMultiwindowW5Context *context = v_multiwindow_w5_preflight_context;
	if (message == WM_INPUT) {
		v_multiwindow_w5_observe_raw_input(context, wparam, lparam);
	}
	if (context && !context->destroying
		&& (message == WM_CLOSE || message == WM_DESTROY)) {
		v_multiwindow_w5_set_primary(context,
			V_MULTIWINDOW_W5_STAGE_WAIT_INPUT, ERROR_CANCELLED);
	}
	return DefWindowProcW(window, message, wparam, lparam);
}

static int v_multiwindow_w5_pump_messages(VMultiwindowW5Context *context,
	int *activity) {
	MSG message;
	UINT processed = 0;
	if (activity) {
		*activity = 0;
	}
	while (processed < 4096u
		&& PeekMessageW(&message, NULL, 0, 0, PM_REMOVE)) {
		processed++;
		if (activity) {
			*activity = 1;
		}
		if (message.message == WM_QUIT) {
			if (context && !context->saw_quit) {
				context->saw_quit = 1;
				context->quit_code = (int)message.wParam;
				v_multiwindow_w5_set_primary(context,
					V_MULTIWINDOW_W5_STAGE_WAIT_INPUT, ERROR_CANCELLED);
			}
			continue;
		}
		TranslateMessage(&message);
		DispatchMessageW(&message);
	}
	if (processed == 4096u
		&& PeekMessageW(&message, NULL, 0, 0, PM_NOREMOVE)) {
		v_multiwindow_w5_set_primary(context,
			V_MULTIWINDOW_W5_STAGE_WAIT_INPUT, ERROR_BUSY);
		return 0;
	}
	return context && !context->saw_quit;
}

static int v_multiwindow_w5_pump_until_quiet(
	VMultiwindowW5Context *context, int attempts) {
	int quiet = 0;
	int index;
	for (index = 0; index < attempts; index++) {
		int activity = 0;
		if (!v_multiwindow_w5_pump_messages(context, &activity)) {
			return 0;
		}
		if (activity) {
			quiet = 0;
		} else {
			quiet++;
			if (quiet >= 3) {
				return 1;
			}
		}
		Sleep(5);
	}
	return 0;
}

static int v_multiwindow_w5_wait_for_foreground(
	VMultiwindowW5Context *context, DWORD timeout_ms) {
	DWORD started = GetTickCount();
	if (!context || !context->window) {
		return 0;
	}
	ShowWindow(context->window, SW_SHOWNORMAL);
	UpdateWindow(context->window);
	BringWindowToTop(context->window);
	SetForegroundWindow(context->window);
	SetActiveWindow(context->window);
	SetFocus(context->window);
	for (;;) {
		int activity = 0;
		if (!v_multiwindow_w5_pump_messages(context, &activity)) {
			return 0;
		}
		if (GetForegroundWindow() == context->window
			&& GetFocus() == context->window) {
			return 1;
		}
		if ((DWORD)(GetTickCount() - started) >= timeout_ms) {
			return 0;
		}
		Sleep(5);
	}
}

static int v_multiwindow_w5_wait_for_raw_input(
	VMultiwindowW5Context *context, DWORD timeout_ms) {
	DWORD started = GetTickCount();
	int quiet = 0;
	for (;;) {
		int activity = 0;
		if (!v_multiwindow_w5_pump_messages(context, &activity)) {
			return 0;
		}
		if (context->primary_stage != V_MULTIWINDOW_W5_STAGE_NONE
			|| context->unexpected_raw_inputs != 0
			|| context->exact_raw_inputs > 1) {
			return 0;
		}
		if (context->exact_raw_inputs == 1) {
			if (activity) {
				quiet = 0;
			} else {
				quiet++;
				if (quiet >= 3) {
					return 1;
				}
			}
		}
		if ((DWORD)(GetTickCount() - started) >= timeout_ms) {
			return 0;
		}
		Sleep(5);
	}
}

static int v_multiwindow_w5_desktop_state_restored(
	const VMultiwindowW5Snapshot *snapshot) {
	RECT clip;
	POINT cursor;
	CURSORINFO cursor_info;
	if (!snapshot || !snapshot->clip_valid || !snapshot->cursor_valid
		|| !snapshot->cursor_info_valid) {
		return 0;
	}
	memset(&cursor_info, 0, sizeof(cursor_info));
	cursor_info.cbSize = sizeof(cursor_info);
	if (!GetClipCursor(&clip) || !GetCursorPos(&cursor)
		|| !GetCursorInfo(&cursor_info)) {
		return 0;
	}
	return EqualRect(&clip, &snapshot->clip)
		&& cursor.x == snapshot->cursor.x && cursor.y == snapshot->cursor.y
		&& v_multiwindow_w5_cursor_info_equal(&cursor_info,
			&snapshot->cursor_info)
		&& GetCapture() == snapshot->capture && GetFocus() == snapshot->focus;
}

static void v_multiwindow_w5_cleanup(VMultiwindowW5Context *context) {
	VMultiwindowW5RawInventory final_inventory;
	uint32_t error_code = 0;
	int quiet_ok;
	if (!context) {
		return;
	}
	memset(&final_inventory, 0, sizeof(final_inventory));
	quiet_ok = v_multiwindow_w5_pump_until_quiet(context, 40);
	if (context->raw_registered) {
		RAWINPUTDEVICE remove_device;
		memset(&remove_device, 0, sizeof(remove_device));
		remove_device.usUsagePage = 0x01;
		remove_device.usUsage = 0x02;
		remove_device.dwFlags = RIDEV_REMOVE;
		remove_device.hwndTarget = NULL;
		SetLastError(ERROR_SUCCESS);
		if (context->apis.register_raw_input_devices(&remove_device, 1,
			sizeof(remove_device))) {
			context->raw_registered = 0;
			context->cleanup |= V_MULTIWINDOW_W5_CLEANUP_RAW_REMOVE;
		} else {
			v_multiwindow_w5_set_cleanup_error(context,
				GetLastError() ? GetLastError() : ERROR_INVALID_DATA);
		}
	} else {
		context->cleanup |= V_MULTIWINDOW_W5_CLEANUP_RAW_REMOVE;
	}
	context->armed = 0;
	if (!v_multiwindow_w5_pump_until_quiet(context, 40)) {
		quiet_ok = 0;
	}
	if (quiet_ok) {
		context->cleanup |= V_MULTIWINDOW_W5_CLEANUP_QUIET;
	} else {
		v_multiwindow_w5_set_cleanup_error(context, WAIT_TIMEOUT);
	}
	if (context->unexpected_raw_inputs != 0 || context->saw_quit) {
		v_multiwindow_w5_set_cleanup_error(context,
			context->saw_quit ? ERROR_CANCELLED : ERROR_BUSY);
	}
	if (context->snapshot.registrations_valid
		&& v_multiwindow_w5_query_inventory(
			context->apis.get_registered_raw_input_devices,
			&final_inventory, &error_code)
		&& v_multiwindow_w5_inventory_equal(
			&context->snapshot.registrations, &final_inventory)) {
		context->cleanup |= V_MULTIWINDOW_W5_CLEANUP_INVENTORY;
	} else if (!context->snapshot.registrations_valid
		&& !context->raw_registered) {
		context->cleanup |= V_MULTIWINDOW_W5_CLEANUP_INVENTORY;
	} else {
		v_multiwindow_w5_set_cleanup_error(context,
			error_code ? error_code : ERROR_INVALID_DATA);
	}
	v_multiwindow_w5_free_inventory(&final_inventory);
	if (context->window && IsWindow(context->window)) {
		context->destroying = 1;
		SetLastError(ERROR_SUCCESS);
		if (DestroyWindow(context->window)) {
			context->cleanup |= V_MULTIWINDOW_W5_CLEANUP_WINDOW;
		} else {
			v_multiwindow_w5_set_cleanup_error(context,
				GetLastError() ? GetLastError() : ERROR_INVALID_DATA);
		}
	} else if (!context->window || context->destroying) {
		context->cleanup |= V_MULTIWINDOW_W5_CLEANUP_WINDOW;
	} else {
		v_multiwindow_w5_set_cleanup_error(context, ERROR_INVALID_HANDLE);
	}
	context->window = NULL;
	if (context->class_atom) {
		SetLastError(ERROR_SUCCESS);
		if (UnregisterClassW(context->class_name, context->instance)) {
			context->class_atom = 0;
			context->cleanup |= V_MULTIWINDOW_W5_CLEANUP_CLASS;
		} else {
			v_multiwindow_w5_set_cleanup_error(context,
				GetLastError() ? GetLastError() : ERROR_INVALID_DATA);
		}
	} else {
		context->cleanup |= V_MULTIWINDOW_W5_CLEANUP_CLASS;
	}
	/* Restoring an external foreground window is intentionally best-effort. */
	if (context->snapshot.foreground
		&& IsWindow(context->snapshot.foreground)) {
		SetForegroundWindow(context->snapshot.foreground);
	}
	if (context->snapshot.focus && IsWindow(context->snapshot.focus)) {
		SetFocus(context->snapshot.focus);
	}
	if (context->snapshot.cursor_valid) {
		POINT restored;
		SetLastError(ERROR_SUCCESS);
		if (SetCursorPos(context->snapshot.cursor.x,
			context->snapshot.cursor.y) && GetCursorPos(&restored)
			&& restored.x == context->snapshot.cursor.x
			&& restored.y == context->snapshot.cursor.y) {
			context->cleanup |= V_MULTIWINDOW_W5_CLEANUP_CURSOR;
		} else {
			v_multiwindow_w5_set_cleanup_error(context,
				GetLastError() ? GetLastError() : ERROR_INVALID_DATA);
		}
	} else {
		context->cleanup |= V_MULTIWINDOW_W5_CLEANUP_CURSOR;
	}
	Sleep(10);
	if (context->snapshot.clip_valid && context->snapshot.cursor_valid
		&& context->snapshot.cursor_info_valid
		&& v_multiwindow_w5_desktop_state_restored(&context->snapshot)) {
		context->cleanup |= V_MULTIWINDOW_W5_CLEANUP_DESKTOP_STATE;
	} else if (!context->snapshot.clip_valid && !context->snapshot.cursor_valid
		&& !context->snapshot.cursor_info_valid) {
		context->cleanup |= V_MULTIWINDOW_W5_CLEANUP_DESKTOP_STATE;
	} else {
		v_multiwindow_w5_set_cleanup_error(context, ERROR_INVALID_DATA);
	}
	if (context->saw_quit) {
		PostQuitMessage(context->quit_code);
	}
	v_multiwindow_w5_free_inventory(&context->snapshot.registrations);
	v_multiwindow_w5_preflight_context = NULL;
}

static int v_multiwindow_test_win32_w5_a0_run(uint32_t timeout_ms,
	uint32_t *out_stage, uint32_t *out_proof, uint32_t *out_cleanup,
	uint32_t *out_error, uint32_t *out_cleanup_error) {
	VMultiwindowW5Context context;
	VMultiwindowW5RawInventory registered_inventory;
	WNDCLASSW window_class;
	RECT screen;
	POINT center;
	INPUT input;
	RAWINPUTDEVICE mouse_device;
	uint32_t query_error = 0;
	DWORD focus_timeout;
	int result;
	memset(&context, 0, sizeof(context));
	memset(&registered_inventory, 0, sizeof(registered_inventory));
	if (!out_stage || !out_proof || !out_cleanup || !out_error
		|| !out_cleanup_error || timeout_ms == 0) {
		if (out_stage) {
			*out_stage = V_MULTIWINDOW_W5_STAGE_ARGUMENTS;
		}
		if (out_proof) {
			*out_proof = 0;
		}
		if (out_cleanup) {
			*out_cleanup = V_MULTIWINDOW_W5_CLEANUP_ALL;
		}
		if (out_error) {
			*out_error = ERROR_INVALID_PARAMETER;
		}
		if (out_cleanup_error) {
			*out_cleanup_error = 0;
		}
		return 0;
	}
	*out_stage = V_MULTIWINDOW_W5_STAGE_NONE;
	*out_proof = 0;
	*out_cleanup = 0;
	*out_error = 0;
	*out_cleanup_error = 0;
	context.class_name = L"VMultiwindowW5RawInputPreflight";
	context.expected_tag = (ULONG_PTR)0x57354130u;
	context.instance = GetModuleHandleW(NULL);
	if (!v_multiwindow_w5_resolve_apis(&context.apis)) {
		v_multiwindow_w5_set_primary(&context,
			V_MULTIWINDOW_W5_STAGE_APIS, ERROR_PROC_NOT_FOUND);
		goto cleanup;
	}
	context.proof |= V_MULTIWINDOW_W5_PROOF_APIS;
	if (!v_multiwindow_w5_query_inventory(
		context.apis.get_registered_raw_input_devices,
		&context.snapshot.registrations, &query_error)) {
		v_multiwindow_w5_set_primary(&context,
			V_MULTIWINDOW_W5_STAGE_INITIAL_REGISTRATIONS, query_error);
		goto cleanup;
	}
	context.snapshot.registrations_valid = 1;
	if (v_multiwindow_w5_inventory_has_forbidden_raw_mouse(
		&context.snapshot.registrations)) {
		v_multiwindow_w5_set_primary(&context,
			V_MULTIWINDOW_W5_STAGE_INITIAL_REGISTRATIONS,
			ERROR_ALREADY_EXISTS);
		goto cleanup;
	}
	context.proof |= V_MULTIWINDOW_W5_PROOF_INITIAL_RAW_CLEAN;
	memset(&context.snapshot.cursor_info, 0,
		sizeof(context.snapshot.cursor_info));
	context.snapshot.cursor_info.cbSize = sizeof(context.snapshot.cursor_info);
	if (!GetClipCursor(&context.snapshot.clip)
		|| !GetCursorPos(&context.snapshot.cursor)
		|| !GetCursorInfo(&context.snapshot.cursor_info)) {
		v_multiwindow_w5_set_primary(&context,
			V_MULTIWINDOW_W5_STAGE_SNAPSHOT,
			GetLastError() ? GetLastError() : ERROR_INVALID_DATA);
		goto cleanup;
	}
	context.snapshot.clip_valid = 1;
	context.snapshot.cursor_valid = 1;
	context.snapshot.cursor_info_valid = 1;
	context.snapshot.capture = GetCapture();
	context.snapshot.foreground = GetForegroundWindow();
	context.snapshot.focus = GetFocus();
	screen = v_multiwindow_w5_virtual_screen();
	if (screen.right <= screen.left || screen.bottom <= screen.top
		|| !EqualRect(&screen, &context.snapshot.clip)) {
		v_multiwindow_w5_set_primary(&context,
			V_MULTIWINDOW_W5_STAGE_SNAPSHOT, ERROR_BUSY);
		goto cleanup;
	}
	context.proof |= V_MULTIWINDOW_W5_PROOF_SNAPSHOT;
	memset(&window_class, 0, sizeof(window_class));
	window_class.style = CS_HREDRAW | CS_VREDRAW;
	window_class.lpfnWndProc = v_multiwindow_w5_preflight_window_proc;
	window_class.hInstance = context.instance;
	window_class.hCursor = context.snapshot.cursor_info.hCursor;
	window_class.lpszClassName = context.class_name;
	SetLastError(ERROR_SUCCESS);
	context.class_atom = RegisterClassW(&window_class);
	if (!context.class_atom) {
		v_multiwindow_w5_set_primary(&context,
			V_MULTIWINDOW_W5_STAGE_CLASS,
			GetLastError() ? GetLastError() : ERROR_INVALID_DATA);
		goto cleanup;
	}
	v_multiwindow_w5_preflight_context = &context;
	center.x = context.snapshot.cursor.x;
	center.y = context.snapshot.cursor.y;
	if (center.x < screen.left + 96) {
		center.x = screen.left + 96;
	}
	if (center.x > screen.right - 96) {
		center.x = screen.right - 96;
	}
	if (center.y < screen.top + 64) {
		center.y = screen.top + 64;
	}
	if (center.y > screen.bottom - 64) {
		center.y = screen.bottom - 64;
	}
	SetLastError(ERROR_SUCCESS);
	context.window = CreateWindowExW(WS_EX_TOOLWINDOW, context.class_name,
		L"V multiwindow W5 raw input preflight",
		WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU,
		center.x - 80, center.y - 48, 160, 96, NULL, NULL,
		context.instance, NULL);
	if (!context.window) {
		v_multiwindow_w5_set_primary(&context,
			V_MULTIWINDOW_W5_STAGE_WINDOW,
			GetLastError() ? GetLastError() : ERROR_INVALID_HANDLE);
		goto cleanup;
	}
	context.proof |= V_MULTIWINDOW_W5_PROOF_WINDOW;
	focus_timeout = timeout_ms < 2000u ? timeout_ms : 2000u;
	if (!v_multiwindow_w5_wait_for_foreground(&context, focus_timeout)
		|| GetForegroundWindow() != context.window
		|| GetFocus() != context.window) {
		v_multiwindow_w5_set_primary(&context,
			V_MULTIWINDOW_W5_STAGE_FOREGROUND, ERROR_ACCESS_DENIED);
		goto cleanup;
	}
	if (!SetCursorPos(center.x, center.y)) {
		v_multiwindow_w5_set_primary(&context,
			V_MULTIWINDOW_W5_STAGE_FOREGROUND,
			GetLastError() ? GetLastError() : ERROR_ACCESS_DENIED);
		goto cleanup;
	}
	context.proof |= V_MULTIWINDOW_W5_PROOF_FOREGROUND;
	if (!v_multiwindow_w5_pump_until_quiet(&context, 40)
		|| context.primary_stage != V_MULTIWINDOW_W5_STAGE_NONE) {
		v_multiwindow_w5_set_primary(&context,
			V_MULTIWINDOW_W5_STAGE_QUIET, WAIT_TIMEOUT);
		goto cleanup;
	}
	memset(&mouse_device, 0, sizeof(mouse_device));
	mouse_device.usUsagePage = 0x01;
	mouse_device.usUsage = 0x02;
	mouse_device.dwFlags = 0;
	mouse_device.hwndTarget = context.window;
	SetLastError(ERROR_SUCCESS);
	if (!context.apis.register_raw_input_devices(&mouse_device, 1,
		sizeof(mouse_device))) {
		v_multiwindow_w5_set_primary(&context,
			V_MULTIWINDOW_W5_STAGE_REGISTER,
			GetLastError() ? GetLastError() : ERROR_INVALID_DATA);
		goto cleanup;
	}
	context.raw_registered = 1;
	query_error = 0;
	if (!v_multiwindow_w5_query_inventory(
		context.apis.get_registered_raw_input_devices,
		&registered_inventory, &query_error)
		|| !v_multiwindow_w5_inventory_matches_registered_mouse(
			&context.snapshot.registrations, &registered_inventory,
			context.window)) {
		v_multiwindow_w5_set_primary(&context,
			V_MULTIWINDOW_W5_STAGE_REGISTER_READBACK,
			query_error ? query_error : ERROR_INVALID_DATA);
		goto cleanup;
	}
	v_multiwindow_w5_free_inventory(&registered_inventory);
	context.proof |= V_MULTIWINDOW_W5_PROOF_REGISTERED;
	if (!v_multiwindow_w5_pump_until_quiet(&context, 40)
		|| context.primary_stage != V_MULTIWINDOW_W5_STAGE_NONE
		|| context.unexpected_raw_inputs != 0) {
		v_multiwindow_w5_set_primary(&context,
			V_MULTIWINDOW_W5_STAGE_QUIET, WAIT_TIMEOUT);
		goto cleanup;
	}
	memset(&input, 0, sizeof(input));
	input.type = INPUT_MOUSE;
	input.mi.dx = 2;
	input.mi.dy = -2;
	input.mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_MOVE_NOCOALESCE;
	input.mi.dwExtraInfo = context.expected_tag;
	context.armed = 1;
	SetLastError(ERROR_SUCCESS);
	if (context.apis.send_input(1, &input, sizeof(INPUT)) != 1) {
		v_multiwindow_w5_set_primary(&context,
			V_MULTIWINDOW_W5_STAGE_SEND_INPUT,
			GetLastError() ? GetLastError() : ERROR_ACCESS_DENIED);
		goto cleanup;
	}
	context.proof |= V_MULTIWINDOW_W5_PROOF_SEND_INPUT;
	if (!v_multiwindow_w5_wait_for_raw_input(&context, timeout_ms)) {
		v_multiwindow_w5_set_primary(&context,
			V_MULTIWINDOW_W5_STAGE_WAIT_INPUT,
			context.unexpected_raw_inputs ? ERROR_BUSY : WAIT_TIMEOUT);
		goto cleanup;
	}
	if (context.exact_raw_inputs != 1 || context.unexpected_raw_inputs != 0
		|| context.proof != V_MULTIWINDOW_W5_PROOF_ALL) {
		v_multiwindow_w5_set_primary(&context,
			V_MULTIWINDOW_W5_STAGE_DECODE_INPUT, ERROR_INVALID_DATA);
		goto cleanup;
	}
	context.primary_stage = V_MULTIWINDOW_W5_STAGE_COMPLETE;
	context.primary_error = 0;

cleanup:
	v_multiwindow_w5_free_inventory(&registered_inventory);
	v_multiwindow_w5_cleanup(&context);
	*out_stage = context.primary_stage;
	*out_proof = context.proof;
	*out_cleanup = context.cleanup;
	*out_error = context.primary_error;
	*out_cleanup_error = context.cleanup_error;
	result = context.primary_stage == V_MULTIWINDOW_W5_STAGE_COMPLETE
		&& context.primary_error == 0
		&& context.proof == V_MULTIWINDOW_W5_PROOF_ALL
		&& context.cleanup == V_MULTIWINDOW_W5_CLEANUP_ALL
		&& context.cleanup_error == 0 && context.exact_raw_inputs == 1
		&& context.unexpected_raw_inputs == 0 && !context.saw_quit;
	if (result) {
		return 1;
	}
	return context.cleanup == V_MULTIWINDOW_W5_CLEANUP_ALL
		&& context.cleanup_error == 0 ? 0 : -1;
}

#endif

#endif
