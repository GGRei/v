// vtest retry: 0
module multiwindow

import os
import time

const win32_red_clipboard_max_bytes = 16 * 1024 * 1024
const win32_red_ws_caption = u64(0x00c00000)

$if windows {
	#include "@VMODROOT/vlib/x/multiwindow/testdata/win32_nonreadback_test_oracle.h"

	fn C.v_multiwindow_test_win32_is_window(hwnd voidptr) int
	fn C.v_multiwindow_test_win32_is_visible(hwnd voidptr) int
	fn C.v_multiwindow_test_win32_is_enabled(hwnd voidptr) int
	fn C.v_multiwindow_test_win32_is_iconic(hwnd voidptr) int
	fn C.v_multiwindow_test_win32_is_zoomed(hwnd voidptr) int
	fn C.v_multiwindow_test_win32_foreground() voidptr
	fn C.v_multiwindow_test_win32_owner(hwnd voidptr) voidptr
	fn C.v_multiwindow_test_win32_style(hwnd voidptr) u64
	fn C.v_multiwindow_test_win32_ex_style(hwnd voidptr) u64
	fn C.v_multiwindow_test_win32_rect(hwnd voidptr, left &int, top &int, right &int, bottom &int) int
	fn C.v_multiwindow_test_win32_is_above(upper voidptr, lower voidptr) int
	fn C.v_multiwindow_test_win32_dpi(hwnd voidptr) u32
	fn C.v_multiwindow_test_win32_monitor_snapshot_new() voidptr
	fn C.v_multiwindow_test_win32_monitor_snapshot_free(snapshot voidptr)
	fn C.v_multiwindow_test_win32_monitor_snapshot(snapshot voidptr) int
	fn C.v_multiwindow_test_win32_monitor_identity(snapshot voidptr, index int) u64
	fn C.v_multiwindow_test_win32_monitor_info(snapshot voidptr, index int, x &int, y &int, width &int, height &int, work_x &int, work_y &int, work_width &int, work_height &int, primary &int) int
	fn C.v_multiwindow_test_win32_emit_display_change(hwnd voidptr) int
	fn C.v_multiwindow_test_win32_clipboard_equals(expected &u16) int
	fn C.v_multiwindow_test_win32_clipboard_bytes() usize
	fn C.v_multiwindow_test_win32_set_clipboard(text &u16, units usize) int
	fn C.v_multiwindow_test_win32_start_clipboard_occupancy() int
	fn C.v_multiwindow_test_win32_stop_clipboard_occupancy()
	fn C.v_multiwindow_test_win32_dwm_dark(hwnd voidptr, value &int) int
}

fn C.v_multiwindow_test_win32_raw_mouse_target() voidptr
fn C.v_multiwindow_test_win32_raw_mouse_registered_for(hwnd voidptr) int
fn C.v_multiwindow_test_win32_emit_focus_loss(hwnd voidptr, next_hwnd voidptr) int
fn C.v_multiwindow_test_win32_clip_matches_client(hwnd voidptr) int
fn C.v_multiwindow_test_win32_clip_is_virtual_screen() int
fn C.v_multiwindow_test_win32_capture() voidptr

fn win32_red_hwnd(app &App, id WindowId) !voidptr {
	index := app.backend.win32.window_record_index(id) or { return error(err_window_not_found) }
	hwnd := app.backend.win32.windows[index].hwnd
	if hwnd == unsafe { nil } {
		return error(err_window_not_found)
	}
	return hwnd
}

fn win32_red_poll(mut app App, attempts int) ! {
	for _ in 0 .. attempts {
		app.poll_events()!
		time.sleep(5 * time.millisecond)
	}
}

fn win32_red_add(mut issues []string, label string, ok bool) {
	if !ok {
		issues << label
	}
}

fn win32_red_capability_matches(actual ServiceOperationCapability, support ServiceSupportLevel, asynchronous bool, requires_user_action bool, state_observable bool) bool {
	return actual.support == support && actual.asynchronous == asynchronous
		&& actual.requires_user_action == requires_user_action
		&& actual.state_observable == state_observable
}

fn win32_red_utf16_units(text string) usize {
	mut units := usize(1)
	for codepoint in text.runes() {
		units += if codepoint > 0xffff { usize(2) } else { usize(1) }
	}
	return units
}

