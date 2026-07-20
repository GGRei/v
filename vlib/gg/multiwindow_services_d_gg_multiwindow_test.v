module gg

import x.multiwindow

fn test_multiwindow_service_config_converts_identity_and_owner() {
	mut app := new_app(backend: .mock, app_id: 'org.vlang.multiwindow.test')!
	owner := app.create_window(title: 'owner')!
	child_config := WindowConfig{
		title: 'child'
		owner: owner
		modal: true
	}
	core := child_config.to_core()
	assert core.modal
	core_owner := core.owner or { panic('core owner missing') }
	assert core_owner == owner.core
	assert app.config.to_core().app_id == 'org.vlang.multiwindow.test'
	app.stop()!
}

fn test_multiwindow_service_complete_cursor_conversion_matches_core() {
	assert window_cursor_shape_to_core(.text) == multiwindow.CursorShape.text
	assert window_cursor_shape_to_core(.crosshair) == multiwindow.CursorShape.crosshair
	assert window_cursor_shape_to_core(.not_allowed) == multiwindow.CursorShape.not_allowed
	assert window_cursor_shape_to_core(.resize_all) == multiwindow.CursorShape.resize_all
}

struct Package2RunSeen {
mut:
	order                []string
	stop_was_deferred    bool
	service_callback_hit int
}

fn test_multiwindow_run_config_dispatches_interleaved_service_and_readback_in_canonical_order() {
	mut app := new_app(backend: .mock)!
	window := app.create_window(title: 'package2 run order')!
	app.show_window(window)!
	_ = app.request_window_capture(window, WindowReadbackConfig{})!
	mut seen := &Package2RunSeen{}
	app.run(
		event_fn:          fn [mut seen] (event WindowEvent, mut app App) ! {
			_ = app
			assert event.kind == .window_created
			seen.order << 'lifecycle'
		}
		window_service_fn: fn [mut seen] (event WindowServiceEvent, mut app App) ! {
			_ = app
			assert event.kind == .state
			seen.service_callback_hit++
			seen.order << 'service'
		}
		readback_fn:       fn [mut seen] (result WindowReadbackResult, mut app App) ! {
			assert result.status == .ready
			seen.order << 'readback'
			app.stop()!
			seen.stop_was_deferred = app.core.status() == multiwindow.AppStatus.running
		}
	)!
	assert seen.order == ['lifecycle', 'service', 'readback']
	assert seen.service_callback_hit == 1
	assert seen.stop_was_deferred
	assert app.core.status() == multiwindow.AppStatus.stopped
}

fn test_multiwindow_run_config_callback_error_replays_failed_event_and_exact_suffix() {
	mut app := new_app(backend: .mock)!
	window := app.create_window(title: 'package2 replay')!
	assert app.drain_events()!.len == 1
	_ = app.request_clipboard_text(window)!
	_ = app.request_window_capture(window, WindowReadbackConfig{})!
	app.show_window(window)!
	mut seen := &Package2RunSeen{}
	mut run_error := ''
	app.run(
		window_service_fn: fn [mut seen] (event WindowServiceEvent, mut app App) ! {
			_ = event
			_ = app
			seen.service_callback_hit++
			return error('package2 injected callback failure')
		}
		readback_fn:       fn (result WindowReadbackResult, mut app App) ! {
			_ = result
			_ = app
		}
	) or { run_error = err.msg() }
	assert run_error.contains('package2 injected callback failure')
	assert seen.service_callback_hit == 1
	replayed := app.drain_window_queued_events()!
	assert replayed.len == 4
	assert replayed.map(it.kind) == [.service, .readback, .service, .lifecycle]
	assert replayed[0].service.kind == .clipboard
	assert replayed[1].readback.status == .ready
	assert replayed[2].service.kind == .state
	assert replayed[3].lifecycle.kind == .window_destroyed
}

fn seed_managed_window_capture_for_test(mut app App, window WindowId, batch_epoch u64) !multiwindow.ServiceReadbackId {
	readback := app.core.service_begin_window_readback(window.core)!
	app.pending_window_captures << MultiWindowPendingWindowCapture{
		id:                     readback
		window:                 window
		rect:                   WindowPixelRect{
			width:  2
			height: 2
		}
		target_submitted_frame: 1
		attempt_batch_epoch:    batch_epoch
		staged_batch_epoch:     batch_epoch
		staged_pixels:          []u8{len: 16, init: 0xff}
	}
	return readback
}

fn test_managed_window_capture_submit_failure_is_terminal_exactly_once() {
	mut app := new_app(backend: .mock)!
	window := app.create_window(title: 'capture submit failure')!
	_ = app.drain_events()!
	readback := seed_managed_window_capture_for_test(mut app, window, 7)!

	app.finish_managed_window_captures(multiwindow.RenderBatchOutcome{
		batch_epoch: 7
		error:       'injected submit failure'
	})!
	results := app.core.drain_readback_events()!
	assert results.len == 1
	assert results[0].id == readback
	assert results[0].status == .failed
	assert results[0].submitted_frame == 0
	assert results[0].pixels_rgba8.len == 0
	assert results[0].error == 'injected submit failure'
	assert app.pending_window_captures.len == 0

	app.finish_managed_window_captures(multiwindow.RenderBatchOutcome{
		batch_epoch: 7
		error:       'injected submit failure'
	})!
	assert app.core.drain_readback_events()!.len == 0
	app.stop()!
}

fn test_managed_window_capture_destroy_is_cancelled_exactly_once() {
	mut app := new_app(backend: .mock)!
	window := app.create_window(title: 'capture destroy cancellation')!
	_ = app.drain_events()!
	readback := seed_managed_window_capture_for_test(mut app, window, 8)!

	app.destroy_window(window)!
	events := app.core.drain_queued_events()!
	readbacks := events.filter(it.kind == .readback)
	assert readbacks.len == 1
	assert readbacks[0].readback.id == readback
	assert readbacks[0].readback.status == .cancelled
	assert readbacks[0].readback.submitted_frame == 0
	assert readbacks[0].readback.pixels_rgba8.len == 0
	assert app.pending_window_captures.len == 0

	app.destroy_window(window)!
	assert app.core.drain_queued_events()!.len == 0
	app.stop()!
}

fn test_managed_window_capture_stop_is_cancelled_exactly_once() {
	mut app := new_app(backend: .mock)!
	window := app.create_window(title: 'capture stop cancellation')!
	_ = app.drain_events()!
	readback := seed_managed_window_capture_for_test(mut app, window, 9)!

	app.stop()!
	events := app.core.drain_queued_events()!
	readbacks := events.filter(it.kind == .readback)
	assert readbacks.len == 1
	assert readbacks[0].readback.id == readback
	assert readbacks[0].readback.status == .cancelled
	assert readbacks[0].readback.submitted_frame == 0
	assert readbacks[0].readback.pixels_rgba8.len == 0
	assert app.pending_window_captures.len == 0

	app.stop()!
	assert app.core.drain_queued_events()!.len == 0
}
