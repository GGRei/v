module multiwindow

import os
import time

fn test_x11_service_state_transitions_are_qualified_by_native_property() {
	assert x11_service_state_transition_operations(true, false, false, true, false, false, false,
		false) == [.minimize]
	assert x11_service_state_transition_operations(true, false, true, false, false, false, false,
		false) == [.restore]
	assert x11_service_state_transition_operations(false, true, false, false, false, true, false,
		false) == [.maximize]
	assert x11_service_state_transition_operations(false, true, false, false, true, false, false,
		false) == [.restore]
	assert x11_service_state_transition_operations(false, true, false, false, false, false, false,
		true) == [.fullscreen]
	assert x11_service_state_transition_operations(false, true, false, false, true, false, true,
		false) == [.restore]
}

fn test_x11_native_service_controls_borrow_monitors_and_readback() {
	$if linux && x_multiwindow_x11 ? {
		if os.getenv('DISPLAY') == '' {
			return
		}
		mut app := new_app(backend: .x11)!
		owner := app.create_window(title: 'package2-owner', width: 96, height: 72)!
		child := app.create_window(
			title:  'package2-child'
			width:  64
			height: 48
		)!
		modal_child := app.create_window(
			title:  'package2-modal-child'
			width:  40
			height: 30
			owner:  owner
			modal:  true
		)!
		_ = app.drain_events()!
		assert app.service_operation_capability(child, .image_readback)!.support == .unsupported
		assert app.service_operation_capability(child, .window_capture)!.support == .available

		monitors := app.service_monitor_ids()!
		assert monitors.len > 0
		monitor := app.service_monitor_info(monitors[0])!
		assert monitor.available
		assert monitor.geometry.known
		assert monitor.geometry.value.width > 0
		assert monitor.geometry.value.height > 0
		assert !monitor.scale.known, 'X11 physical monitor DPI must not be exposed as logical UI scale'
		assert app.backend.x11.service_owner_modal_matches_for_test(modal_child, owner, true)!
		assert app.backend.x11.service_ewmh_capabilities_match_root_for_test()
		assert app.backend.x11.service_root_property_subscription_for_test(), 'X11 backend did not subscribe to root property changes'
		assert app.backend.x11.service_randr_subscription_for_test(), 'X11 backend did not subscribe to RandR topology events'
		randr_events := app.backend.x11.service_randr_snapshot_events_for_test()!
		assert randr_events.len == 1
		accepted_randr := app.accept_backend_event_batch(randr_events, app.frame_count + 1)!
		assert accepted_randr.accepted == 1
		randr_delivery := app.drain_queued_events()!
		assert randr_delivery.len == 1
		assert randr_delivery[0].kind == .service
		assert randr_delivery[0].service.kind == .monitor
		assert randr_delivery[0].service.window == WindowId{}
		assert randr_delivery[0].service.monitors.len > 0
		assert randr_delivery[0].service.monitors[0].sequence > 0
		initial_monitor_id := monitors[0]
		empty_randr := app.backend.x11.service_randr_events_for_snapshot_for_test([])
		assert empty_randr.len == 1
		accepted_empty := app.accept_backend_event_batch(empty_randr, app.frame_count + 2)!
		assert accepted_empty.accepted == 1
		empty_delivery := app.drain_queued_events()!
		assert empty_delivery.len == 1
		assert empty_delivery[0].service.kind == .monitor
		assert empty_delivery[0].service.monitors.len == 0
		assert app.service_monitor_ids()!.len == 0
		replug_randr := app.backend.x11.service_randr_snapshot_events_for_test()!
		accepted_replug := app.accept_backend_event_batch(replug_randr, app.frame_count + 3)!
		assert accepted_replug.accepted == 1
		_ = app.drain_queued_events()!
		replugged_ids := app.service_monitor_ids()!
		assert replugged_ids.len > 0
		assert replugged_ids[0].slot_for_gg() == initial_monitor_id.slot_for_gg()
		assert replugged_ids[0].generation_for_gg() == initial_monitor_id.generation_for_gg() + 1
		mut stale_monitor_rejected := false
		app.service_monitor_info(initial_monitor_id) or {
			assert err.msg() == err_service_request_stale
			stale_monitor_rejected = true
		}
		assert stale_monitor_rejected
		replugged_monitor := app.service_monitor_info(replugged_ids[0])!
		if replugged_monitor.work_area.known {
			assert replugged_monitor.work_area.value.width > 0
			assert replugged_monitor.work_area.value.height > 0
		}
		if replugged_monitor.scale.known {
			assert replugged_monitor.scale.value > 0
		}

		// Separate native MapNotify/UnmapNotify observations from the synchronous
		// state returned by the service calls.
		_ = app.poll_events()!
		_ = app.drain_queued_events()!
		app.service_show_window(child)!
		_ = app.drain_queued_events()!
		mut mapped_before_hide := false
		for _ in 0 .. 100 {
			_ = app.poll_events()!
			_ = app.drain_queued_events()!
			if app.backend.x11.service_window_state(child)!.mapping == .mapped {
				mapped_before_hide = true
				break
			}
			time.sleep(time.millisecond)
		}
		assert mapped_before_hide, 'X11 service test window was not mapped before hide'
		app.service_hide_window(child)!
		_ = app.drain_queued_events()!
		mut native_hidden := false
		for _ in 0 .. 100 {
			_ = app.poll_events()!
			hide_events := app.drain_queued_events()!
			if hide_events.any(it.kind == .service && it.service.kind == .state
				&& it.service.window == child && it.service.state.mapping == .unmapped
				&& it.service.state.visibility == .hidden)
			{
				native_hidden = true
				break
			}
			time.sleep(time.millisecond)
		}
		assert native_hidden, 'X11 UnmapNotify did not publish a canonical state transition'
		app.service_show_window(child)!
		_ = app.drain_queued_events()!
		mut native_visible := false
		for _ in 0 .. 100 {
			_ = app.poll_events()!
			show_events := app.drain_queued_events()!
			if show_events.any(it.kind == .service && it.service.kind == .state
				&& it.service.window == child && it.service.state.mapping == .mapped
				&& it.service.state.visibility == .visible)
			{
				native_visible = true
				break
			}
			time.sleep(time.millisecond)
		}
		assert native_visible, 'X11 MapNotify did not publish a canonical state transition'

		app.service_hide_window(child)!
		app.service_show_window(child)!
		app.service_set_position(child, 8, 8)!
		app.service_raise_window(child)!
		raise_capability := app.service_operation_capability(child, .raise)!
		assert raise_capability.support == .available
		assert !raise_capability.state_observable
		_ = app.drain_queued_events()!
		_ = app.poll_events()!
		_ = app.drain_queued_events()!
		assert app.service_operation_capability(child, .mouse_lock)!.support == .conditional
		mut lock_acquired := false
		for _ in 0 .. 100 {
			app.service_set_mouse_lock(child, true) or {
				time.sleep(time.millisecond)
				continue
			}
			lock_acquired = true
			break
		}
		assert lock_acquired, 'X11 pointer grab was not acquired for the native proof'
		assert app.backend.x11.service_mouse_locked_for_test(child)!
		_ = app.drain_queued_events()!
		app.backend.x11.service_warp_relative_for_test(child, 3, 2)!
		mut relative_motion := false
		for _ in 0 .. 100 {
			_ = app.poll_events()!
			motion_events := app.drain_queued_events()!
			if motion_events.any(it.kind == .input && it.input.window_id == child
				&& it.input.kind == .mouse_move && it.input.mouse_dx == 3 && it.input.mouse_dy == 2)
			{
				relative_motion = true
				break
			}
			time.sleep(time.millisecond)
		}
		assert relative_motion, 'X11 locked pointer did not report relative motion'
		assert app.backend.x11.service_pointer_recentered_for_test(child)!
		app.service_hide_window(child)!
		_ = app.drain_queued_events()!
		mut unmap_released_lock := false
		for _ in 0 .. 100 {
			_ = app.poll_events()!
			unmap_events := app.drain_queued_events()!
			if !app.backend.x11.service_mouse_locked_for_test(child)!
				&& unmap_events.any(it.kind == .service && it.service.kind == .state
				&& it.service.window == child && it.service.state.mouse_locked == .off) {
				unmap_released_lock = true
				break
			}
			time.sleep(time.millisecond)
		}
		assert unmap_released_lock, 'X11 UnmapNotify did not release and publish mouse lock state'
		app.service_show_window(child)!
		_ = app.drain_queued_events()!
		mut focus_lock_acquired := false
		for _ in 0 .. 100 {
			app.service_set_mouse_lock(child, true) or {
				time.sleep(time.millisecond)
				continue
			}
			focus_lock_acquired = true
			break
		}
		assert focus_lock_acquired
		_ = app.drain_queued_events()!
		app.backend.x11.service_send_focus_out_for_test(child)!
		mut focus_released_lock := false
		for _ in 0 .. 100 {
			_ = app.poll_events()!
			focus_events := app.drain_queued_events()!
			if !app.backend.x11.service_mouse_locked_for_test(child)!
				&& focus_events.any(it.kind == .service && it.service.kind == .state
				&& it.service.window == child && it.service.state.mouse_locked == .off) {
				focus_released_lock = true
				break
			}
			time.sleep(time.millisecond)
		}
		assert focus_released_lock, 'X11 FocusOut did not release and publish mouse lock state'
		focus_capability := app.service_operation_capability(child, .focus)!
		if focus_capability.support == .available {
			app.service_request_focus(child)!
		} else {
			assert focus_capability.support == .unsupported
		}

		app_ptr := unsafe { voidptr(app) }
		callback := fn [app_ptr, child] (borrow NativeWindowBorrow) ! {
			owner_app := unsafe { &App(app_ptr) }
			assert borrow.backend_for_gg() == .x11
			assert borrow.primary_for_gg() != unsafe { nil }
			assert borrow.secondary_for_gg() != 0
			assert owner_app.validate_native_borrow_for_gg(child, borrow.epoch_for_gg())! == .x11
		}
		app.with_native_window_for_gg(child, callback)!

		portal_capability := app.service_operation_capability(child, .portal_parent)!
		assert portal_capability.support == .available
		assert portal_capability.asynchronous
		portal_request := app.service_request_portal_parent(child)!
		portal_events := app.drain_queued_events()!
		portal_results := portal_events.filter(it.kind == .service
			&& it.service.kind == .portal_parent && it.service.portal_parent.id == portal_request)
		assert portal_results.len == 1
		portal := portal_results[0].service.portal_parent
		assert portal.status == .ready
		assert portal.identifier.starts_with('x11:')
		assert portal.identifier.len > 4
		app.service_release_portal_parent(portal.lease)!

		clipboard_text := 'x.multiwindow native X11 clipboard'
		clipboard_write := app.service_set_clipboard_text(child, clipboard_text)!
		clipboard_write_events := app.drain_queued_events()!
		clipboard_write_results := clipboard_write_events.filter(it.kind == .service
			&& it.service.kind == .clipboard && it.service.clipboard.id == clipboard_write)
		assert clipboard_write_results.len == 1
		assert clipboard_write_results[0].service.clipboard.status == .ready
		utf8_advertised, legacy_advertised := app.backend.x11.service_clipboard_targets_for_test(child,
			owner)!
		assert utf8_advertised
		assert !legacy_advertised
		clipboard_read := app.service_request_clipboard_text(child)!
		mut clipboard_result := ServiceClipboardResult{}
		mut clipboard_found := false
		for _ in 0 .. 100 {
			_ = app.poll_events()!
			clipboard_events := app.drain_queued_events()!
			clipboard_results := clipboard_events.filter(it.kind == .service
				&& it.service.kind == .clipboard && it.service.clipboard.id == clipboard_read)
			if clipboard_results.len == 1 {
				clipboard_result = clipboard_results[0].service.clipboard
				clipboard_found = true
				break
			}
			time.sleep(time.millisecond)
		}
		assert clipboard_found
		assert clipboard_result.status == .ready
		assert clipboard_result.text == clipboard_text

		large_clipboard_text := '0123456789abcdef'.repeat(8192)
		large_write := app.service_set_clipboard_text(child, large_clipboard_text)!
		large_write_events := app.drain_queued_events()!
		assert large_write_events.any(it.kind == .service && it.service.kind == .clipboard
			&& it.service.clipboard.id == large_write && it.service.clipboard.status == .ready)
		large_read := app.service_request_clipboard_text(child)!
		mut large_result := ServiceClipboardResult{}
		mut large_found := false
		for _ in 0 .. 200 {
			_ = app.poll_events()!
			large_events := app.drain_queued_events()!
			large_results := large_events.filter(it.kind == .service
				&& it.service.kind == .clipboard && it.service.clipboard.id == large_read)
			if large_results.len == 1 {
				large_result = large_results[0].service.clipboard
				large_found = true
				break
			}
			time.sleep(time.millisecond)
		}
		assert large_found
		assert large_result.status == .ready
		assert large_result.text == large_clipboard_text

		// A peer that starts INCR but never deletes the property must not retain
		// the copied payload forever.
		mut completed_transfer_released := false
		for _ in 0 .. 100 {
			_ = app.poll_events()!
			_ = app.drain_queued_events()!
			_, completed_transfers := app.backend.x11.service_clipboard_pending_counts_for_test()
			if completed_transfers == 0 {
				completed_transfer_released = true
				break
			}
			time.sleep(time.millisecond)
		}
		assert completed_transfer_released, 'completed X11 INCR transfer was not released'
		app.backend.x11.service_start_unresponsive_incr_peer_for_test(owner)!
		mut transfer_started := false
		for _ in 0 .. 100 {
			_ = app.poll_events()!
			_ = app.drain_queued_events()!
			_, transfers := app.backend.x11.service_clipboard_pending_counts_for_test()
			if transfers == 1 {
				transfer_started = true
				break
			}
			time.sleep(time.millisecond)
		}
		assert transfer_started, 'X11 INCR transfer did not enter the bounded pending state'
		app.backend.x11.service_expire_clipboard_for_test()
		_ = app.poll_events()!
		_, transfers_after_timeout := app.backend.x11.service_clipboard_pending_counts_for_test()
		assert transfers_after_timeout == 0

		// A selection owner that never answers must produce one terminal failure.
		app.backend.x11.service_make_clipboard_peer_unresponsive_for_test(owner)!
		stalled_read := app.service_request_clipboard_text(child)!
		reads_before_timeout, _ := app.backend.x11.service_clipboard_pending_counts_for_test()
		assert reads_before_timeout == 1
		app.backend.x11.service_expire_clipboard_for_test()
		_ = app.poll_events()!
		stalled_events := app.drain_queued_events()!
		stalled_results := stalled_events.filter(it.kind == .service
			&& it.service.kind == .clipboard && it.service.clipboard.id == stalled_read)
		assert stalled_results.len == 1
		assert stalled_results[0].service.clipboard.status == .failed
		assert stalled_results[0].service.clipboard.error == err_clipboard_timeout

		// Destroying the requestor cancels the canonical request once and purges
		// the backend state before the native window disappears.
		interrupted := app.create_window(title: 'clipboard-interrupted', width: 32, height: 24)!
		_ = app.drain_queued_events()!
		interrupted_read := app.service_request_clipboard_text(interrupted)!
		app.destroy_window(interrupted)!
		interrupted_events := app.drain_queued_events()!
		interrupted_results := interrupted_events.filter(it.kind == .service
			&& it.service.kind == .clipboard && it.service.clipboard.id == interrupted_read)
		assert interrupted_results.len == 1
		assert interrupted_results[0].service.clipboard.status == .cancelled
		reads_after_destroy, transfers_after_destroy :=
			app.backend.x11.service_clipboard_pending_counts_for_test()
		assert reads_after_destroy == 0
		assert transfers_after_destroy == 0

		mut probe := app.backend.x11.service_readback_probe_for_test(child, 32, 24)!
		for _ in 0 .. 100 {
			if probe.map_state == 2 {
				break
			}
			_ = app.poll_events()!
			time.sleep(5 * time.millisecond)
			probe = app.backend.x11.service_readback_probe_for_test(child, 32, 24)!
		}
		assert probe.attributes_available == 1, 'X11 readback probe has no window attributes'
		assert probe.map_state == 2, 'X11 readback probe map_state=${probe.map_state}, native=${probe.actual_width}x${probe.actual_height}, requested=${probe.requested_width}x${probe.requested_height}, pixels=${probe.pixels_length}, expected=${probe.expected_pixels_length}'
		assert probe.actual_width >= probe.requested_width
		assert probe.actual_height >= probe.requested_height
		assert probe.pixels_length == probe.expected_pixels_length
		app.backend.x11.service_paint_readback_pattern_for_test(child, 5, 7)!
		pattern_readback := app.service_request_window_readback_region(child, 5, 7, 2, 2, 1)!
		pattern_events := app.drain_queued_events()!
		pattern_results := pattern_events.filter(it.kind == .readback
			&& it.readback.id == pattern_readback)
		assert pattern_results.len == 1
		pattern := pattern_results[0].readback.pixels_rgba8
		assert pattern.len == 16
		assert pattern[0] > 200 && pattern[1] < 55 && pattern[2] < 55 && pattern[3] == 255
		assert pattern[4] < 55 && pattern[5] > 200 && pattern[6] < 55 && pattern[7] == 255
		assert pattern[8] < 55 && pattern[9] < 55 && pattern[10] > 200 && pattern[11] == 255
		assert pattern[12] > 200 && pattern[13] > 200 && pattern[14] > 200 && pattern[15] == 255
		readback := app.service_request_window_readback(child, 32, 24, 1)!
		events := app.drain_queued_events()!
		results := events.filter(it.kind == .readback && it.readback.id == readback)
		assert results.len == 1
		assert results[0].readback.status == .ready
		assert results[0].readback.pixels_rgba8.len == 32 * 24 * 4
		app.stop()!
	}
}

