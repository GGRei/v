module multiwindow

const win32_service_ok = 1
const win32_service_unavailable = 0
const win32_service_wrong_thread = -1
const win32_service_invalid = -2

struct Win32ServiceRawMonitor {
	native_id   u64
	name        string
	x           int
	y           int
	width       int
	height      int
	work_x      int
	work_y      int
	work_width  int
	work_height int
	dpi         u32
	primary     int
}

struct Win32ServiceMonitorRecord {
	native_id  u64
	name       string
	slot       int
	generation u32
	available  bool
}

struct Win32ServiceMetricsObservation {
	event       QueuedEvent
	monitor_ids []ServiceMonitorId
	dpi         u32
}

struct Win32ServiceRefreshObservation {
	index       int
	sequence    u64
	publish     bool
	observation Win32ServiceMetricsObservation
}

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
	fn C.v_multiwindow_win32_service_monitor_snapshot_new() voidptr
	fn C.v_multiwindow_win32_service_monitor_snapshot_free(snapshot voidptr)
	fn C.v_multiwindow_win32_service_monitor_snapshot_count(snapshot voidptr) int
	fn C.v_multiwindow_win32_service_monitor_snapshot_native_id(snapshot voidptr, index int) u64
	fn C.v_multiwindow_win32_service_monitor_snapshot_name(snapshot voidptr, index int) &u16
	fn C.v_multiwindow_win32_service_monitor_snapshot_info(snapshot voidptr, index int, x &int, y &int, width &int, height &int, work_x &int, work_y &int, work_width &int, work_height &int, dpi &u32, primary &int) int
	fn C.v_multiwindow_win32_service_window_monitor(hwnd voidptr) u64
	fn C.v_multiwindow_win32_service_window_dpi(hwnd voidptr) u32
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

fn win32_service_monitor_info(raw Win32ServiceRawMonitor, record Win32ServiceMonitorRecord, app_instance u64) ServiceMonitorInfo {
	return ServiceMonitorInfo{
		id:        ServiceMonitorId{
			app_instance: app_instance
			slot:         record.slot
			generation:   record.generation
		}
		name:      raw.name
		geometry:  ServiceKnownRect{
			known: raw.width > 0 && raw.height > 0
			value: ServiceRect{
				x:      raw.x
				y:      raw.y
				width:  raw.width
				height: raw.height
			}
		}
		work_area: ServiceKnownRect{
			known: raw.work_width > 0 && raw.work_height > 0
			value: ServiceRect{
				x:      raw.work_x
				y:      raw.work_y
				width:  raw.work_width
				height: raw.work_height
			}
		}
		scale:     ServiceKnownScale{
			known: raw.dpi > 0
			value: if raw.dpi > 0 { f32(raw.dpi) / 96.0 } else { f32(0) }
		}
		primary:   if raw.primary != 0 { .on } else { .off }
		available: true
	}
}

fn win32_reconcile_service_monitors(mut records []Win32ServiceMonitorRecord, snapshot []Win32ServiceRawMonitor, app_instance u64) []ServiceMonitorInfo {
	mut seen := []bool{len: records.len}
	mut slots := []int{len: snapshot.len, init: -1}
	mut monitors := []ServiceMonitorInfo{cap: snapshot.len}
	for snapshot_index, raw in snapshot {
		if raw.native_id == 0 || raw.name == '' {
			continue
		}
		for index, record in records {
			if !seen[index] && record.available && record.name == raw.name {
				slots[snapshot_index] = index
				seen[index] = true
				break
			}
		}
	}
	for snapshot_index, raw in snapshot {
		if slots[snapshot_index] >= 0 || raw.native_id == 0 || raw.name == '' {
			continue
		}
		for index, record in records {
			if !seen[index] && !record.available && record.name == raw.name
				&& record.generation < u32(0xffffffff) {
				slots[snapshot_index] = index
				seen[index] = true
				break
			}
		}
	}
	for snapshot_index, raw in snapshot {
		if slots[snapshot_index] >= 0 || raw.native_id == 0 || raw.name == '' {
			continue
		}
		for index, record in records {
			if !seen[index] && !record.available && record.generation < u32(0xffffffff) {
				slots[snapshot_index] = index
				seen[index] = true
				break
			}
		}
	}
	for snapshot_index, raw in snapshot {
		if raw.native_id == 0 || raw.name == '' {
			continue
		}
		mut slot := slots[snapshot_index]
		if slot < 0 {
			slot = records.len
			records << Win32ServiceMonitorRecord{
				native_id:  raw.native_id
				name:       raw.name
				slot:       slot
				generation: 1
				available:  true
			}
			seen << true
		} else {
			generation := if records[slot].available {
				records[slot].generation
			} else {
				records[slot].generation + 1
			}
			records[slot] = Win32ServiceMonitorRecord{
				native_id:  raw.native_id
				name:       raw.name
				slot:       slot
				generation: generation
				available:  true
			}
			seen[slot] = true
		}
		monitors << win32_service_monitor_info(raw, records[slot], app_instance)
	}
	for index, record in records {
		if index < seen.len && !seen[index] && record.available {
			records[index] = Win32ServiceMonitorRecord{
				...record
				available: false
			}
		}
	}
	return monitors
}