fn win32_red_clipboard_terminals(mut app App, request ServiceRequestId, attempts int) ![]ServiceClipboardResult {
	mut terminals := []ServiceClipboardResult{}
	for _ in 0 .. attempts {
		app.poll_events()!
		for event in app.drain_queued_events()! {
			if event.kind == .service && event.service.kind == .clipboard
				&& event.service.clipboard.id == request {
				terminals << event.service.clipboard
			}
		}
		if terminals.len > 0 {
			break
		}
		time.sleep(5 * time.millisecond)
	}
	return terminals
}

fn test_win32_native_controls_state_and_independent_window_oracles_red() {
	$if windows {
		eprintln('PACKAGE2_RED_TEST=test_win32_native_controls_state_and_independent_window_oracles_red')
		eprintln('PACKAGE2_RED_FAMILY=controls_state')
		mut app := new_app(backend: .win32)!
		defer {
			app.stop() or {}
		}
		target := app.create_window(
			title:   'Win32 controls target'
			width:   220
			height:  140
			visible: false
		)!
		blocker := app.create_window(
			title:  'Win32 raise blocker'
			width:  180
			height: 120
		)!
		_ = app.drain_queued_events()!
		hwnd := win32_red_hwnd(app, target)!
		blocker_hwnd := win32_red_hwnd(app, blocker)!
		mut issues := []string{}

		for operation in [ServiceOperation.show, .hide, .raise, .position, .minimize, .maximize,
			.restore, .fullscreen] {
			capability := app.service_operation_capability(target, operation)!
			win32_red_add(mut issues, '${operation} capability is not available/observable', win32_red_capability_matches(capability,
				.available, false, false, true))
		}
		focus_capability := app.service_operation_capability(target, .focus)!
		win32_red_add(mut issues, 'focus must be conditional and require user action', win32_red_capability_matches(focus_capability,
			.conditional, false, true, true))

		app.service_show_window(target) or { issues << 'show failed: ${err.msg()}' }
		win32_red_poll(mut app, 2)!
		win32_red_add(mut issues, 'ShowWindow oracle remains hidden',
			C.v_multiwindow_test_win32_is_visible(hwnd) == 1)
		state_after_show := app.service_window_state(target)!
		win32_red_add(mut issues, 'show state is not mapped/visible',

			state_after_show.mapping == .mapped && state_after_show.visibility == .visible)

		app.service_set_position(target, 37, 41) or { issues << 'position failed: ${err.msg()}' }
		win32_red_poll(mut app, 2)!
		mut left := 0
		mut top := 0
		mut right := 0
		mut bottom := 0
		assert C.v_multiwindow_test_win32_rect(hwnd, &left, &top, &right, &bottom) == 1, 'GetWindowRect oracle admission failed'

		win32_red_add(mut issues, 'GetWindowRect does not observe requested position', left == 37
			&& top == 41)

		app.service_minimize_window(target) or { issues << 'minimize failed: ${err.msg()}' }
		win32_red_poll(mut app, 4)!
		win32_red_add(mut issues, 'IsIconic did not observe minimize',
			C.v_multiwindow_test_win32_is_iconic(hwnd) == 1)

		app.service_restore_window(target) or {
			issues << 'restore after minimize failed: ${err.msg()}'
		}
		win32_red_poll(mut app, 4)!
		win32_red_add(mut issues, 'restore left the window iconic',
			C.v_multiwindow_test_win32_is_iconic(hwnd) == 0)

		app.service_maximize_window(target) or { issues << 'maximize failed: ${err.msg()}' }
		win32_red_poll(mut app, 4)!
		win32_red_add(mut issues, 'IsZoomed did not observe maximize',
			C.v_multiwindow_test_win32_is_zoomed(hwnd) == 1)

		app.service_restore_window(target) or {
			issues << 'restore after maximize failed: ${err.msg()}'
		}
		win32_red_poll(mut app, 4)!
		win32_red_add(mut issues, 'restore left the window zoomed',
			C.v_multiwindow_test_win32_is_zoomed(hwnd) == 0)

		app.service_raise_window(target) or { issues << 'raise failed: ${err.msg()}' }
		win32_red_poll(mut app, 2)!
		win32_red_add(mut issues, 'z-order oracle did not place target above peer', C.v_multiwindow_test_win32_is_above(hwnd,
			blocker_hwnd) == 1)

		// Windows may deny foreground activation even when the request is valid.
		app.service_request_focus(target) or {}
		win32_red_poll(mut app, 4)!
		if C.v_multiwindow_test_win32_foreground() == hwnd {
			focused_state := app.service_window_state(target)!
			win32_red_add(mut issues, 'foreground HWND is not reflected as focused/active',

				focused_state.focused == .on && focused_state.active == .on)
		}

		style_before_fullscreen := C.v_multiwindow_test_win32_style(hwnd)
		app.service_set_fullscreen(target, true) or {
			issues << 'fullscreen enter failed: ${err.msg()}'
		}
		win32_red_poll(mut app, 4)!
		fullscreen_state := app.service_window_state(target)!
		win32_red_add(mut issues, 'fullscreen state did not become on',
			fullscreen_state.fullscreen == .on)
		win32_red_add(mut issues, 'native style did not change for fullscreen',
			C.v_multiwindow_test_win32_style(hwnd) != style_before_fullscreen)
		app.service_set_fullscreen(target, false) or {
			issues << 'fullscreen exit failed: ${err.msg()}'
		}
		win32_red_poll(mut app, 4)!
		win32_red_add(mut issues, 'native style was not restored after fullscreen',
			C.v_multiwindow_test_win32_style(hwnd) == style_before_fullscreen)

		app.service_hide_window(target) or { issues << 'hide failed: ${err.msg()}' }
		win32_red_poll(mut app, 2)!
		win32_red_add(mut issues, 'ShowWindow oracle remains visible after hide',
			C.v_multiwindow_test_win32_is_visible(hwnd) == 0)
		state_after_hide := app.service_window_state(target)!
		win32_red_add(mut issues, 'hide state is not unmapped/hidden',

			state_after_hide.mapping == .unmapped && state_after_hide.visibility == .hidden)

		if issues.len > 0 {
			eprintln('PACKAGE2_RED_TERMINAL=behavioral_red:controls_state')
		}
		assert issues.len == 0, 'Win32 controls/state RED:\n${issues.join('\n')}'
	}
}