fn test_x11_clipboard_global_operation_and_byte_limits() {
	$if linux && x_multiwindow_x11 ? {
		if os.getenv('DISPLAY') == '' {
			return
		}
		mut read_app := new_app(backend: .x11)!
		read_owner := read_app.create_window(
			title:  'clipboard-capacity-owner'
			width:  32
			height: 24
		)!
		reader := read_app.create_window(title: 'clipboard-capacity-reader', width: 32, height: 24)!
		_ = read_app.drain_queued_events()!

		read_app.backend.x11.service_make_clipboard_peer_unresponsive_for_test(read_owner)!
		mut reads := []ServiceRequestId{cap: x11_clipboard_max_pending_operations}
		for _ in 0 .. x11_clipboard_max_pending_operations {
			reads << read_app.service_request_clipboard_text(reader)!
		}
		mut overflow_error := ''
		read_app.service_request_clipboard_text(reader) or { overflow_error = err.msg() }
		assert overflow_error == err_clipboard_capacity
		pending_reads, pending_transfers :=
			read_app.backend.x11.service_clipboard_pending_counts_for_test()
		assert pending_reads == reads.len
		assert pending_transfers == 0
		read_app.destroy_window(reader)!
		cancelled_events := read_app.drain_queued_events()!
		cancelled := cancelled_events.filter(it.kind == .service && it.service.kind == .clipboard
			&& it.service.clipboard.status == .cancelled && it.service.window == reader)
		assert cancelled.len == reads.len
		read_app.stop()!

		mut transfer_app := new_app(backend: .x11)!
		transfer_owner := transfer_app.create_window(
			title:  'clipboard-byte-owner'
			width:  32
			height: 24
		)!
		first_peer := transfer_app.create_window(
			title:  'clipboard-capacity-peer-a'
			width:  32
			height: 24
		)!
		second_peer := transfer_app.create_window(
			title:  'clipboard-capacity-peer-b'
			width:  32
			height: 24
		)!
		_ = transfer_app.drain_queued_events()!
		payload := 'x'.repeat(x11_clipboard_max_pending_bytes / 2 + 1)
		_ = transfer_app.service_set_clipboard_text(transfer_owner, payload)!
		_ = transfer_app.drain_queued_events()!
		transfer_app.backend.x11.service_start_unresponsive_incr_peer_for_test(first_peer)!
		mut first_started := false
		for _ in 0 .. 100 {
			_ = transfer_app.poll_events()!
			_ = transfer_app.drain_queued_events()!
			_, transfers := transfer_app.backend.x11.service_clipboard_pending_counts_for_test()
			if transfers == 1 {
				first_started = true
				break
			}
			time.sleep(time.millisecond)
		}
		assert first_started
		first_bytes := transfer_app.backend.x11.service_clipboard_pending_bytes_for_test()
		assert first_bytes == u64(payload.len)
		transfer_app.backend.x11.service_start_unresponsive_incr_peer_for_test(second_peer)!
		for _ in 0 .. 20 {
			_ = transfer_app.poll_events()!
			_ = transfer_app.drain_queued_events()!
			time.sleep(time.millisecond)
		}
		_, transfers_after_overflow :=
			transfer_app.backend.x11.service_clipboard_pending_counts_for_test()
		assert transfers_after_overflow == 1
		assert transfer_app.backend.x11.service_clipboard_pending_bytes_for_test() == first_bytes
		transfer_app.stop()!
	}
}

