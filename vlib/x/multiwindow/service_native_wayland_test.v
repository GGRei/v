module multiwindow

import os
import time

fn wayland_runtime_probe_available() bool {
	if os.getenv('WAYLAND_DISPLAY') != '' {
		return true
	}
	eprintln('SKIP Wayland native Package2 probe: WAYLAND_DISPLAY is not set')
	assert os.getenv('VGG_MULTIWINDOW_RUNTIME_PROBES') != '1', 'Wayland runtime probes were required, but no compositor is available'
	return false
}

fn test_wayland_app_id_reaches_the_native_marshal_boundary() {
	$if linux && sokol_wayland ? {
		if !wayland_runtime_probe_available() {
			return
		}
		expected := 'org.vlang.package2-wayland-proof'
		mut app := new_app(
			backend:          .wayland
			require_renderer: false
			app_id:           expected
		)!
		_ = app.create_window(title: 'package2-wayland-app-id')!
		marshaled := unsafe { cstring_to_vstring(C.v_multiwindow_wayland_get_last_marshaled_app_id()) }
		assert marshaled == expected
		app.stop()!
	}
}

fn test_wayland_owner_relation_reaches_xdg_toplevel_parent() {
	$if linux && sokol_wayland ? {
		if !wayland_runtime_probe_available() {
			return
		}
		mut app := new_app(backend: .wayland, require_renderer: false)!
		owner := app.create_window(title: 'package2-wayland-owner')!
		child := app.create_window(
			title: 'package2-wayland-modal-child'
			owner: owner
			modal: true
		)!
		owner_index := app.backend.wayland.window_record_index(owner) or {
			app.stop()!
			panic(err_window_not_found)
		}
		child_index := app.backend.wayland.window_record_index(child) or {
			app.stop()!
			panic(err_window_not_found)
		}
		assert C.v_multiwindow_wayland_get_last_parent_child() == usize(app.backend.wayland.windows[child_index].xdg_toplevel)
		assert C.v_multiwindow_wayland_get_last_parent_owner() == usize(app.backend.wayland.windows[owner_index].xdg_toplevel)
		service_index := app.services.window_index(child)!
		registered_owner := app.services.windows[service_index].owner or {
			app.stop()!
			panic(err_window_not_found)
		}

		assert registered_owner == owner
		assert app.services.windows[service_index].modal
		app.stop()!
	}
}

fn test_wayland_cursor_support_is_runtime_and_shape_specific() {
	$if linux && sokol_wayland ? {
		mut backend := &WaylandBackend{}
		assert backend.cursor_support(.pointer) == .conditional
		assert backend.cursor_support(.resize_all) == .unsupported
		backend.pointer = voidptr(usize(0x11))
		backend.cursor_shape_manager = voidptr(usize(0x12))
		backend.cursor_shape_device = voidptr(usize(0x13))
		for shape in [CursorShape.default, .pointer, .move, .n_resize, .s_resize, .e_resize,
			.w_resize, .ne_resize, .nw_resize, .se_resize, .sw_resize, .ew_resize, .ns_resize,
			.nesw_resize, .nwse_resize, .grab, .grabbing, .text, .crosshair, .not_allowed] {
			assert backend.cursor_support(shape) == .available
		}
		assert backend.cursor_support(.resize_all) == .unsupported
	}
}

fn test_wayland_output_removal_updates_membership_scale_and_metrics() {
	$if linux && sokol_wayland ? {
		mut backend := &WaylandBackend{}
		output := &WaylandOutputRecord{
			slot:       0
			owner:      backend
			generation: 3
			scale:      2
			ready:      true
			available:  true
		}
		window := &WaylandWindowRecord{
			id:           WindowId{
				app_instance: 1
				slot:         0
				generation:   1
			}
			owner:        backend
			high_dpi:     true
			configured:   true
			width:        40
			height:       30
			buffer_scale: 2
			output_slots: [0]
		}
		backend.outputs = [output]
		backend.windows = [window]

		backend.destroy_output_record(0)

		assert !output.available
		assert output.generation == 3
		assert window.output_slots.len == 0
		assert window.buffer_scale == 1
		assert window.service_window_state().monitor_ids.len == 0
		assert window.pending_events.len == 1
		assert window.pending_events[0].event.kind == .service
		assert window.pending_events[0].event.service.kind == .metrics
		assert window.pending_events[0].event.service.metrics.dpi_scale == f32(1)
	}
}

fn test_wayland_fractional_scale_preference_updates_metrics_and_framebuffer() {
	$if linux && sokol_wayland ? {
		mut backend := &WaylandBackend{}
		fractional_scale := voidptr(usize(0x31))
		viewport := voidptr(usize(0x32))
		mut record := &WaylandWindowRecord{
			id:                       WindowId{
				app_instance: 1
				slot:         0
				generation:   1
			}
			owner:                    backend
			high_dpi:                 true
			width:                    101
			height:                   51
			configured:               true
			fractional_scale:         fractional_scale
			viewport:                 viewport
			render_target_generation: 1
		}
		backend.windows << record

		wayland_fractional_scale_preferred(record.listener_data(), fractional_scale, 180)

		assert record.fractional_scale_numerator == 180
		assert record.render_scale == f32(1.5)
		assert record.pending_egl_resize
		assert record.render_target_generation == 2
		assert record.pending_events.len == 1
		assert record.pending_events[0].event.kind == .service
		metrics := record.pending_events[0].event.service.metrics
		assert metrics.framebuffer_width == 152
		assert metrics.framebuffer_height == 77
		assert metrics.dpi_scale == f32(1.5)
	}
}

