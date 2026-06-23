module dungeon_gg

import dungeon_core
import gg

const view_x = 28
const view_y = 56
const view_w = 1224
const view_h = 500
const map_origin_x = 1110
const map_origin_y = 92
const map_max_w = 124
const map_max_h = 104
const hud_y = 588
const log_x = 760
const max_log_lines = 4

struct ProjectionRect {
	x int
	y int
	w int
	h int
}

struct CorridorWallSegment {
	depth       int
	points      []f32
	material_id dungeon_core.MaterialId
}

fn draw_scene(mut ctx gg.Context, snapshot dungeon_core.RenderSnapshot, materials MaterialRegistry, status string, bindings InputBindings) {
	ctx.draw_text(28, 20, 'Dungeon Async Executor',
		size:  28
		bold:  true
		color: gg.rgb(232, 224, 199)
	)
	draw_first_person(mut ctx, snapshot, materials)
	draw_map(mut ctx, snapshot, materials)
	draw_hud(mut ctx, snapshot, status, bindings)
}

fn draw_map(mut ctx gg.Context, snapshot dungeon_core.RenderSnapshot, materials MaterialRegistry) {
	tile_size := minimap_tile_size(snapshot)
	map_w := snapshot.width * tile_size
	map_h := snapshot.height * tile_size
	ctx.draw_rect_filled(map_origin_x - 12, map_origin_y - 34, map_w + 24, map_h + 48, gg.rgb(4, 5,
		8))
	ctx.draw_rect_empty(map_origin_x - 12, map_origin_y - 34, map_w + 24, map_h + 48, gg.rgb(220,
		200, 145))
	ctx.draw_rect_empty(map_origin_x - 8, map_origin_y - 8, map_w + 16, map_h + 16, gg.rgb(77, 73,
		62))
	for tile in snapshot.tiles {
		if !tile.discovered {
			continue
		}
		material := materials.resolve(tile.material_id)
		x := map_origin_x + tile.pos.x * tile_size
		y := map_origin_y + tile.pos.y * tile_size
		ctx.draw_rect_filled(x, y, tile_size - 1, tile_size - 1, minimap_tile_color(tile, material))
	}
	player_x := map_origin_x + snapshot.player.x * tile_size + tile_size / 5
	player_y := map_origin_y + snapshot.player.y * tile_size + tile_size / 5
	marker := minimap_marker_size(tile_size)
	ctx.draw_rect_filled(player_x, player_y, marker, marker, gg.rgb(245, 209, 83))
	ctx.draw_rect_empty(player_x - 1, player_y - 1, marker + 2, marker + 2, gg.rgb(20, 14, 4))
	delta := snapshot.facing.step_delta()
	center_x := player_x + marker / 2
	center_y := player_y + marker / 2
	ctx.draw_line(center_x, center_y, center_x + delta.x * tile_size / 2, center_y +
		delta.y * tile_size / 2, gg.rgb(255, 244, 170))
}

fn draw_first_person(mut ctx gg.Context, snapshot dungeon_core.RenderSnapshot, materials MaterialRegistry) {
	ctx.draw_rect_filled(view_x, view_y, view_w, view_h / 2, gg.rgb(22, 26, 36))
	ctx.draw_rect_filled(view_x, view_y + view_h / 2, view_w, view_h / 2, gg.rgb(31, 29, 27))

	max_depth := 5
	draw_corridor_wall_segments(mut ctx, snapshot, materials, max_depth, -1)
	draw_corridor_wall_segments(mut ctx, snapshot, materials, max_depth, 1)

	for depth := max_depth; depth > 0; depth-- {
		pos := step_from(snapshot.player, snapshot.facing, depth)
		tile := tile_at(snapshot, pos) or { continue }
		rect := front_wall_rect(depth, false, false)
		if !tile.visible {
			// Unknown space is represented by the existing sky/floor background.
			// Do not draw a central panel here; only visible blockers should do that.
			continue
		}
		material := materials.resolve(tile.material_id)
		if tile.blocks_sight {
			wall_rect := front_wall_projection(snapshot, depth) or { continue }
			ctx.draw_rect_filled(wall_rect.x, wall_rect.y, wall_rect.w, wall_rect.h, shade(material.color,
				depth))
			ctx.draw_rect_empty(wall_rect.x, wall_rect.y, wall_rect.w, wall_rect.h, gg.rgb(18, 18,
				18))
			continue
		}
		if tile.kind == .stairs {
			ctx.draw_rect_filled(rect.x + rect.w / 3, rect.y + rect.h / 2, rect.w / 3, rect.h / 4,
				material.color)
		}
	}
}