fn win32_service_monitor_ids_for_native(records []Win32ServiceMonitorRecord, native_id u64, app_instance u64) []ServiceMonitorId {
	if native_id == 0 || app_instance == 0 {
		return []ServiceMonitorId{}
	}
	for record in records {
		if record.available && record.native_id == native_id {
			return [
				ServiceMonitorId{
					app_instance: app_instance
					slot:         record.slot
					generation:   record.generation
				},
			]
		}
	}
	return []ServiceMonitorId{}
}

fn win32_service_raw_monitor_snapshot() ![]Win32ServiceRawMonitor {
	$if windows {
		snapshot := C.v_multiwindow_win32_service_monitor_snapshot_new()
		if snapshot == unsafe { nil } {
			return error(err_capability_unsupported)
		}
		defer {
			C.v_multiwindow_win32_service_monitor_snapshot_free(snapshot)
		}
		count := C.v_multiwindow_win32_service_monitor_snapshot_count(snapshot)
		if count < 0 {
			return error(err_capability_unsupported)
		}
		mut monitors := []Win32ServiceRawMonitor{cap: count}
		for index in 0 .. count {
			name_pointer := C.v_multiwindow_win32_service_monitor_snapshot_name(snapshot, index)
			native_id := C.v_multiwindow_win32_service_monitor_snapshot_native_id(snapshot, index)
			if name_pointer == unsafe { nil } || native_id == 0 {
				return error(err_capability_unsupported)
			}
			mut raw := Win32ServiceRawMonitor{
				native_id: native_id
				name:      unsafe { string_from_wide(name_pointer) }
			}
			if raw.name == ''
				|| C.v_multiwindow_win32_service_monitor_snapshot_info(snapshot, index, &raw.x, &raw.y, &raw.width, &raw.height, &raw.work_x, &raw.work_y, &raw.work_width, &raw.work_height, &raw.dpi, &raw.primary) == 0 {
				return error(err_capability_unsupported)
			}
			monitors << raw
		}
		return monitors
	} $else {
		return error(err_backend_unsupported)
	}
}

