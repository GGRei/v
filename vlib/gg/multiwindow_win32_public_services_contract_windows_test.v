// vtest retry: 0
module gg

#flag windows -DV_MULTIWINDOW_WIN32_SERVICE_TEST

$if windows && gg_multiwindow ? {
	fn C.v_multiwindow_win32_service_test_set_focus_refused(refused int)
	fn C.SetForegroundWindow(hwnd voidptr) int
	fn C.GetForegroundWindow() voidptr
	fn C.SetFocus(hwnd voidptr) voidptr
	fn C.GetFocus() voidptr
}

struct Win32PublicBorrowRouteProbe {
mut:
	callback_count int
	accessor_count int
	first_hwnd     voidptr
	second_hwnd    voidptr
	first_epoch    u64
	second_epoch   u64
	first_lease    NativeWindowLease
}

fn record_disabled_public_service(label string, err IError, expected string, count int) int {
	assert err.msg() == expected, '${label} returned `${err.msg()}` without -d gg_multiwindow'
	return count + 1
}

fn win32_public_state_is_observed(state WindowState) bool {
	return state.mapping != .unknown && state.visibility != .unknown && state.active != .unknown
		&& state.focused != .unknown && state.minimized != .unknown && state.maximized != .unknown
		&& state.fullscreen != .unknown && state.position.known
}

fn win32_public_hwnd(mut app App, window WindowId) !voidptr {
	mut hwnd := voidptr(unsafe { nil })
	callback := fn [mut hwnd] (mut lease NativeWindowLease) ! {
		lease.with_win32(fn [mut hwnd] (borrowed voidptr) ! {
			hwnd = borrowed
		})!
	}
	app.with_native_window(window, callback)!
	if hwnd == unsafe { nil } {
		return error('gg.App.with_native_window returned a nil HWND')
	}
	return hwnd
}

fn win32_public_request_refused_focus(mut app App, window WindowId) ! {
	$if gg_multiwindow ? {
		C.v_multiwindow_win32_service_test_set_focus_refused(1)
		defer {
			C.v_multiwindow_win32_service_test_set_focus_refused(0)
		}
		app.request_window_focus(window)!
	} $else {
		_ = app
		_ = window
		return error(err_multiwindow_not_enabled)
	}
}

fn test_win32_public_services_stay_disabled_without_opt_in() {
	$if !gg_multiwindow ? {
		mut app := App{}
		window := WindowId{}
		mut rejected := 0
		mut callback_called := false

		_ = app.window_state(window) or {
			rejected = record_disabled_public_service('window_state', err,
				err_multiwindow_not_enabled, rejected)
			WindowState{}
		}
		_ = app.window_operation_capability(window, .native_borrow) or {
			rejected = record_disabled_public_service('window_operation_capability', err,
				err_multiwindow_not_enabled, rejected)
			WindowOperationCapability{}
		}
		callback := fn [mut callback_called] (mut lease NativeWindowLease) ! {
			callback_called = true
			_ = lease
		}
		app.with_native_window(window, callback) or {
			rejected = record_disabled_public_service('with_native_window', err,
				err_multiwindow_not_enabled, rejected)
		}
		app.show_window(window) or {
			rejected = record_disabled_public_service('show_window', err,
				err_multiwindow_not_enabled, rejected)
		}
		app.hide_window(window) or {
			rejected = record_disabled_public_service('hide_window', err,
				err_multiwindow_not_enabled, rejected)
		}
		app.request_window_focus(window) or {
			rejected = record_disabled_public_service('request_window_focus', err,
				err_multiwindow_not_enabled, rejected)
		}
		app.raise_window(window) or {
			rejected = record_disabled_public_service('raise_window', err,
				err_multiwindow_not_enabled, rejected)
		}
		app.set_window_position(window, 1, 2) or {
			rejected = record_disabled_public_service('set_window_position', err,
				err_multiwindow_not_enabled, rejected)
		}
		app.minimize_window(window) or {
			rejected = record_disabled_public_service('minimize_window', err,
				err_multiwindow_not_enabled, rejected)
		}
		app.maximize_window(window) or {
			rejected = record_disabled_public_service('maximize_window', err,
				err_multiwindow_not_enabled, rejected)
		}
		app.restore_window(window) or {
			rejected = record_disabled_public_service('restore_window', err,
				err_multiwindow_not_enabled, rejected)
		}
		app.set_window_fullscreen(window, true) or {
			rejected = record_disabled_public_service('set_window_fullscreen', err,
				err_multiwindow_not_enabled, rejected)
		}

		assert rejected == 12
		assert !callback_called
	}
}

