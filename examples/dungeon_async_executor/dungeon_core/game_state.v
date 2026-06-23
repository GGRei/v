module dungeon_core

// ApplyGenerationStatus describes how an async generation payload was handled.
pub enum ApplyGenerationStatus {
	applied
	stale
	invalid
}

// ApplyGenerationResult is returned after validating generation freshness.
pub struct ApplyGenerationResult {
pub:
	status     ApplyGenerationStatus
	message    string
	version_id u64
}

// GameState is semantic render-free state only. It does not own render resources,
// async handles, executor queues, textures, or asset paths.
pub struct GameState {
mut:
	seed               u64
	dungeon            Dungeon
	player             Pos
	facing             Direction
	version_id         u64
	generation_id      u64
	pending_generation bool
	discovered         []bool
	visible            []bool
	log                []string
	log_limit          int
}

// new_game_state creates a playable initial state from seed and dimensions.
pub fn new_game_state(seed u64, width int, height int) !GameState {
	generated := generate_dungeon(GenerationConfig{
		request_id: 0
		seed:       seed
		width:      width
		height:     height
	})!
	return new_game_state_from_generated(generated)
}

// new_game_state_from_generated creates state from a validated generation result.
pub fn new_game_state_from_generated(generated GeneratedDungeon) !GameState {
	validate_generated_dungeon(generated)!
	mut state := GameState{
		seed:          generated.seed
		dungeon:       generated.dungeon.clone()
		player:        generated.spawn_pos
		facing:        .east
		version_id:    1
		generation_id: generated.request_id
		log:           ['Dungeon ${generated.request_id} ready.']
		log_limit:     default_log_limit
	}
	state.reset_exploration()
	return state
}

// begin_generation_request marks a new generation request as current.
pub fn (mut state GameState) begin_generation_request(seed u64, width int, height int) GenerationConfig {
	state.generation_id++
	state.pending_generation = true
	state.record_change('Generation ${state.generation_id} requested.')
	return GenerationConfig{
		request_id: state.generation_id
		seed:       seed
		width:      width
		height:     height
	}
}

// apply_generated_dungeon applies result only if it is still the current request.
pub fn (mut state GameState) apply_generated_dungeon(result GeneratedDungeon) ApplyGenerationResult {
	if result.request_id != state.generation_id || !state.pending_generation {
		message := 'Ignored stale generation ${result.request_id}; current is ${state.generation_id}.'
		state.record_change(message)
		return ApplyGenerationResult{
			status:     .stale
			message:    message
			version_id: state.version_id
		}
	}

	validate_generated_dungeon(result) or {
		message := 'Rejected generation ${result.request_id}: ${err.msg()}'
		state.pending_generation = false
		state.record_change(message)
		return ApplyGenerationResult{
			status:     .invalid
			message:    message
			version_id: state.version_id
		}
	}

	state.seed = result.seed
	state.dungeon = result.dungeon.clone()
	state.player = result.spawn_pos
	state.facing = .east
	state.pending_generation = false
	state.reset_exploration()
	message := 'Applied generation ${result.request_id}.'
	state.record_change(message)
	return ApplyGenerationResult{
		status:     .applied
		message:    message
		version_id: state.version_id
	}
}

// apply_generation_failure records a failed async generation if it is still current.
pub fn (mut state GameState) apply_generation_failure(request_id u64, failure string) ApplyGenerationResult {
	if request_id != state.generation_id || !state.pending_generation {
		message := 'Ignored stale generation failure ${request_id}; current is ${state.generation_id}.'
		state.record_change(message)
		return ApplyGenerationResult{
			status:     .stale
			message:    message
			version_id: state.version_id
		}
	}

	detail := if failure != '' { failure } else { 'unknown failure' }
	message := 'Generation ${request_id} failed: ${detail}'
	state.pending_generation = false
	state.record_change(message)
	return ApplyGenerationResult{
		status:     .invalid
		message:    message
		version_id: state.version_id
	}
}

fn validate_generated_dungeon(result GeneratedDungeon) ! {
	validate_generation_dimensions(result.dungeon.width, result.dungeon.height)!
	if result.dungeon.cells.len != result.dungeon.width * result.dungeon.height {
		return error('dungeon: generated cell count does not match dimensions')
	}
	spawn_cell := result.dungeon.cell_at(result.spawn_pos)!
	if spawn_cell.blocks_movement() {
		return error('dungeon: generated spawn is blocked')
	}
	stairs_cell := result.dungeon.cell_at(result.stairs)!
	if stairs_cell.kind != .stairs {
		return error('dungeon: generated stairs position is not stairs')
	}
	if !can_reach_stairs(result.dungeon, result.spawn_pos, result.stairs) {
		return error('dungeon: generated spawn cannot reach stairs')
	}
}

fn can_reach_stairs(layout Dungeon, start Pos, goal Pos) bool {
	if !layout.in_bounds(start) || !layout.in_bounds(goal) {
		return false
	}
	mut seen := []bool{len: layout.width * layout.height}
	mut queue := []Pos{cap: layout.width * layout.height}
	seen[layout.index(start)] = true
	queue << start
	mut head := 0
	for head < queue.len {
		current := queue[head]
		head++
		if current == goal {
			return true
		}
		for dir in [Direction.north, .east, .south, .west] {
			next := current.step(dir)
			if !layout.in_bounds(next) {
				continue
			}
			next_index := layout.index(next)
			if seen[next_index] {
				continue
			}
			cell := layout.cell_at(next) or { continue }
			if !cell.is_generation_path_passable() {
				continue
			}
			seen[next_index] = true
			queue << next
		}
	}
	return false
}

fn (cell Cell) is_generation_path_passable() bool {
	return cell.kind == .floor || cell.kind == .door || cell.kind == .stairs
}

fn (mut state GameState) record_change(message string) {
	state.append_log(message)
	state.version_id++
}

fn (mut state GameState) append_log(message string) {
	if message == '' {
		return
	}
	state.log << message
	limit := if state.log_limit > 0 { state.log_limit } else { default_log_limit }
	if state.log.len > limit {
		state.log = state.log[state.log.len - limit..].clone()
	}
}
