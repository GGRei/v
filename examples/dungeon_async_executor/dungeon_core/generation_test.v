module dungeon_core

fn test_generation_is_deterministic_for_same_seed() {
	config := GenerationConfig{
		request_id: 7
		seed:       42
		width:      11
		height:     9
	}
	first := generate_dungeon(config)!
	second := generate_dungeon(config)!

	assert first.spawn_pos == second.spawn_pos
	assert first.stairs == second.stairs
	assert first.dungeon.width == second.dungeon.width
	assert first.dungeon.height == second.dungeon.height
	assert first.dungeon.cells == second.dungeon.cells
}

fn test_generation_changes_with_seed() {
	first := generate_dungeon(GenerationConfig{
		request_id: 1
		seed:       1
		width:      11
		height:     9
	})!
	second := generate_dungeon(GenerationConfig{
		request_id: 1
		seed:       2
		width:      11
		height:     9
	})!

	assert first.dungeon.cells != second.dungeon.cells
	assert first_door_pos(first.dungeon)! != first_door_pos(second.dungeon)!
}

fn test_generation_rejects_too_small_dimensions_before_allocation() {
	generate_dungeon(GenerationConfig{
		request_id: 1
		seed:       1
		width:      min_dungeon_width - 1
		height:     min_dungeon_height
	}) or {
		assert err.msg() == 'dungeon: dimensions must be at least 7x7'
		return
	}
	assert false, 'too-small dungeon dimensions were accepted'
}

fn test_generation_rejects_too_large_dimensions_before_allocation() {
	generate_dungeon(GenerationConfig{
		request_id: 1
		seed:       1
		width:      max_dungeon_width + 1
		height:     max_dungeon_height
	}) or {
		assert err.msg() == 'dungeon: dimensions exceed maximum 64x64'
		return
	}
	assert false, 'too-large dungeon dimensions were accepted'
}

fn test_new_game_state_from_generated_rejects_oversized_public_payload() {
	payload := oversized_generated_payload(3)!
	new_game_state_from_generated(payload) or {
		assert err.msg() == 'dungeon: dimensions exceed maximum 64x64'
		return
	}
	assert false, 'oversized generated payload was accepted'
}

fn test_new_game_state_from_generated_rejects_disconnected_public_payload() {
	payload := disconnected_generated_payload(4)!
	new_game_state_from_generated(payload) or {
		assert err.msg() == 'dungeon: generated spawn cannot reach stairs'
		return
	}
	assert false, 'disconnected generated payload was accepted'
}

fn test_apply_generated_dungeon_rejects_oversized_current_payload_without_installing_it() {
	mut state := new_game_state(10, 11, 9)!
	original := state.dungeon.clone()
	request := state.begin_generation_request(20, max_dungeon_width + 1, max_dungeon_height)
	payload := oversized_generated_payload(request.request_id)!

	result := state.apply_generated_dungeon(payload)
	assert result.status == .invalid
	assert result.message == 'Rejected generation ${request.request_id}: dungeon: dimensions exceed maximum 64x64'
	assert !state.pending_generation
	assert state.dungeon.width == original.width
	assert state.dungeon.height == original.height
	assert state.dungeon.cells == original.cells
	assert state.seed == 10
}

fn test_apply_generated_dungeon_rejects_disconnected_current_payload_without_installing_it() {
	mut state := new_game_state(10, 11, 9)!
	original := state.dungeon.clone()
	request := state.begin_generation_request(20, 7, 7)
	payload := disconnected_generated_payload(request.request_id)!

	result := state.apply_generated_dungeon(payload)
	assert result.status == .invalid
	assert result.message == 'Rejected generation ${request.request_id}: dungeon: generated spawn cannot reach stairs'
	assert !state.pending_generation
	assert state.dungeon.width == original.width
	assert state.dungeon.height == original.height
	assert state.dungeon.cells == original.cells
	assert state.seed == 10
}

fn test_apply_generation_failure_clears_only_current_pending_request() {
	mut state := new_game_state(10, 11, 9)!
	request := state.begin_generation_request(20, 11, 9)

	result := state.apply_generation_failure(request.request_id, 'worker timed out')
	assert result.status == .invalid
	assert result.message == 'Generation ${request.request_id} failed: worker timed out'
	assert !state.pending_generation
	assert state.generation_id == request.request_id
}