fn test_x11_selection_clear_destroy_and_stop_purge_clipboard_state() {
	$if linux && x_multiwindow_x11 ? {
		if os.getenv('DISPLAY') == '' {
			return
		}
		mut app := new_app(backend: .x11)!
		owner := app.create_window(title: 'clipboard-purge-owner', width: 32, height: 24)!
		peer := app.create_window(title: 'clipboard-purge-peer', width: 32, height: 24)!
		thief := app.create_window(title: 'clipboard-purge-thief', width: 32, height: 24)!
		_ = app.drain_queued_events()!
		payload := 'selection-clear'.repeat(8192)
		_ = app.service_set_clipboard_text(owner, payload)!
		_ = app.drain_queued_events()!
		app.backend.x11.service_start_unresponsive_incr_peer_for_test(peer)!
		mut transfer_started := false
		for _ in 0 .. 100 {
			_ = app.poll_events()!
			_ = app.drain_queued_events()!
			_, transfers := app.backend.x11.service_clipboard_pending_counts_for_test()
			if transfers == 1 {
				transfer_started = true
				break
			}
			time.sleep(time.millisecond)
		}
		assert transfer_started
		owned_before_clear, text_before_clear := app.backend.x11.service_clipboard_owner_for_test()
		assert owned_before_clear
		assert text_before_clear == payload.len
		app.backend.x11.service_take_clipboard_selection_for_test(thief)!
		mut selection_clear_observed := false
		for _ in 0 .. 100 {
			_ = app.poll_events()!
			_ = app.drain_queued_events()!
			owned, _ := app.backend.x11.service_clipboard_owner_for_test()
			if !owned {
				selection_clear_observed = true
				break
			}
			time.sleep(time.millisecond)
		}
		assert selection_clear_observed
		owned_after_clear, text_after_clear := app.backend.x11.service_clipboard_owner_for_test()
		reads_after_clear, transfers_after_clear :=
			app.backend.x11.service_clipboard_pending_counts_for_test()
		assert !owned_after_clear
		assert text_after_clear == 0
		assert reads_after_clear == 0
		assert transfers_after_clear == 0

		_ = app.service_set_clipboard_text(owner, payload)!
		_ = app.drain_queued_events()!
		app.backend.x11.service_start_unresponsive_incr_peer_for_test(peer)!
		for _ in 0 .. 100 {
			_ = app.poll_events()!
			_ = app.drain_queued_events()!
			_, transfers := app.backend.x11.service_clipboard_pending_counts_for_test()
			if transfers == 1 {
				break
			}
			time.sleep(time.millisecond)
		}
		app.destroy_window(owner)!
		_ = app.drain_queued_events()!
		owned_after_destroy, text_after_destroy :=
			app.backend.x11.service_clipboard_owner_for_test()
		reads_after_destroy, transfers_after_destroy :=
			app.backend.x11.service_clipboard_pending_counts_for_test()
		assert !owned_after_destroy
		assert text_after_destroy == 0
		assert reads_after_destroy == 0
		assert transfers_after_destroy == 0

		_ = app.service_set_clipboard_text(thief, 'stop-purge')!
		_ = app.drain_queued_events()!
		app.backend.x11.service_make_clipboard_peer_unresponsive_for_test(thief)!
		_ = app.service_request_clipboard_text(peer)!
		app.stop()!
		owned_after_stop, text_after_stop := app.backend.x11.service_clipboard_owner_for_test()
		reads_after_stop, transfers_after_stop :=
			app.backend.x11.service_clipboard_pending_counts_for_test()
		assert !owned_after_stop
		assert text_after_stop == 0
		assert reads_after_stop == 0
		assert transfers_after_stop == 0
	}
}

