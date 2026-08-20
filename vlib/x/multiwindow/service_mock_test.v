module multiwindow

fn test_service_app_id_reaches_wayland_native_adapter_state() {
	mut backend := new_backend(.wayland, false)!
	backend.configure_app(Config{
		backend: .wayland
		app_id:  'org.vlang.package2.test'
	})
	assert backend.wayland.native_app_id() == 'org.vlang.package2.test'

	mut default_backend := new_backend(.wayland, false)!
	default_backend.configure_app(Config{
		backend: .wayland
	})
	assert default_backend.wayland.native_app_id() == 'v.x.multiwindow'
}

fn test_service_cursor_support_is_shape_and_runtime_specific() {
	mut mock := new_backend(.mock, false)!
	assert mock.cursor_support(.resize_all) == .available

	x11 := new_x11_backend()
	assert x11.cursor_support(.pointer) == .available
	assert x11.cursor_support(.not_allowed) == .conditional
	assert x11.cursor_support(.resize_all) == .conditional

	mut wayland := new_wayland_backend()
	assert wayland.cursor_support(.pointer) == .conditional
	assert wayland.cursor_support(.resize_all) == .unsupported
	wayland.pointer = voidptr(1)
	wayland.cursor_shape_manager = voidptr(1)
	wayland.cursor_shape_device = voidptr(1)
	assert wayland.cursor_support(.pointer) == .available

	appkit := new_appkit_backend()
	assert appkit.cursor_support(.pointer) == .available
	assert appkit.cursor_support(.resize_all) == .conditional

	win32 := new_win32_backend()
	assert win32.cursor_support(.resize_all) == .available
}

fn test_mock_native_borrow_is_not_advertised_or_exposed() {
	mut app := new_app()!
	window := app.create_window()!
	assert app.service_operation_capability(window, .native_borrow)!.support == .unsupported
	app.with_native_window_for_gg(window, fn (borrow NativeWindowBorrow) ! {
		_ = borrow
	}) or {
		assert err.msg() == err_capability_unsupported
		app.stop()!
		return
	}
	assert false, 'mock backend exposed a native window borrow'
}

fn test_all_specialized_drains_are_strict_prefix_projections() {
	mut app := new_app()!
	window := app.create_window()!
	app.service_show_window(window)!
	assert app.drain_service_events()!.len == 0
	assert app.drain_input_events()!.len == 0
	assert app.drain_events()!.len == 1

	app.enqueue_mock_input_for_test(InputEvent{
		kind:      .mouse_move
		window_id: window
	})!
	assert app.poll_events()! == 1
	_ = app.service_request_window_readback(window, 1, 1, 1)!
	assert app.drain_input_events()!.len == 0
	assert app.drain_readback_events()!.len == 0
	assert app.drain_service_events()!.len == 1
	assert app.drain_readback_events()!.len == 0
	assert app.drain_input_events()!.len == 1
	assert app.drain_readback_events()!.len == 1
	assert app.drain_queued_events()!.len == 0
	app.stop()!
}

fn test_delivered_terminal_requests_are_purged_once() {
	mut app := new_app()!
	window := app.create_window()!
	_ = app.drain_events()!
	_ = app.service_request_clipboard_text(window)!
	_ = app.service_request_window_readback(window, 1, 1, 1)!
	assert app.services.pending.len == 1
	assert app.services.readbacks.len == 1
	assert app.drain_service_events()!.len == 1
	assert app.services.pending.len == 0
	assert app.services.readbacks.len == 1
	assert app.drain_readback_events()!.len == 1
	assert app.services.readbacks.len == 0
	app.stop()!
}

fn test_service_window_config_copies_preserve_owner_and_modal_relation() {
	owner := WindowId{
		app_instance: 91
		slot:         2
		generation:   7
	}
	config := WindowConfig{
		title:  'child'
		width:  320
		height: 200
		owner:  owner
		modal:  true
	}
	titled := window_config_with_title(config, 'renamed')
	sized := window_config_with_size(config, 640, 480)
	assert titled.owner == config.owner
	assert titled.modal
	assert sized.owner == config.owner
	assert sized.modal
}

