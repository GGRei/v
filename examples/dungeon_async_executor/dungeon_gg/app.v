module dungeon_gg

import gg

const window_width = 1280
const window_height = 720

// RunConfig configures the playable demo without exposing runtime internals.
@[params]
pub struct RunConfig {
pub:
	seed   u64 = 7
	width  int = 15
	height int = 13
}

@[heap]
struct App {
mut:
	ctx      &gg.Context = unsafe { nil }
	runtime  &Runtime    = unsafe { nil }
	bindings InputBindings
}

// run opens the gg window, then performs blocking cleanup only after it closes.
pub fn run(config RunConfig) ! {
	log_info('app start seed=${config.seed} size=${config.width}x${config.height} log=${demo_log_path()}')
	mut app := new_app(config)!
	app.ctx.run()
	log_info('gg loop returned')
	app.runtime.shutdown_wait() or {
		log_critical('shutdown_wait error: ${err.msg()}')
		return err
	}
	log_info('shutdown completed')
}

fn new_app(config RunConfig) !&App {
	bindings := detect_input_bindings()
	log_info('keyboard layout ${bindings.layout}')
	mut app := &App{
		runtime:  new_runtime(
			seed:   config.seed
			width:  config.width
			height: config.height
		)!
		bindings: bindings
	}
	app.ctx = gg.new_context(
		bg_color:     gg.rgb(12, 13, 16)
		width:        window_width
		height:       window_height
		window_title: 'Dungeon Async Executor'
		user_data:    app
		frame_fn:     frame
		event_fn:     event
	)
	return app
}

fn frame(mut app App) {
	app.runtime.drain_owner() or {
		log_critical('drain_owner error: ${err.msg()}')
		app.runtime.note_status('Owner executor error: ${err.msg()}')
		app.runtime.request_shutdown()
		app.ctx.quit()
	}

	snapshot := app.runtime.render_snapshot()
	app.ctx.begin()
	draw_scene(mut app.ctx, snapshot, app.runtime.materials, app.runtime.status, app.bindings)
	app.ctx.end()
}

fn event(e &gg.Event, mut app App) {
	if e.typ != .key_down {
		return
	}
	action := action_from_key(app.bindings, e.key_code, e.key_repeat) or { return }
	log_info('key ${e.key_code} mapped to ${action.log_label()}')
	match action.kind {
		.command {
			app.runtime.post_command(action.command) or {
				log_error('post_command ${action.command} failed: ${err.msg()}')
				app.runtime.note_status('Dropped input: ${err.msg()}')
			}
		}
		.generation {
			app.runtime.post_generation_request() or {
				log_error('post_generation_request failed: ${err.msg()}')
				app.runtime.note_status('Generation request dropped: ${err.msg()}')
			}
		}
		.shutdown {
			log_info('app quit requested by key ${e.key_code}')
			app.runtime.request_shutdown()
			app.ctx.quit()
		}
	}
}