fn test_wayland_fractional_scale_requires_both_protocol_objects() {
	$if linux && sokol_wayland ? {
		mut backend := &WaylandBackend{}
		fractional_scale := voidptr(usize(0x41))
		mut record := &WaylandWindowRecord{
			id:               WindowId{
				app_instance: 1
				slot:         0
				generation:   1
			}
			owner:            backend
			high_dpi:         true
			width:            101
			height:           51
			fractional_scale: fractional_scale
		}
		backend.windows << record

		wayland_fractional_scale_preferred(record.listener_data(), fractional_scale, 180)

		assert record.fractional_scale_numerator == 0
		assert record.framebuffer_width() == 101
		assert record.framebuffer_height() == 51
		assert record.pending_events.len == 0
	}
}

fn test_wayland_xdg_configure_states_are_published_after_surface_configure() {
	$if linux && sokol_wayland ? {
		mut record := &WaylandWindowRecord{
			id:        WindowId{
				app_instance: 1
				slot:         0
				generation:   1
			}
			resizable: true
			width:     64
			height:    48
		}
		mut active_states := [u32(1), u32(4)]
		mut active_array := C.wl_array{
			size:  usize(active_states.len) * sizeof(u32)
			alloc: usize(active_states.len) * sizeof(u32)
			data:  active_states.data
		}
		wayland_xdg_toplevel_configure(record.listener_data(), unsafe { nil }, 64, 48,
			&active_array)
		assert record.pending_events.len == 0
		wayland_xdg_surface_configure(record.listener_data(), unsafe { nil }, 1)
		first :=
			record.pending_events.filter(it.event.kind == .service).map(it.event.service.operation)
		assert ServiceOperation.maximize in first
		assert ServiceOperation.focus in first
		assert ServiceOperation.restore !in first
		assert record.pending_events.filter(it.event.kind == .service).all(it.event.service.metrics.metrics_available)

		record.pending_events.clear()
		mut inactive_array := C.wl_array{}
		wayland_xdg_toplevel_configure(record.listener_data(), unsafe { nil }, 64, 48,
			&inactive_array)
		assert record.pending_events.len == 0
		wayland_xdg_surface_configure(record.listener_data(), unsafe { nil }, 2)
		second :=
			record.pending_events.filter(it.event.kind == .service).map(it.event.service.operation)
		assert ServiceOperation.restore in second
		assert ServiceOperation.focus in second
	}
}

fn test_wayland_relative_pointer_callbacks_publish_observed_state_and_motion() {
	$if linux && sokol_wayland ? {
		mut backend := &WaylandBackend{}
		mut record := &WaylandWindowRecord{
			id:     WindowId{
				app_instance: 1
				slot:         0
				generation:   1
			}
			owner:  backend
			width:  64
			height: 48
		}
		locked_pointer := voidptr(usize(0x21))
		relative_pointer := voidptr(usize(0x22))
		record.locked_pointer = locked_pointer
		record.relative_pointer = relative_pointer
		record.mouse_lock_requested = true

		wayland_locked_pointer_locked(record.listener_data(), locked_pointer)
		assert record.mouse_locked
		assert record.pending_events.len == 1
		assert record.pending_events[0].event.kind == .service
		assert record.pending_events[0].event.service.operation == .mouse_lock
		assert record.pending_events[0].event.service.state.mouse_locked == .on

		record.pending_events.clear()
		wayland_relative_pointer_motion(record.listener_data(), relative_pointer, 0, 1, 3.25, -2.5,
			3.0, -2.0)
		assert record.pending_events.len == 1
		assert record.pending_events[0].event.kind == .input
		assert record.pending_events[0].event.input.kind == .mouse_move
		assert record.pending_events[0].event.input.mouse_dx == f32(3.25)
		assert record.pending_events[0].event.input.mouse_dy == f32(-2.5)

		record.pending_events.clear()
		wayland_locked_pointer_unlocked(record.listener_data(), locked_pointer)
		assert !record.mouse_locked
		assert record.pending_events.len == 1
		assert record.pending_events[0].event.kind == .service
		assert record.pending_events[0].event.service.operation == .mouse_lock
		assert record.pending_events[0].event.service.state.mouse_locked == .off
	}
}