fn test_service_create_rollback_does_not_leave_registry_record() {
	mut app := new_app()!
	app.state_mutex.lock()
	app.render_runtime.next_epoch = 0
	app.state_mutex.unlock()
	app.create_window(title: 'rollback') or {
		assert err.msg() == err_window_generation_exhausted
		assert app.services.windows.len == 0
		app.stop()!
		return
	}
	assert false, 'create_window unexpectedly succeeded'
}

fn test_service_monitor_identity_and_native_unknown_state() {
	mut app := new_app()!
	window := app.create_window()!
	_ = app.drain_events()!
	ids := app.service_monitor_ids()!
	assert ids.len == 1
	info := app.service_monitor_info(ids[0])!
	assert info.geometry.value.width == 1920
	assert info.geometry.value.height == 1080

	mut foreign := new_app()!
	foreign.service_monitor_info(ids[0]) or {
		assert err.msg() == err_app_identity_mismatch
		app.stop()!
		foreign.stop()!
		return
	}
	assert false, 'foreign monitor identity was accepted'
	_ = window
}

fn test_native_registry_starts_without_mock_observations() {
	mut registry := new_service_registry(77, .x11)
	id := WindowId{
		app_instance: 77
		slot:         0
		generation:   1
	}
	registry.register_window(id, WindowConfig{ visible: true, fullscreen: true }, WindowSize{
		width:  640
		height: 480
	}, false)
	assert registry.monitors.len == 0
	state := registry.windows[0].state
	assert state.mapping == .unknown
	assert state.visibility == .unknown
	assert state.fullscreen == .unknown
	assert !registry.windows[0].metrics.metrics_available
}

fn test_service_drains_are_prefix_projections_of_canonical_queue() {
	mut app := new_app()!
	window := app.create_window()!
	app.service_show_window(window)!
	assert app.drain_service_events()!.len == 0
	lifecycle := app.drain_events()!
	assert lifecycle.len == 1
	assert lifecycle[0].kind == .window_created
	services := app.drain_service_events()!
	assert services.len == 1
	assert services[0].kind == .state
	app.stop()!
}

fn test_mock_readback_is_canonical_owned_rgba8() {
	mut app := new_app()!
	window := app.create_window()!
	_ = app.drain_events()!
	id := app.service_request_window_readback(window, 2, 3, 9)!
	events := app.drain_queued_events()!
	assert events.len == 1
	assert events[0].kind == .readback
	result := events[0].readback
	assert result.id == id
	assert result.status == .ready
	assert result.submitted_frame == 9
	assert result.width == 2
	assert result.height == 3
	assert result.stride == 8
	assert result.pixels_rgba8.len == 24
	assert result.pixels_rgba8.all(it == 0)
	app.stop()!
}

fn test_service_readback_layout_validation_is_overflow_safe_and_atomic() {
	mut app := new_app()!
	window := app.create_window()!
	_ = app.drain_events()!
	request_before := app.services.next_request
	delivery_before := app.next_event_delivery_token
	app.service_complete_readback(window, 600_000_000, 1, 1, [u8(0)], 1) or {
		assert err.msg() == err_readback_invalid
		assert app.services.next_request == request_before
		assert app.next_event_delivery_token == delivery_before
		assert app.services.readbacks.len == 0
		assert app.drain_queued_events()!.len == 0
	}
	assert app.services.next_request == request_before
	assert app.services.readbacks.len == 0

	readback := app.service_begin_window_readback(window)!
	request_after_begin := app.services.next_request
	delivery_after_begin := app.next_event_delivery_token
	app.service_finish_window_readback(readback, 600_000_000, 1, 1, [u8(0)], 2) or {
		assert err.msg() == err_readback_invalid
		assert app.services.next_request == request_after_begin
		assert app.next_event_delivery_token == delivery_after_begin
		assert app.services.readbacks.len == 1
		assert app.services.readbacks[0].id == readback
		assert !app.services.readbacks[0].terminal
		assert app.drain_queued_events()!.len == 0
	}
	assert app.services.readbacks.len == 1
	assert !app.services.readbacks[0].terminal

	app.service_finish_window_readback(readback, 2, 2, 12, []u8{len: 24}, 3)!
	finished := app.drain_queued_events()!
	assert finished.len == 1
	assert finished[0].kind == .readback
	assert finished[0].readback.id == readback
	assert finished[0].readback.status == .ready
	assert finished[0].readback.width == 2
	assert finished[0].readback.height == 2
	assert finished[0].readback.stride == 12
	assert finished[0].readback.pixels_rgba8.len == 24
	assert app.services.readbacks.len == 0

	completed := app.service_complete_readback(window, 1, 2, 8, []u8{len: 16}, 4)!
	completed_events := app.drain_queued_events()!
	assert completed_events.len == 1
	assert completed_events[0].readback.id == completed
	assert completed_events[0].readback.stride == 8
	assert completed_events[0].readback.pixels_rgba8.len == 16
	app.stop()!
}