fn draw_corridor_wall_segments(mut ctx gg.Context, snapshot dungeon_core.RenderSnapshot, materials MaterialRegistry, max_depth int, side int) {
	segments := corridor_wall_segments(snapshot, max_depth, side)
	for i := segments.len; i > 0; i-- {
		segment := segments[i - 1]
		material := materials.resolve(segment.material_id)
		ctx.draw_convex_poly(segment.points, wall_segment_color(material.color, segment.depth))
	}
}

fn front_wall_projection(snapshot dungeon_core.RenderSnapshot, depth int) ?ProjectionRect {
	pos := step_from(snapshot.player, snapshot.facing, depth)
	tile := tile_at(snapshot, pos) or { return none }
	if !tile.visible || !tile.blocks_sight {
		return none
	}
	extend_left := side_blocks_sight_at_depth(snapshot, depth, -1)
		&& !continuous_corridor_wall_reaches_depth(snapshot, depth, -1)
	extend_right := side_blocks_sight_at_depth(snapshot, depth, 1)
		&& !continuous_corridor_wall_reaches_depth(snapshot, depth, 1)
	return front_wall_rect(depth, extend_left, extend_right)
}

fn side_blocks_sight_at_depth(snapshot dungeon_core.RenderSnapshot, depth int, side int) bool {
	tile := corridor_blocker_at_depth(snapshot, depth, side) or { return false }
	return tile.blocks_sight
}

fn continuous_corridor_wall_reaches_depth(snapshot dungeon_core.RenderSnapshot, depth int, side int) bool {
	if depth <= 0 {
		return false
	}
	for current_depth in 0 .. depth {
		corridor_blocker_at_depth(snapshot, current_depth, side) or { return false }
	}
	return true
}

fn corridor_blocker_at_depth(snapshot dungeon_core.RenderSnapshot, depth int, side int) ?dungeon_core.RenderTile {
	pos := side_pos_at_depth(snapshot.player, snapshot.facing, depth, side)
	tile := tile_at(snapshot, pos) or { return none }
	if !tile.visible || !tile.blocks_sight {
		return none
	}
	return tile
}

fn corridor_wall_segments(snapshot dungeon_core.RenderSnapshot, max_depth int, side int) []CorridorWallSegment {
	front_depth := front_blocker_depth(snapshot, max_depth) or { max_depth + 1 }
	limit_depth := if front_depth <= max_depth { front_depth } else { max_depth }
	mut segments := []CorridorWallSegment{}
	for depth in 0 .. limit_depth {
		tile := corridor_blocker_at_depth(snapshot, depth, side) or { break }
		segments << CorridorWallSegment{
			depth:       depth
			points:      corridor_wall_segment_points(depth, side)
			material_id: tile.material_id
		}
	}
	return segments
}

fn front_blocker_depth(snapshot dungeon_core.RenderSnapshot, max_depth int) ?int {
	for depth in 1 .. max_depth + 1 {
		pos := step_from(snapshot.player, snapshot.facing, depth)
		tile := tile_at(snapshot, pos) or { continue }
		if tile.visible && tile.blocks_sight {
			return depth
		}
	}
	return none
}

fn draw_hud(mut ctx gg.Context, snapshot dungeon_core.RenderSnapshot, status string, bindings InputBindings) {
	mut y := hud_y
	ctx.draw_text(view_x, y, controls_legend(bindings),
		size:  14
		color: gg.rgb(218, 207, 178)
	)
	y += 24
	pending := if snapshot.pending_generation { 'busy' } else { 'idle' }
	ctx.draw_text(view_x, y,
		'Facing: ${snapshot.facing}  Gen: ${snapshot.generation_id}  Async: ${pending}',
		size:  14
		color: gg.rgb(183, 201, 190)
	)
	y += 22
	ctx.draw_text(view_x, y, status,
		size:  14
		color: gg.rgb(238, 215, 147)
	)
	ctx.draw_text(log_x, hud_y, 'Log',
		size:  16
		bold:  true
		color: gg.rgb(198, 187, 158)
	)
	mut log_y := hud_y + 24
	log_start := if snapshot.log.len > max_log_lines {
		snapshot.log.len - max_log_lines
	} else {
		0
	}
	for entry in snapshot.log[log_start..] {
		ctx.draw_text(log_x, log_y, entry,
			size:  14
			color: gg.rgb(196, 193, 181)
		)
		log_y += 20
	}
}

