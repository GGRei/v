module multiwindow

const win32_service_ok = 1
const win32_service_unavailable = 0
const win32_service_wrong_thread = -1
const win32_service_invalid = -2

$if windows {
	#insert "@VMODROOT/vlib/x/multiwindow/win32_service_native.h"

	fn C.v_multiwindow_win32_service_authority(state voidptr) int
	fn C.v_multiwindow_win32_service_create(hwnd voidptr, record_data voidptr, initial_fullscreen int, width int, height int, resizable int, borderless int) voidptr
	fn C.v_multiwindow_win32_service_release(state voidptr) int
	fn C.v_multiwindow_win32_service_window_state(state voidptr, out_mapping &int, out_visibility &int, out_active &int, out_focused &int, out_minimized &int, out_maximized &int, out_fullscreen &int, out_position_known &int, out_x &int, out_y &int) int
	fn C.v_multiwindow_win32_service_show_window(state voidptr) int
	fn C.v_multiwindow_win32_service_hide_window(state voidptr) int
	fn C.v_multiwindow_win32_service_focus_window(state voidptr) int
	fn C.v_multiwindow_win32_service_raise_window(state voidptr) int
	fn C.v_multiwindow_win32_service_set_window_position(state voidptr, x int, y int) int
	fn C.v_multiwindow_win32_service_minimize_window(state voidptr) int
	fn C.v_multiwindow_win32_service_maximize_window(state voidptr) int
	fn C.v_multiwindow_win32_service_restore_window(state voidptr) int
	fn C.v_multiwindow_win32_service_set_fullscreen(state voidptr, enabled int) int
	fn C.v_multiwindow_win32_service_native_window(state voidptr) voidptr
}

struct Win32ServiceRawWindowState {
	mapping        int
	visibility     int
	active         int
	focused        int
	minimized      int
	maximized      int
	fullscreen     int
	position_known int
	x              int
	y              int
}

fn win32_service_observed_bool(value int) ServiceObservedBool {
	return match value {
		1 { .off }
		2 { .on }
		else { .unknown }
	}
}

fn win32_service_mapping(value int) ServiceMappingState {
	return match value {
		1 { .unmapped }
		2 { .mapped }
		else { .unknown }
	}
}

fn win32_service_visibility(value int) ServiceVisibilityState {
	return match value {
		1 { .hidden }
		2 { .visible }
		3 { .occluded }
		else { .unknown }
	}
}

fn win32_service_result(result int) ! {
	match result {
		win32_service_ok {
			return
		}
		win32_service_wrong_thread {
			return error(err_owner_thread_required)
		}
		win32_service_invalid {
			return error(err_window_not_found)
		}
		else {
			return error(err_capability_unsupported)
		}
	}
}

fn win32_window_config_with_fullscreen(config WindowConfig, fullscreen bool) WindowConfig {
	return WindowConfig{
		title:           config.title
		width:           config.width
		height:          config.height
		min_width:       config.min_width
		min_height:      config.min_height
		resizable:       config.resizable
		visible:         config.visible
		high_dpi:        config.high_dpi
		borderless:      config.borderless
		fullscreen:      fullscreen
		sample_count:    config.sample_count
		redraw_mode:     config.redraw_mode
		owner:           config.owner
		modal:           config.modal
		render_workload: config.render_workload
	}
}

fn (backend &Win32Backend) ensure_service_window(id WindowId) !int {
	$if windows {
		if backend.native_operations == unsafe { nil }
			|| !backend.native_operations.owner_thread_is_current() {
			return error(err_owner_thread_required)
		}
		if !backend.started {
			return error(err_backend_unsupported)
		}
		index := backend.window_record_index(id) or { return error(err_window_not_found) }
		record := backend.windows[index]
		if record.destroyed || record.hwnd == unsafe { nil }
			|| record.service_state == unsafe { nil } {
			return error(err_window_not_found)
		}
		win32_service_result(C.v_multiwindow_win32_service_authority(record.service_state))!
		return index
	} $else {
		_ = id
		return error(err_backend_unsupported)
	}
}

fn (backend &Win32Backend) service_operation_capability(id WindowId, operation ServiceOperation) ServiceOperationCapability {
	index := backend.ensure_service_window(id) or { return ServiceOperationCapability{} }
	record := backend.windows[index]
	return match operation {
		.show, .hide, .raise, .position, .minimize, .restore, .fullscreen {
			ServiceOperationCapability{
				support:          .available
				state_observable: true
			}
		}
		.maximize {
			ServiceOperationCapability{
				support:          if record.config.resizable && !record.config.borderless {
					.available
				} else {
					.unsupported
				}
				state_observable: record.config.resizable && !record.config.borderless
			}
		}
		.focus {
			ServiceOperationCapability{
				support:              .conditional
				requires_user_action: true
				state_observable:     true
			}
		}
		.native_borrow {
			ServiceOperationCapability{
				support: .available
			}
		}
		else {
			ServiceOperationCapability{}
		}
	}
}