fn test_mock_focus_publishes_losses_then_gain_with_authoritative_sequences() {
	mut app := new_app()!
	a := app.create_window(title: 'focus A')!
	b := app.create_window(title: 'focus B')!
	c := app.create_window(title: 'focus C')!
	_ = app.drain_events()!

	app.service_request_focus(a)!
	first := app.drain_queued_events()!
	assert first.len == 1
	assert first[0].kind == .service
	assert first[0].service.window == a
	assert first[0].service.state.active == .on
	assert first[0].service.state.focused == .on
	c_before := app.service_window_state(c)!

	app.service_request_focus(b)!
	transfer := app.drain_queued_events()!
	assert transfer.len == 2
	assert transfer[0].kind == .service
	assert transfer[0].service.window == a
	assert transfer[0].service.operation == .focus
	assert transfer[0].service.state.active == .off
	assert transfer[0].service.state.focused == .off
	assert transfer[1].kind == .service
	assert transfer[1].service.window == b
	assert transfer[1].service.operation == .focus
	assert transfer[1].service.state.active == .on
	assert transfer[1].service.state.focused == .on
	assert transfer[0].sequence < transfer[1].sequence
	assert transfer[0].service.sequence == transfer[0].sequence
	assert transfer[0].service.state.sequence == transfer[0].sequence
	assert transfer[1].service.sequence == transfer[1].sequence
	assert transfer[1].service.state.sequence == transfer[1].sequence
	assert app.service_window_state(a)!.sequence == transfer[0].sequence
	assert app.service_window_state(b)!.sequence == transfer[1].sequence
	c_after := app.service_window_state(c)!
	assert c_after.active == c_before.active
	assert c_after.focused == c_before.focused
	assert c_after.sequence == c_before.sequence

	app.service_request_focus(b)!
	assert app.drain_queued_events()!.len == 0
	assert app.service_window_state(a)!.sequence == transfer[0].sequence
	assert app.service_window_state(b)!.sequence == transfer[1].sequence
	app.stop()!
}

fn test_mock_focus_delivery_exhaustion_is_atomic() {
	mut app := new_app()!
	a := app.create_window(title: 'focus exhaustion A')!
	b := app.create_window(title: 'focus exhaustion B')!
	_ = app.drain_events()!
	app.service_request_focus(a)!
	_ = app.drain_queued_events()!
	a_before := app.service_window_state(a)!
	b_before := app.service_window_state(b)!
	saved_delivery_token := app.next_event_delivery_token
	app.state_mutex.lock()
	app.next_event_delivery_token = ~u64(0)
	app.state_mutex.unlock()

	mut rejected := false
	app.service_request_focus(b) or {
		assert err.msg() == err_event_delivery_exhausted
		rejected = true
	}
	assert rejected
	assert app.next_event_delivery_token == ~u64(0)
	assert app.drain_queued_events()!.len == 0
	a_after := app.service_window_state(a)!
	b_after := app.service_window_state(b)!
	assert a_after.active == a_before.active
	assert a_after.focused == a_before.focused
	assert a_after.sequence == a_before.sequence
	assert b_after.active == b_before.active
	assert b_after.focused == b_before.focused
	assert b_after.sequence == b_before.sequence

	app.state_mutex.lock()
	app.next_event_delivery_token = saved_delivery_token
	app.state_mutex.unlock()
	app.stop()!
}

fn test_owner_modal_registry_and_child_first_cascade() {
	mut app := new_app()!
	owner := app.create_window(title: 'owner')!
	child := app.create_window(WindowConfig{
		title: 'child'
		owner: owner
		modal: true
	})!
	grandchild := app.create_window(WindowConfig{
		title: 'grandchild'
		owner: child
	})!
	sibling := app.create_window(WindowConfig{
		title: 'sibling'
		owner: owner
	})!
	order := app.window_destroy_order(owner)!
	assert order == [grandchild, child, sibling, owner]
	child_index := app.services.window_index(child)!
	assert app.services.windows[child_index].modal

	mut foreign := new_app()!
	foreign_owner := foreign.create_window()!
	app.create_window(WindowConfig{
		owner: foreign_owner
	}) or {
		assert err.msg() == err_app_identity_mismatch
		app.stop()!
		foreign.stop()!
		return
	}
	assert false, 'foreign owner was accepted'
}