fn test_wayland_seat_loss_releases_active_mouse_lock_and_publishes_off() {
	$if linux && sokol_wayland ? {
		if !wayland_runtime_probe_available() {
			return
		}
		mut app := new_app(backend: .wayland, require_renderer: false)!
		window := app.create_window(title: 'package2-wayland-seat-loss-mouse-lock')!
		capability := app.service_operation_capability(window, .mouse_lock)!
		if capability.support == .unsupported {
			eprintln('SKIP Wayland active mouse-lock loss probe: relative-pointer protocols are unavailable')
			app.stop()!
			return
		}
		app.service_set_mouse_lock(window, true)!
		index := app.backend.wayland.window_record_index(window) or {
			app.stop()!
			panic(err_window_not_found)
		}
		mut record := app.backend.wayland.windows[index]
		assert record.locked_pointer != unsafe { nil }
		assert record.relative_pointer != unsafe { nil }
		wayland_locked_pointer_locked(record.listener_data(), record.locked_pointer)
		assert record.mouse_lock_requested
		assert record.mouse_locked
		record.pending_events.clear()
		seat_name := app.backend.wayland.seat_name
		assert seat_name != 0

		wayland_registry_handle_global_remove(unsafe { voidptr(&app.backend.wayland) }, unsafe {
			&C.wl_registry(app.backend.wayland.registry)
		}, seat_name)

		assert record.locked_pointer == unsafe { nil }
		assert record.relative_pointer == unsafe { nil }
		assert !record.mouse_lock_requested
		assert !record.mouse_locked
		state_events := record.pending_events.filter(it.event.kind == .service
			&& it.event.service.kind == .state && it.event.service.operation == .mouse_lock)
		assert state_events.len == 1
		assert state_events[0].event.service.state.mouse_locked == .off
		capability_events := wayland_capability_events_for(record, .mouse_lock)
		assert capability_events.len == 1
		assert capability_events[0].event.service.capability.support == .unsupported
		before_duplicate_remove := record.pending_events.len
		wayland_registry_handle_global_remove(unsafe { voidptr(&app.backend.wayland) }, unsafe {
			&C.wl_registry(app.backend.wayland.registry)
		}, seat_name)
		assert record.pending_events.len == before_duplicate_remove
		app.stop()!
	}
}

fn wayland_capability_events_for(record &WaylandWindowRecord, operation ServiceOperation) []WaylandNativeQueuedEvent {
	return record.pending_events.filter(it.event.kind == .service
		&& it.event.service.kind == .capability && it.event.service.operation == operation)
}

fn test_wayland_data_device_manager_remove_and_readd_publish_idempotent_capabilities() {
	$if linux && sokol_wayland ? {
		if !wayland_runtime_probe_available() {
			return
		}
		mut app := new_app(backend: .wayland, require_renderer: false)!
		window := app.create_window(title: 'package2-wayland-data-manager-capabilities')!
		index := app.backend.wayland.window_record_index(window) or {
			app.stop()!
			panic(err_window_not_found)
		}
		mut record := app.backend.wayland.windows[index]
		name := app.backend.wayland.data_device_manager_name
		assert name != 0
		assert app.backend.wayland.data_device_manager != unsafe { nil }
		assert app.backend.wayland.data_device != unsafe { nil }
		record.pending_events.clear()

		wayland_registry_handle_global_remove(unsafe { voidptr(&app.backend.wayland) }, unsafe {
			&C.wl_registry(app.backend.wayland.registry)
		}, name)
		assert wayland_capability_events_for(record, .clipboard_read).len == 1
		assert wayland_capability_events_for(record, .clipboard_write).len == 1
		assert wayland_capability_events_for(record, .clipboard_read)[0].event.service.capability.support == .unsupported
		before_duplicate_remove := record.pending_events.len
		wayland_registry_handle_global_remove(unsafe { voidptr(&app.backend.wayland) }, unsafe {
			&C.wl_registry(app.backend.wayland.registry)
		}, name)
		assert record.pending_events.len == before_duplicate_remove

		record.pending_events.clear()
		wayland_registry_handle_global(unsafe { voidptr(&app.backend.wayland) }, unsafe {
			&C.wl_registry(app.backend.wayland.registry)
		}, name, c'wl_data_device_manager', 3)
		assert app.backend.wayland.data_device_manager != unsafe { nil }
		assert app.backend.wayland.data_device != unsafe { nil }
		assert wayland_capability_events_for(record, .clipboard_read).len == 1
		assert wayland_capability_events_for(record, .clipboard_write).len == 1
		assert wayland_capability_events_for(record, .clipboard_read)[0].event.service.capability.support == .conditional
		before_duplicate_add := record.pending_events.len
		wayland_registry_handle_global(unsafe { voidptr(&app.backend.wayland) }, unsafe {
			&C.wl_registry(app.backend.wayland.registry)
		}, name, c'wl_data_device_manager', 3)
		assert record.pending_events.len == before_duplicate_add
		app.stop()!
	}
}

