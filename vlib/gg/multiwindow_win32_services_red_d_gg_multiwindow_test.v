// vtest retry: 0
module gg

$if windows {
	#include "@VMODROOT/vlib/x/multiwindow/testdata/win32_nonreadback_test_oracle.h"

	fn C.v_multiwindow_test_win32_is_window(hwnd voidptr) int
}

struct Win32GgBorrowRedProbe {
mut:
	callback_hit       bool
	hwnd               voidptr
	copied             NativeWindowLease
	live_after_destroy bool
	behavior_issues    []string
}

fn test_win32_gg_public_facade_capabilities_are_distinct_and_complete_red() {
	$if windows {
		eprintln('PACKAGE2_RED_TEST=test_win32_gg_public_facade_capabilities_are_distinct_and_complete_red')
		eprintln('PACKAGE2_RED_FAMILY=gg_public_facade')
		mut app := new_app(backend: .win32)!
		defer {
			app.stop() or {}
		}
		window := app.create_window(title: 'gg.App Win32 public facade RED')!
		mut issues := []string{}
		for operation in [WindowOperation.show, .hide, .raise, .position, .minimize, .maximize,
			.restore, .fullscreen, .clipboard_read, .clipboard_write, .native_borrow, .mouse_lock,
			.titlebar_appearance] {
			capability := app.window_operation_capability(window, operation)!
			if capability.support == .unsupported {
				issues << '${operation} is not exposed by the public gg.App facade'
			}
		}
		focus := app.window_operation_capability(window, .focus)!
		if focus.support != .conditional || !focus.requires_user_action || !focus.state_observable {
			issues << 'focus is not conditional/user-action/observable through gg.App'
		}
		app.show_window(window) or { issues << 'gg.App.show_window failed: ${err.msg()}' }
		app.hide_window(window) or { issues << 'gg.App.hide_window failed: ${err.msg()}' }
		if issues.len > 0 {
			eprintln('PACKAGE2_RED_TERMINAL=behavioral_red:gg_public_facade')
		}
		assert issues.len == 0, 'Win32 gg.App public facade RED:\n${issues.join('\n')}'
	}
}

fn test_win32_gg_public_borrow_is_live_callback_bounded_stale_and_defers_teardown_red() {
	$if windows {
		eprintln('PACKAGE2_RED_TEST=test_win32_gg_public_borrow_is_live_callback_bounded_stale_and_defers_teardown_red')
		eprintln('PACKAGE2_RED_FAMILY=gg_public_borrow')
		mut app := new_app(backend: .win32)!
		window := app.create_window(title: 'gg.App Win32 borrow RED')!
		mut probe := &Win32GgBorrowRedProbe{}
		mut issues := []string{}
		app_ptr := unsafe { voidptr(&app) }
		callback := fn [mut probe, app_ptr, window] (mut lease NativeWindowLease) ! {
			mut owner := unsafe { &App(app_ptr) }
			probe.callback_hit = true
			probe.copied = lease
			inspect_before := fn [mut probe] (hwnd voidptr) ! {
				probe.hwnd = hwnd
			}
			lease.with_win32(inspect_before) or {
				probe.behavior_issues << 'gg lease did not expose Win32 authority: ${err.msg()}'
				return
			}
			if C.v_multiwindow_test_win32_is_window(probe.hwnd) != 1 {
				probe.behavior_issues << 'gg lease did not expose a live HWND'
				return
			}
			owner.destroy_window(window)!
			inspect_after := fn [mut probe] (hwnd voidptr) ! {
				probe.live_after_destroy = C.v_multiwindow_test_win32_is_window(hwnd) == 1
			}
			lease.with_win32(inspect_after) or {
				probe.behavior_issues << 'gg lease expired before callback return: ${err.msg()}'
			}
		}
		mut borrow_error := ''
		app.with_native_window(window, callback) or { borrow_error = err.msg() }
		if borrow_error.len > 0 {
			if probe.callback_hit {
				assert false, 'gg borrow callback fixture/trigger failed: ${borrow_error}'
			}
			issues << 'gg.App.with_native_window failed: ${borrow_error}'
		}
		for issue in probe.behavior_issues {
			issues << issue
		}
		if !probe.callback_hit {
			issues << 'native borrow callback was not invoked'
		}
		if probe.hwnd == unsafe { nil } {
			issues << 'native borrow callback did not expose an HWND'
		} else if C.v_multiwindow_test_win32_is_window(probe.hwnd) != 0 {
			issues << 'HWND survived deferred teardown flush'
		}
		if !probe.live_after_destroy {
			issues << 'native teardown was not deferred until callback return'
		}

		if probe.callback_hit {
			mut stale_rejected := false
			stale_callback := fn (_ voidptr) ! {}
			probe.copied.with_win32(stale_callback) or { stale_rejected = true }
			if !stale_rejected {
				issues << 'copied gg.NativeWindowLease remained valid after callback'
			}
		}
		app.stop()!
		if issues.len > 0 {
			eprintln('PACKAGE2_RED_TERMINAL=behavioral_red:gg_public_borrow')
		}
		assert issues.len == 0, 'Win32 gg.App public borrow RED:\n${issues.join('\n')}'
	}
}
