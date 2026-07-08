// vtest build: gg_multiwindow?
// Run with `v -d gg_multiwindow run examples/gg/multiwindow.v`.
// For Linux X11/Xvfb native rendering, add `-d x_multiwindow_x11`.
// For Linux Wayland native rendering, add `-d sokol_wayland`.
// Without enabled native display support, `backend: .auto` can fall back to `.mock`.
// Without `-d gg_multiwindow`, the source still compiles and reports the opt-in error.
// CI also compiles platform render variants with `-d x_multiwindow_x11`,
// `-d sokol_wayland`, `-d sokol_metal` on macOS, and `-d sokol_d3d11` on Windows.
module main

import gg

struct EventState {
	mock        bool
	input_limit int = 12
mut:
	resized int
	inputs  int
}

fn main() {
	run_example() or {
		eprintln('multi-window example failed: ${err.msg()}')
		exit(1)
	}
}

fn run_example() ! {
	mut app := gg.new_app()!
	defer {
		app.stop() or {}
	}

	caps := app.capabilities()
	println('gg multi-window backend: ${caps.backend}')
	if caps.mock {
		println('mock backend selected; stopping after initial lifecycle events')
	} else {
		println('input logging enabled for key/mouse/focus/scroll events; first 12 events will be printed')
	}

	main_window := app.create_window(
		title:  'GG Multi-Window'
		width:  640
		height: 360
	)!
	tools_window := app.create_window(
		title:  'Tools'
		width:  320
		height: 240
	)!

	app.set_window_title(tools_window, 'Tools - updated')!
	resize_or_ignore_unsupported(mut app, main_window, 720, 420)!
	resize_or_ignore_unsupported(mut app, tools_window, 360, 260)!

	println('live windows:')
	for info in app.window_infos()! {
		println('  ${info.title}: ${info.width}x${info.height}')
	}

	mut state := &EventState{
		mock: caps.mock
	}
	app.run(
		event_fn: fn [mut state] (event gg.WindowEvent, mut app gg.App) ! {
			match event.kind {
				.window_created {
					println('window created: ${event.window}')
				}
				.window_resized {
					state.resized++
					println('window resized: ${event.window} -> ${event.width}x${event.height}')
					if state.mock && state.resized >= 2 {
						app.stop()!
					}
				}
				.window_close_requested {
					println('window close requested: ${event.window}')
					if app.window_exists(event.window) {
						app.destroy_window(event.window)!
					}
				}
				.window_destroyed {
					println('window destroyed: ${event.window}')
					if app.window_ids()!.len == 0 {
						app.stop()!
					}
				}
			}
		}
		input_fn: fn [mut state] (event gg.WindowInputEvent, mut app gg.App) ! {
			_ = app
			if state.inputs >= state.input_limit {
				return
			}
			message := input_event_summary(event)
			if message == '' {
				return
			}
			state.inputs++
			println('input ${state.inputs}/${state.input_limit}: ${message}')
		}
	)!
}

fn input_event_summary(event gg.WindowInputEvent) string {
	input := event.event
	match input.typ {
		.key_down {
			return '${event.window}: key down ${input.key_code} repeat=${input.key_repeat} modifiers=${input.modifiers}'
		}
		.key_up {
			return '${event.window}: key up ${input.key_code} modifiers=${input.modifiers}'
		}
		.char {
			return '${event.window}: char code ${input.char_code}'
		}
		.mouse_down {
			return '${event.window}: mouse down ${input.mouse_button} at ${input.mouse_x},${input.mouse_y}'
		}
		.mouse_up {
			return '${event.window}: mouse up ${input.mouse_button} at ${input.mouse_x},${input.mouse_y}'
		}
		.mouse_move {
			return '${event.window}: mouse move ${input.mouse_x},${input.mouse_y} delta=${input.mouse_dx},${input.mouse_dy}'
		}
		.mouse_scroll {
			return '${event.window}: scroll ${input.scroll_x},${input.scroll_y} at ${input.mouse_x},${input.mouse_y}'
		}
		.mouse_enter {
			return '${event.window}: mouse enter'
		}
		.mouse_leave {
			return '${event.window}: mouse leave'
		}
		.focused {
			return '${event.window}: focused'
		}
		.unfocused {
			return '${event.window}: unfocused'
		}
		.clipboard_pasted {
			return '${event.window}: clipboard pasted'
		}
		.files_dropped {
			return '${event.window}: ${event.dropped_files.len} file(s) dropped'
		}
		else {
			return ''
		}
	}
}

fn resize_or_ignore_unsupported(mut app gg.App, window gg.WindowId, width int, height int) ! {
	app.resize_window(window, width, height) or {
		if err.msg() == 'multiwindow: backend capability is unsupported' {
			return
		}
		return err
	}
}