fn test_win32_public_hwnd_borrow_route_red() {
	$if windows {
		$if gg_multiwindow ? {
			mut app := new_app(backend: .win32)!
			defer {
				app.stop() or {}
			}
			window := app.create_window(title: 'Win32 public HWND borrow RED')!
			mut probe := &Win32PublicBorrowRouteProbe{}
			capability := app.window_operation_capability(window, .native_borrow)!
			assert capability.support == .available
			assert !capability.asynchronous
			assert !capability.requires_user_action
			assert !capability.state_observable
			first_callback := fn [mut probe] (mut lease NativeWindowLease) ! {
				probe.callback_count++
				probe.first_epoch = lease.lease_epoch
				probe.first_lease = lease
				lease.with_win32(fn [mut probe] (hwnd voidptr) ! {
					probe.accessor_count++
					probe.first_hwnd = hwnd
				})!
			}

			app.with_native_window(window, first_callback)!
			assert probe.callback_count == 1
			assert probe.accessor_count == 1
			assert probe.first_hwnd != unsafe { nil }
			assert probe.first_epoch != 0

			mut stale_rejected := false
			probe.first_lease.with_win32(fn (_ voidptr) ! {}) or { stale_rejected = true }
			assert stale_rejected, 'copied gg.NativeWindowLease remained valid after callback'

			second_callback := fn [mut probe] (mut lease NativeWindowLease) ! {
				probe.callback_count++
				probe.second_epoch = lease.lease_epoch
				lease.with_win32(fn [mut probe] (hwnd voidptr) ! {
					probe.accessor_count++
					probe.second_hwnd = hwnd
				})!
			}
			app.with_native_window(window, second_callback)!
			assert probe.callback_count == 2
			assert probe.accessor_count == 2
			assert probe.second_hwnd == probe.first_hwnd
			assert probe.second_epoch != 0
			assert probe.second_epoch != probe.first_epoch

			stale_window := app.create_window(title: 'Win32 stale public WindowId RED')!
			app.destroy_window(stale_window)!
			_ = app.create_window(title: 'Win32 replacement public WindowId RED')!
			mut stale_id_callback_called := false
			stale_id_callback := fn [mut stale_id_callback_called] (mut lease NativeWindowLease) ! {
				stale_id_callback_called = true
				lease.with_win32(fn (_ voidptr) ! {})!
			}
			mut stale_id_rejected := false
			app.with_native_window(stale_window, stale_id_callback) or { stale_id_rejected = true }
			assert stale_id_rejected, 'stale gg.WindowId unexpectedly retained native borrow authority'
			assert !stale_id_callback_called
		}
	}
}

fn test_win32_public_conditional_focus_refusal_is_not_a_capability_error_red() {
	$if gg_multiwindow ? {
		mut app := new_app(backend: .win32)!
		defer {
			C.v_multiwindow_win32_service_test_set_focus_refused(0)
			app.stop() or {}
		}
		target := app.create_window(
			title:   'Win32 public refused focus target RED'
			visible: false
		)!
		peer := app.create_window(title: 'Win32 public refused focus peer RED')!
		app.show_window(target)!
		target_hwnd := win32_public_hwnd(mut app, target)!
		peer_hwnd := win32_public_hwnd(mut app, peer)!
		assert C.SetForegroundWindow(peer_hwnd) != 0
		_ = C.SetFocus(peer_hwnd)
		assert C.GetForegroundWindow() == peer_hwnd
		assert C.GetFocus() == peer_hwnd

		before := app.window_state(target)!
		assert before.active == .off
		assert before.focused == .off
		win32_public_request_refused_focus(mut app, target)!
		after := app.window_state(target)!
		assert after.active == .off
		assert after.focused == .off
		assert target_hwnd != peer_hwnd
	}
}

fn test_win32_public_partial_focus_is_never_reported_as_success_red() {
	$if gg_multiwindow ? {
		mut app := new_app(backend: .win32)!
		defer {
			C.v_multiwindow_win32_service_test_set_focus_refused(0)
			app.stop() or {}
		}
		target := app.create_window(title: 'Win32 public partial focus target RED')!
		peer := app.create_window(title: 'Win32 public partial focus peer RED')!
		peer_hwnd := win32_public_hwnd(mut app, peer)!
		assert C.SetForegroundWindow(peer_hwnd) != 0
		_ = C.SetFocus(peer_hwnd)
		assert C.GetForegroundWindow() == peer_hwnd
		assert C.GetFocus() == peer_hwnd

		win32_public_request_refused_focus(mut app, target)!
		assert C.GetForegroundWindow() == peer_hwnd
		assert C.GetFocus() == peer_hwnd
		state := app.window_state(target)!
		assert state.active == .off
		assert state.focused == .off
	}
}