fn test_monitor_reconciliation_keeps_slots_and_advances_replug_generation() {
	mut registry := new_service_registry(73, .x11)
	first := ServiceMonitorInfo{
		id:        ServiceMonitorId{
			app_instance: 73
			slot:         0
			generation:   1
		}
		name:      'HDMI-A-1'
		available: true
	}
	registry.replace_monitors([first])
	assert registry.reconcile_monitor_snapshot([], 10).len == 0
	assert !registry.monitors[0].available
	replugged := registry.reconcile_monitor_snapshot([first], 11)
	assert replugged.len == 1
	assert replugged[0].id.slot == first.id.slot
	assert replugged[0].id.generation == first.id.generation + 1
	registry.monitor_index(first.id) or {
		assert err.msg() == err_service_request_stale
		return
	}
	assert false, 'removed monitor generation remained valid after replug'
}

fn test_x11_native_borrow_copy_is_stale_after_callback() {
	$if linux && x_multiwindow_x11 ? {
		if os.getenv('DISPLAY') == '' {
			return
		}
		mut app := new_app(backend: .x11)!
		window := app.create_window(title: 'borrow-stale-proof')!
		_ = app.drain_queued_events()!
		mut copied := NativeWindowBorrow{}
		callback := fn [mut copied] (borrow NativeWindowBorrow) ! {
			copied = borrow
		}
		app.with_native_window_for_gg(window, callback)!
		app.validate_native_borrow_for_gg(window, copied.epoch_for_gg()) or {
			assert err.msg() == err_native_borrow_stale
			app.stop()!
			return
		}
		assert false, 'copied X11 native borrow remained valid after its callback'
	}
}