fn test_win32_native_modal_reenable_and_child_first_hwnd_destruction_red() {
	$if windows {
		eprintln('PACKAGE2_RED_TEST=test_win32_native_modal_reenable_and_child_first_hwnd_destruction_red')
		eprintln('PACKAGE2_RED_FAMILY=modal_child_first')
		mut app := new_app(backend: .win32)!
		defer {
			app.stop() or {}
		}
		owner := app.create_window(title: 'Win32 modal owner')!
		child := app.create_window(
			title:   'Win32 modal child'
			owner:   owner
			modal:   true
			visible: false
		)!
		grandchild := app.create_window(
			title:   'Win32 modal grandchild'
			owner:   child
			visible: false
		)!
		_ = app.drain_queued_events()!
		owner_hwnd := win32_red_hwnd(app, owner)!
		child_hwnd := win32_red_hwnd(app, child)!
		grandchild_hwnd := win32_red_hwnd(app, grandchild)!
		mut issues := []string{}

		app.service_show_window(child) or { issues << 'modal show failed: ${err.msg()}' }
		win32_red_poll(mut app, 2)!
		win32_red_add(mut issues, 'GW_OWNER does not match configured owner',
			C.v_multiwindow_test_win32_owner(child_hwnd) == owner_hwnd)
		win32_red_add(mut issues, 'shown modal child did not disable owner',
			C.v_multiwindow_test_win32_is_enabled(owner_hwnd) == 0)

		app.service_hide_window(child) or { issues << 'modal hide failed: ${err.msg()}' }
		win32_red_poll(mut app, 2)!
		win32_red_add(mut issues, 'hiding modal child did not re-enable owner',
			C.v_multiwindow_test_win32_is_enabled(owner_hwnd) == 1)

		app.service_show_window(child) or { issues << 'second modal show failed: ${err.msg()}' }
		app.destroy_window(child)!
		win32_red_poll(mut app, 2)!
		destroy_events := app.drain_queued_events()!
		mut destroyed_ids := []WindowId{}
		for event in destroy_events {
			if event.kind == .lifecycle && event.lifecycle.kind == .window_destroyed {
				destroyed_ids << event.lifecycle.window_id
			}
		}
		win32_red_add(mut issues, 'destroying modal child did not re-enable owner',
			C.v_multiwindow_test_win32_is_enabled(owner_hwnd) == 1)
		win32_red_add(mut issues, 'child HWND survived public destroy',
			C.v_multiwindow_test_win32_is_window(child_hwnd) == 0)
		win32_red_add(mut issues, 'grandchild HWND survived child-first cascade',
			C.v_multiwindow_test_win32_is_window(grandchild_hwnd) == 0)
		win32_red_add(mut issues, 'canonical lifecycle queue is not child-first',

			destroyed_ids.len == 2 && destroyed_ids[0] == grandchild && destroyed_ids[1] == child)

		app.destroy_window(owner)!
		win32_red_poll(mut app, 2)!
		win32_red_add(mut issues, 'owner HWND survived public destroy',
			C.v_multiwindow_test_win32_is_window(owner_hwnd) == 0)
		if issues.len > 0 {
			eprintln('PACKAGE2_RED_TERMINAL=behavioral_red:modal_child_first')
		}
		assert issues.len == 0, 'Win32 owner/modal/child-first RED:\n${issues.join('\n')}'
	}
}

