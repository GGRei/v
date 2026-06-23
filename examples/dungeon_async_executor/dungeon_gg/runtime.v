module dungeon_gg

import context
import dungeon_core
import x.async as xasync
import x.executor

const default_owner_queue_size = 128
const default_pool_workers = 2
const default_pool_queue_size = 16
const default_drain_budget = 32
const err_runtime_not_accepting = 'dungeon: runtime is shutting down'

@[params]
struct RuntimeConfig {
	seed             u64 = 7
	width            int = 15
	height           int = 13
	owner_queue_size int = default_owner_queue_size
	pool_workers     int = default_pool_workers
	pool_queue_size  int = default_pool_queue_size
	drain_budget     int = default_drain_budget
}

@[heap]
struct Runtime {
mut:
	owner                 &executor.Executor = unsafe { nil }
	pool                  &xasync.Pool       = unsafe { nil }
	cancel                context.CancelFn   = unsafe { nil }
	state                 dungeon_core.GameState
	materials             MaterialRegistry
	status                string
	next_seed             u64
	generation_width      int
	generation_height     int
	drain_budget          int
	owner_results         chan OwnerResult
	pending_owner_results []OwnerResult
	shutting_down         bool
	closed                bool
}

enum OwnerResultKind {
	generated
	failure
}

struct OwnerResult {
	kind       OwnerResultKind
	payload    dungeon_core.GeneratedDungeon
	request_id u64
	failure    string
}

struct OwnerResultSink {
	results chan OwnerResult @[required]
}

fn new_runtime(config RuntimeConfig) !&Runtime {
	app_ctx, cancel := xasync.with_cancel()
	return new_runtime_with_context(app_ctx, cancel, config)!
}

fn new_runtime_with_context(app_ctx context.Context, cancel context.CancelFn, config RuntimeConfig) !&Runtime {
	state := dungeon_core.new_game_state(config.seed, config.width, config.height)!
	owner := executor.new(queue_size: config.owner_queue_size)!
	pool := xasync.new_pool_with_context(app_ctx,
		workers:    config.pool_workers
		queue_size: config.pool_queue_size
	)!
	return &Runtime{
		owner:                 owner
		pool:                  pool
		cancel:                cancel
		state:                 state
		materials:             new_material_registry()
		status:                'Ready. Press M to generate a new floor.'
		next_seed:             config.seed
		generation_width:      config.width
		generation_height:     config.height
		drain_budget:          config.drain_budget
		owner_results:         chan OwnerResult{cap: config.owner_queue_size}
		pending_owner_results: []OwnerResult{cap: config.owner_queue_size}
	}
}

fn (mut rt Runtime) post_command(command dungeon_core.Command) ! {
	if !rt.accepting_admission() {
		return error(err_runtime_not_accepting)
	}
	rt.owner.try_post(fn [mut rt, command] () ! {
		if !rt.accepting_admission() {
			return
		}
		result := rt.state.apply_command(command)
		rt.status = result.message
	}) or {
		log_error('post_command ${command} admission failed: ${err.msg()}')
		return err
	}
}

fn (mut rt Runtime) post_generation_request() ! {
	if !rt.accepting_admission() {
		return error(err_runtime_not_accepting)
	}
	rt.owner.try_post(fn [mut rt] () ! {
		if !rt.accepting_admission() {
			return
		}
		rt.start_generation_owner()
	}) or {
		log_error('post_generation_request admission failed: ${err.msg()}')
		return err
	}
}

fn (mut rt Runtime) start_generation_owner() {
	if !rt.accepting_admission() {
		return
	}
	snapshot := rt.state.game_snapshot()
	if snapshot.pending_generation {
		rt.status = 'Generation already running.'
		return
	}
	rt.next_seed++
	config := rt.state.begin_generation_request(rt.next_seed, rt.generation_width,
		rt.generation_height)
	rt.status = 'Generation ${config.request_id} queued.'
	sink := rt.owner_result_sink()
	rt.submit_generation(config, sink) or {
		log_error('submit_generation ${config.request_id} failed: ${err.msg()}')
		result := rt.state.apply_generation_failure(config.request_id, err.msg())
		rt.status = result.message
	}
}

fn (mut rt Runtime) submit_generation(config dungeon_core.GenerationConfig, sink OwnerResultSink) ! {
	rt.pool.try_submit(fn [sink, config] (mut ctx context.Context) ! {
		if context_is_canceled(mut ctx) {
			return
		}
		generated := dungeon_core.generate_dungeon(config) or {
			sink.post_failure_from_worker(mut ctx, config.request_id, err.msg())!
			return
		}
		payload := generated.clone()
		if context_is_canceled(mut ctx) {
			return
		}
		sink.post_generated_from_worker(mut ctx, payload)!
	})!
}

fn (mut rt Runtime) owner_result_sink() OwnerResultSink {
	return OwnerResultSink{
		results: rt.owner_results
	}
}

fn (sink OwnerResultSink) post_generated(parent context.Context, payload dungeon_core.GeneratedDungeon) ! {
	mut ctx := parent
	sink.post_generated_from_worker(mut ctx, payload)!
}