fn test_wayland_relative_pointer_manager_remove_and_readd_publish_idempotent_capability() {
	$if linux && sokol_wayland ? {
		if !wayland_runtime_probe_available() {
			return
		}
		mut app := new_app(backend: .wayland, require_renderer: false)!
		window := app.create_window(title: 'package2-wayland-pointer-manager-capability')!
		index := app.backend.wayland.window_record_index(window) or {
			app.stop()!
			panic(err_window_not_found)
		}
		mut record := app.backend.wayland.windows[index]
		name := app.backend.wayland.relative_pointer_manager_name
		if name == 0 || app.backend.wayland.relative_pointer_manager == unsafe { nil } {
			eprintln('SKIP Wayland relative-pointer capability transition: protocol is unavailable')
			app.stop()!
			return
		}
		record.pending_events.clear()

		wayland_registry_handle_global_remove(unsafe { voidptr(&app.backend.wayland) }, unsafe {
			&C.wl_registry(app.backend.wayland.registry)
		}, name)
		assert wayland_capability_events_for(record, .mouse_lock).len == 1
		assert wayland_capability_events_for(record, .mouse_lock)[0].event.service.capability.support == .unsupported
		before_duplicate_remove := record.pending_events.len
		wayland_registry_handle_global_remove(unsafe { voidptr(&app.backend.wayland) }, unsafe {
			&C.wl_registry(app.backend.wayland.registry)
		}, name)
		assert record.pending_events.len == before_duplicate_remove

		record.pending_events.clear()
		wayland_registry_handle_global(unsafe { voidptr(&app.backend.wayland) }, unsafe {
			&C.wl_registry(app.backend.wayland.registry)
		}, name, c'zwp_relative_pointer_manager_v1', 1)
		assert wayland_capability_events_for(record, .mouse_lock).len == 1
		assert wayland_capability_events_for(record, .mouse_lock)[0].event.service.capability.support == .conditional
		before_duplicate_add := record.pending_events.len
		wayland_registry_handle_global(unsafe { voidptr(&app.backend.wayland) }, unsafe {
			&C.wl_registry(app.backend.wayland.registry)
		}, name, c'zwp_relative_pointer_manager_v1', 1)
		assert record.pending_events.len == before_duplicate_add
		app.stop()!
	}
}

fn test_wayland_exporter_remove_and_readd_publish_idempotent_capability() {
	$if linux && sokol_wayland ? {
		if !wayland_runtime_probe_available() {
			return
		}
		mut app := new_app(backend: .wayland, require_renderer: false)!
		window := app.create_window(title: 'package2-wayland-exporter-capability')!
		index := app.backend.wayland.window_record_index(window) or {
			app.stop()!
			panic(err_window_not_found)
		}
		mut record := app.backend.wayland.windows[index]
		name := app.backend.wayland.foreign_exporter_name
		if name == 0 || app.backend.wayland.foreign_exporter == unsafe { nil } {
			eprintln('SKIP Wayland exporter capability transition: xdg-foreign v2 is unavailable')
			app.stop()!
			return
		}
		record.pending_events.clear()

		wayland_registry_handle_global_remove(unsafe { voidptr(&app.backend.wayland) }, unsafe {
			&C.wl_registry(app.backend.wayland.registry)
		}, name)
		assert wayland_capability_events_for(record, .portal_parent).len == 1
		assert wayland_capability_events_for(record, .portal_parent)[0].event.service.capability.support == .unsupported
		before_duplicate_remove := record.pending_events.len
		wayland_registry_handle_global_remove(unsafe { voidptr(&app.backend.wayland) }, unsafe {
			&C.wl_registry(app.backend.wayland.registry)
		}, name)
		assert record.pending_events.len == before_duplicate_remove

		record.pending_events.clear()
		wayland_registry_handle_global(unsafe { voidptr(&app.backend.wayland) }, unsafe {
			&C.wl_registry(app.backend.wayland.registry)
		}, name, c'zxdg_exporter_v2', 1)
		assert wayland_capability_events_for(record, .portal_parent).len == 1
		assert wayland_capability_events_for(record, .portal_parent)[0].event.service.capability.support == .available
		before_duplicate_add := record.pending_events.len
		wayland_registry_handle_global(unsafe { voidptr(&app.backend.wayland) }, unsafe {
			&C.wl_registry(app.backend.wayland.registry)
		}, name, c'zxdg_exporter_v2', 1)
		assert record.pending_events.len == before_duplicate_add
		app.stop()!
	}
}

fn test_wayland_xdg_foreign_callback_retains_and_releases_exact_lease() {
	$if linux && sokol_wayland ? {
		mut backend := &WaylandBackend{}
		window := WindowId{
			app_instance: 7
			slot:         2
			generation:   3
		}
		request := ServiceRequestId{
			app_instance: 7
			serial:       11
		}
		lease := ServicePortalLeaseId{
			app_instance: 7
			serial:       11
		}
		exported := voidptr(usize(0x41))
		mut portal := &WaylandPortalExport{
			request:  request
			window:   window
			lease:    lease
			owner:    backend
			exported: exported
		}
		backend.portal_exports << portal

		wayland_exported_handle(portal.listener_data(), exported, c'portal-handle')
		assert portal.terminal
		assert portal.identifier == 'wayland:portal-handle'
		assert backend.pending_service_events.len == 1
		event := backend.pending_service_events[0].event.service
		assert event.kind == .portal_parent
		assert event.portal_parent.id == request
		assert event.portal_parent.lease == lease
		assert event.portal_parent.identifier == 'wayland:portal-handle'

		// The deterministic probe has no live Wayland proxy. The release path
		// still proves exact lease lookup/removal and stale replay rejection.
		portal.exported = unsafe { nil }
		backend.service_release_portal_parent(lease)!
		assert backend.portal_exports.len == 0
		if _ := backend.service_release_portal_parent(lease) {
			assert false
		} else {
			assert err.msg() == err_service_request_stale
		}
	}
}