fn test_win32_native_monitor_dpi_display_change_and_generation_red() {
	$if windows {
		eprintln('PACKAGE2_RED_TEST=test_win32_native_monitor_dpi_display_change_and_generation_red')
		eprintln('PACKAGE2_RED_FAMILY=monitor_dpi_hotplug')
		mut app := new_app(backend: .win32)!
		defer {
			app.stop() or {}
		}
		window := app.create_window(title: 'Win32 monitor oracle', high_dpi: true)!
		_ = app.drain_queued_events()!
		hwnd := win32_red_hwnd(app, window)!
		before_native := C.v_multiwindow_test_win32_monitor_snapshot_new()
		assert before_native != unsafe { nil }
		defer {
			C.v_multiwindow_test_win32_monitor_snapshot_free(before_native)
		}
		native_count := C.v_multiwindow_test_win32_monitor_snapshot(before_native)
		assert native_count > 0, 'EnumDisplayMonitors oracle admission produced no monitors'
		before_ids := app.service_monitor_ids()!
		mut issues := []string{}
		win32_red_add(mut issues, 'public monitor count differs from EnumDisplayMonitors',
			before_ids.len == native_count)
		for native_index in 0 .. native_count {
			mut x := 0
			mut y := 0
			mut width := 0
			mut height := 0
			mut work_x := 0
			mut work_y := 0
			mut work_width := 0
			mut work_height := 0
			mut primary := 0
			assert C.v_multiwindow_test_win32_monitor_info(before_native, native_index, &x, &y,
				&width, &height, &work_x, &work_y, &work_width, &work_height, &primary) == 1
			mut matched := false
			for id in before_ids {
				info := app.service_monitor_info(id)!
				if info.geometry.known && info.geometry.value == ServiceRect{
					x:      x
					y:      y
					width:  width
					height: height
				} {
					matched = info.work_area.known && info.work_area.value == ServiceRect{
						x:      work_x
						y:      work_y
						width:  work_width
						height: work_height
					} && info.primary == if primary != 0 {
						ServiceObservedBool.on
					} else {
						ServiceObservedBool.off
					}
					break
				}
			}
			win32_red_add(mut issues,
				'native monitor ${native_index} has no matching public snapshot', matched)
		}
		window_state := app.service_window_state(window)!
		if window_state.monitor_ids.len > 0 {
			monitor := app.service_monitor_info(window_state.monitor_ids[0])!
			native_scale := f32(C.v_multiwindow_test_win32_dpi(hwnd)) / 96.0
			win32_red_add(mut issues, 'window DPI differs from native GetDpiForWindow',
				monitor.scale.known && monitor.scale.value > native_scale - 0.01
				&& monitor.scale.value < native_scale + 0.01)
		} else {
			issues << 'window state has no native monitor membership'
		}

		assert C.v_multiwindow_test_win32_emit_display_change(hwnd) == 1
		win32_red_poll(mut app, 4)!
		after_ids := app.service_monitor_ids()!
		events := app.drain_service_events()!
		win32_red_add(mut issues, 'WM_DISPLAYCHANGE produced no canonical monitor event',
			events.any(it.kind == .monitor))
		win32_red_add(mut issues, 'WM_DISPLAYCHANGE produced no sequence-coherent metrics event', events.any(
			it.kind == .metrics && it.window == window && it.metrics.metrics_sequence == it.sequence))
		after_native := C.v_multiwindow_test_win32_monitor_snapshot_new()
		assert after_native != unsafe { nil }
		defer {
			C.v_multiwindow_test_win32_monitor_snapshot_free(after_native)
		}
		after_count := C.v_multiwindow_test_win32_monitor_snapshot(after_native)
		assert after_count > 0, 'post-WM_DISPLAYCHANGE monitor oracle produced no monitors'
		if after_count == native_count {
			mut same_identities := true
			for index in 0 .. native_count {
				if C.v_multiwindow_test_win32_monitor_identity(before_native, index) != C.v_multiwindow_test_win32_monitor_identity(after_native,
					index) {
					same_identities = false
					break
				}
			}
			if same_identities {
				win32_red_add(mut issues, 'stable topology changed public monitor generations',
					before_ids == after_ids)
			}
		}
		if issues.len > 0 {
			eprintln('PACKAGE2_RED_TERMINAL=behavioral_red:monitor_dpi_hotplug')
		}
		assert issues.len == 0, 'Win32 monitors/DPI/hotplug/generation RED:\n${issues.join('\n')}'
	}
}

