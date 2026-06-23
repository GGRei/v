module dungeon_core

fn test_spawn_discovers_limited_starting_area() {
	state := new_game_state(1, 11, 9)!
	player_index := state.dungeon.index(state.player)

	assert state.visible[player_index]
	assert state.discovered[player_index]
	assert count_true(state.discovered) > 1
	assert count_true(state.discovered) < state.dungeon.cells.len
}

fn test_movement_extends_discovered_area() {
	mut state := new_game_state(1, 15, 13)!
	start_pos := state.player
	start_index := state.dungeon.index(start_pos)
	discovered_before := count_true(state.discovered)

	mut expanded := false
	for _ in 0 .. front_view_depth {
		result := state.apply_command(.move_forward)
		assert result.status == .moved
		if count_true(state.discovered) > discovered_before {
			expanded = true
			break
		}
	}
	assert expanded
	assert count_true(state.discovered) > discovered_before
	assert state.discovered[start_index]
	assert state.visible[state.dungeon.index(state.player)]
}

fn test_front_visibility_reaches_depth_five_but_not_six() {
	state := visibility_depth_test_state()!

	assert state.visible[state.dungeon.index(Pos{6, 3})]
	assert !state.visible[state.dungeon.index(Pos{7, 3})]
	assert state.visible[state.dungeon.index(Pos{6, 1})]
}

fn test_generated_spawn_keeps_north_parallel_wall_run_visible() {
	state := new_game_state(7, 15, 13)!

	assert state.player == Pos{1, 1}
	assert state.facing == .east
	for x in 1 .. 7 {
		pos := Pos{x, 0}
		assert state.dungeon.cell_at(pos)!.blocks_sight()
		assert state.visible[state.dungeon.index(pos)]
		assert state.discovered[state.dungeon.index(pos)]
	}
}

fn test_wall_blocks_visibility_but_wall_is_visible() {
	state := visibility_blocker_test_state(wall_cell())!

	assert state.visible[state.dungeon.index(Pos{3, 3})]
	assert state.discovered[state.dungeon.index(Pos{3, 3})]
	assert !state.visible[state.dungeon.index(Pos{4, 3})]
	assert !state.discovered[state.dungeon.index(Pos{4, 3})]
}

fn test_closed_door_blocks_visibility_but_door_is_visible() {
	state := visibility_blocker_test_state(closed_door_cell())!

	assert state.visible[state.dungeon.index(Pos{3, 3})]
	assert state.discovered[state.dungeon.index(Pos{3, 3})]
	assert !state.visible[state.dungeon.index(Pos{4, 3})]
	assert !state.discovered[state.dungeon.index(Pos{4, 3})]
}

fn test_wall_line_at_same_depth_keeps_side_blockers_visible() {
	state := visibility_wall_line_test_state()!

	assert state.visible[state.dungeon.index(Pos{3, 3})]
	assert state.visible[state.dungeon.index(Pos{3, 2})]
	assert state.visible[state.dungeon.index(Pos{3, 4})]
	assert state.visible[state.dungeon.index(Pos{3, 1})]
	assert state.visible[state.dungeon.index(Pos{3, 5})]
	assert !state.visible[state.dungeon.index(Pos{4, 3})]
	assert !state.discovered[state.dungeon.index(Pos{4, 3})]
}

fn test_near_wide_side_blocker_is_visible_but_floor_behind_stays_hidden() {
	state := visibility_wide_side_blocker_test_state()!

	assert state.visible[state.dungeon.index(Pos{2, 5})]
	assert state.discovered[state.dungeon.index(Pos{2, 5})]
	assert !state.visible[state.dungeon.index(Pos{3, 5})]
	assert !state.discovered[state.dungeon.index(Pos{3, 5})]
}

fn test_wide_parallel_blockers_do_not_reveal_late_floors() {
	state := visibility_wide_parallel_blockers_test_state()!
	player := Pos{1, 4}

	for side in [-2, 2] {
		blocker := visibility_offset_pos(player, 1, side)
		assert state.visible[state.dungeon.index(blocker)]
		assert state.discovered[state.dungeon.index(blocker)]
		for depth in [4, 5] {
			behind := visibility_offset_pos(player, depth, side)
			assert !state.visible[state.dungeon.index(behind)]
			assert !state.discovered[state.dungeon.index(behind)]
		}
	}
}