fn test_wayland_xdg_foreign_runtime_capability_and_public_completion() {
	$if linux && sokol_wayland ? {
		if !wayland_runtime_probe_available() {
			return
		}
		mut app := new_app(backend: .wayland, require_renderer: false)!
		window := app.create_window(
			title:  'package2-wayland-portal-parent'
			width:  48
			height: 32
		)!
		capability := app.service_operation_capability(window, .portal_parent)!
		if capability.support == .unsupported {
			before_pending := app.services.pending.len
			app.service_request_portal_parent(window) or {
				assert err.msg() == err_capability_unsupported
				assert app.services.pending.len == before_pending
				app.stop()!
				return
			}
			assert false
		}
		assert capability.support == .available
		assert capability.asynchronous
		request := app.service_request_portal_parent(window)!
		mut result := ServicePortalParentResult{}
		mut completed := false
		for _ in 0 .. 100 {
			_ = app.poll_events()!
			for queued in app.drain_queued_events()! {
				if queued.kind == .service && queued.service.kind == .portal_parent
					&& queued.service.portal_parent.id == request {
					result = queued.service.portal_parent
					completed = true
				}
			}
			if completed {
				break
			}
			time.sleep(time.millisecond)
		}
		assert completed
		assert result.status == .ready
		assert result.identifier.starts_with('wayland:')
		app.service_release_portal_parent(result.lease)!
		app.service_release_portal_parent(result.lease) or {
			assert err.msg() == err_service_request_stale
			app.stop()!
			return
		}
		assert false
	}
}

fn test_wayland_service_capabilities_follow_runtime_authority() {
	$if linux && sokol_wayland ? {
		if !wayland_runtime_probe_available() {
			return
		}
		mut plain := new_app(backend: .wayland, require_renderer: false)!
		plain_window := plain.create_window(
			title:  'package2-wayland-capabilities-plain'
			width:  48
			height: 32
		)!
		mouse_lock := plain.service_operation_capability(plain_window, .mouse_lock)!
		if plain.backend.wayland.pointer != unsafe { nil }
			&& plain.backend.wayland.relative_pointer_manager != unsafe { nil }
			&& plain.backend.wayland.pointer_constraints != unsafe { nil } {
			assert mouse_lock.support == .conditional
			assert mouse_lock.state_observable
		} else {
			assert mouse_lock.support == .unsupported
		}
		assert plain.service_operation_capability(plain_window, .image_readback)!.support == .unsupported
		assert plain.service_operation_capability(plain_window, .window_capture)!.support == .unsupported
		if plain.backend.wayland.seat != unsafe { nil }
			&& plain.backend.wayland.data_device != unsafe { nil } {
			assert plain.service_operation_capability(plain_window, .clipboard_read)!.support == .conditional
			assert plain.service_operation_capability(plain_window, .clipboard_write)!.support == .conditional
			mut serial_required := false
			plain.service_set_clipboard_text(plain_window, 'serial-required') or {
				assert err.msg() == err_capability_unsupported
				serial_required = true
			}
			assert serial_required
			assert plain.services.pending.len == 0
		}
		plain.stop()!

		mut rendered := new_app(backend: .wayland, require_renderer: true)!
		rendered_window := rendered.create_window(
			title:  'package2-wayland-capabilities-rendered'
			width:  48
			height: 32
		)!
		assert rendered.service_operation_capability(rendered_window, .image_readback)!.support == .available
		assert rendered.service_operation_capability(rendered_window, .window_capture)!.support == .unsupported
		before_readbacks := rendered.services.readbacks.len
		rendered.service_request_window_readback(rendered_window, 4, 4, 1) or {
			assert err.msg() == err_capability_unsupported
			assert rendered.services.readbacks.len == before_readbacks
			rendered.stop()!
			return
		}
		assert false, 'Wayland core advertised compositor-owned window capture'
		rendered.stop()!
	}
}