fn test_service_cancellation_is_exactly_once_before_registry_removal() {
	mut app := new_app()!
	window := app.create_window()!
	_ = app.drain_events()!
	clipboard := app.services.take_request_id()!
	portal := app.services.take_request_id()!
	readback := app.services.take_readback_id(window)!
	lease := ServicePortalLeaseId{
		app_instance: app.instance_id
		serial:       portal.serial
	}
	app.services.pending << PendingServiceRequest{
		id:     clipboard
		window: window
		kind:   .clipboard_read
	}
	app.services.pending << PendingServiceRequest{
		id:     portal
		window: window
		kind:   .portal_parent
	}
	app.services.readbacks << PendingReadbackRequest{
		id: readback
	}
	app.services.portal_leases << ServicePortalLease{
		id:     lease
		window: window
	}

	ticket := app.prepare_window_destroy(window)!
	app.seal_window_destroy(ticket)!
	assert app.services.window_index(window)! >= 0
	assert app.services.pending.all(it.terminal)
	assert app.services.readbacks.all(it.terminal)
	assert app.services.portal_leases.len == 0
	app.finish_window_destroy(ticket, []string{})!
	events := app.drain_queued_events()!
	assert events.len == 4
	assert events.map(it.kind) == [.service, .service, .readback, .lifecycle]
	for index in 1 .. events.len {
		assert events[index - 1].sequence < events[index].sequence
	}
	assert events[0].service.clipboard.status == .cancelled
	assert events[1].service.portal_parent.status == .cancelled
	assert events[2].readback.status == .cancelled
	assert events[3].lifecycle.kind == .window_destroyed
	assert app.services.pending.len == 0
	assert app.services.readbacks.len == 0
	app.services.window_index(window) or {
		assert err.msg() == err_stale_window
		app.stop()!
		return
	}
	assert false, 'destroyed service record remained registered'
}

fn test_owner_cascade_cancels_descendant_clipboard_portal_and_leases_exactly_once() {
	mut app := new_app()!
	owner := app.create_window(title: 'service cascade owner')!
	child := app.create_window(WindowConfig{
		title: 'service cascade child'
		owner: owner
	})!
	grandchild := app.create_window(WindowConfig{
		title: 'service cascade grandchild'
		owner: child
	})!
	sibling := app.create_window(WindowConfig{
		title: 'service cascade sibling'
		owner: owner
	})!
	order := [grandchild, child, sibling, owner]
	descendants := order[..order.len - 1]
	assert app.drain_events()!.len == order.len
	mut clipboard_requests := []ServiceRequestId{cap: descendants.len}
	mut portal_requests := []ServiceRequestId{cap: descendants.len}
	mut portal_leases := []ServicePortalLeaseId{cap: descendants.len}
	for window in descendants {
		clipboard := app.services.take_request_id()!
		portal := app.services.take_request_id()!
		lease := ServicePortalLeaseId{
			app_instance: app.instance_id
			serial:       portal.serial
		}
		app.services.pending << PendingServiceRequest{
			id:     clipboard
			window: window
			kind:   .clipboard_read
		}
		app.services.pending << PendingServiceRequest{
			id:     portal
			window: window
			kind:   .portal_parent
		}
		app.services.portal_leases << ServicePortalLease{
			id:     lease
			window: window
		}
		clipboard_requests << clipboard
		portal_requests << portal
		portal_leases << lease
	}
	assert app.services.pending.len == descendants.len * 2
	assert app.services.portal_leases.len == descendants.len

	app.destroy_window(owner)!
	assert app.services.pending.len == descendants.len * 2
	assert app.services.pending.all(it.terminal)
	assert app.services.portal_leases.len == 0
	for lease in portal_leases {
		mut rejected := false
		app.service_release_portal_parent(lease) or {
			assert err.msg() == err_service_request_stale
			rejected = true
		}
		assert rejected
	}
	events := app.drain_queued_events()!
	assert events.len == descendants.len * 3 + 1
	for index in 1 .. events.len {
		assert events[index - 1].sequence < events[index].sequence
	}
	mut event_index := 0
	for index, window in descendants {
		clipboard_event := events[event_index]
		portal_event := events[event_index + 1]
		destroyed_event := events[event_index + 2]
		assert clipboard_event.kind == .service
		assert clipboard_event.service.kind == .clipboard
		assert clipboard_event.service.clipboard.id == clipboard_requests[index]
		assert clipboard_event.service.clipboard.window == window
		assert clipboard_event.service.clipboard.status == .cancelled
		assert portal_event.kind == .service
		assert portal_event.service.kind == .portal_parent
		assert portal_event.service.portal_parent.id == portal_requests[index]
		assert portal_event.service.portal_parent.window == window
		assert portal_event.service.portal_parent.status == .cancelled
		assert destroyed_event.kind == .lifecycle
		assert destroyed_event.lifecycle.kind == .window_destroyed
		assert destroyed_event.lifecycle.window_id == window
		event_index += 3
	}
	assert events[event_index].kind == .lifecycle
	assert events[event_index].lifecycle.kind == .window_destroyed
	assert events[event_index].lifecycle.window_id == owner
	assert app.services.pending.len == 0
	for window in order {
		app.services.window_index(window) or {
			assert err.msg() == err_stale_window
			continue
		}
		assert false, 'destroyed service cascade record remained registered'
	}

	app.destroy_window(owner)!
	assert app.drain_queued_events()!.len == 0
	assert app.services.pending.len == 0
	assert app.services.portal_leases.len == 0
	app.stop()!
}

