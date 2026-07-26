// vtest retry: 0
module multiwindow

import time

const win32_red_clipboard_max_bytes = 16 * 1024 * 1024
const win32_red_ws_caption = u64(0x00c00000)
const win32_red_ws_child = u64(0x40000000)

#flag windows -DV_MULTIWINDOW_WIN32_SERVICE_TEST

$if windows {
	#include "@VMODROOT/vlib/x/multiwindow/testdata/win32_nonreadback_test_oracle.h"

	fn C.v_multiwindow_win32_service_test_set_focus_refused(refused int)
	fn C.v_multiwindow_win32_service_test_set_show_failure(fail int)
	fn C.v_multiwindow_win32_service_test_set_fullscreen_exit_failure(failure int)
	fn C.v_multiwindow_win32_service_test_set_fullscreen_rollback_failure(failure_mask int)
	fn C.v_multiwindow_win32_service_test_fullscreen_rollback_attempts() int
	fn C.v_multiwindow_win32_test_modal_trace_reset(owner voidptr, window voidptr)
	fn C.v_multiwindow_win32_test_modal_set_enable_failure(fail int)
	fn C.v_multiwindow_win32_test_modal_set_enable_failures(count int)
	fn C.v_multiwindow_win32_test_modal_set_show_created_failures(count int)
	fn C.v_multiwindow_win32_test_modal_set_destroy_failures(count int)
	fn C.v_multiwindow_win32_test_modal_trace_window_value() voidptr
	fn C.v_multiwindow_win32_test_modal_owner_disable_count_value() int
	fn C.v_multiwindow_win32_test_modal_owner_enable_count_value() int
	fn C.v_multiwindow_win32_test_modal_show_count_value() int
	fn C.v_multiwindow_win32_test_modal_destroy_count_value() int
	fn C.v_multiwindow_win32_test_modal_owner_destroy_count_value() int
	fn C.v_multiwindow_win32_test_modal_destroy_attempt_count_value() int
	fn C.v_multiwindow_win32_test_modal_owner_destroy_attempt_count_value() int
	fn C.v_multiwindow_win32_test_modal_owner_disable_sequence_value() u64
	fn C.v_multiwindow_win32_test_modal_owner_enable_sequence_value() u64
	fn C.v_multiwindow_win32_test_modal_show_sequence_value() u64
	fn C.v_multiwindow_win32_test_modal_destroy_sequence_value() u64
	fn C.v_multiwindow_win32_test_modal_owner_destroy_sequence_value() u64
	fn C.v_multiwindow_test_win32_is_window(hwnd voidptr) int
	fn C.v_multiwindow_test_win32_is_visible(hwnd voidptr) int
	fn C.v_multiwindow_test_win32_is_enabled(hwnd voidptr) int
	fn C.v_multiwindow_test_win32_set_enabled(hwnd voidptr, enabled int) int
	fn C.v_multiwindow_test_win32_is_iconic(hwnd voidptr) int
	fn C.v_multiwindow_test_win32_is_zoomed(hwnd voidptr) int
	fn C.v_multiwindow_test_win32_foreground() voidptr
	fn C.v_multiwindow_test_win32_focus() voidptr
	fn C.v_multiwindow_test_win32_establish_foreground_focus(hwnd voidptr) int
	fn C.v_multiwindow_test_win32_swap_user_data(hwnd voidptr, replacement voidptr) voidptr
	fn C.v_multiwindow_test_win32_owner(hwnd voidptr) voidptr
	fn C.v_multiwindow_test_win32_style(hwnd voidptr) u64
	fn C.v_multiwindow_test_win32_ex_style(hwnd voidptr) u64
	fn C.v_multiwindow_test_win32_rect(hwnd voidptr, left &int, top &int, right &int, bottom &int) int
	fn C.v_multiwindow_test_win32_is_above(upper voidptr, lower voidptr) int
	fn C.v_multiwindow_test_win32_window_snapshot_new(hwnd voidptr) voidptr
	fn C.v_multiwindow_test_win32_window_snapshot_free(snapshot voidptr)
	fn C.v_multiwindow_test_win32_window_snapshot_matches(snapshot voidptr, hwnd voidptr) int
	fn C.v_multiwindow_test_win32_synthesized_windowed_matches(hwnd voidptr, resizable int, borderless int, requested_width int, requested_height int, expected_visible int, expected_show_command u32) int
	fn C.v_multiwindow_test_win32_service_wrong_thread_rejected(service_state voidptr) int
	fn C.v_multiwindow_test_win32_service_wrong_thread_timing(worker_delay u32, wait_timeout u32)
	fn C.v_multiwindow_test_win32_service_wrong_thread_active_count() int
	fn C.v_multiwindow_test_win32_service_wrong_thread_wait_cleanup(timeout u32) int
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

fn win32_w1_wrong_thread_service_state(backend_pointer voidptr, id WindowId) string {
	unsafe {
		backend := &Win32Backend(backend_pointer)
		backend.service_window_state(id) or { return err.msg() }
	}
	return ''
}

struct Win32W1BorrowEpochProof {
mut:
	epoch        u64
	valid_inside bool
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

fn test_win32_w1_native_authority_show_focus_and_fullscreen_contract() {
	$if windows {
		mut app := new_app(backend: .win32)!
		defer {
			app.stop() or {}
		}
		target := app.create_window(
			title:   'Win32 W1 target'
			width:   220
			height:  140
			visible: false
		)!
		peer := app.create_window(
			title:  'Win32 W1 visible peer'
			width:  180
			height: 120
		)!
		_ = app.drain_queued_events()!
		index := app.backend.win32.window_record_index(target) or {
			assert false, 'W1 target has no Win32 record'
			return
		}
		record := app.backend.win32.windows[index]
		peer_index := app.backend.win32.window_record_index(peer) or {
			assert false, 'W1 peer has no Win32 record'
			return
		}
		peer_record := app.backend.win32.windows[peer_index]
		hwnd := record.hwnd
		peer_hwnd := peer_record.hwnd
		assert hwnd != unsafe { nil }
		assert peer_hwnd != unsafe { nil }
		assert record.service_state != unsafe { nil }

		assert C.v_multiwindow_test_win32_service_wrong_thread_rejected(record.service_state) == 1
		C.v_multiwindow_test_win32_service_wrong_thread_timing(25, 1)
		assert C.v_multiwindow_test_win32_service_wrong_thread_rejected(record.service_state) == 0
		assert C.v_multiwindow_test_win32_service_wrong_thread_active_count() == 1
		assert C.v_multiwindow_test_win32_service_wrong_thread_wait_cleanup(1000) == 1
		assert C.v_multiwindow_test_win32_service_wrong_thread_active_count() == 0
		C.v_multiwindow_test_win32_service_wrong_thread_timing(0, 5000)
		backend_pointer := unsafe { voidptr(&app.backend.win32) }
		wrong_thread := spawn win32_w1_wrong_thread_service_state(backend_pointer, target)
		assert wrong_thread.wait() == err_owner_thread_required

		show_capability := app.backend.win32.service_operation_capability(target, .show)
		assert win32_red_capability_matches(show_capability, .available, false, false, true)
		focus_capability := app.backend.win32.service_operation_capability(target, .focus)
		assert win32_red_capability_matches(focus_capability, .conditional, false, true, true)
		fullscreen_capability := app.backend.win32.service_operation_capability(target, .fullscreen)
		assert win32_red_capability_matches(fullscreen_capability, .available, false, false, true)

		foreground_before_show := C.v_multiwindow_test_win32_foreground()
		first_show := app.backend.win32.service_show_window(target)!
		second_show := app.backend.win32.service_show_window(target)!
		assert C.v_multiwindow_test_win32_is_visible(hwnd) == 1
		assert first_show.mapping == .mapped && first_show.visibility == .visible
		assert second_show.mapping == .mapped && second_show.visibility == .visible
		if foreground_before_show != unsafe { nil } && foreground_before_show != hwnd {
			assert C.v_multiwindow_test_win32_foreground() != hwnd, 'idempotent show unexpectedly activated the target window'
		}

		hidden_before_focus := app.backend.win32.service_hide_window(target)!
		assert hidden_before_focus.active == .off
		assert hidden_before_focus.focused == .off
		assert C.v_multiwindow_test_win32_establish_foreground_focus(peer_hwnd) == 1
		foreground_before_refusal := C.v_multiwindow_test_win32_foreground()
		focus_before_refusal := C.v_multiwindow_test_win32_focus()
		assert foreground_before_refusal == peer_hwnd
		assert focus_before_refusal == peer_hwnd
		C.v_multiwindow_win32_service_test_set_focus_refused(1)
		focus_after := app.backend.win32.service_focus_window(target)!
		C.v_multiwindow_win32_service_test_set_focus_refused(0)
		assert focus_after.active == .off
		assert focus_after.focused == .off
		assert focus_after.focused != .on || focus_after.active == .on
		assert C.v_multiwindow_test_win32_foreground() == foreground_before_refusal
		assert C.v_multiwindow_test_win32_focus() == focus_before_refusal
		_ = app.backend.win32.service_show_window(target)!

		replacement_data := unsafe { voidptr(peer_record) }
		expected_data := unsafe { voidptr(record) }
		original_data := C.v_multiwindow_test_win32_swap_user_data(hwnd, replacement_data)
		mut replaced_state_error := ''
		if _ := app.backend.win32.service_window_state(target) {
			replaced_state_error = 'replaced GWLP_USERDATA unexpectedly retained authority'
		} else {
			replaced_state_error = err.msg()
		}
		mut replaced_borrow_error := ''
		if _ := app.backend.win32.service_native_window_borrow(target) {
			replaced_borrow_error = 'recycled GWLP_USERDATA unexpectedly retained HWND borrow authority'
		} else {
			replaced_borrow_error = err.msg()
		}
		replaced_data := C.v_multiwindow_test_win32_swap_user_data(hwnd, original_data)
		assert original_data == expected_data
		assert replaced_data == replacement_data
		assert replaced_state_error == err_window_not_found
		assert replaced_borrow_error == err_window_not_found
		_ = app.backend.win32.service_window_state(target)!

		windowed_snapshot := C.v_multiwindow_test_win32_window_snapshot_new(hwnd)
		assert windowed_snapshot != unsafe { nil }
		defer {
			C.v_multiwindow_test_win32_window_snapshot_free(windowed_snapshot)
		}
		first_fullscreen := app.backend.win32.service_set_fullscreen(target, true)!
		assert first_fullscreen.fullscreen == .on
		fullscreen_snapshot := C.v_multiwindow_test_win32_window_snapshot_new(hwnd)
		assert fullscreen_snapshot != unsafe { nil }
		defer {
			C.v_multiwindow_test_win32_window_snapshot_free(fullscreen_snapshot)
		}
		second_fullscreen := app.backend.win32.service_set_fullscreen(target, true)!
		assert second_fullscreen.fullscreen == .on
		assert C.v_multiwindow_test_win32_window_snapshot_matches(fullscreen_snapshot, hwnd) == 1, 'idempotent fullscreen enter changed native state'

		for failure in 1 .. 4 {
			C.v_multiwindow_win32_service_test_set_fullscreen_exit_failure(failure)
			mut failure_error := ''
			if _ := app.backend.win32.service_set_fullscreen(target, false) {
				failure_error = 'injected fullscreen exit failure unexpectedly succeeded'
			} else {
				failure_error = err.msg()
			}
			C.v_multiwindow_win32_service_test_set_fullscreen_exit_failure(0)
			assert failure_error == err_capability_unsupported
			rollback_state := app.backend.win32.service_window_state(target)!
			assert rollback_state.fullscreen == .on
			assert C.v_multiwindow_test_win32_window_snapshot_matches(fullscreen_snapshot, hwnd) == 1, 'fullscreen exit failure ${failure} left partial native state'
		}

		first_restore := app.backend.win32.service_set_fullscreen(target, false)!
		assert first_restore.fullscreen == .off
		assert C.v_multiwindow_test_win32_window_snapshot_matches(windowed_snapshot, hwnd) == 1, 'fullscreen exit did not restore style/exstyle/WINDOWPLACEMENT'
		second_restore := app.backend.win32.service_set_fullscreen(target, false)!
		assert second_restore.fullscreen == .off
		assert C.v_multiwindow_test_win32_window_snapshot_matches(windowed_snapshot, hwnd) == 1, 'idempotent fullscreen exit changed restored native state'

		rollback_target := app.create_window(
			title:  'Win32 W1 rollback failure'
			width:  240
			height: 160
		)!
		rollback_index := app.backend.win32.window_record_index(rollback_target) or {
			assert false, 'W1 rollback target has no Win32 record'
			return
		}
		rollback_hwnd := app.backend.win32.windows[rollback_index].hwnd
		_ = app.backend.win32.service_set_fullscreen(rollback_target, true)!
		rollback_fullscreen_snapshot :=
			C.v_multiwindow_test_win32_window_snapshot_new(rollback_hwnd)
		assert rollback_fullscreen_snapshot != unsafe { nil }
		defer {
			C.v_multiwindow_test_win32_window_snapshot_free(rollback_fullscreen_snapshot)
		}
		C.v_multiwindow_win32_service_test_set_fullscreen_rollback_failure(1)
		C.v_multiwindow_win32_service_test_set_fullscreen_exit_failure(1)
		mut rollback_failure_error := ''
		if _ := app.backend.win32.service_set_fullscreen(rollback_target, false) {
			rollback_failure_error = 'injected rollback failure unexpectedly succeeded'
		} else {
			rollback_failure_error = err.msg()
		}
		C.v_multiwindow_win32_service_test_set_fullscreen_exit_failure(0)
		rollback_attempts := C.v_multiwindow_win32_service_test_fullscreen_rollback_attempts()
		C.v_multiwindow_win32_service_test_set_fullscreen_rollback_failure(0)
		assert rollback_failure_error == err_capability_unsupported
		assert rollback_attempts == 15
		unknown_rollback_state := app.backend.win32.service_window_state(rollback_target)!
		assert unknown_rollback_state.fullscreen == .unknown
		assert C.v_multiwindow_test_win32_window_snapshot_matches(rollback_fullscreen_snapshot,
			rollback_hwnd) == 0, 'injected rollback failure unexpectedly restored an exact native snapshot'

		initial_fullscreen := app.create_window(
			title:      'Win32 W1 initial fullscreen'
			width:      320
			height:     200
			resizable:  true
			borderless: false
			fullscreen: true
		)!
		initial_index := app.backend.win32.window_record_index(initial_fullscreen) or {
			assert false, 'W1 initial-fullscreen window has no Win32 record'
			return
		}
		initial_hwnd := app.backend.win32.windows[initial_index].hwnd
		initial_state := app.backend.win32.service_window_state(initial_fullscreen)!
		assert initial_state.fullscreen == .on
		synthesized_restore := app.backend.win32.service_set_fullscreen(initial_fullscreen, false)!
		assert synthesized_restore.fullscreen == .off
		assert C.v_multiwindow_test_win32_synthesized_windowed_matches(initial_hwnd, 1, 0, 320,
			200, 1, 3) == 1
		synthesized_snapshot := C.v_multiwindow_test_win32_window_snapshot_new(initial_hwnd)
		assert synthesized_snapshot != unsafe { nil }
		defer {
			C.v_multiwindow_test_win32_window_snapshot_free(synthesized_snapshot)
		}
		second_synthesized_restore := app.backend.win32.service_set_fullscreen(initial_fullscreen,
			false)!
		assert second_synthesized_restore.fullscreen == .off
		assert C.v_multiwindow_test_win32_window_snapshot_matches(synthesized_snapshot,
			initial_hwnd) == 1, 'idempotent synthesized restore changed native state'

		hidden_initial_fullscreen := app.create_window(
			title:      'Win32 W1 hidden initial fullscreen'
			width:      320
			height:     200
			resizable:  true
			borderless: false
			fullscreen: true
			visible:    false
		)!
		hidden_initial_index := app.backend.win32.window_record_index(hidden_initial_fullscreen) or {
			assert false, 'W1 hidden initial-fullscreen window has no Win32 record'
			return
		}
		hidden_initial_hwnd := app.backend.win32.windows[hidden_initial_index].hwnd
		assert C.v_multiwindow_test_win32_is_visible(hidden_initial_hwnd) == 0
		hidden_initial_state := app.backend.win32.service_window_state(hidden_initial_fullscreen)!
		assert hidden_initial_state.fullscreen == .on
		hidden_synthesized_restore := app.backend.win32.service_set_fullscreen(hidden_initial_fullscreen,
			false)!
		assert hidden_synthesized_restore.fullscreen == .off
		assert hidden_synthesized_restore.visibility == .hidden
		assert C.v_multiwindow_test_win32_is_visible(hidden_initial_hwnd) == 0
		assert C.v_multiwindow_test_win32_synthesized_windowed_matches(hidden_initial_hwnd, 1, 0,
			320, 200, 0, 1) == 1

		stale := app.create_window(title: 'Win32 W1 stale generation', visible: false)!
		app.destroy_window(stale)!
		replacement := app.create_window(title: 'Win32 W1 replacement', visible: false)!
		assert replacement.slot == stale.slot
		assert replacement.generation == stale.generation + 1
		mut stale_error := ''
		if _ := app.backend.win32.service_window_state(stale) {
			stale_error = 'stale WindowId unexpectedly resolved'
		} else {
			stale_error = err.msg()
		}
		assert stale_error == err_window_not_found
	}
}

fn test_win32_w1_native_borrow_is_bounded_and_epoch_checked() {
	$if windows {
		mut app := new_app(backend: .win32)!
		defer {
			app.stop() or {}
		}
		window := app.create_window(title: 'Win32 W1 native borrow')!
		_ = app.drain_queued_events()!
		raw := app.backend.win32.service_native_window_borrow(window)!
		assert raw.backend == .win32
		assert raw.primary != unsafe { nil }
		assert raw.secondary == 0
		assert C.v_multiwindow_test_win32_is_window(raw.primary) == 1

		app_pointer := unsafe { voidptr(app) }
		shared epoch_proof := Win32W1BorrowEpochProof{}
		copy_callback := fn [app_pointer, shared epoch_proof, window, raw] (borrow NativeWindowBorrow) ! {
			owner := unsafe { &App(app_pointer) }
			assert borrow.window_for_gg() == window
			assert borrow.backend_for_gg() == .win32
			assert borrow.primary_for_gg() == raw.primary
			backend := owner.validate_native_borrow_for_gg(window, borrow.epoch_for_gg())!
			lock epoch_proof {
				epoch_proof.epoch = borrow.epoch_for_gg()
				epoch_proof.valid_inside = backend == .win32
			}
		}
		app.with_native_window_borrow(window, raw.backend, raw.primary, raw.secondary,
			copy_callback)!
		epoch, valid_inside := rlock epoch_proof {
			epoch_proof.epoch, epoch_proof.valid_inside
		}
		assert epoch != 0
		assert valid_inside
		mut epoch_error := ''
		if _ := app.validate_native_borrow_for_gg(window, epoch) {
			epoch_error = 'borrow epoch remained valid after callback'
		} else {
			epoch_error = err.msg()
		}
		assert epoch_error == err_native_borrow_stale

		bounded := app.backend.win32.service_native_window_borrow(window)!
		foreign_callback := fn [app_pointer, window] (borrow NativeWindowBorrow) ! {
			mut owner := unsafe { &App(app_pointer) }
			assert owner.validate_native_borrow_for_gg(window, borrow.epoch_for_gg())! == .win32
			result := chan string{cap: 1}
			worker := spawn fn [app_pointer, result, window] () {
				mut foreign := unsafe { &App(app_pointer) }
				foreign.destroy_window(window) or {
					result <- err.msg()
					return
				}
				result <- 'accepted'
			}()
			assert <-result == err_owner_thread_required
			worker.wait()
			owner.state_mutex.lock()
			queued := window in owner.deferred_native_windows
			owner.state_mutex.unlock()
			assert !queued
			assert owner.window_exists(window)
		}
		app.with_native_window_borrow(window, bounded.backend, bounded.primary, bounded.secondary,
			foreign_callback)!
		assert app.window_exists(window)
		assert C.v_multiwindow_test_win32_is_window(bounded.primary) == 1

		destroy_callback := fn [app_pointer, window, bounded] (borrow NativeWindowBorrow) ! {
			mut owner := unsafe { &App(app_pointer) }
			assert owner.validate_native_borrow_for_gg(window, borrow.epoch_for_gg())! == .win32
			assert borrow.primary_for_gg() == bounded.primary
			owner.destroy_window(window)!
			assert owner.window_exists(window)
			assert C.v_multiwindow_test_win32_is_window(bounded.primary) == 1
		}
		app.with_native_window_borrow(window, bounded.backend, bounded.primary, bounded.secondary,
			destroy_callback)!
		assert !app.window_exists(window)
		assert C.v_multiwindow_test_win32_is_window(bounded.primary) == 0
		mut destroyed_events := 0
		for event in app.drain_queued_events()! {
			if event.kind == .lifecycle && event.lifecycle.kind == .window_destroyed
				&& event.lifecycle.window_id == window {
				destroyed_events++
			}
		}
		assert destroyed_events == 1
	}
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

fn win32_w2_native_modal_fault_path_regressions(mut issues []string) ! {
	$if windows {
		mut create_app := new_app(backend: .win32)!
		defer {
			C.v_multiwindow_win32_test_modal_set_enable_failures(0)
			C.v_multiwindow_win32_test_modal_set_show_created_failures(0)
			create_app.stop() or {}
		}
		create_owner := create_app.create_window(title: 'Win32 modal create-fault owner')!
		create_owner_hwnd := win32_red_hwnd(create_app, create_owner)!
		before_create_records := create_app.backend.win32.windows.len
		C.v_multiwindow_win32_test_modal_trace_reset(create_owner_hwnd, unsafe { nil })
		C.v_multiwindow_win32_test_modal_set_show_created_failures(1)
		C.v_multiwindow_win32_test_modal_set_enable_failures(1)
		mut create_error := ''
		create_app.create_window(
			title: 'Win32 modal create-fault child'
			owner: create_owner
			modal: true
		) or { create_error = err.msg() }
		C.v_multiwindow_win32_test_modal_set_show_created_failures(0)
		C.v_multiwindow_win32_test_modal_set_enable_failures(0)
		attempted_hwnd := C.v_multiwindow_win32_test_modal_trace_window_value()
		win32_red_add(mut issues, 'create show/release fault suppressed rollback failure',
			create_error.contains(err_win32_create_window_failed)
			&& create_error.contains('modal rollback failed:'))
		win32_red_add(mut issues, 'create show/release fault left a backend record',
			create_app.backend.win32.windows.len == before_create_records)
		win32_red_add(mut issues, 'create show/release fault left a native HWND',
			attempted_hwnd != unsafe { nil }
			&& C.v_multiwindow_test_win32_is_window(attempted_hwnd) == 0)
		win32_red_add(mut issues, 'create show/release fault left owner disabled',
			C.v_multiwindow_test_win32_is_enabled(create_owner_hwnd) == 1)
		win32_red_add(mut issues, 'create show/release recovery violated release-before-destroy',
			C.v_multiwindow_win32_test_modal_owner_enable_count_value() == 1
			&& C.v_multiwindow_win32_test_modal_destroy_count_value() == 1
			&& C.v_multiwindow_win32_test_modal_owner_enable_sequence_value() > 0
			&& C.v_multiwindow_win32_test_modal_owner_enable_sequence_value() < C.v_multiwindow_win32_test_modal_destroy_sequence_value())
		create_app.destroy_window(create_owner) or {
			issues << 'create-fault owner cleanup failed: ${err.msg()}'
		}

		mut destroy_app := new_app(backend: .win32)!
		defer {
			C.v_multiwindow_win32_test_modal_set_destroy_failures(0)
			destroy_app.stop() or {}
		}
		destroy_owner := destroy_app.create_window(title: 'Win32 modal destroy-fault owner')!
		destroy_modal := destroy_app.create_window(
			title: 'Win32 modal destroy-fault child'
			owner: destroy_owner
			modal: true
		)!
		_ = destroy_app.drain_queued_events()!
		destroy_owner_hwnd := win32_red_hwnd(destroy_app, destroy_owner)!
		destroy_modal_hwnd := win32_red_hwnd(destroy_app, destroy_modal)!
		C.v_multiwindow_win32_test_modal_trace_reset(destroy_owner_hwnd, destroy_modal_hwnd)
		C.v_multiwindow_win32_test_modal_set_destroy_failures(1)
		mut destroy_error := ''
		destroy_app.destroy_window(destroy_modal) or { destroy_error = err.msg() }
		C.v_multiwindow_win32_test_modal_set_destroy_failures(0)
		expected_child_destroy_error := 'multiwindow: terminal lifecycle failed: multiwindow: win32 destroy window failed'
		win32_red_add(mut issues, 'DestroyWindow fault was not propagated',
			destroy_error == expected_child_destroy_error)
		mut child_destroy_events := 0
		for event in destroy_app.drain_queued_events()! {
			if event.kind == .lifecycle && event.lifecycle.kind == .window_destroyed
				&& event.lifecycle.window_id == destroy_modal {
				child_destroy_events++
			}
		}
		win32_red_add(mut issues, 'failed child destroy did not become core-terminal once',

			destroy_app.window_destroy_finished(destroy_modal) && child_destroy_events == 1)
		if destroy_modal_index := destroy_app.backend.win32.window_record_index(destroy_modal) {
			if destroy_owner_index := destroy_app.backend.win32.window_record_index(destroy_owner) {
				destroy_record := destroy_app.backend.win32.windows[destroy_modal_index]
				mut retained_owner_matches := false
				if retained_owner := destroy_record.config.owner {
					retained_owner_matches = retained_owner == destroy_owner
				}
				win32_red_add(mut issues,
					'DestroyWindow fault did not retain complete released child debt',
					destroy_record.hwnd == destroy_modal_hwnd
					&& destroy_record.service_state != unsafe { nil } && retained_owner_matches
					&& !destroy_record.modal_active
					&& destroy_app.backend.win32.windows[destroy_owner_index].modal_child_count == 0
					&& !destroy_app.backend.win32.windows[destroy_owner_index].modal_restore_enabled)
			} else {
				issues << 'DestroyWindow fault removed the owner record'
			}
		} else {
			issues << 'DestroyWindow fault removed the modal record'
		}
		win32_red_add(mut issues, 'DestroyWindow fault did not retain released child HWND',
			C.v_multiwindow_test_win32_is_window(destroy_modal_hwnd) == 1
			&& C.v_multiwindow_test_win32_is_enabled(destroy_owner_hwnd) == 1)
		win32_red_add(mut issues, 'DestroyWindow fault reactivated native modality',
			C.v_multiwindow_win32_test_modal_owner_enable_count_value() == 1
			&& C.v_multiwindow_win32_test_modal_owner_disable_count_value() == 0
			&& C.v_multiwindow_win32_test_modal_destroy_count_value() == 0
			&& C.v_multiwindow_win32_test_modal_destroy_attempt_count_value() == 1)
		mut retained_child_records := 0
		for retained_record in destroy_app.backend.win32.windows {
			if retained_record.id == destroy_modal {
				retained_child_records++
			}
		}
		win32_red_add(mut issues, 'DestroyWindow fault did not retain exactly one child debt',

			retained_child_records == 1 && destroy_app.backend.win32.windows.len == 2)
		mut replay_error := ''
		destroy_app.destroy_window(destroy_modal) or { replay_error = err.msg() }
		mut replay_destroy_events := 0
		for event in destroy_app.drain_queued_events()! {
			if event.kind == .lifecycle && event.lifecycle.kind == .window_destroyed
				&& event.lifecycle.window_id == destroy_modal {
				replay_destroy_events++
			}
		}
		win32_red_add(mut issues, 'second child destroy did not replay terminal error',
			replay_error == destroy_error)
		win32_red_add(mut issues, 'second child destroy retried HWND or emitted another event',
			C.v_multiwindow_win32_test_modal_destroy_attempt_count_value() == 1
			&& replay_destroy_events == 0)
		mut owner_destroy_error := ''
		destroy_app.destroy_window(destroy_owner) or { owner_destroy_error = err.msg() }
		expected_owner_destroy_error := 'multiwindow: terminal lifecycle failed: multiwindow: window owner relation is invalid'
		win32_red_add(mut issues, 'retained child debt did not reject owner destroy',
			owner_destroy_error == expected_owner_destroy_error
			&& destroy_app.window_destroy_finished(destroy_owner))
		mut owner_destroy_events := 0
		for event in destroy_app.drain_queued_events()! {
			if event.kind == .lifecycle && event.lifecycle.kind == .window_destroyed
				&& event.lifecycle.window_id == destroy_owner {
				owner_destroy_events++
			}
		}
		win32_red_add(mut issues, 'rejected owner destroy did not emit exactly one event',
			owner_destroy_events == 1)
		win32_red_add(mut issues, 'rejected owner destroy reached native DestroyWindow',
			C.v_multiwindow_test_win32_is_window(destroy_owner_hwnd) == 1
			&& C.v_multiwindow_test_win32_is_window(destroy_modal_hwnd) == 1
			&& C.v_multiwindow_win32_test_modal_owner_destroy_attempt_count_value() == 0)
		win32_red_add(mut issues, 'rejected owner destroy changed released modality',
			C.v_multiwindow_test_win32_is_enabled(destroy_owner_hwnd) == 1
			&& C.v_multiwindow_win32_test_modal_owner_enable_count_value() == 1
			&& C.v_multiwindow_win32_test_modal_owner_disable_count_value() == 0)
		mut owner_replay_error := ''
		destroy_app.destroy_window(destroy_owner) or { owner_replay_error = err.msg() }
		mut owner_replay_destroy_events := 0
		for event in destroy_app.drain_queued_events()! {
			if event.kind == .lifecycle && event.lifecycle.kind == .window_destroyed
				&& event.lifecycle.window_id == destroy_owner {
				owner_replay_destroy_events++
			}
		}
		win32_red_add(mut issues, 'second owner destroy did not replay terminal error',
			owner_replay_error == expected_owner_destroy_error)
		win32_red_add(mut issues, 'second owner destroy retried HWND or emitted another event',
			C.v_multiwindow_win32_test_modal_owner_destroy_attempt_count_value() == 0
			&& owner_replay_destroy_events == 0)
		destroy_app.stop() or { issues << 'retained child debt stop cleanup failed: ${err.msg()}' }
		win32_red_add(mut issues, 'one stop left retained Win32 records',
			destroy_app.backend.win32.windows.len == 0)
		win32_red_add(mut issues, 'one stop left native owner/modal HWNDs alive',
			C.v_multiwindow_test_win32_is_window(destroy_owner_hwnd) == 0
			&& C.v_multiwindow_test_win32_is_window(destroy_modal_hwnd) == 0)
		win32_red_add(mut issues, 'stop did not retry retained child before owner',
			C.v_multiwindow_win32_test_modal_destroy_attempt_count_value() == 2
			&& C.v_multiwindow_win32_test_modal_owner_destroy_attempt_count_value() == 1
			&& C.v_multiwindow_win32_test_modal_destroy_count_value() == 1
			&& C.v_multiwindow_win32_test_modal_owner_destroy_count_value() == 1
			&& C.v_multiwindow_win32_test_modal_destroy_sequence_value() > 0
			&& C.v_multiwindow_win32_test_modal_destroy_sequence_value() < C.v_multiwindow_win32_test_modal_owner_destroy_sequence_value())
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
			modal:   true
			visible: false
		)!
		modal_peer := app.create_window(
			title:   'Win32 modal peer'
			owner:   owner
			modal:   true
			visible: false
		)!
		_ = app.drain_queued_events()!
		owner_hwnd := win32_red_hwnd(app, owner)!
		child_hwnd := win32_red_hwnd(app, child)!
		grandchild_hwnd := win32_red_hwnd(app, grandchild)!
		modal_peer_hwnd := win32_red_hwnd(app, modal_peer)!
		mut issues := []string{}
		win32_w2_native_modal_fault_path_regressions(mut issues) or {
			issues << 'modal fault-path setup failed: ${err.msg()}'
		}

		app.service_show_window(child) or { issues << 'modal show failed: ${err.msg()}' }
		app.service_show_window(child) or { issues << 'idempotent modal show failed: ${err.msg()}' }
		win32_red_poll(mut app, 2)!
		win32_red_add(mut issues, 'GW_OWNER does not match configured owner',
			C.v_multiwindow_test_win32_owner(child_hwnd) == owner_hwnd)
		win32_red_add(mut issues, 'owned window was incorrectly converted to WS_CHILD',
			C.v_multiwindow_test_win32_style(child_hwnd) & win32_red_ws_child == 0)
		win32_red_add(mut issues, 'shown modal child did not disable owner',
			C.v_multiwindow_test_win32_is_enabled(owner_hwnd) == 0)

		app.service_show_window(grandchild) or {
			issues << 'nested modal show failed: ${err.msg()}'
		}
		win32_red_add(mut issues, 'nested modal did not disable its direct owner',
			C.v_multiwindow_test_win32_is_enabled(child_hwnd) == 0)
		win32_red_add(mut issues, 'nested modal unexpectedly re-enabled the root owner',
			C.v_multiwindow_test_win32_is_enabled(owner_hwnd) == 0)
		app.service_hide_window(grandchild) or {
			issues << 'nested modal hide failed: ${err.msg()}'
		}
		win32_red_add(mut issues, 'nested modal did not restore its direct owner',
			C.v_multiwindow_test_win32_is_enabled(child_hwnd) == 1)
		win32_red_add(mut issues, 'nested modal release unexpectedly restored the root owner',
			C.v_multiwindow_test_win32_is_enabled(owner_hwnd) == 0)

		app.service_show_window(modal_peer) or { issues << 'modal peer show failed: ${err.msg()}' }
		win32_red_add(mut issues, 'modal peer GW_OWNER does not match configured owner',
			C.v_multiwindow_test_win32_owner(modal_peer_hwnd) == owner_hwnd)
		app.service_hide_window(child) or { issues << 'modal hide failed: ${err.msg()}' }
		app.service_hide_window(child) or { issues << 'idempotent modal hide failed: ${err.msg()}' }
		win32_red_poll(mut app, 2)!
		win32_red_add(mut issues, 'hiding one modal re-enabled owner while peer remained visible',
			C.v_multiwindow_test_win32_is_enabled(owner_hwnd) == 0)
		app.service_hide_window(modal_peer) or { issues << 'modal peer hide failed: ${err.msg()}' }
		win32_red_add(mut issues, 'hiding final modal child did not re-enable owner',
			C.v_multiwindow_test_win32_is_enabled(owner_hwnd) == 1)

		app.service_show_window(child) or { issues << 'second modal show failed: ${err.msg()}' }
		C.v_multiwindow_win32_test_modal_trace_reset(owner_hwnd, child_hwnd)
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
		win32_red_add(mut issues, 'modal owner was not re-enabled exactly once before destroy',
			C.v_multiwindow_win32_test_modal_owner_enable_count_value() == 1
			&& C.v_multiwindow_win32_test_modal_destroy_count_value() == 1
			&& C.v_multiwindow_win32_test_modal_owner_enable_sequence_value() > 0
			&& C.v_multiwindow_win32_test_modal_owner_enable_sequence_value() < C.v_multiwindow_win32_test_modal_destroy_sequence_value())
		win32_red_add(mut issues, 'canonical lifecycle queue is not child-first',

			destroyed_ids.len == 2 && destroyed_ids[0] == grandchild && destroyed_ids[1] == child)

		C.v_multiwindow_win32_test_modal_trace_reset(owner_hwnd, unsafe { nil })
		initial_modal := app.create_window(
			title: 'Win32 initially visible modal'
			owner: owner
			modal: true
		)!
		initial_modal_hwnd := win32_red_hwnd(app, initial_modal)!
		win32_red_add(mut issues, 'initially visible modal has no configured GW_OWNER',
			C.v_multiwindow_test_win32_owner(initial_modal_hwnd) == owner_hwnd)
		win32_red_add(mut issues, 'initially visible modal did not disable owner',
			C.v_multiwindow_test_win32_is_enabled(owner_hwnd) == 0)
		win32_red_add(mut issues, 'initial modal became visible before disabling its owner',
			C.v_multiwindow_win32_test_modal_owner_disable_count_value() == 1
			&& C.v_multiwindow_win32_test_modal_show_count_value() == 1
			&& C.v_multiwindow_win32_test_modal_owner_disable_sequence_value() > 0
			&& C.v_multiwindow_win32_test_modal_owner_disable_sequence_value() < C.v_multiwindow_win32_test_modal_show_sequence_value())
		app.service_hide_window(initial_modal) or {
			issues << 'initially visible modal hide failed: ${err.msg()}'
		}
		win32_red_add(mut issues, 'hiding initially visible modal did not re-enable owner',
			C.v_multiwindow_test_win32_is_enabled(owner_hwnd) == 1)
		app.destroy_window(initial_modal)!

		disabled_owner := app.create_window(title: 'Win32 initially disabled owner')!
		disabled_owner_hwnd := win32_red_hwnd(app, disabled_owner)!
		win32_red_add(mut issues, 'oracle could not disable modal owner', C.v_multiwindow_test_win32_set_enabled(disabled_owner_hwnd,
			0) == 1)
		disabled_owner_modal := app.create_window(
			title:   'Win32 modal with initially disabled owner'
			owner:   disabled_owner
			modal:   true
			visible: false
		)!
		app.service_show_window(disabled_owner_modal) or {
			issues << 'initially-disabled owner modal show failed: ${err.msg()}'
		}
		app.service_hide_window(disabled_owner_modal) or {
			issues << 'initially-disabled owner modal hide failed: ${err.msg()}'
		}
		win32_red_add(mut issues, 'modal release enabled an owner that started disabled',
			C.v_multiwindow_test_win32_is_enabled(disabled_owner_hwnd) == 0)
		win32_red_add(mut issues, 'oracle could not restore initially-disabled owner for cleanup', C.v_multiwindow_test_win32_set_enabled(disabled_owner_hwnd,
			1) == 1)
		app.destroy_window(disabled_owner_modal)!
		app.destroy_window(disabled_owner)!

		rollback_owner := app.create_window(title: 'Win32 modal rollback owner')!
		rollback_modal := app.create_window(
			title:   'Win32 modal rollback child'
			owner:   rollback_owner
			modal:   true
			visible: false
		)!
		rollback_owner_hwnd := win32_red_hwnd(app, rollback_owner)!
		C.v_multiwindow_win32_service_test_set_show_failure(1)
		C.v_multiwindow_win32_test_modal_set_enable_failure(1)
		mut rollback_error := ''
		app.service_show_window(rollback_modal) or { rollback_error = err.msg() }
		C.v_multiwindow_win32_service_test_set_show_failure(0)
		C.v_multiwindow_win32_test_modal_set_enable_failure(0)
		win32_red_add(mut issues, 'show rollback suppressed release_modal failure',
			rollback_error.contains('modal rollback failed:'))
		if rollback_index := app.backend.win32.window_record_index(rollback_modal) {
			win32_red_add(mut issues, 'failed modal rollback announced inactive state',
				app.backend.win32.windows[rollback_index].modal_active
				&& C.v_multiwindow_test_win32_is_enabled(rollback_owner_hwnd) == 0)
		} else {
			issues << 'failed modal rollback removed the native record'
		}
		app.service_hide_window(rollback_modal) or {
			issues << 'modal rollback recovery failed: ${err.msg()}'
		}
		win32_red_add(mut issues, 'modal rollback recovery did not restore owner',
			C.v_multiwindow_test_win32_is_enabled(rollback_owner_hwnd) == 1)
		app.destroy_window(rollback_modal)!
		app.destroy_window(rollback_owner)!

		teardown_owner := app.create_window(title: 'Win32 modal teardown owner')!
		teardown_modal := app.create_window(
			title: 'Win32 modal teardown child'
			owner: teardown_owner
			modal: true
		)!
		teardown_owner_hwnd := win32_red_hwnd(app, teardown_owner)!
		teardown_modal_hwnd := win32_red_hwnd(app, teardown_modal)!
		C.v_multiwindow_win32_test_modal_set_enable_failure(1)
		mut teardown_error := ''
		app.backend.win32.finish_window_teardown(teardown_modal) or { teardown_error = err.msg() }
		C.v_multiwindow_win32_test_modal_set_enable_failure(0)
		win32_red_add(mut issues, 'teardown ignored modal release failure',
			teardown_error == err_capability_unsupported)
		if teardown_index := app.backend.win32.window_record_index(teardown_modal) {
			win32_red_add(mut issues, 'failed modal release partially destroyed native state',
				app.backend.win32.windows[teardown_index].modal_active
				&& C.v_multiwindow_test_win32_is_window(teardown_modal_hwnd) == 1
				&& C.v_multiwindow_test_win32_is_enabled(teardown_owner_hwnd) == 0)
		} else {
			issues << 'failed modal release removed the native teardown record'
		}
		app.destroy_window(teardown_modal)!
		app.destroy_window(teardown_owner)!

		app.destroy_window(owner)!
		win32_red_poll(mut app, 2)!
		win32_red_add(mut issues, 'owner HWND survived public destroy',
			C.v_multiwindow_test_win32_is_window(owner_hwnd) == 0)

		mut stop_app := new_app(backend: .win32)!
		stop_owner := stop_app.create_window(title: 'Win32 modal stop owner')!
		stop_modal_a := stop_app.create_window(
			title: 'Win32 modal stop child A'
			owner: stop_owner
			modal: true
		)!
		stop_modal_b := stop_app.create_window(
			title: 'Win32 modal stop child B'
			owner: stop_owner
			modal: true
		)!
		stop_owner_hwnd := win32_red_hwnd(stop_app, stop_owner)!
		stop_modal_a_hwnd := win32_red_hwnd(stop_app, stop_modal_a)!
		stop_modal_b_hwnd := win32_red_hwnd(stop_app, stop_modal_b)!
		C.v_multiwindow_win32_test_modal_trace_reset(stop_owner_hwnd, stop_modal_b_hwnd)
		stop_app.stop() or { issues << 'modal stop failed: ${err.msg()}' }
		win32_red_add(mut issues,
			'stop did not restore owner exactly once before final modal destroy',
			C.v_multiwindow_win32_test_modal_owner_enable_count_value() == 1
			&& C.v_multiwindow_win32_test_modal_destroy_count_value() == 1
			&& C.v_multiwindow_win32_test_modal_owner_enable_sequence_value() > 0
			&& C.v_multiwindow_win32_test_modal_owner_enable_sequence_value() < C.v_multiwindow_win32_test_modal_destroy_sequence_value())
		win32_red_add(mut issues, 'stop left native owner/modal HWNDs alive',
			C.v_multiwindow_test_win32_is_window(stop_owner_hwnd) == 0
			&& C.v_multiwindow_test_win32_is_window(stop_modal_a_hwnd) == 0
			&& C.v_multiwindow_test_win32_is_window(stop_modal_b_hwnd) == 0)
		if issues.len > 0 {
			eprintln('PACKAGE2_RED_TERMINAL=behavioral_red:modal_child_first')
		}
		assert issues.len == 0, 'Win32 owner/modal/child-first RED:\n${issues.join('\n')}'
		eprintln('PACKAGE2_W2_GREEN_TERMINAL=behavioral_green:modal_child_first')
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