fn test_wayland_surface_output_membership_updates_public_metrics() {
	$if linux && sokol_wayland ? {
		if !wayland_runtime_probe_available() {
			return
		}
		mut app := new_app(backend: .wayland, require_renderer: false)!
		window := app.create_window(
			title:    'package2-wayland-output-membership'
			width:    48
			height:   32
			high_dpi: true
		)!
		index := app.backend.wayland.window_record_index(window) or {
			app.stop()!
			panic(err_window_not_found)
		}
		if app.backend.wayland.fractional_scale_manager_name != 0
			&& app.backend.wayland.viewporter_name != 0 {
			assert app.backend.wayland.windows[index].fractional_scale != unsafe { nil }
			assert app.backend.wayland.windows[index].viewport != unsafe { nil }
			mut saw_fractional_preference := false
			for _ in 0 .. 100 {
				_ = app.poll_events()!
				if app.backend.wayland.windows[index].fractional_scale_numerator > 0 {
					saw_fractional_preference = true
					break
				}
				time.sleep(time.millisecond)
			}
			assert saw_fractional_preference
			metrics := app.backend.wayland.windows[index].service_metrics_snapshot()
			assert metrics.dpi_scale > 0
			assert metrics.framebuffer_width > 0
			assert metrics.framebuffer_height > 0
		}
		mut saw_metrics := false
		for _ in 0 .. 100 {
			_ = app.poll_events()!
			events := app.drain_queued_events()!
			if events.any(it.kind == .service && it.service.kind == .metrics
				&& it.service.window == window && it.service.metrics.metrics_available)
			{
				saw_metrics = true
				break
			}
			time.sleep(time.millisecond)
		}
		monitors := app.service_monitor_ids()!
		if monitors.len > 0 {
			assert saw_metrics
			state := app.service_window_state(window)!
			assert state.monitor_ids.len > 0
			monitor := app.service_monitor_info(state.monitor_ids[0])!
			assert monitor.available
			assert !monitor.geometry.known
			assert monitor.scale.known
			assert monitor.scale.value >= 1
		}
		app.stop()!
	}
}

fn test_wayland_hidden_window_remaps_through_fresh_xdg_configure_cycle() {
	$if linux && sokol_wayland ? {
		if !wayland_runtime_probe_available() {
			return
		}
		mut app := new_app(backend: .wayland, require_renderer: false)!
		window := app.create_window(
			title:   'package2-wayland-show-hide'
			width:   48
			height:  32
			visible: false
		)!
		_ = app.poll_events()!
		_ = app.drain_queued_events()!
		assert app.service_operation_capability(window, .show)!.support == .available
		assert app.service_operation_capability(window, .hide)!.support == .available
		assert app.service_window_state(window)!.mapping == .unmapped

		app.service_show_window(window)!
		assert app.service_window_state(window)!.mapping == .mapped
		app.service_hide_window(window)!
		assert app.service_window_state(window)!.mapping == .unmapped
		app.service_show_window(window)!
		assert app.service_window_state(window)!.mapping == .mapped
		app.stop()!
	}
}

fn test_wayland_unavailable_window_controls_are_not_advertised() {
	$if linux && sokol_wayland ? {
		if !wayland_runtime_probe_available() {
			return
		}
		mut app := new_app(backend: .wayland, require_renderer: false)!
		window := app.create_window(
			title:  'package2-wayland-capability-honesty'
			width:  48
			height: 32
		)!
		for operation in [ServiceOperation.focus, .raise, .position, .titlebar_appearance] {
			assert app.service_operation_capability(window, operation)!.support == .unsupported
		}
		minimize := app.service_operation_capability(window, .minimize)!
		assert minimize.support == .available
		assert !minimize.state_observable
		assert app.service_operation_capability(window, .restore)!.support == .conditional
		app.stop()!
	}
}

fn test_wayland_clipboard_read_timeout_is_terminal_exactly_once() {
	$if linux && sokol_wayland ? {
		mut backend := &WaylandBackend{}
		window := WindowId{
			app_instance: 1
			slot:         0
			generation:   1
		}
		mut record := &WaylandWindowRecord{
			id:    window
			owner: backend
		}
		backend.windows << record
		mut fds := [-1, -1]!
		assert C.pipe(&fds[0]) == 0
		backend.clipboard_read = WaylandClipboardRead{
			request: ServiceRequestId{
				app_instance: 1
				serial:       7
			}
			window:  window
			fd:      fds[0]
			buffer:  []u8{}
		}
		backend.clipboard_read_active = true

		backend.drain_clipboard_read()
		C.close(fds[1])

		assert !backend.clipboard_read_active
		assert backend.clipboard_read.fd == -1
		assert record.pending_events.len == 1
		result := record.pending_events[0].event.service.clipboard
		assert result.status == .failed
		assert result.error == err_clipboard_timeout
		backend.drain_clipboard_read()
		assert record.pending_events.len == 1
	}
}

