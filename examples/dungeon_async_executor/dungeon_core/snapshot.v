module dungeon_core

// GameSnapshot is a copy-safe gameplay snapshot for background calculations.
pub struct GameSnapshot {
pub:
	dungeon            Dungeon
	player             Pos
	facing             Direction
	version_id         u64
	generation_id      u64
	pending_generation bool
}

// RenderTile is render-facing data with semantic material keys only.
pub struct RenderTile {
pub:
	pos             Pos
	kind            CellKind
	material_id     MaterialId
	blocks_movement bool
	blocks_sight    bool
	discovered      bool
	visible         bool
}

// RenderSnapshot is immutable render input with no gg, Sokol, texture, or image handles.
pub struct RenderSnapshot {
pub:
	width              int
	height             int
	tiles              []RenderTile
	player             Pos
	facing             Direction
	version_id         u64
	generation_id      u64
	pending_generation bool
	log                []string
}

// game_snapshot returns a copy-safe semantic snapshot for workers.
pub fn (state GameState) game_snapshot() GameSnapshot {
	return GameSnapshot{
		dungeon:            state.dungeon.clone()
		player:             state.player
		facing:             state.facing
		version_id:         state.version_id
		generation_id:      state.generation_id
		pending_generation: state.pending_generation
	}
}

// render_snapshot returns render-facing semantic data without render resources.
pub fn (state GameState) render_snapshot() RenderSnapshot {
	mut tiles := []RenderTile{cap: state.dungeon.cells.len}
	for index, cell in state.dungeon.cells {
		pos := Pos{
			x: index % state.dungeon.width
			y: index / state.dungeon.width
		}
		tiles << RenderTile{
			pos:             pos
			kind:            cell.kind
			material_id:     cell.material_id()
			blocks_movement: cell.blocks_movement()
			blocks_sight:    cell.blocks_sight()
			discovered:      bool_at(state.discovered, index)
			visible:         bool_at(state.visible, index)
		}
	}
	return RenderSnapshot{
		width:              state.dungeon.width
		height:             state.dungeon.height
		tiles:              tiles
		player:             state.player
		facing:             state.facing
		version_id:         state.version_id
		generation_id:      state.generation_id
		pending_generation: state.pending_generation
		log:                state.log.clone()
	}
}

fn bool_at(values []bool, index int) bool {
	return index >= 0 && index < values.len && values[index]
}