fn (backend &Win32Backend) service_raw_window_state(index int) !Win32ServiceRawWindowState {
	$if windows {
		if index < 0 || index >= backend.windows.len {
			return error(err_window_not_found)
		}
		mut raw := Win32ServiceRawWindowState{}
		result := C.v_multiwindow_win32_service_window_state(backend.windows[index].service_state,
			&raw.mapping, &raw.visibility, &raw.active, &raw.focused, &raw.minimized,
			&raw.maximized, &raw.fullscreen, &raw.position_known, &raw.x, &raw.y)
		win32_service_result(result)!
		return raw
	} $else {
		_ = index
		return error(err_backend_unsupported)
	}
}

fn (backend &Win32Backend) service_window_state(id WindowId) !ServiceWindowState {
	index := backend.ensure_service_window(id)!
	raw := backend.service_raw_window_state(index)!
	return ServiceWindowState{
		mapping:    win32_service_mapping(raw.mapping)
		visibility: win32_service_visibility(raw.visibility)
		active:     win32_service_observed_bool(raw.active)
		focused:    win32_service_observed_bool(raw.focused)
		minimized:  win32_service_observed_bool(raw.minimized)
		maximized:  win32_service_observed_bool(raw.maximized)
		fullscreen: win32_service_observed_bool(raw.fullscreen)
		position:   ServicePosition{
			known: raw.position_known != 0
			x:     raw.x
			y:     raw.y
		}
	}
}

fn (mut backend Win32Backend) service_show_window(id WindowId) !ServiceWindowState {
	index := backend.ensure_service_window(id)!
	$if windows {
		win32_service_result(C.v_multiwindow_win32_service_show_window(backend.windows[index].service_state))!
	}
	return backend.service_window_state(id)!
}

fn (mut backend Win32Backend) service_hide_window(id WindowId) !ServiceWindowState {
	index := backend.ensure_service_window(id)!
	$if windows {
		win32_service_result(C.v_multiwindow_win32_service_hide_window(backend.windows[index].service_state))!
	}
	return backend.service_window_state(id)!
}

fn (mut backend Win32Backend) service_focus_window(id WindowId) !ServiceWindowState {
	index := backend.ensure_service_window(id)!
	$if windows {
		win32_service_result(C.v_multiwindow_win32_service_focus_window(backend.windows[index].service_state))!
	}
	return backend.service_window_state(id)!
}

fn (mut backend Win32Backend) service_raise_window(id WindowId) !ServiceWindowState {
	index := backend.ensure_service_window(id)!
	$if windows {
		win32_service_result(C.v_multiwindow_win32_service_raise_window(backend.windows[index].service_state))!
	}
	return backend.service_window_state(id)!
}

fn (mut backend Win32Backend) service_set_window_position(id WindowId, x int, y int) !ServiceWindowState {
	index := backend.ensure_service_window(id)!
	$if windows {
		win32_service_result(C.v_multiwindow_win32_service_set_window_position(backend.windows[index].service_state,
			x, y))!
	}
	return backend.service_window_state(id)!
}

fn (mut backend Win32Backend) service_minimize_window(id WindowId) !ServiceWindowState {
	index := backend.ensure_service_window(id)!
	$if windows {
		win32_service_result(C.v_multiwindow_win32_service_minimize_window(backend.windows[index].service_state))!
	}
	return backend.service_window_state(id)!
}

fn (mut backend Win32Backend) service_maximize_window(id WindowId) !ServiceWindowState {
	index := backend.ensure_service_window(id)!
	if !backend.windows[index].config.resizable || backend.windows[index].config.borderless {
		return error(err_capability_unsupported)
	}
	$if windows {
		win32_service_result(C.v_multiwindow_win32_service_maximize_window(backend.windows[index].service_state))!
	}
	return backend.service_window_state(id)!
}

fn (mut backend Win32Backend) service_restore_window(id WindowId) !ServiceWindowState {
	index := backend.ensure_service_window(id)!
	$if windows {
		win32_service_result(C.v_multiwindow_win32_service_restore_window(backend.windows[index].service_state))!
	}
	backend.windows[index].config = win32_window_config_with_fullscreen(backend.windows[index].config,
		false)
	return backend.service_window_state(id)!
}

fn (mut backend Win32Backend) service_set_fullscreen(id WindowId, enabled bool) !ServiceWindowState {
	index := backend.ensure_service_window(id)!
	$if windows {
		win32_service_result(C.v_multiwindow_win32_service_set_fullscreen(backend.windows[index].service_state,
			win32_bool_to_int(enabled)))!
	}
	backend.windows[index].config = win32_window_config_with_fullscreen(backend.windows[index].config,
		enabled)
	return backend.service_window_state(id)!
}

fn (backend &Win32Backend) service_native_window_borrow(id WindowId) !BackendNativeWindowBorrow {
	index := backend.ensure_service_window(id)!
	$if windows {
		hwnd := C.v_multiwindow_win32_service_native_window(backend.windows[index].service_state)
		if hwnd == unsafe { nil } {
			return error(err_window_not_found)
		}
		return BackendNativeWindowBorrow{
			backend: .win32
			primary: hwnd
		}
	}
	return error(err_backend_unsupported)
}