fn test_wayland_clipboard_selection_replacement_cancels_read_exactly_once() {
	$if linux && sokol_wayland ? {
		mut backend := &WaylandBackend{}
		window := WindowId{
			app_instance: 1
			slot:         0
			generation:   1
		}
		mut record := &WaylandWindowRecord{
			id:    window
			owner: backend
		}
		backend.windows << record
		mut fds := [-1, -1]!
		assert C.pipe(&fds[0]) == 0
		backend.clipboard_read = WaylandClipboardRead{
			request:     ServiceRequestId{
				app_instance: 1
				serial:       8
			}
			window:      window
			fd:          fds[0]
			buffer:      []u8{}
			deadline_ns: i64(0x7fffffffffffffff)
		}
		backend.clipboard_read_active = true
		replacement := voidptr(usize(0x51))

		backend.set_selection_offer(replacement)
		C.close(fds[1])

		assert !backend.clipboard_read_active
		assert backend.clipboard_read.fd == -1
		assert backend.selection_offer == replacement
		assert record.pending_events.len == 1
		result := record.pending_events[0].event.service.clipboard
		assert result.status == .failed
		assert result.error == err_clipboard_selection_lost
		backend.drain_clipboard_read()
		assert record.pending_events.len == 1
		// The deterministic replacement is not a live wl_data_offer proxy.
		backend.selection_offer = unsafe { nil }
	}
}

fn wayland_test_begin_clipboard_read(mut backend WaylandBackend, serial u64, buffer []u8) (WindowId, &WaylandWindowRecord, [2]int) {
	window := WindowId{
		app_instance: 1
		slot:         0
		generation:   1
	}
	mut record := &WaylandWindowRecord{
		id:    window
		owner: backend
	}
	backend.windows << record
	mut fds := [-1, -1]!
	assert C.pipe(&fds[0]) == 0
	backend.clipboard_read = WaylandClipboardRead{
		request:     ServiceRequestId{
			app_instance: 1
			serial:       serial
		}
		window:      window
		fd:          fds[0]
		buffer:      buffer
		deadline_ns: i64(0x7fffffffffffffff)
	}
	backend.clipboard_read_active = true
	return window, record, fds
}

fn wayland_assert_clipboard_failure(record &WaylandWindowRecord, request ServiceRequestId, message string) {
	assert record.pending_events.len == 1
	event := record.pending_events[0].event
	assert event.kind == .service
	assert event.service.kind == .clipboard
	assert event.service.operation == .clipboard_read
	result := event.service.clipboard
	assert result.id == request
	assert result.status == .failed
	assert result.error == message
}

fn test_wayland_seat_removal_finishes_pending_clipboard_read_exactly_once() {
	$if linux && sokol_wayland ? {
		mut backend := &WaylandBackend{}
		_, record, fds := wayland_test_begin_clipboard_read(mut backend, 80, []u8{})
		request := backend.clipboard_read.request
		backend.seat_name = 71

		wayland_registry_handle_global_remove(voidptr(backend), unsafe { nil }, 71)
		C.close(fds[1])

		assert backend.seat_name == 0
		assert !backend.clipboard_read_active
		assert backend.clipboard_read.fd == -1
		assert backend.clipboard_read.buffer.len == 0
		wayland_assert_clipboard_failure(record, request, err_clipboard_selection_lost)
		wayland_registry_handle_global_remove(voidptr(backend), unsafe { nil }, 71)
		assert record.pending_events.len == 1
	}
}

fn test_wayland_data_device_manager_removal_finishes_pending_clipboard_read_exactly_once() {
	$if linux && sokol_wayland ? {
		mut backend := &WaylandBackend{}
		_, record, fds := wayland_test_begin_clipboard_read(mut backend, 81, []u8{})
		request := backend.clipboard_read.request
		backend.data_device_manager_name = 72

		wayland_registry_handle_global_remove(voidptr(backend), unsafe { nil }, 72)
		C.close(fds[1])

		assert backend.data_device_manager_name == 0
		assert !backend.clipboard_read_active
		assert backend.clipboard_read.fd == -1
		assert backend.clipboard_read.buffer.len == 0
		wayland_assert_clipboard_failure(record, request, err_clipboard_selection_lost)
		wayland_registry_handle_global_remove(voidptr(backend), unsafe { nil }, 72)
		assert record.pending_events.len == 1
	}
}

fn test_wayland_clipboard_exact_capacity_succeeds_at_eof() {
	$if linux && sokol_wayland ? {
		mut backend := &WaylandBackend{}
		payload := []u8{len: wayland_clipboard_max_bytes, init: `a`}
		_, record, fds := wayland_test_begin_clipboard_read(mut backend, 82, payload)
		C.close(fds[1])

		backend.drain_clipboard_read()

		assert !backend.clipboard_read_active
		assert backend.clipboard_read.fd == -1
		assert record.pending_events.len == 1
		result := record.pending_events[0].event.service.clipboard
		assert result.status == .ready
		assert result.error == ''
		assert result.text.len == wayland_clipboard_max_bytes
	}
}

fn test_wayland_clipboard_capacity_plus_one_fails() {
	$if linux && sokol_wayland ? {
		mut backend := &WaylandBackend{}
		payload := []u8{len: wayland_clipboard_max_bytes, init: `b`}
		_, record, fds := wayland_test_begin_clipboard_read(mut backend, 83, payload)
		assert C.write(fds[1], c'x', usize(1)) == 1
		C.close(fds[1])

		backend.drain_clipboard_read()

		assert !backend.clipboard_read_active
		assert backend.clipboard_read.fd == -1
		assert record.pending_events.len == 1
		result := record.pending_events[0].event.service.clipboard
		assert result.status == .failed
		assert result.error == err_clipboard_capacity
		assert result.text == ''
	}
}