fn test_continuous_adjacent_parallel_wall_run_stays_visible_without_revealing_space_behind() {
	state := visibility_continuous_parallel_wall_run_test_state()!

	for x in 1 .. 5 {
		wall_pos := Pos{x, 2}
		back_pos := Pos{x, 1}
		assert state.visible[state.dungeon.index(wall_pos)]
		assert state.discovered[state.dungeon.index(wall_pos)]
		assert !state.visible[state.dungeon.index(back_pos)]
		assert !state.discovered[state.dungeon.index(back_pos)]
	}
}

fn test_parallel_wall_gap_stops_visibility_before_far_blocker() {
	state := visibility_parallel_wall_gap_test_state()!

	assert state.visible[state.dungeon.index(Pos{1, 2})]
	assert state.discovered[state.dungeon.index(Pos{1, 2})]
	assert !state.visible[state.dungeon.index(Pos{2, 2})]
	assert !state.discovered[state.dungeon.index(Pos{2, 2})]
	assert !state.visible[state.dungeon.index(Pos{3, 2})]
	assert !state.discovered[state.dungeon.index(Pos{3, 2})]
}

fn test_front_blocker_limits_parallel_wall_visibility() {
	state := visibility_parallel_wall_front_blocker_test_state()!

	assert state.visible[state.dungeon.index(Pos{3, 3})]
	assert state.visible[state.dungeon.index(Pos{1, 2})]
	assert state.visible[state.dungeon.index(Pos{2, 2})]
	assert state.visible[state.dungeon.index(Pos{3, 2})]
	assert !state.visible[state.dungeon.index(Pos{4, 2})]
	assert !state.discovered[state.dungeon.index(Pos{4, 2})]
	assert !state.visible[state.dungeon.index(Pos{4, 3})]
	assert !state.discovered[state.dungeon.index(Pos{4, 3})]
}

fn test_open_door_does_not_block_visibility() {
	state := visibility_blocker_test_state(open_door_cell())!

	assert state.visible[state.dungeon.index(Pos{3, 3})]
	assert state.visible[state.dungeon.index(Pos{4, 3})]
	assert state.discovered[state.dungeon.index(Pos{4, 3})]
}

fn test_wall_blocks_diagonal_corner_peeking() {
	state := visibility_corner_test_state(wall_cell())!

	assert state.visible[state.dungeon.index(Pos{2, 3})]
	assert state.discovered[state.dungeon.index(Pos{2, 3})]
	assert !state.visible[state.dungeon.index(Pos{2, 4})]
	assert !state.discovered[state.dungeon.index(Pos{2, 4})]
	assert !state.visible[state.dungeon.index(Pos{3, 4})]
	assert !state.discovered[state.dungeon.index(Pos{3, 4})]
}

fn test_closed_door_blocks_diagonal_corner_peeking() {
	state := visibility_corner_test_state(closed_door_cell())!

	assert state.visible[state.dungeon.index(Pos{2, 3})]
	assert state.discovered[state.dungeon.index(Pos{2, 3})]
	assert !state.visible[state.dungeon.index(Pos{2, 4})]
	assert !state.discovered[state.dungeon.index(Pos{2, 4})]
	assert !state.visible[state.dungeon.index(Pos{3, 4})]
	assert !state.discovered[state.dungeon.index(Pos{3, 4})]
}

fn test_open_door_allows_diagonal_corner_visibility() {
	state := visibility_corner_test_state(open_door_cell())!

	assert state.visible[state.dungeon.index(Pos{2, 3})]
	assert state.visible[state.dungeon.index(Pos{2, 4})]
	assert state.discovered[state.dungeon.index(Pos{2, 4})]
	assert state.visible[state.dungeon.index(Pos{3, 4})]
	assert state.discovered[state.dungeon.index(Pos{3, 4})]
}

