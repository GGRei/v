module dungeon_core

pub const min_dungeon_width = 7
pub const min_dungeon_height = 7
pub const max_dungeon_width = 64
pub const max_dungeon_height = 64
pub const max_dungeon_cells = max_dungeon_width * max_dungeon_height

// GenerationConfig is the immutable input for deterministic dungeon generation.
pub struct GenerationConfig {
pub:
	request_id u64
	seed       u64
	width      int
	height     int
}

// GeneratedDungeon is the worker-safe payload later applied on the owner loop.
pub struct GeneratedDungeon {
pub:
	request_id u64
	seed       u64
	dungeon    Dungeon
	spawn_pos  Pos
	stairs     Pos
}

// clone returns a worker/owner boundary-safe copy of a generated payload.
pub fn (generated GeneratedDungeon) clone() GeneratedDungeon {
	return GeneratedDungeon{
		request_id: generated.request_id
		seed:       generated.seed
		dungeon:    generated.dungeon.clone()
		spawn_pos:  generated.spawn_pos
		stairs:     generated.stairs
	}
}

// generate_dungeon creates a deterministic semantic dungeon for config.
pub fn generate_dungeon(config GenerationConfig) !GeneratedDungeon {
	validate_generation_dimensions(config.width, config.height)!

	mut layout := new_dungeon(config.width, config.height, wall_cell())!
	for y in 1 .. config.height - 1 {
		for x in 1 .. config.width - 1 {
			layout.set_cell(Pos{x, y}, floor_cell())!
		}
	}

	mid_x := config.width / 2
	for y in 1 .. config.height - 1 {
		layout.set_cell(Pos{mid_x, y}, wall_cell())!
	}

	door_y := deterministic_door_y(config.seed, config.height)
	door_pos := Pos{mid_x, door_y}
	spawn_pos := Pos{1, 1}
	stairs := Pos{config.width - 2, config.height - 2}

	layout.set_cell(door_pos, closed_door_cell())!
	layout.set_cell(spawn_pos, floor_cell())!
	layout.set_cell(stairs, stairs_down_cell())!

	return GeneratedDungeon{
		request_id: config.request_id
		seed:       config.seed
		dungeon:    layout
		spawn_pos:  spawn_pos
		stairs:     stairs
	}
}

fn validate_generation_dimensions(width int, height int) ! {
	if width < min_dungeon_width || height < min_dungeon_height {
		return error('dungeon: dimensions must be at least 7x7')
	}
	if width > max_dungeon_width || height > max_dungeon_height {
		return error('dungeon: dimensions exceed maximum 64x64')
	}
	if width * height > max_dungeon_cells {
		return error('dungeon: dimensions exceed maximum cell count')
	}
}

fn deterministic_door_y(seed u64, height int) int {
	span := height - 2
	return 1 + int(seed % u64(span))
}