fn test_wayland_clipboard_exact_capacity_waits_on_eagain_then_succeeds_at_eof() {
	$if linux && sokol_wayland ? {
		mut backend := &WaylandBackend{}
		payload := []u8{len: wayland_clipboard_max_bytes, init: `c`}
		_, record, fds := wayland_test_begin_clipboard_read(mut backend, 84, payload)
		assert C.v_multiwindow_wayland_fd_set_nonblocking(fds[0]) == 1

		backend.drain_clipboard_read()
		assert backend.clipboard_read_active
		assert backend.clipboard_read.fd == fds[0]
		assert record.pending_events.len == 0

		C.close(fds[1])
		backend.drain_clipboard_read()
		assert !backend.clipboard_read_active
		assert backend.clipboard_read.fd == -1
		assert record.pending_events.len == 1
		result := record.pending_events[0].event.service.clipboard
		assert result.status == .ready
		assert result.error == ''
		assert result.text.len == wayland_clipboard_max_bytes
	}
}

fn test_wayland_clipboard_send_accepts_only_one_fd_and_purges_it() {
	$if linux && sokol_wayland ? {
		mut backend := &WaylandBackend{}
		source := voidptr(usize(0x61))
		backend.clipboard_source = source
		backend.clipboard_text = 'bounded clipboard payload'
		mut first := [-1, -1]!
		mut second := [-1, -1]!
		assert C.pipe(&first[0]) == 0
		assert C.pipe(&second[0]) == 0

		wayland_data_source_send(backend, source, c'text/plain;charset=utf-8', first[1])
		assert backend.clipboard_send_fd == first[1]
		wayland_data_source_send(backend, source, c'text/plain', second[1])
		assert backend.clipboard_send_fd == first[1]
		assert C.write(second[1], c'x', usize(1)) == -1

		backend.clipboard_send_deadline_ns = 0
		backend.drain_clipboard_send()
		assert backend.clipboard_send_fd == -1
		backend.drain_clipboard_send()
		assert backend.clipboard_send_fd == -1
		C.close(first[0])
		C.close(second[0])
		backend.clipboard_source = unsafe { nil }
	}
}

fn test_wayland_native_borrow_copy_is_stale_after_callback() {
	$if linux && sokol_wayland ? {
		if !wayland_runtime_probe_available() {
			return
		}
		mut app := new_app(backend: .wayland, require_renderer: false)!
		window := app.create_window(title: 'package2-wayland-borrow-stale')!
		_ = app.drain_queued_events()!
		mut copied := NativeWindowBorrow{}
		callback := fn [mut copied] (borrow NativeWindowBorrow) ! {
			assert borrow.backend_for_gg() == .wayland
			assert borrow.primary_for_gg() != unsafe { nil }
			assert borrow.secondary_for_gg() != 0
			copied = borrow
		}
		app.with_native_window_for_gg(window, callback)!
		app.validate_native_borrow_for_gg(window, copied.epoch_for_gg()) or {
			assert err.msg() == err_native_borrow_stale
			app.stop()!
			return
		}
		assert false, 'copied Wayland native borrow remained valid after its callback'
	}
}

fn test_wayland_native_borrow_defers_destroy_and_stop_until_callback_return() {
	$if linux && sokol_wayland ? {
		if !wayland_runtime_probe_available() {
			return
		}
		mut destroy_app := new_app(backend: .wayland, require_renderer: false)!
		destroy_window := destroy_app.create_window(title: 'package2-wayland-borrow-destroy')!
		_ = destroy_app.drain_queued_events()!
		destroy_ptr := unsafe { voidptr(destroy_app) }
		destroy_callback := fn [destroy_ptr, destroy_window] (_ NativeWindowBorrow) ! {
			mut owner := unsafe { &App(destroy_ptr) }
			owner.destroy_window(destroy_window)!
			assert owner.window_exists(destroy_window)
			assert owner.backend.wayland.window_record_index(destroy_window) != none
		}
		destroy_app.with_native_window_for_gg(destroy_window, destroy_callback)!
		assert !destroy_app.window_exists(destroy_window)
		destroy_app.stop()!

		mut stop_app := new_app(backend: .wayland, require_renderer: false)!
		stop_window := stop_app.create_window(title: 'package2-wayland-borrow-stop')!
		_ = stop_app.drain_queued_events()!
		stop_ptr := unsafe { voidptr(stop_app) }
		stop_callback := fn [stop_ptr] (_ NativeWindowBorrow) ! {
			mut owner := unsafe { &App(stop_ptr) }
			owner.stop()!
			assert owner.status() == .running
		}
		stop_app.with_native_window_for_gg(stop_window, stop_callback)!
		assert stop_app.status() == .stopped
	}
}
