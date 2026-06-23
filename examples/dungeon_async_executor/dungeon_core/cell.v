module dungeon_core

const default_log_limit = 8

// MaterialId is a stable semantic visual key. Render code can map it to colors,
// textures, or materials without putting render resources in core state.
pub enum MaterialId {
	void
	wall_stone
	floor_flagstone
	door_wood_closed
	door_wood_open
	stairs_down
}

// CellKind is the gameplay meaning of a dungeon tile.
pub enum CellKind {
	void
	wall
	floor
	door
	stairs
}

// Direction is the player's grid-facing direction.
pub enum Direction {
	north
	east
	south
	west
}

// Pos is an integer grid position.
pub struct Pos {
pub:
	x int
	y int
}

// Cell stores gameplay semantics and texture-ready material identity only.
pub struct Cell {
pub:
	kind          CellKind
	base_material MaterialId
	door_open     bool
}

// Dungeon stores cells in row-major order.
pub struct Dungeon {
pub:
	width  int
	height int
mut:
	cells []Cell
}

// turn_left returns the direction after a left turn.
pub fn (dir Direction) turn_left() Direction {
	match dir {
		.north { return .west }
		.west { return .south }
		.south { return .east }
		.east { return .north }
	}
}

// turn_right returns the direction after a right turn.
pub fn (dir Direction) turn_right() Direction {
	match dir {
		.north { return .east }
		.east { return .south }
		.south { return .west }
		.west { return .north }
	}
}

// opposite returns the reverse direction.
pub fn (dir Direction) opposite() Direction {
	match dir {
		.north { return .south }
		.south { return .north }
		.east { return .west }
		.west { return .east }
	}
}

// step_delta returns the unit movement vector for a direction.
pub fn (dir Direction) step_delta() Pos {
	match dir {
		.north { return Pos{0, -1} }
		.east { return Pos{1, 0} }
		.south { return Pos{0, 1} }
		.west { return Pos{-1, 0} }
	}
}

// step returns a new position one tile from p in dir.
pub fn (p Pos) step(dir Direction) Pos {
	delta := dir.step_delta()
	return Pos{
		x: p.x + delta.x
		y: p.y + delta.y
	}
}

// wall_cell returns a stone wall tile.
pub fn wall_cell() Cell {
	return Cell{
		kind:          .wall
		base_material: .wall_stone
	}
}

// floor_cell returns a walkable floor tile.
pub fn floor_cell() Cell {
	return Cell{
		kind:          .floor
		base_material: .floor_flagstone
	}
}

// closed_door_cell returns a closed wooden door tile.
pub fn closed_door_cell() Cell {
	return Cell{
		kind:          .door
		base_material: .door_wood_closed
	}
}

// open_door_cell returns an open wooden door tile.
pub fn open_door_cell() Cell {
	return Cell{
		kind:          .door
		base_material: .door_wood_closed
		door_open:     true
	}
}

// stairs_down_cell returns a down-stairs tile.
pub fn stairs_down_cell() Cell {
	return Cell{
		kind:          .stairs
		base_material: .stairs_down
	}
}

// material_id returns the current semantic visual key for the cell.
pub fn (cell Cell) material_id() MaterialId {
	if cell.kind == .door && cell.door_open {
		return .door_wood_open
	}
	return cell.base_material
}

// blocks_movement reports whether the player can enter this cell.
pub fn (cell Cell) blocks_movement() bool {
	return cell.kind == .wall || (cell.kind == .door && !cell.door_open) || cell.kind == .void
}

// blocks_sight reports whether this cell blocks line of sight.
pub fn (cell Cell) blocks_sight() bool {
	return cell.kind == .wall || (cell.kind == .door && !cell.door_open) || cell.kind == .void
}

// opened returns an open-door variant of this cell when it is a door.
pub fn (cell Cell) opened() Cell {
	if cell.kind != .door {
		return cell
	}
	return Cell{
		kind:          .door
		base_material: .door_wood_closed
		door_open:     true
	}
}

// new_dungeon creates a rectangular dungeon filled with fill.
pub fn new_dungeon(width int, height int, fill Cell) !Dungeon {
	if width <= 0 || height <= 0 {
		return error('dungeon: dimensions must be positive')
	}
	return Dungeon{
		width:  width
		height: height
		cells:  []Cell{len: width * height, init: fill}
	}
}

// clone returns a deep copy of the dungeon cell slice.
pub fn (d Dungeon) clone() Dungeon {
	return Dungeon{
		width:  d.width
		height: d.height
		cells:  d.cells.clone()
	}
}

// in_bounds reports whether pos is inside the dungeon.
pub fn (d Dungeon) in_bounds(pos Pos) bool {
	return pos.x >= 0 && pos.y >= 0 && pos.x < d.width && pos.y < d.height
}

// cell_at returns the cell at pos.
pub fn (d Dungeon) cell_at(pos Pos) !Cell {
	if !d.in_bounds(pos) {
		return error('dungeon: position out of bounds')
	}
	return d.cells[d.index(pos)]
}

// set_cell replaces the cell at pos.
pub fn (mut d Dungeon) set_cell(pos Pos, cell Cell) ! {
	if !d.in_bounds(pos) {
		return error('dungeon: position out of bounds')
	}
	d.cells[d.index(pos)] = cell
}

fn (d Dungeon) index(pos Pos) int {
	return pos.y * d.width + pos.x
}