fn test_applied_generation_resets_exploration() {
	mut state := new_game_state(1, 11, 9)!
	far_index := state.dungeon.index(Pos{state.dungeon.width - 2, state.dungeon.height - 2})
	assert !state.discovered[far_index]
	state.discovered[far_index] = true
	expanded_count := count_true(state.discovered)
	request := state.begin_generation_request(2, 11, 9)
	result := generate_dungeon(request)!

	applied := state.apply_generated_dungeon(result)
	assert applied.status == .applied
	assert count_true(state.discovered) < expanded_count
	assert !state.discovered[far_index]
	assert state.visible[state.dungeon.index(state.player)]
	assert state.discovered[state.dungeon.index(state.player)]
}

fn test_render_snapshot_contains_fog_flags() {
	state := new_game_state(1, 11, 9)!
	snapshot := state.render_snapshot()
	player_index := state.player.y * snapshot.width + state.player.x
	far_index := snapshot.tiles.len - 1

	assert snapshot.tiles[player_index].visible
	assert snapshot.tiles[player_index].discovered
	assert !snapshot.tiles[far_index].visible
	assert !snapshot.tiles[far_index].discovered
}

fn visibility_depth_test_state() !GameState {
	mut layout := new_dungeon(9, 7, floor_cell())!
	for x in 0 .. layout.width {
		layout.set_cell(Pos{x, 0}, wall_cell())!
		layout.set_cell(Pos{x, layout.height - 1}, wall_cell())!
	}
	for y in 0 .. layout.height {
		layout.set_cell(Pos{0, y}, wall_cell())!
		layout.set_cell(Pos{layout.width - 1, y}, wall_cell())!
	}
	layout.set_cell(Pos{6, 1}, wall_cell())!
	mut state := GameState{
		seed:          1
		dungeon:       layout
		player:        Pos{1, 3}
		facing:        .east
		version_id:    1
		generation_id: 0
		log_limit:     default_log_limit
	}
	state.reset_exploration()
	return state
}

fn visibility_corner_test_state(blocker Cell) !GameState {
	mut layout := new_dungeon(9, 7, floor_cell())!
	for x in 0 .. layout.width {
		layout.set_cell(Pos{x, 0}, wall_cell())!
		layout.set_cell(Pos{x, layout.height - 1}, wall_cell())!
	}
	for y in 0 .. layout.height {
		layout.set_cell(Pos{0, y}, wall_cell())!
		layout.set_cell(Pos{layout.width - 1, y}, wall_cell())!
	}
	layout.set_cell(Pos{2, 3}, blocker)!
	mut state := GameState{
		seed:          1
		dungeon:       layout
		player:        Pos{1, 3}
		facing:        .east
		version_id:    1
		generation_id: 0
		log_limit:     default_log_limit
	}
	state.reset_exploration()
	return state
}

fn visibility_wall_line_test_state() !GameState {
	mut layout := new_dungeon(9, 7, floor_cell())!
	for x in 0 .. layout.width {
		layout.set_cell(Pos{x, 0}, wall_cell())!
		layout.set_cell(Pos{x, layout.height - 1}, wall_cell())!
	}
	for y in 0 .. layout.height {
		layout.set_cell(Pos{0, y}, wall_cell())!
		layout.set_cell(Pos{layout.width - 1, y}, wall_cell())!
	}
	layout.set_cell(Pos{3, 1}, wall_cell())!
	layout.set_cell(Pos{3, 2}, wall_cell())!
	layout.set_cell(Pos{3, 3}, wall_cell())!
	layout.set_cell(Pos{3, 4}, wall_cell())!
	layout.set_cell(Pos{3, 5}, wall_cell())!
	mut state := GameState{
		seed:          1
		dungeon:       layout
		player:        Pos{1, 3}
		facing:        .east
		version_id:    1
		generation_id: 0
		log_limit:     default_log_limit
	}
	state.reset_exploration()
	return state
}

