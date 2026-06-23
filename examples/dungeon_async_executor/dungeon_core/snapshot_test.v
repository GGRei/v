module dungeon_core

fn test_game_snapshot_copies_dungeon_cells() {
	mut state := new_game_state(4, 11, 9)!
	snap := state.game_snapshot()
	original := snap.dungeon.cell_at(state.player)!

	state.dungeon.set_cell(state.player, wall_cell())!
	assert state.dungeon.cell_at(state.player)!.kind == .wall
	assert snap.dungeon.cell_at(state.player)! == original
}

fn test_render_snapshot_uses_material_keys_without_resources() {
	mut state := snapshot_test_state()!
	state.apply_command(.move_forward)
	state.apply_command(.turn_right)
	state.apply_command(.interact)

	snap := state.render_snapshot()
	door_index := 2 + 2 * snap.width
	assert snap.tiles[door_index].kind == .door
	assert snap.tiles[door_index].material_id == .door_wood_open
	assert !snap.tiles[door_index].blocks_movement
	assert snap.version_id == state.version_id
	assert snap.generation_id == state.generation_id
}

fn snapshot_test_state() !GameState {
	mut layout := new_dungeon(5, 5, wall_cell())!
	for y in 1 .. 4 {
		for x in 1 .. 4 {
			layout.set_cell(Pos{x, y}, floor_cell())!
		}
	}
	layout.set_cell(Pos{2, 2}, closed_door_cell())!
	layout.set_cell(Pos{3, 3}, stairs_down_cell())!
	return GameState{
		seed:          1
		dungeon:       layout
		player:        Pos{1, 1}
		facing:        .east
		version_id:    1
		generation_id: 0
		log_limit:     default_log_limit
	}
}

fn test_render_snapshot_copies_log() {
	mut state := new_game_state(4, 11, 9)!
	snap := state.render_snapshot()
	state.apply_command(.move_forward)

	assert snap.log.len == 1
	assert state.log.len > snap.log.len
}