fn test_win32_native_cf_unicodetext_roundtrip_exact_limit_and_terminal_queue_red() {
	$if windows {
		eprintln('PACKAGE2_RED_TEST=test_win32_native_cf_unicodetext_roundtrip_exact_limit_and_terminal_queue_red')
		eprintln('PACKAGE2_RED_FAMILY=clipboard_unicode_limit')
		mut app := new_app(backend: .win32)!
		defer {
			app.stop() or {}
		}
		window := app.create_window(title: 'Win32 clipboard oracle')!
		_ = app.drain_queued_events()!
		mut issues := []string{}

		external := 'external € 🙂'
		external_wide := external.to_wide()
		assert C.v_multiwindow_test_win32_set_clipboard(external_wide,
			win32_red_utf16_units(external)) == 1
		read_request := app.service_request_clipboard_text(window) or {
			issues << 'public CF_UNICODETEXT read start failed: ${err.msg()}'
			ServiceRequestId{}
		}
		if read_request != ServiceRequestId{} {
			terminals := win32_red_clipboard_terminals(mut app, read_request, 200)!
			win32_red_add(mut issues,
				'external-to-public clipboard did not produce one ready terminal',

				terminals.len == 1 && terminals[0].status == .ready && terminals[0].text == external)
		}

		written := 'public € 🙂'
		write_request := app.service_set_clipboard_text(window, written) or {
			issues << 'public CF_UNICODETEXT write start failed: ${err.msg()}'
			ServiceRequestId{}
		}
		if write_request != ServiceRequestId{} {
			terminals := win32_red_clipboard_terminals(mut app, write_request, 200)!
			win32_red_add(mut issues,
				'public-to-external clipboard did not produce one ready terminal',

				terminals.len == 1 && terminals[0].status == .ready)
			win32_red_add(mut issues, 'CF_UNICODETEXT does not equal the public UTF-16 payload',
				C.v_multiwindow_test_win32_clipboard_equals(written.to_wide()) == 1)
		}

		exact := 'x'.repeat(win32_red_clipboard_max_bytes / 2 - 1)
		exact_request := app.service_set_clipboard_text(window, exact) or {
			issues << 'exact clipboard limit failed: ${err.msg()}'
			ServiceRequestId{}
		}
		if exact_request != ServiceRequestId{} {
			terminals := win32_red_clipboard_terminals(mut app, exact_request, 300)!
			win32_red_add(mut issues, 'exact clipboard limit lacks one ready terminal',

				terminals.len == 1 && terminals[0].status == .ready)
			win32_red_add(mut issues,
				'CF_UNICODETEXT exact allocation is below the contract limit',
				C.v_multiwindow_test_win32_clipboard_bytes() >= usize(win32_red_clipboard_max_bytes))
		}
		oversized := 'x'.repeat(win32_red_clipboard_max_bytes / 2)
		mut oversized_error := ''
		app.service_set_clipboard_text(window, oversized) or { oversized_error = err.msg() }
		win32_red_add(mut issues, 'limit+one UTF-16 unit was not rejected as capacity',
			oversized_error == err_clipboard_capacity)
		if issues.len > 0 {
			eprintln('PACKAGE2_RED_TERMINAL=behavioral_red:clipboard_unicode_limit')
		}
		assert issues.len == 0, 'Win32 CF_UNICODETEXT RED:\n${issues.join('\n')}'
	}
}