fn win32_service_window_monitor(hwnd voidptr) u64 {
	$if windows {
		return C.v_multiwindow_win32_service_window_monitor(hwnd)
	} $else {
		_ = hwnd
		return 0
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

fn (backend &Win32Backend) service_window_state_with_monitors(index int, monitors []Win32ServiceMonitorRecord) !ServiceWindowState {
	if index < 0 || index >= backend.windows.len {
		return error(err_window_not_found)
	}
	raw := backend.service_raw_window_state(index)!
	app_instance := if backend.native_operations == unsafe { nil } {
		u64(0)
	} else {
		backend.native_operations.app_identity
	}
	native_monitor := win32_service_window_monitor(backend.windows[index].hwnd)
	return ServiceWindowState{
		mapping:     win32_service_mapping(raw.mapping)
		visibility:  win32_service_visibility(raw.visibility)
		active:      win32_service_observed_bool(raw.active)
		focused:     win32_service_observed_bool(raw.focused)
		minimized:   win32_service_observed_bool(raw.minimized)
		maximized:   win32_service_observed_bool(raw.maximized)
		fullscreen:  win32_service_observed_bool(raw.fullscreen)
		position:    ServicePosition{
			known: raw.position_known != 0
			x:     raw.x
			y:     raw.y
		}
		monitor_ids: win32_service_monitor_ids_for_native(monitors, native_monitor, app_instance)
	}
}

fn (backend &Win32Backend) service_window_state(id WindowId) !ServiceWindowState {
	index := backend.ensure_service_window(id)!
	return backend.service_window_state_with_monitors(index, backend.service_monitors)
}

fn (mut backend Win32Backend) service_monitor_snapshot(app_instance u64) ![]ServiceMonitorInfo {
	$if windows {
		if !backend.started || app_instance == 0 {
			return error(err_backend_unsupported)
		}
		raw := win32_service_raw_monitor_snapshot()!
		mut staged_records := backend.service_monitors.clone()
		monitors := win32_reconcile_service_monitors(mut staged_records, raw, app_instance)
		backend.service_monitors = staged_records
		return monitors
	} $else {
		_ = app_instance
		return error(err_backend_unsupported)
	}
}

fn win32_service_monitor_ids_equal(left []ServiceMonitorId, right []ServiceMonitorId) bool {
	if left.len != right.len {
		return false
	}
	for index, id in left {
		if id != right[index] {
			return false
		}
	}
	return true
}

fn (backend &Win32Backend) service_metrics_observation(index int, monitors []Win32ServiceMonitorRecord) !Win32ServiceMetricsObservation {
	$if windows {
		if index < 0 || index >= backend.windows.len {
			return error(err_window_not_found)
		}
		record := backend.windows[index]
		if record.destroyed || record.hwnd == unsafe { nil } {
			return error(err_window_not_found)
		}
		mut visible := 0
		mut minimized := 0
		mut logical_width := 0
		mut logical_height := 0
		mut framebuffer_width := 0
		mut framebuffer_height := 0
		mut native_scale := f32(0)
		mut conversion_available := 0
		if C.v_multiwindow_win32_render_snapshot(record.hwnd, &visible, &minimized, &logical_width,
			&logical_height, &framebuffer_width, &framebuffer_height, &native_scale,
			&conversion_available) == 0 {
			return error(err_capability_unsupported)
		}
		dpi := C.v_multiwindow_win32_service_window_dpi(record.hwnd)
		scale := if dpi > 0 { f32(dpi) / 96.0 } else { native_scale }
		metrics_available := logical_width > 0 && logical_height > 0 && framebuffer_width > 0
			&& framebuffer_height > 0 && scale > 0
		state := backend.service_window_state_with_monitors(index, monitors)!
		return Win32ServiceMetricsObservation{
			event:       queued_service_event(ServiceEvent{
				kind:    .metrics
				window:  record.id
				state:   state
				metrics: RenderMetricsSnapshot{
					logical_width:        f32(logical_width)
					logical_height:       f32(logical_height)
					framebuffer_width:    framebuffer_width
					framebuffer_height:   framebuffer_height
					dpi_scale:            scale
					metrics_available:    metrics_available
					conversion_available: conversion_available != 0
				}
			})
			monitor_ids: state.monitor_ids.clone()
			dpi:         dpi
		}
	} $else {
		_ = index
		return error(err_backend_unsupported)
	}
}

fn (mut backend Win32Backend) collect_service_refresh_events() ![]Win32NativeQueuedEvent {
	$if windows {
		if backend.native_operations == unsafe { nil } {
			return error(err_app_identity_mismatch)
		}
		app_instance := backend.native_operations.app_identity
		if app_instance == 0 {
			return error(err_app_identity_mismatch)
		}
		mut display_sequence := u64(0)
		for record in backend.windows {
			if record.pending_display_refresh && record.service_refresh_sequence != 0
				&& (display_sequence == 0 || record.service_refresh_sequence < display_sequence) {
				display_sequence = record.service_refresh_sequence
			}
		}
		mut events := []Win32NativeQueuedEvent{}
		if display_sequence != 0 {
			raw_monitors := win32_service_raw_monitor_snapshot()!
			mut staged_records := backend.service_monitors.clone()
			monitors := win32_reconcile_service_monitors(mut staged_records, raw_monitors,
				app_instance)
			events << Win32NativeQueuedEvent{
				sequence: display_sequence
				event:    queued_service_event(ServiceEvent{
					kind:     .monitor
					monitor:  if monitors.len > 0 {
						monitors[0]
					} else {
						ServiceMonitorInfo{
							id: ServiceMonitorId{
								app_instance: app_instance
							}
						}
					}
					monitors: monitors
				})
			}
			mut observations := []Win32ServiceRefreshObservation{cap: backend.windows.len}
			for index in 0 .. backend.windows.len {
				record := backend.windows[index]
				if record.destroyed || record.hwnd == unsafe { nil } {
					continue
				}
				observation := backend.service_metrics_observation(index, staged_records)!
				observations << Win32ServiceRefreshObservation{
					index:       index
					sequence:    display_sequence
					publish:     true
					observation: observation
				}
			}
			backend.service_monitors = staged_records
			for index in 0 .. backend.windows.len {
				mut record := backend.windows[index]
				record.pending_display_refresh = false
				record.pending_dpi_refresh = false
				record.pending_membership_refresh = false
				record.service_refresh_sequence = 0
			}
			for staged in observations {
				mut record := backend.windows[staged.index]
				observation := staged.observation
				record.service_monitor_ids = observation.monitor_ids.clone()
				record.service_dpi = observation.dpi
				events << Win32NativeQueuedEvent{
					sequence: staged.sequence
					event:    observation.event
				}
			}
			return events
		}
		mut pending_indices := []int{}
		mut observations := []Win32ServiceRefreshObservation{}
		for index in 0 .. backend.windows.len {
			record := backend.windows[index]
			if (!record.pending_dpi_refresh && !record.pending_membership_refresh)
				|| record.service_refresh_sequence == 0 {
				continue
			}
			pending_indices << index
			sequence := record.service_refresh_sequence
			dpi_refresh := record.pending_dpi_refresh
			if record.destroyed || record.hwnd == unsafe { nil } {
				continue
			}
			observation := backend.service_metrics_observation(index, backend.service_monitors)!
			membership_changed := !win32_service_monitor_ids_equal(record.service_monitor_ids,
				observation.monitor_ids)
			dpi_changed := observation.dpi != record.service_dpi
			observations << Win32ServiceRefreshObservation{
				index:       index
				sequence:    sequence
				publish:     dpi_refresh || membership_changed || dpi_changed
				observation: observation
			}
		}
		for index in pending_indices {
			mut record := backend.windows[index]
			record.pending_dpi_refresh = false
			record.pending_membership_refresh = false
			record.service_refresh_sequence = 0
		}
		for staged in observations {
			mut record := backend.windows[staged.index]
			observation := staged.observation
			record.service_monitor_ids = observation.monitor_ids.clone()
			record.service_dpi = observation.dpi
			if staged.publish {
				events << Win32NativeQueuedEvent{
					sequence: staged.sequence
					event:    observation.event
				}
			}
		}
		return events
	} $else {
		return []Win32NativeQueuedEvent{}
	}
}

fn (mut backend Win32Backend) service_show_window(id WindowId) !ServiceWindowState {
	index := backend.ensure_service_window(id)!
	$if windows {
		was_modal_active := backend.windows[index].modal_active
		backend.activate_modal(index)!
		win32_service_result(C.v_multiwindow_win32_service_show_window(backend.windows[index].service_state)) or {
			show_error := err.msg()
			if !was_modal_active {
				backend.release_modal(index) or {
					return error(merge_backend_errors(show_error,
						'modal rollback failed: ${err.msg()}'))
				}
			}
			return error(show_error)
		}
	}
	return backend.service_window_state(id)!
}

fn (mut backend Win32Backend) service_hide_window(id WindowId) !ServiceWindowState {
	index := backend.ensure_service_window(id)!
	$if windows {
		win32_service_result(C.v_multiwindow_win32_service_hide_window(backend.windows[index].service_state))!
		backend.release_modal(index)!
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
