module dungeon_gg

import context
import dungeon_core
import time

fn test_core_command_mutates_only_after_executor_drain() {
	mut rt := new_runtime(
		seed:   1
		width:  9
		height: 9
	)!
	defer {
		rt.shutdown_wait() or { panic(err.msg()) }
	}

	assert rt.render_snapshot().facing == dungeon_core.Direction.east
	rt.post_command(.turn_left)!
	assert rt.render_snapshot().facing == dungeon_core.Direction.east
	rt.drain_owner()!
	assert rt.render_snapshot().facing == dungeon_core.Direction.north
}

fn test_owner_queue_full_reports_backpressure() {
	mut rt := new_runtime(
		seed:             1
		width:            9
		height:           9
		owner_queue_size: 1
	)!
	defer {
		rt.shutdown_wait() or { panic(err.msg()) }
	}

	rt.post_command(.turn_left)!
	rt.post_command(.turn_right) or {
		assert err.msg().contains('queue is full')
		return
	}
	assert false
}

fn test_runtime_rejects_user_admission_after_shutdown_requested() {
	mut rt := new_runtime(
		seed:   1
		width:  9
		height: 9
	)!
	defer {
		rt.shutdown_wait() or { panic(err.msg()) }
	}

	rt.request_shutdown()
	mut command_rejected := false
	rt.post_command(.turn_left) or {
		assert err.msg() == 'dungeon: runtime is shutting down'
		command_rejected = true
	}
	assert command_rejected
	mut generation_rejected := false
	rt.post_generation_request() or {
		assert err.msg() == 'dungeon: runtime is shutting down'
		generation_rejected = true
	}
	assert generation_rejected
}

fn test_runtime_rejects_user_admission_after_close() {
	mut rt := new_runtime(
		seed:   1
		width:  9
		height: 9
	)!

	rt.shutdown_wait()!
	mut command_rejected := false
	rt.post_command(.turn_left) or {
		assert err.msg() == 'dungeon: runtime is shutting down'
		command_rejected = true
	}
	assert command_rejected
	mut generation_rejected := false
	rt.post_generation_request() or {
		assert err.msg() == 'dungeon: runtime is shutting down'
		generation_rejected = true
	}
	assert generation_rejected
}

fn test_generation_failure_is_applied_by_owner_job() {
	mut rt := new_runtime(
		seed:   1
		width:  9
		height: 9
	)!
	defer {
		rt.shutdown_wait() or { panic(err.msg()) }
	}

	config_ch := chan dungeon_core.GenerationConfig{cap: 1}
	rt.owner.try_post(fn [mut rt, config_ch] () ! {
		config := rt.state.begin_generation_request(2, 9, 9)
		config_ch <- config
	})!
	rt.drain_owner()!
	config := <-config_ch

	sink := rt.owner_result_sink()
	sink.post_failure(context.background(), config.request_id, 'boom')!
	rt.drain_owner()!
	snapshot := rt.render_snapshot()
	assert !snapshot.pending_generation
	assert rt.status.contains('failed')
}

fn test_submit_generation_reports_pool_backpressure_when_pool_is_full() {
	mut rt := new_runtime(
		seed:             1
		width:            9
		height:           9
		owner_queue_size: 1
		pool_workers:     1
		pool_queue_size:  1
		drain_budget:     1
	)!
	defer {
		rt.request_shutdown()
		rt.shutdown_wait() or { panic(err.msg()) }
	}

	rt.owner_results <- OwnerResult{
		kind:       .failure
		request_id: 999
		failure:    'hold mailbox capacity'
	}
	sink := rt.owner_result_sink()
	rt.submit_generation(dungeon_core.GenerationConfig{
		request_id: 1
		seed:       10
		width:      9
		height:     9
	}, sink)!
	rt.submit_generation(dungeon_core.GenerationConfig{
		request_id: 2
		seed:       11
		width:      9
		height:     9
	}, sink)!
	rt.submit_generation(dungeon_core.GenerationConfig{
		request_id: 3
		seed:       12
		width:      9
		height:     9
	}, sink) or {
		assert err.msg() == 'async: pool queue is full'
		return
	}
	assert false
}

fn test_stale_generation_result_is_ignored_by_owner_job() {
	mut rt := new_runtime(
		seed:   1
		width:  9
		height: 9
	)!
	defer {
		rt.shutdown_wait() or { panic(err.msg()) }
	}

	config_ch := chan dungeon_core.GenerationConfig{cap: 2}
	rt.owner.try_post(fn [mut rt, config_ch] () ! {
		config_ch <- rt.state.begin_generation_request(2, 9, 9)
		config_ch <- rt.state.begin_generation_request(3, 9, 9)
	})!
	rt.drain_owner()!
	old_config := <-config_ch
	current_config := <-config_ch
	payload := dungeon_core.generate_dungeon(old_config)!.clone()

	sink := rt.owner_result_sink()
	sink.post_generated(context.background(), payload)!
	rt.drain_owner()!
	snapshot := rt.render_snapshot()
	assert snapshot.generation_id == current_config.request_id
	assert snapshot.pending_generation
	assert rt.status.contains('stale')
}

