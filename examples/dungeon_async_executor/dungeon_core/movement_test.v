module dungeon_core

fn test_turning_updates_facing_and_version() {
	mut state := new_game_state(1, 11, 9)!
	start_version := state.version_id

	left := state.apply_command(.turn_left)
	assert left.status == .turned
	assert state.facing == .north
	assert state.version_id == start_version + 1

	right := state.apply_command(.turn_right)
	assert right.status == .turned
	assert state.facing == .east
	assert state.version_id == start_version + 2
}

fn test_movement_blocks_walls_and_closed_doors() {
	mut state := movement_test_state()!

	wall := state.apply_command(.move_back)
	assert wall.status == .blocked
	assert state.player == Pos{1, 1}

	moved := state.apply_command(.move_forward)
	assert moved.status == .moved
	assert state.player == Pos{2, 1}

	state.apply_command(.turn_right)
	door := state.apply_command(.move_forward)
	assert door.status == .blocked
	assert state.player == Pos{2, 1}
}

fn test_strafe_moves_without_changing_facing_and_blocks() {
	mut state := movement_test_state()!
	start_facing := state.facing

	right := state.apply_command(.strafe_right)
	assert right.status == .moved
	assert state.player == Pos{1, 2}
	assert state.facing == start_facing
	right_index := state.dungeon.index(state.player)
	assert state.visible[right_index]
	assert state.discovered[right_index]

	left := state.apply_command(.strafe_left)
	assert left.status == .moved
	assert state.player == Pos{1, 1}
	assert state.facing == start_facing

	wall := state.apply_command(.strafe_left)
	assert wall.status == .blocked
	assert state.player == Pos{1, 1}
	assert state.facing == start_facing

	state.player = Pos{2, 1}
	door := state.apply_command(.strafe_right)
	assert door.status == .blocked
	assert state.player == Pos{2, 1}
	assert state.facing == start_facing
}

fn test_interact_opens_door_then_movement_enters_it() {
	mut state := movement_test_state()!
	state.apply_command(.move_forward)
	state.apply_command(.turn_right)

	opened := state.apply_command(.interact)
	assert opened.status == .interacted
	door_cell := state.dungeon.cell_at(Pos{2, 2})!
	assert door_cell.door_open
	assert door_cell.material_id() == .door_wood_open

	moved := state.apply_command(.move_forward)
	assert moved.status == .moved
	assert state.player == Pos{2, 2}
}

fn test_stairs_report_reached_stairs() {
	mut state := movement_test_state()!
	state.player = Pos{2, 3}
	state.facing = .east

	result := state.apply_command(.move_forward)
	assert result.status == .reached_stairs
	assert state.player == Pos{3, 3}
}

fn movement_test_state() !GameState {
	mut layout := dungeon_from_rows([
		'#####',
		'#...#',
		'#.D.#',
		'#..S#',
		'#####',
	])!
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

fn dungeon_from_rows(rows []string) !Dungeon {
	if rows.len == 0 {
		return error('missing rows')
	}
	width := rows[0].len
	mut layout := new_dungeon(width, rows.len, wall_cell())!
	for y, row in rows {
		if row.len != width {
			return error('rows must have equal width')
		}
		for x in 0 .. width {
			cell := match row[x] {
				`#` { wall_cell() }
				`.` { floor_cell() }
				`D` { closed_door_cell() }
				`d` { open_door_cell() }
				`S` { stairs_down_cell() }
				else { return error('unknown map cell') }
			}

			layout.set_cell(Pos{x, y}, cell)!
		}
	}
	return layout
}