fn visibility_wide_side_blocker_test_state() !GameState {
	mut layout := new_dungeon(9, 8, floor_cell())!
	for x in 0 .. layout.width {
		layout.set_cell(Pos{x, 0}, wall_cell())!
		layout.set_cell(Pos{x, layout.height - 1}, wall_cell())!
	}
	for y in 0 .. layout.height {
		layout.set_cell(Pos{0, y}, wall_cell())!
		layout.set_cell(Pos{layout.width - 1, y}, wall_cell())!
	}
	layout.set_cell(Pos{2, 5}, wall_cell())!
	mut state := GameState{
		seed:          1
		dungeon:       layout
		player:        Pos{1, 3}
		facing:        .east
		version_id:    1
		generation_id: 0
		log_limit:     default_log_limit
	}
	state.reset_exploration()
	return state
}

fn visibility_wide_parallel_blockers_test_state() !GameState {
	mut layout := visibility_floor_box(9, 9)!
	player := Pos{1, 4}
	layout.set_cell(visibility_offset_pos(player, 1, -2), wall_cell())!
	layout.set_cell(visibility_offset_pos(player, 1, 2), wall_cell())!
	return visibility_test_state(layout, player, .east)
}

fn visibility_continuous_parallel_wall_run_test_state() !GameState {
	mut layout := visibility_floor_box(9, 7)!
	for x in 1 .. 5 {
		layout.set_cell(Pos{x, 2}, wall_cell())!
	}
	return visibility_test_state(layout, Pos{1, 3}, .east)
}

fn visibility_parallel_wall_gap_test_state() !GameState {
	mut layout := visibility_floor_box(9, 7)!
	layout.set_cell(Pos{1, 2}, wall_cell())!
	layout.set_cell(Pos{3, 2}, wall_cell())!
	return visibility_test_state(layout, Pos{1, 3}, .east)
}

fn visibility_parallel_wall_front_blocker_test_state() !GameState {
	mut layout := visibility_floor_box(9, 7)!
	for x in 1 .. 6 {
		layout.set_cell(Pos{x, 2}, wall_cell())!
	}
	layout.set_cell(Pos{3, 3}, wall_cell())!
	return visibility_test_state(layout, Pos{1, 3}, .east)
}

fn visibility_blocker_test_state(blocker Cell) !GameState {
	mut layout := new_dungeon(9, 7, floor_cell())!
	for x in 0 .. layout.width {
		layout.set_cell(Pos{x, 0}, wall_cell())!
		layout.set_cell(Pos{x, layout.height - 1}, wall_cell())!
	}
	for y in 0 .. layout.height {
		layout.set_cell(Pos{0, y}, wall_cell())!
		layout.set_cell(Pos{layout.width - 1, y}, wall_cell())!
	}
	layout.set_cell(Pos{3, 3}, blocker)!
	mut state := GameState{
		seed:          1
		dungeon:       layout
		player:        Pos{1, 3}
		facing:        .east
		version_id:    1
		generation_id: 0
		log_limit:     default_log_limit
	}
	state.reset_exploration()
	return state
}

fn visibility_floor_box(width int, height int) !Dungeon {
	mut layout := new_dungeon(width, height, floor_cell())!
	for x in 0 .. layout.width {
		layout.set_cell(Pos{x, 0}, wall_cell())!
		layout.set_cell(Pos{x, layout.height - 1}, wall_cell())!
	}
	for y in 0 .. layout.height {
		layout.set_cell(Pos{0, y}, wall_cell())!
		layout.set_cell(Pos{layout.width - 1, y}, wall_cell())!
	}
	return layout
}

fn visibility_test_state(layout Dungeon, player Pos, facing Direction) GameState {
	mut state := GameState{
		seed:          1
		dungeon:       layout
		player:        player
		facing:        facing
		version_id:    1
		generation_id: 0
		log_limit:     default_log_limit
	}
	state.reset_exploration()
	return state
}

fn visibility_offset_pos(player Pos, depth int, side int) Pos {
	offset := rotate_offset(Pos{depth, side}, .east)
	return Pos{player.x + offset.x, player.y + offset.y}
}

fn count_true(values []bool) int {
	mut count := 0
	for value in values {
		if value {
			count++
		}
	}
	return count
}
