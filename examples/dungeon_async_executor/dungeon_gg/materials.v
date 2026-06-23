module dungeon_gg

import dungeon_core
import gg

pub struct Material {
pub:
	id          dungeon_core.MaterialId
	name        string
	color       gg.Color
	texture_key string
}

pub struct MaterialRegistry {
pub:
	materials map[dungeon_core.MaterialId]Material
}

// new_material_registry returns the MVP color palette with texture-ready keys.
pub fn new_material_registry() MaterialRegistry {
	mut materials := map[dungeon_core.MaterialId]Material{}
	materials[dungeon_core.MaterialId.void] = Material{
		id:    .void
		name:  'void'
		color: gg.rgb(5, 6, 8)
	}
	materials[dungeon_core.MaterialId.wall_stone] = Material{
		id:          .wall_stone
		name:        'stone wall'
		color:       gg.rgb(88, 91, 100)
		texture_key: 'wall_stone'
	}
	materials[dungeon_core.MaterialId.floor_flagstone] = Material{
		id:          .floor_flagstone
		name:        'flagstone floor'
		color:       gg.rgb(58, 54, 49)
		texture_key: 'floor_flagstone'
	}
	materials[dungeon_core.MaterialId.door_wood_closed] = Material{
		id:          .door_wood_closed
		name:        'closed wooden door'
		color:       gg.rgb(118, 75, 38)
		texture_key: 'door_wood_closed'
	}
	materials[dungeon_core.MaterialId.door_wood_open] = Material{
		id:          .door_wood_open
		name:        'open wooden door'
		color:       gg.rgb(155, 111, 64)
		texture_key: 'door_wood_open'
	}
	materials[dungeon_core.MaterialId.stairs_down] = Material{
		id:          .stairs_down
		name:        'stairs down'
		color:       gg.rgb(50, 104, 118)
		texture_key: 'stairs_down'
	}
	return MaterialRegistry{
		materials: materials
	}
}

// resolve returns a material for id, falling back to void for unknown future IDs.
pub fn (registry MaterialRegistry) resolve(id dungeon_core.MaterialId) Material {
	if material := registry.materials[id] {
		return material
	}
	return registry.materials[dungeon_core.MaterialId.void] or {
		Material{
			id:    .void
			name:  'missing'
			color: gg.rgb(255, 0, 255)
		}
	}
}