fn test_backend_readback_acceptance_terminalizes_pending_before_destroy() {
	mut app := new_app()!
	window := app.create_window()!
	_ = app.drain_events()!
	readback := app.service_begin_window_readback(window)!
	acceptance := app.accept_backend_event_batch([
		queued_readback_event(ServiceReadbackResult{
			id:              readback
			window:          window
			status:          .ready
			submitted_frame: 1
			width:           1
			height:          1
			stride:          4
			pixels_rgba8:    [u8(1), 2, 3, 4]
		}),
	], 1)!
	assert acceptance.accepted == 1
	assert app.services.readbacks.len == 1
	assert app.services.readbacks[0].terminal

	ticket := app.prepare_window_destroy(window)!
	app.seal_window_destroy(ticket)!
	app.finish_window_destroy(ticket, []string{})!
	events := app.drain_queued_events()!
	assert events.filter(it.kind == .readback).len == 1
	assert events.filter(it.kind == .readback)[0].readback.status == .ready
	app.stop()!
}

fn test_native_backend_close_cancels_pending_readback_once_before_finish() {
	mut app := new_app()!
	window := app.create_window()!
	_ = app.drain_events()!
	readback := app.service_begin_window_readback(window)!
	accepted := app.accept_backend_event_batch([
		queued_lifecycle_event(Event{
			kind:      .window_close_requested
			window_id: window
		}),
		queued_lifecycle_event(Event{
			kind:      .window_destroyed
			window_id: window
		}),
	], 1)!
	assert accepted.accepted == 2
	assert app.windows[window.slot].services_cancelled
	before_finish := app.drain_queued_events()!
	assert before_finish.len == 2
	assert before_finish[0].kind == .lifecycle
	assert before_finish[0].lifecycle.kind == .window_close_requested
	assert before_finish[1].kind == .readback
	assert before_finish[1].readback.id == readback
	assert before_finish[1].readback.status == .cancelled
	assert before_finish[0].sequence < before_finish[1].sequence
	assert app.services.readbacks.len == 0

	duplicate := app.accept_backend_event_batch([
		queued_lifecycle_event(Event{
			kind:      .window_destroyed
			window_id: window
		}),
	], 2)!
	assert duplicate.accepted == 0
	notices := app.drain_render_teardown_notices()!
	assert notices.len == 1
	app.finish_window_destroy(notices[0].ticket, []string{})!
	after_finish := app.drain_queued_events()!
	assert after_finish.len == 1
	assert after_finish[0].kind == .lifecycle
	assert after_finish[0].lifecycle.kind == .window_destroyed
	assert after_finish[0].lifecycle.window_id == window
	app.finish_window_destroy(notices[0].ticket, []string{})!
	assert app.drain_queued_events()!.len == 0
	app.stop()!
	assert app.drain_queued_events()!.len == 0
}