fn test_win32_native_clipboard_occupancy_timeout_failure_and_cancel_red() {
	$if windows {
		eprintln('PACKAGE2_RED_TEST=test_win32_native_clipboard_occupancy_timeout_failure_and_cancel_red')
		eprintln('PACKAGE2_RED_FAMILY=clipboard_occupancy_cancel')
		mut issues := []string{}
		mut app := new_app(backend: .win32)!
		window := app.create_window(title: 'Win32 clipboard occupied')!
		_ = app.drain_queued_events()!
		assert C.v_multiwindow_test_win32_start_clipboard_occupancy() == 1
		request := app.service_request_clipboard_text(window) or {
			issues << 'occupied clipboard request was not admitted asynchronously: ${err.msg()}'
			ServiceRequestId{}
		}
		if request != ServiceRequestId{} {
			terminals := win32_red_clipboard_terminals(mut app, request, 400)!
			win32_red_add(mut issues, 'occupied clipboard did not end in one bounded failure',

				terminals.len == 1 && terminals[0].status == .failed)
		}
		C.v_multiwindow_test_win32_stop_clipboard_occupancy()
		app.stop()!

		mut destroy_app := new_app(backend: .win32)!
		destroy_window := destroy_app.create_window(title: 'Win32 clipboard destroy cancel')!
		_ = destroy_app.drain_queued_events()!
		assert C.v_multiwindow_test_win32_start_clipboard_occupancy() == 1
		destroy_request := destroy_app.service_request_clipboard_text(destroy_window) or {
			issues << 'destroy cancellation request was not admitted: ${err.msg()}'
			ServiceRequestId{}
		}
		destroy_app.destroy_window(destroy_window)!
		destroy_events := destroy_app.drain_queued_events()!
		if destroy_request != ServiceRequestId{} {
			destroy_terminals := destroy_events.filter(it.kind == .service
				&& it.service.kind == .clipboard && it.service.clipboard.id == destroy_request)
			win32_red_add(mut issues,
				'destroy did not queue exactly one cancelled clipboard terminal',
				destroy_terminals.len == 1
				&& destroy_terminals[0].service.clipboard.status == .cancelled)
		}
		C.v_multiwindow_test_win32_stop_clipboard_occupancy()
		destroy_app.stop()!

		mut stop_app := new_app(backend: .win32)!
		stop_window := stop_app.create_window(title: 'Win32 clipboard stop cancel')!
		_ = stop_app.drain_queued_events()!
		assert C.v_multiwindow_test_win32_start_clipboard_occupancy() == 1
		stop_request := stop_app.service_request_clipboard_text(stop_window) or {
			issues << 'stop cancellation request was not admitted: ${err.msg()}'
			ServiceRequestId{}
		}
		stop_app.stop()!
		stop_events := stop_app.drain_queued_events()!
		if stop_request != ServiceRequestId{} {
			stop_terminals := stop_events.filter(it.kind == .service
				&& it.service.kind == .clipboard && it.service.clipboard.id == stop_request)
			win32_red_add(mut issues,
				'stop did not queue exactly one cancelled clipboard terminal',

				stop_terminals.len == 1 && stop_terminals[0].service.clipboard.status == .cancelled)
		}
		C.v_multiwindow_test_win32_stop_clipboard_occupancy()
		if issues.len > 0 {
			eprintln('PACKAGE2_RED_TERMINAL=behavioral_red:clipboard_occupancy_cancel')
		}
		assert issues.len == 0, 'Win32 clipboard occupancy RED:\n${issues.join('\n')}'
	}
}