fn minimap_tile_size(snapshot dungeon_core.RenderSnapshot) int {
	if snapshot.width <= 0 || snapshot.height <= 0 {
		return 2
	}
	mut size := map_max_w / snapshot.width
	height_size := map_max_h / snapshot.height
	if height_size < size {
		size = height_size
	}
	if size < 2 {
		return 2
	}
	return size
}

fn minimap_marker_size(tile_size int) int {
	if tile_size <= 0 {
		return 4
	}
	marker := tile_size * 3 / 5
	if marker < 4 {
		return 4
	}
	return marker
}

fn minimap_tile_color(tile dungeon_core.RenderTile, material Material) gg.Color {
	if !tile.discovered {
		return gg.rgb(7, 8, 11)
	}
	if !tile.visible {
		return dim_color(material.color, 3)
	}
	return material.color
}

fn tile_at(snapshot dungeon_core.RenderSnapshot, pos dungeon_core.Pos) ?dungeon_core.RenderTile {
	if pos.x < 0 || pos.y < 0 || pos.x >= snapshot.width || pos.y >= snapshot.height {
		return none
	}
	index := pos.y * snapshot.width + pos.x
	if index < 0 || index >= snapshot.tiles.len {
		return none
	}
	return snapshot.tiles[index]
}

fn step_from(pos dungeon_core.Pos, direction dungeon_core.Direction, depth int) dungeon_core.Pos {
	mut out := pos
	for _ in 0 .. depth {
		out = out.step(direction)
	}
	return out
}

fn side_pos_at_depth(pos dungeon_core.Pos, direction dungeon_core.Direction, depth int, side int) dungeon_core.Pos {
	center := step_from(pos, direction, depth)
	side_dir := if side < 0 { direction.turn_left() } else { direction.turn_right() }
	return center.step(side_dir)
}

fn front_wall_rect(depth int, extend_left bool, extend_right bool) ProjectionRect {
	base := layer_rect(depth)
	margin_x := base.x - view_x
	mut x := base.x
	mut w := base.w
	if extend_left {
		x = view_x
		w += margin_x
	}
	if extend_right {
		w += margin_x
	}
	return ProjectionRect{
		x: x
		y: base.y
		w: w
		h: base.h
	}
}

fn layer_rect(depth int) ProjectionRect {
	margin_x := perspective_margin_x(depth)
	margin_y := perspective_margin_y(depth)
	return ProjectionRect{
		x: view_x + margin_x
		y: view_y + margin_y
		w: view_w - margin_x * 2
		h: view_h - margin_y * 2
	}
}

fn corridor_wall_segment_points(depth int, side int) []f32 {
	if side < 0 {
		return left_wall_segment_points(depth)
	}
	return right_wall_segment_points(depth)
}

fn left_wall_segment_points(depth int) []f32 {
	near := layer_rect(depth)
	far := layer_rect(depth + 1)
	near_x := f32(near.x)
	far_x := f32(far.x)
	return [near_x, f32(near.y), far_x, f32(far.y), far_x, f32(far.y + far.h), near_x,
		f32(near.y + near.h)]
}

fn right_wall_segment_points(depth int) []f32 {
	near := layer_rect(depth)
	far := layer_rect(depth + 1)
	near_x := f32(near.x + near.w)
	far_x := f32(far.x + far.w)
	return [far_x, f32(far.y), near_x, f32(near.y), near_x, f32(near.y + near.h), far_x,
		f32(far.y + far.h)]
}

fn shade(color gg.Color, depth int) gg.Color {
	divisor := if depth <= 1 { 1 } else { depth }
	return dim_color(color, divisor)
}

fn wall_segment_color(color gg.Color, depth int) gg.Color {
	factors := [100, 82, 68, 56, 48, 42]
	index := if depth >= 0 && depth < factors.len { depth } else { factors.len - 1 }
	factor := factors[index]
	return gg.rgb(u8(int(color.r) * factor / 100), u8(int(color.g) * factor / 100),
		u8(int(color.b) * factor / 100))
}

fn perspective_margin_x(depth int) int {
	margins := [0, 100, 190, 270, 340, 390]
	if depth >= 0 && depth < margins.len {
		return margins[depth]
	}
	return margins[margins.len - 1]
}

fn perspective_margin_y(depth int) int {
	margins := [0, 42, 80, 116, 148, 172]
	if depth >= 0 && depth < margins.len {
		return margins[depth]
	}
	return margins[margins.len - 1]
}

fn dim_color(color gg.Color, divisor int) gg.Color {
	return gg.rgb(u8(int(color.r) / divisor), u8(int(color.g) / divisor),
		u8(int(color.b) / divisor))
}