fn test_win32_public_controls_publish_observed_state_red() {
	$if windows {
		$if gg_multiwindow ? {
			mut app := new_app(backend: .win32)!
			defer {
				app.stop() or {}
			}
			window := app.create_window(
				title:   'Win32 public controls and state RED'
				visible: false
			)!
			mut issues := []string{}
			for _ in 0 .. 4 {
				app.poll_events() or {
					issues << 'initial event polling failed: ${err.msg()}'
					break
				}
			}
			initial := app.window_state(window)!
			if !win32_public_state_is_observed(initial) {
				issues << 'initial Win32 state is not observable through gg.App'
			}
			_ = app.drain_window_service_events()!

			for operation in [WindowOperation.show, .hide, .raise, .position, .minimize, .maximize,
				.restore, .fullscreen] {
				capability := app.window_operation_capability(window, operation)!
				if capability.support != .available || capability.asynchronous
					|| capability.requires_user_action || !capability.state_observable {
					issues << '${operation} is not available/synchronous/observable through gg.App'
				}
			}
			focus_capability := app.window_operation_capability(window, .focus)!
			if focus_capability.support != .conditional || focus_capability.asynchronous
				|| !focus_capability.requires_user_action || !focus_capability.state_observable {
				issues << 'focus is not conditional/user-action/observable through gg.App'
			}

			app.show_window(window) or { issues << 'show_window failed: ${err.msg()}' }
			for _ in 0 .. 2 {
				app.poll_events() or { issues << 'show event polling failed: ${err.msg()}' }
			}
			shown := app.window_state(window)!
			if shown.mapping != .mapped || shown.visibility != .visible {
				issues << 'show_window did not publish mapped/visible state'
			}

			app.raise_window(window) or { issues << 'raise_window failed: ${err.msg()}' }
			app.set_window_position(window, 48, 64) or {
				issues << 'set_window_position failed: ${err.msg()}'
			}
			for _ in 0 .. 2 {
				app.poll_events() or { issues << 'position event polling failed: ${err.msg()}' }
			}
			positioned := app.window_state(window)!
			if !positioned.position.known || positioned.position.x != 48
				|| positioned.position.y != 64 {
				issues << 'set_window_position did not publish the requested position'
			}

			app.minimize_window(window) or { issues << 'minimize_window failed: ${err.msg()}' }
			for _ in 0 .. 4 {
				app.poll_events() or { issues << 'minimize event polling failed: ${err.msg()}' }
			}
			minimized := app.window_state(window)!
			if minimized.minimized != .on {
				issues << 'minimize_window did not publish minimized state'
			}

			app.restore_window(window) or {
				issues << 'restore_window after minimize failed: ${err.msg()}'
			}
			for _ in 0 .. 4 {
				app.poll_events() or { issues << 'restore event polling failed: ${err.msg()}' }
			}
			restored_from_minimize := app.window_state(window)!
			if restored_from_minimize.minimized != .off {
				issues << 'restore_window did not clear minimized state'
			}

			app.maximize_window(window) or { issues << 'maximize_window failed: ${err.msg()}' }
			for _ in 0 .. 4 {
				app.poll_events() or { issues << 'maximize event polling failed: ${err.msg()}' }
			}
			maximized := app.window_state(window)!
			if maximized.maximized != .on {
				issues << 'maximize_window did not publish maximized state'
			}

			app.restore_window(window) or {
				issues << 'restore_window after maximize failed: ${err.msg()}'
			}
			for _ in 0 .. 4 {
				app.poll_events() or { issues << 'restore event polling failed: ${err.msg()}' }
			}
			restored_from_maximize := app.window_state(window)!
			if restored_from_maximize.maximized != .off {
				issues << 'restore_window did not clear maximized state'
			}

			app.set_window_fullscreen(window, true) or {
				issues << 'set_window_fullscreen(true) failed: ${err.msg()}'
			}
			for _ in 0 .. 4 {
				app.poll_events() or { issues << 'fullscreen event polling failed: ${err.msg()}' }
			}
			fullscreen := app.window_state(window)!
			if fullscreen.fullscreen != .on {
				issues << 'set_window_fullscreen(true) did not publish fullscreen state'
			}

			app.set_window_fullscreen(window, false) or {
				issues << 'set_window_fullscreen(false) failed: ${err.msg()}'
			}
			for _ in 0 .. 4 {
				app.poll_events() or { issues << 'fullscreen event polling failed: ${err.msg()}' }
			}
			windowed := app.window_state(window)!
			if windowed.fullscreen != .off {
				issues << 'set_window_fullscreen(false) did not clear fullscreen state'
			}

			app.hide_window(window) or { issues << 'hide_window failed: ${err.msg()}' }
			for _ in 0 .. 2 {
				app.poll_events() or { issues << 'hide event polling failed: ${err.msg()}' }
			}
			final_state := app.window_state(window)!
			if final_state.mapping != .unmapped || final_state.visibility != .hidden {
				issues << 'hide_window did not publish unmapped/hidden state'
			}
			if !win32_public_state_is_observed(final_state) {
				issues << 'post-control Win32 state is not observable through gg.App'
			}
			if final_state.sequence <= initial.sequence {
				issues << 'public Win32 state sequence did not advance after controls'
			}
			events := app.drain_window_service_events()!
			if events.filter(it.kind == .state && it.window == window).len == 0 {
				issues << 'controls did not publish a canonical gg.WindowServiceEvent state'
			}
			assert issues.len == 0, 'Win32 gg.App controls/state RED:\n${issues.join('\n')}'
		}
	}
}