fn win32_red_mouse_release_case(cause string) ![]string {
	mut app := new_app(backend: .win32)!
	mut app_stopped := false
	defer {
		if !app_stopped {
			app.stop() or {}
		}
	}
	first := app.create_window(title: 'Win32 mouse lock first')!
	second := app.create_window(title: 'Win32 mouse lock second')!
	_ = app.drain_queued_events()!
	first_hwnd := win32_red_hwnd(app, first)!
	second_hwnd := win32_red_hwnd(app, second)!
	mut issues := []string{}
	app.service_set_mouse_lock(first, true) or { issues << 'lock failed: ${err.msg()}' }
	win32_red_poll(mut app, 3)!
	win32_red_add(mut issues, 'Raw Input target is not the locked HWND',
		C.v_multiwindow_test_win32_raw_mouse_registered_for(first_hwnd) == 1
		&& C.v_multiwindow_test_win32_raw_mouse_target() == first_hwnd)
	win32_red_add(mut issues, 'ClipCursor is not bounded to the locked client',
		C.v_multiwindow_test_win32_clip_matches_client(first_hwnd) == 1)
	win32_red_add(mut issues, 'second window inherited first-window mouse lock',
		C.v_multiwindow_test_win32_raw_mouse_registered_for(second_hwnd) == 0)

	match cause {
		'focus' {
			if C.v_multiwindow_test_win32_emit_focus_loss(first_hwnd, second_hwnd) != 1 {
				return error('native WM_KILLFOCUS oracle trigger failed')
			}
			win32_red_poll(mut app, 4)!
		}
		'hide' {
			app.service_hide_window(first) or {
				issues << 'hide release service failed: ${err.msg()}'
			}
			win32_red_poll(mut app, 2)!
		}
		'destroy' {
			app.destroy_window(first)!
			win32_red_poll(mut app, 2)!
		}
		'stop' {
			app.stop()!
			app_stopped = true
		}
		else {}
	}
	win32_red_add(mut issues, '${cause} left Raw Input targeting the released HWND',
		C.v_multiwindow_test_win32_raw_mouse_registered_for(first_hwnd) == 0)
	win32_red_add(mut issues, '${cause} left mouse capture on the released HWND',
		C.v_multiwindow_test_win32_capture() != first_hwnd)
	win32_red_add(mut issues, '${cause} did not release ClipCursor to the virtual screen',
		C.v_multiwindow_test_win32_clip_is_virtual_screen() == 1)
	if cause == 'focus' || cause == 'hide' {
		state := app.service_window_state(first)!
		win32_red_add(mut issues, '${cause} did not publish mouse_locked=off',
			state.mouse_locked == .off)
	}
	if !app_stopped {
		app.stop()!
		app_stopped = true
	}
	return issues
}

fn test_win32_native_raw_input_clipcursor_release_and_two_window_isolation_red() {
	$if windows {
		eprintln('PACKAGE2_RED_TEST=test_win32_native_raw_input_clipcursor_release_and_two_window_isolation_red')
		eprintln('PACKAGE2_RED_FAMILY=mouse_lock_isolation')
		mut issues := []string{}
		for cause in ['focus', 'hide', 'destroy', 'stop'] {
			for issue in win32_red_mouse_release_case(cause)! {
				issues << '${cause}: ${issue}'
			}
		}
		if issues.len > 0 {
			eprintln('PACKAGE2_RED_TERMINAL=behavioral_red:mouse_lock_isolation')
		}
		assert issues.len == 0, 'Win32 Raw Input/ClipCursor RED:\n${issues.join('\n')}'
	}
}