fn test_generation_result_waits_until_owner_can_post_application() {
	mut rt := new_runtime(
		seed:             1
		width:            9
		height:           9
		owner_queue_size: 1
		drain_budget:     1
	)!
	defer {
		rt.shutdown_wait() or { panic(err.msg()) }
	}

	config := begin_generation_for_test(mut rt, 2)
	payload := dungeon_core.generate_dungeon(config)!.clone()
	rt.owner.try_post(fn () ! {})!

	done := chan bool{cap: 1}
	sink := rt.owner_result_sink()
	spawn fn [sink, payload, done] () {
		sink.post_generated(context.background(), payload) or {
			done <- false
			return
		}
		done <- true
	}()

	assert wait_bool(done, 1 * time.second)
	rt.drain_owner()!
	assert rt.render_snapshot().pending_generation
	rt.drain_owner()!
	snapshot := rt.render_snapshot()
	assert !snapshot.pending_generation
	assert snapshot.generation_id == config.request_id
	assert rt.status.contains('Applied')
}

fn test_generation_failure_waits_until_owner_can_post_application_and_clears_busy() {
	mut rt := new_runtime(
		seed:             1
		width:            9
		height:           9
		owner_queue_size: 1
		drain_budget:     1
	)!
	defer {
		rt.shutdown_wait() or { panic(err.msg()) }
	}

	config := begin_generation_for_test(mut rt, 2)
	rt.owner.try_post(fn () ! {})!

	done := chan bool{cap: 1}
	sink := rt.owner_result_sink()
	request_id := config.request_id
	spawn fn [sink, request_id, done] () {
		sink.post_failure(context.background(), request_id, 'boom') or {
			done <- false
			return
		}
		done <- true
	}()

	assert wait_bool(done, 1 * time.second)
	rt.drain_owner()!
	assert rt.render_snapshot().pending_generation
	rt.drain_owner()!
	snapshot := rt.render_snapshot()
	assert !snapshot.pending_generation
	assert snapshot.generation_id == config.request_id
	assert rt.status.contains('failed')
}

fn test_posted_owner_result_does_not_apply_after_shutdown_request() {
	mut rt := new_runtime(
		seed:             1
		width:            9
		height:           9
		owner_queue_size: 2
		drain_budget:     1
	)!

	config := begin_generation_for_test(mut rt, 2)
	payload := dungeon_core.generate_dungeon(config)!.clone()
	sink := rt.owner_result_sink()
	sink.post_generated(context.background(), payload)!
	rt.collect_owner_results()
	assert rt.post_owner_result_applications() == 1

	rt.request_shutdown()
	rt.shutdown_wait()!

	snapshot := rt.render_snapshot()
	assert snapshot.pending_generation
	assert snapshot.generation_id == config.request_id
	assert rt.status == 'Shutting down.'
}

fn test_shutdown_wait_ignores_normal_cancel_while_generation_waits_for_mailbox_capacity() {
	mut rt := new_runtime(
		seed:             1
		width:            9
		height:           9
		owner_queue_size: 1
		pool_workers:     1
		pool_queue_size:  1
		drain_budget:     1
	)!

	config := begin_generation_for_test(mut rt, 2)
	rt.owner_results <- OwnerResult{
		kind:       .failure
		request_id: 999
		failure:    'hold mailbox capacity'
	}
	sink := rt.owner_result_sink()
	rt.submit_generation(config, sink)!
	time.sleep(20 * time.millisecond)

	rt.request_shutdown()
	rt.shutdown_wait() or {
		assert false, 'normal shutdown should not surface worker post cancellation: ${err.msg()}'
	}
	assert rt.status == 'Shutting down.'
}

fn begin_generation_for_test(mut rt Runtime, seed u64) dungeon_core.GenerationConfig {
	config_ch := chan dungeon_core.GenerationConfig{cap: 1}
	rt.owner.try_post(fn [mut rt, config_ch, seed] () ! {
		config_ch <- rt.state.begin_generation_request(seed, 9, 9)
	}) or { panic(err.msg()) }
	rt.drain_owner() or { panic(err.msg()) }
	return <-config_ch
}

fn wait_bool(ch chan bool, timeout time.Duration) bool {
	select {
		ok := <-ch {
			return ok
		}
		timeout {
			return false
		}
	}
	return false
}