fn (sink OwnerResultSink) post_failure(parent context.Context, request_id u64, failure string) ! {
	mut ctx := parent
	sink.post_failure_from_worker(mut ctx, request_id, failure)!
}

fn (sink OwnerResultSink) post_generated_from_worker(mut ctx context.Context, payload dungeon_core.GeneratedDungeon) ! {
	sink.post_from_worker(mut ctx, OwnerResult{
		kind:    .generated
		payload: payload
	}) or {
		if context_is_canceled(mut ctx) {
			return
		}
		return err
	}
}

fn (sink OwnerResultSink) post_failure_from_worker(mut ctx context.Context, request_id u64, failure string) ! {
	sink.post_from_worker(mut ctx, OwnerResult{
		kind:       .failure
		request_id: request_id
		failure:    failure
	}) or {
		if context_is_canceled(mut ctx) {
			return
		}
		return err
	}
}

fn (sink OwnerResultSink) post_from_worker(mut ctx context.Context, result OwnerResult) ! {
	done := ctx.done()
	mut watch_done := true
	select {
		_ := <-done {
			err := ctx.err()
			if err !is none {
				return err
			}
			watch_done = false
		}
		else {}
	}
	for {
		if watch_done {
			err := ctx.err()
			if err !is none {
				return err
			}
		}
		if !watch_done {
			sink.results <- result
			return
		}
		select {
			sink.results <- result {
				return
			}
			_ := <-done {
				err := ctx.err()
				if err !is none {
					return err
				}
				watch_done = false
			}
		}
	}
}

fn (mut rt Runtime) drain_owner() ! {
	rt.drain_owner_once()!
}

fn (mut rt Runtime) drain_owner_once() !int {
	rt.collect_owner_results()
	mut drained := rt.owner.drain_pending(rt.drain_budget)!
	rt.collect_owner_results()
	posted := rt.post_owner_result_applications()
	if posted > 0 && drained < rt.drain_budget {
		drained += rt.owner.drain_pending(rt.drain_budget - drained)!
	}
	return drained + posted
}

fn (mut rt Runtime) collect_owner_results() {
	for {
		mut received := false
		select {
			result := <-rt.owner_results {
				rt.pending_owner_results << result
				received = true
			}
			else {}
		}
		if !received {
			break
		}
	}
}

fn (mut rt Runtime) post_owner_result_applications() int {
	if !rt.accepting_admission() {
		if rt.pending_owner_results.len > 0 {
			log_info('dropping ${rt.pending_owner_results.len} generation result messages during shutdown')
			rt.pending_owner_results.clear()
		}
		return 0
	}
	mut posted := 0
	for rt.pending_owner_results.len > 0 {
		owner_result := rt.pending_owner_results[0]
		rt.owner.try_post(fn [mut rt, owner_result] () ! {
			if !rt.accepting_admission() {
				return
			}
			match owner_result.kind {
				.generated {
					result := rt.state.apply_generated_dungeon(owner_result.payload)
					rt.status = result.message
				}
				.failure {
					result := rt.state.apply_generation_failure(owner_result.request_id,
						owner_result.failure)
					rt.status = result.message
				}
			}
		}) or {
			log_error('generation result admission failed: ${err.msg()}')
			return posted
		}
		rt.pending_owner_results.delete(0)
		posted++
	}
	return posted
}

fn (rt Runtime) render_snapshot() dungeon_core.RenderSnapshot {
	return rt.state.render_snapshot()
}

fn (mut rt Runtime) note_status(message string) {
	rt.status = message
}

fn (rt Runtime) accepting_admission() bool {
	return !rt.shutting_down && !rt.closed
}

fn (mut rt Runtime) request_shutdown() {
	if rt.shutting_down {
		return
	}
	rt.shutting_down = true
	rt.status = 'Shutting down.'
	log_info('runtime shutdown requested')
	rt.cancel()
}

fn (mut rt Runtime) shutdown_wait() ! {
	if rt.closed {
		log_info('shutdown_wait skipped: already closed')
		return
	}
	rt.closed = true
	log_info('shutdown_wait begin')
	rt.cancel()

	mut first_err := IError(none)
	rt.pool.close() or {
		log_error('pool close error during shutdown_wait: ${err.msg()}')
		first_err = err
	}
	for {
		drained := rt.drain_owner_once() or {
			log_error('owner drain error before stop during shutdown_wait: ${err.msg()}')
			if first_err is none {
				first_err = err
			}
			break
		}
		if drained == 0 {
			break
		}
	}
	rt.owner.stop()
	for {
		drained := rt.owner.drain_pending(rt.drain_budget) or {
			log_error('owner drain error during shutdown_wait: ${err.msg()}')
			if first_err is none {
				first_err = err
			}
			break
		}
		if drained == 0 {
			break
		}
	}
	rt.owner.wait() or {
		log_error('owner wait error during shutdown_wait: ${err.msg()}')
		if first_err is none {
			first_err = err
		}
	}
	if first_err !is none {
		log_error('shutdown_wait failed: ${first_err.msg()}')
		return first_err
	}
	log_info('shutdown_wait completed')
}

fn context_is_canceled(mut ctx context.Context) bool {
	err := ctx.err()
	return err !is none
}