fn test_win32_native_conditional_titlebar_dwm_and_style_oracles_red() {
	$if windows {
		eprintln('PACKAGE2_RED_TEST=test_win32_native_conditional_titlebar_dwm_and_style_oracles_red')
		eprintln('PACKAGE2_RED_FAMILY=titlebar_dwm_style')
		mut app := new_app(backend: .win32)!
		defer {
			app.stop() or {}
		}
		decorated := app.create_window(title: 'Win32 DWM titlebar')!
		borderless := app.create_window(title: 'Win32 borderless', borderless: true)!
		decorated_hwnd := win32_red_hwnd(app, decorated)!
		borderless_hwnd := win32_red_hwnd(app, borderless)!
		mut issues := []string{}
		decorated_capability := app.service_operation_capability(decorated, .titlebar_appearance)!
		borderless_capability := app.service_operation_capability(borderless, .titlebar_appearance)!
		win32_red_add(mut issues, 'decorated titlebar capability is not conditional', win32_red_capability_matches(decorated_capability,
			.conditional, false, false, false))
		win32_red_add(mut issues, 'borderless titlebar capability is not unsupported',
			borderless_capability.support == .unsupported)
		win32_red_add(mut issues, 'decorated HWND lacks WS_CAPTION',
			C.v_multiwindow_test_win32_style(decorated_hwnd) & win32_red_ws_caption != 0)
		win32_red_add(mut issues, 'borderless HWND unexpectedly has WS_CAPTION',
			C.v_multiwindow_test_win32_style(borderless_hwnd) & win32_red_ws_caption == 0)
		_ = C.v_multiwindow_test_win32_ex_style(decorated_hwnd)

		mut original_dark := 0
		dwm_observable := C.v_multiwindow_test_win32_dwm_dark(decorated_hwnd, &original_dark) == 1
		app.service_set_titlebar_appearance(decorated, .dark) or {
			if dwm_observable {
				issues << 'DWM dark titlebar failed: ${err.msg()}'
			}
		}
		if dwm_observable {
			mut dark := 0
			assert C.v_multiwindow_test_win32_dwm_dark(decorated_hwnd, &dark) == 1, 'DWM dark-titlebar oracle query failed after admission'

			win32_red_add(mut issues, 'DWM did not observe dark titlebar', dark == 1)
		}
		app.service_set_titlebar_appearance(decorated, .light) or {
			if dwm_observable {
				issues << 'DWM light titlebar failed: ${err.msg()}'
			}
		}
		if dwm_observable {
			mut light := 1
			assert C.v_multiwindow_test_win32_dwm_dark(decorated_hwnd, &light) == 1, 'DWM light-titlebar oracle query failed after admission'

			win32_red_add(mut issues, 'DWM did not observe light titlebar', light == 0)
		}
		app.service_set_titlebar_appearance(decorated, .system) or {
			if dwm_observable {
				issues << 'DWM system titlebar restore failed: ${err.msg()}'
			}
		}
		if dwm_observable {
			mut restored := -1
			assert C.v_multiwindow_test_win32_dwm_dark(decorated_hwnd, &restored) == 1, 'DWM system-titlebar oracle query failed after admission'

			win32_red_add(mut issues, 'DWM system titlebar did not restore prior state',
				restored == original_dark)
		}
		if issues.len > 0 {
			eprintln('PACKAGE2_RED_TERMINAL=behavioral_red:titlebar_dwm_style')
		}
		assert issues.len == 0, 'Win32 conditional titlebar RED:\n${issues.join('\n')}'
	}
}

fn test_win32_nonreadback_no_flag_facade_stays_disabled() {
	vlib_dir := os.join_path(@DIR, '..', '..')
	base := os.join_path(os.temp_dir(), 'win32_package2_no_flag_${os.getpid()}')
	source_path := '${base}.v'
	binary_path := '${base}.bin'
	defer {
		os.rm(source_path) or {}
		os.rm(binary_path) or {}
		os.rm('${binary_path}.exe') or {}
	}
	source := [
		'module main',
		'',
		'import gg',
		'',
		'fn main() {',
		'\tmut app := gg.App{}',
		'\tapp.monitor_ids() or {',
		'\t\tprintln(err.msg())',
		'\t\treturn',
		'\t}',
		"\tprintln('unexpected success')",
		'}',
	].join('\n')
	os.write_file(source_path, source) or { panic(err) }
	compile :=
		os.execute('${os.quoted_path(@VEXE)} -gc none -subsystem console -path "${vlib_dir}|@vlib|@vmodules" -o ${os.quoted_path(binary_path)} ${os.quoted_path(source_path)}')
	assert compile.exit_code == 0, 'no-flag consumer failed to compile:\n${compile.output}'
	executable := if os.exists(binary_path) { binary_path } else { '${binary_path}.exe' }
	run := os.execute(os.quoted_path(executable))
	assert run.exit_code == 0, 'no-flag consumer failed to run:\n${run.output}'
	assert run.output.trim_space() == 'gg.multiwindow: compile with `-d gg_multiwindow` to enable gg.App'
}