fn test_destroy_window_replays_remembered_terminal_before_live_validation() {
	mut app := new_app()!
	window := app.create_window()!
	_ = app.drain_events()!
	app.destroy_window(window)!
	app.destroy_window(window)!
	app.stop()!
}

fn test_backend_destroy_during_native_borrow_keeps_registry_until_retry() {
	mut app := new_app()!
	window := app.create_window()!
	_ = app.drain_events()!
	app_ptr := unsafe { voidptr(app) }
	callback := fn [app_ptr, window] (_ NativeWindowBorrow) ! {
		mut owner := unsafe { &App(app_ptr) }
		accepted := owner.accept_backend_event_batch([
			queued_lifecycle_event(Event{
				kind:      .window_destroyed
				window_id: window
			}),
		], 1)!
		assert accepted.accepted == 1
		notices := owner.drain_render_teardown_notices()!
		assert notices.len == 1
		owner.finish_window_destroy(notices[0].ticket, []string{}) or {
			assert err.msg() == err_native_borrow_active
			assert owner.services.window_index(window)! >= 0
			backend_index := owner.backend.mock.window_record_index(window) or { -1 }
			assert backend_index >= 0
			return
		}
		assert false, 'backend teardown removed a window during an active native borrow'
	}
	app.with_native_window_borrow_for_test(window, callback)!
	notices := app.drain_render_teardown_notices()!
	assert notices.len == 1
	app.finish_window_destroy(notices[0].ticket, []string{})!
	app.services.window_index(window) or {
		assert err.msg() == err_stale_window
		app.stop()!
		return
	}
	assert false, 'backend teardown retry left the service record registered'
}

fn test_nested_native_borrows_defer_destroy_until_outer_callback_returns() {
	mut app := new_app()!
	window := app.create_window()!
	_ = app.drain_events()!
	app_ptr := unsafe { voidptr(app) }
	inner := fn [app_ptr, window] (borrow NativeWindowBorrow) ! {
		mut owner := unsafe { &App(app_ptr) }
		assert owner.validate_native_borrow_for_gg(window, borrow.epoch_for_gg())! == .mock
		owner.destroy_window(window)!
		assert owner.window_exists(window)
	}
	outer := fn [app_ptr, window, inner] (borrow NativeWindowBorrow) ! {
		mut owner := unsafe { &App(app_ptr) }
		assert owner.validate_native_borrow_for_gg(window, borrow.epoch_for_gg())! == .mock
		owner.with_native_window_borrow_for_test(window, inner)!
		assert owner.window_exists(window)
	}
	app.with_native_window_borrow_for_test(window, outer)!
	assert !app.window_exists(window)
	events := app.drain_queued_events()!
	assert events.len == 1
	assert events[0].lifecycle.kind == .window_destroyed
	app.stop()!
}

fn test_app_level_monitor_event_does_not_require_live_window() {
	mut app := new_app()!
	monitor := app.services.monitors[0]
	accepted := app.accept_backend_event_batch([
		queued_service_event(ServiceEvent{
			kind:    .monitor
			monitor: monitor
		}),
	], 1)!
	assert accepted.accepted == 1
	events := app.drain_queued_events()!
	assert events.len == 1
	assert events[0].kind == .service
	assert events[0].service.kind == .monitor
	assert events[0].service.monitor.id == monitor.id
	app.stop()!
}

fn test_service_metrics_event_uses_one_authoritative_sequence() {
	mut app := new_app()!
	window := app.create_window()!
	_ = app.drain_events()!
	accepted := app.accept_backend_event_batch([
		queued_service_event(ServiceEvent{
			kind:    .metrics
			window:  window
			metrics: RenderMetricsSnapshot{
				logical_width:        320
				logical_height:       200
				framebuffer_width:    640
				framebuffer_height:   400
				dpi_scale:            2
				metrics_available:    true
				conversion_available: true
			}
		}),
	], 1)!
	assert accepted.accepted == 1
	events := app.drain_queued_events()!
	assert events.len == 1
	assert events[0].sequence == events[0].service.sequence
	assert events[0].service.sequence == events[0].service.metrics.metrics_sequence
	assert events[0].service.metrics.framebuffer_width == 640
	app.stop()!
}