fn test_apply_generation_failure_ignores_stale_failure_and_keeps_pending_request() {
	mut state := new_game_state(10, 11, 9)!
	request_1 := state.begin_generation_request(20, 11, 9)
	request_2 := state.begin_generation_request(21, 11, 9)

	result := state.apply_generation_failure(request_1.request_id, 'late worker error')
	assert result.status == .stale
	assert result.message == 'Ignored stale generation failure ${request_1.request_id}; current is ${request_2.request_id}.'
	assert state.pending_generation
	assert state.generation_id == request_2.request_id
}

fn test_generated_dungeon_has_valid_semantic_materials() {
	generated := generate_dungeon(GenerationConfig{
		request_id: 0
		seed:       5
		width:      11
		height:     9
	})!

	assert generated.dungeon.cell_at(Pos{0, 0})!.material_id() == .wall_stone
	assert generated.dungeon.cell_at(generated.spawn_pos)!.material_id() == .floor_flagstone
	assert generated.dungeon.cell_at(generated.stairs)!.material_id() == .stairs_down

	door := generated.dungeon.cell_at(first_door_pos(generated.dungeon)!)!
	assert door.kind == .door
	assert door.material_id() == .door_wood_closed
	assert door.blocks_movement()
}

fn test_generated_dungeon_clone_deep_copies_cells() {
	original := generate_dungeon(GenerationConfig{
		request_id: 1
		seed:       9
		width:      11
		height:     9
	})!
	copied := original.clone()
	mut copied_layout := copied.dungeon
	copied_layout.set_cell(original.spawn_pos, wall_cell())!

	assert original.dungeon.cell_at(original.spawn_pos)!.kind == .floor
	assert copied_layout.cell_at(original.spawn_pos)!.kind == .wall
}

fn test_stale_generation_result_is_ignored_after_newer_request() {
	mut state := new_game_state(10, 11, 9)!
	request_1 := state.begin_generation_request(11, 11, 9)
	result_1 := generate_dungeon(request_1)!
	request_2 := state.begin_generation_request(12, 11, 9)
	unchanged := state.dungeon.clone()

	stale := state.apply_generated_dungeon(result_1)
	assert stale.status == .stale
	assert state.pending_generation
	assert state.generation_id == request_2.request_id
	assert state.dungeon.cells == unchanged.cells

	result_2 := generate_dungeon(request_2)!
	applied := state.apply_generated_dungeon(result_2)
	assert applied.status == .applied
	assert !state.pending_generation
	assert state.seed == 12
	assert state.dungeon.cells == result_2.dungeon.cells
}

fn test_duplicate_generation_result_is_stale_after_apply() {
	mut state := new_game_state(20, 11, 9)!
	request := state.begin_generation_request(21, 11, 9)
	result := generate_dungeon(request)!

	assert state.apply_generated_dungeon(result).status == .applied
	duplicate := state.apply_generated_dungeon(result)
	assert duplicate.status == .stale
	assert !state.pending_generation
}

fn first_door_pos(layout Dungeon) !Pos {
	for index, cell in layout.cells {
		if cell.kind == .door {
			return Pos{
				x: index % layout.width
				y: index / layout.width
			}
		}
	}
	return error('missing door')
}

fn disconnected_generated_payload(request_id u64) !GeneratedDungeon {
	mut layout := new_dungeon(7, 7, wall_cell())!
	spawn_pos := Pos{1, 1}
	stairs := Pos{5, 5}
	layout.set_cell(spawn_pos, floor_cell())!
	layout.set_cell(stairs, stairs_down_cell())!
	return GeneratedDungeon{
		request_id: request_id
		seed:       55
		dungeon:    layout
		spawn_pos:  spawn_pos
		stairs:     stairs
	}
}

fn oversized_generated_payload(request_id u64) !GeneratedDungeon {
	mut layout := new_dungeon(max_dungeon_width + 1, max_dungeon_height, floor_cell())!
	spawn_pos := Pos{1, 1}
	stairs := Pos{max_dungeon_width - 1, max_dungeon_height - 2}
	layout.set_cell(stairs, stairs_down_cell())!
	return GeneratedDungeon{
		request_id: request_id
		seed:       99
		dungeon:    layout
		spawn_pos:  spawn_pos
		stairs:     stairs
	}
}
