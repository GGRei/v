module dungeon_core

const visible_offsets = [
	Pos{0, 0},
	Pos{1, 0},
	Pos{-1, 0},
	Pos{0, 1},
	Pos{0, -1},
]

const front_view_depth = 5

fn (mut state GameState) reset_exploration() {
	cell_count := state.dungeon.width * state.dungeon.height
	state.discovered = []bool{len: cell_count}
	state.visible = []bool{len: cell_count}
	state.refresh_visibility()
}

fn (mut state GameState) refresh_visibility() {
	cell_count := state.dungeon.width * state.dungeon.height
	if state.visible.len != cell_count || state.discovered.len != cell_count {
		state.discovered = []bool{len: cell_count}
		state.visible = []bool{len: cell_count}
	}
	for i in 0 .. state.visible.len {
		state.visible[i] = false
	}
	for offset in visible_offsets {
		state.mark_visible(state.player.x + offset.x, state.player.y + offset.y)
	}
	front_blocker_depth := state.front_blocker_depth() or { front_view_depth + 1 }
	for side in -2 .. 3 {
		mut blocked_by_lateral := false
		for depth in 1 .. front_view_depth + 1 {
			if side != 0 && depth > front_blocker_depth {
				break
			}
			rotated := rotate_offset(Pos{depth, side}, state.facing)
			pos := Pos{state.player.x + rotated.x, state.player.y + rotated.y}
			cell := state.dungeon.cell_at(pos) or { break }
			if blocked_by_lateral && !cell.blocks_sight() {
				break
			}
			if (side < -1 || side > 1) && depth < 4 && !cell.blocks_sight() {
				continue
			}
			if state.corner_blocks_front_offset(depth, side) && !cell.blocks_sight() {
				break
			}
			if !state.mark_visible_pos(pos) {
				break
			}
			if cell.blocks_sight() {
				if side == 0 {
					break
				}
				blocked_by_lateral = true
				continue
			}
		}
	}
}

fn (state GameState) front_blocker_depth() ?int {
	for depth in 1 .. front_view_depth + 1 {
		if state.offset_blocks_sight(Pos{depth, 0}) {
			return depth
		}
	}
	return none
}

fn (state GameState) corner_blocks_front_offset(depth int, side int) bool {
	if side == 0 {
		return false
	}
	side_step := if side > 0 { 1 } else { -1 }
	return state.offset_blocks_sight(Pos{depth, side - side_step})
		|| state.offset_blocks_sight(Pos{depth - 1, side})
}

fn (state GameState) offset_blocks_sight(offset Pos) bool {
	rotated := rotate_offset(offset, state.facing)
	pos := Pos{state.player.x + rotated.x, state.player.y + rotated.y}
	cell := state.dungeon.cell_at(pos) or { return true }
	return cell.blocks_sight()
}

fn (mut state GameState) mark_visible(x int, y int) {
	state.mark_visible_pos(Pos{x, y})
}

fn (mut state GameState) mark_visible_pos(pos Pos) bool {
	if !state.dungeon.in_bounds(pos) {
		return false
	}
	index := state.dungeon.index(pos)
	state.visible[index] = true
	state.discovered[index] = true
	return true
}

fn rotate_offset(offset Pos, facing Direction) Pos {
	match facing {
		.east {
			return offset
		}
		.south {
			return Pos{-offset.y, offset.x}
		}
		.west {
			return Pos{-offset.x, -offset.y}
		}
		.north {
			return Pos{offset.y, -offset.x}
		}
	}
}
