module dungeon_gg

import dungeon_core

fn test_material_mapping_has_all_core_materials() {
	registry := new_material_registry()
	for id in [
		dungeon_core.MaterialId.void,
		.wall_stone,
		.floor_flagstone,
		.door_wood_closed,
		.door_wood_open,
		.stairs_down,
	] {
		material := registry.resolve(id)
		assert material.id == id
		assert material.name != ''
	}
	assert registry.resolve(.wall_stone).texture_key == 'wall_stone'
	assert registry.resolve(.floor_flagstone).texture_key == 'floor_flagstone'
}