fn test_x11_stop_purges_unfinished_clipboard_state() {
	$if linux && x_multiwindow_x11 ? {
		if os.getenv('DISPLAY') == '' {
			return
		}
		mut app := new_app(backend: .x11)!
		owner := app.create_window(title: 'clipboard-unresponsive-owner')!
		requestor := app.create_window(title: 'clipboard-stop-requestor')!
		_ = app.drain_queued_events()!
		app.backend.x11.service_make_clipboard_peer_unresponsive_for_test(owner)!
		_ = app.service_request_clipboard_text(requestor)!
		reads, _ := app.backend.x11.service_clipboard_pending_counts_for_test()
		assert reads == 1
		app.stop()!
		reads_after, transfers_after := app.backend.x11.service_clipboard_pending_counts_for_test()
		assert reads_after == 0
		assert transfers_after == 0
	}
}

fn test_x11_native_borrow_defers_destroy_until_callback_return() {
	$if linux && x_multiwindow_x11 ? {
		if os.getenv('DISPLAY') == '' {
			return
		}
		mut app := new_app(backend: .x11)!
		window := app.create_window(title: 'borrow-destroy-proof')!
		_ = app.drain_queued_events()!
		app_ptr := unsafe { voidptr(app) }
		callback := fn [app_ptr, window] (_ NativeWindowBorrow) ! {
			mut owner := unsafe { &App(app_ptr) }
			owner.destroy_window(window)!
			assert owner.window_exists(window)
			assert owner.backend.x11.window_record_index(window) != none
		}
		app.with_native_window_for_gg(window, callback)!
		assert !app.window_exists(window)
		_ = app.backend.x11.window_record_index(window) or {
			app.stop()!
			return
		}
		assert false, 'X11 native window survived deferred destroy flush'
	}
}

fn test_x11_native_borrow_defers_stop_until_callback_return() {
	$if linux && x_multiwindow_x11 ? {
		if os.getenv('DISPLAY') == '' {
			return
		}
		mut app := new_app(backend: .x11)!
		window := app.create_window(title: 'borrow-stop-proof')!
		_ = app.drain_queued_events()!
		app_ptr := unsafe { voidptr(app) }
		callback := fn [app_ptr] (_ NativeWindowBorrow) ! {
			mut owner := unsafe { &App(app_ptr) }
			owner.stop()!
			assert owner.status() == .running
		}
		app.with_native_window_for_gg(window, callback)!
		assert app.status() == .stopped
	}
}
