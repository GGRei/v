module dungeon_gg

import dungeon_core
import gg

fn test_minimap_tile_color_respects_fog_flags() {
	material := Material{
		id:    .wall_stone
		name:  'stone'
		color: gg.rgb(90, 60, 30)
	}
	hidden := render_tile_for_fog_test(false, false)
	seen := render_tile_for_fog_test(true, false)
	visible := render_tile_for_fog_test(true, true)

	hidden_color := minimap_tile_color(hidden, material)
	seen_color := minimap_tile_color(seen, material)
	visible_color := minimap_tile_color(visible, material)

	assert hidden_color != material.color
	assert seen_color.r < material.color.r
	assert seen_color.g < material.color.g
	assert seen_color.b < material.color.b
	assert visible_color == material.color
}

fn test_minimap_layout_helpers_stay_visible() {
	snapshot := dungeon_core.RenderSnapshot{
		width:  64
		height: 64
	}
	tile_size := minimap_tile_size(snapshot)
	assert tile_size > 0
	assert minimap_marker_size(tile_size) >= 4
	assert minimap_tile_color(render_tile_for_fog_test(false, false), Material{
		id:    .floor_flagstone
		name:  'floor'
		color: gg.rgb(60, 60, 60)
	}) != gg.rgb(60, 60, 60)
}

fn test_front_wall_rect_extends_coplanar_sides() {
	base := front_wall_rect(4, false, false)
	left := front_wall_rect(4, true, false)
	right := front_wall_rect(4, false, true)
	both := front_wall_rect(4, true, true)

	assert left.y == base.y
	assert left.h == base.h
	assert right.y == base.y
	assert right.h == base.h
	assert left.x < base.x
	assert left.w > base.w
	assert right.x == base.x
	assert right.w > base.w
	assert both.x == left.x
	assert both.w > left.w
	assert both.w > right.w
}

fn test_front_wall_projection_extends_for_side_blockers() {
	base := front_wall_rect(3, false, false)
	projection := front_wall_projection(wall_projection_snapshot(side_blocker_tile(1, false), side_blocker_tile(3,
		false)), 3) or { panic('expected front wall projection') }

	assert projection.y == base.y
	assert projection.h == base.h
	assert projection.x < base.x
	assert projection.w > base.w
}

fn test_front_wall_projection_still_extends_for_coplanar_blocker_without_depth_zero_run() {
	base := front_wall_rect(3, false, false)
	left_only := front_wall_projection(wall_projection_snapshot(side_blocker_tile(1, false),
		side_floor_tile(3)), 3) or { panic('expected front wall projection') }
	right_only := front_wall_projection(wall_projection_snapshot(side_floor_tile(1), side_blocker_tile(3,
		false)), 3) or { panic('expected front wall projection') }

	assert left_only.x < base.x
	assert left_only.w > base.w
	assert right_only.x == base.x
	assert right_only.w > base.w
}

fn test_front_wall_projection_does_not_extend_left_over_continuous_corridor_wall() {
	base := front_wall_rect(3, false, false)
	projection := front_wall_projection(front_with_corridor_runs_snapshot(3, 3, -1), 3) or {
		panic('expected front wall projection')
	}

	assert projection.x == base.x
	assert projection.y == base.y
	assert projection.w == base.w
	assert projection.h == base.h
}

fn test_front_wall_projection_does_not_extend_right_over_continuous_corridor_wall() {
	base := front_wall_rect(3, false, false)
	projection := front_wall_projection(front_with_corridor_runs_snapshot(3, -1, 3), 3) or {
		panic('expected front wall projection')
	}

	assert projection.x == base.x
	assert projection.y == base.y
	assert projection.w == base.w
	assert projection.h == base.h
}

fn test_front_wall_projection_does_not_extend_full_width_over_two_corridor_walls() {
	base := front_wall_rect(3, false, false)
	projection := front_wall_projection(front_with_corridor_runs_snapshot(3, 3, 3), 3) or {
		panic('expected front wall projection')
	}

	assert projection.x == base.x
	assert projection.y == base.y
	assert projection.w == base.w
	assert projection.h == base.h
}

fn test_corridor_wall_far_edge_raccords_to_front_base_edge() {
	snapshot := front_with_corridor_runs_snapshot(3, 3, 3)
	front := front_wall_rect(3, false, false)
	left := corridor_wall_segments(snapshot, 5, -1)
	right := corridor_wall_segments(snapshot, 5, 1)

	assert left.len == 3
	assert right.len == 3
	assert_left_segment_far_edge(left[left.len - 1].points, front)
	assert_right_segment_far_edge(right[right.len - 1].points, front)
}

fn test_front_wall_projection_ignores_discovered_only_side_blockers() {
	base := front_wall_rect(3, false, false)
	projection := front_wall_projection(wall_projection_snapshot(side_blocker_tile(1, true),
		side_blocker_tile(3, true)), 3) or { panic('expected front wall projection') }

	assert projection.x == base.x
	assert projection.y == base.y
	assert projection.w == base.w
	assert projection.h == base.h
}

fn test_front_wall_projection_does_not_extend_empty_or_hidden_sides() {
	base := front_wall_rect(3, false, false)
	projection := front_wall_projection(wall_projection_snapshot(side_floor_tile(1),
		hidden_wall_tile()), 3) or { panic('expected front wall projection') }

	assert projection.x == base.x
	assert projection.y == base.y
	assert projection.w == base.w
	assert projection.h == base.h
}

fn test_layer_rect_recedes_monotonically() {
	near := layer_rect(0)
	far := layer_rect(4)

	assert near.x < far.x
	assert near.y < far.y
	assert near.w > far.w
	assert near.h > far.h
}

fn test_wall_segment_color_uses_smooth_monotone_depth_factors() {
	base := gg.rgb(200, 150, 100)
	first := wall_segment_color(base, 0)
	second := wall_segment_color(base, 1)
	third := wall_segment_color(base, 2)
	last := wall_segment_color(base, 5)

	assert first == base
	assert second.r == 164
	assert second.g == 123
	assert second.b == 82
	assert third.r == 136
	assert third.r < second.r
	assert int(second.r) >= int(first.r) * 75 / 100
	assert int(second.g) >= int(first.g) * 75 / 100
	assert int(second.b) >= int(first.b) * 75 / 100
	assert int(third.r) >= int(second.r) * 75 / 100
	assert int(third.g) >= int(second.g) * 75 / 100
	assert int(third.b) >= int(second.b) * 75 / 100
	assert last.r < third.r
	assert last.g < third.g
	assert last.b < third.b
	assert second.r > shade(base, 2).r
	assert last.r <= first.r
	assert last.g <= first.g
	assert last.b <= first.b
}

fn test_corridor_wall_segments_require_visible_blocker() {
	discovered_only := open_corridor_projection_snapshot(side_blocker_tile(1, true),
		side_blocker_tile(3, true))
	empty_or_hidden := open_corridor_projection_snapshot(side_floor_tile(1), hidden_wall_tile())

	assert !has_corridor_wall(discovered_only, -1)
	assert !has_corridor_wall(discovered_only, 1)
	assert !has_corridor_wall(empty_or_hidden, -1)
	assert !has_corridor_wall(empty_or_hidden, 1)
}

fn test_corridor_wall_segments_ignore_far_only_blocker_near_front() {
	snapshot := far_only_with_front_projection_snapshot(side_floor_tile(1), side_blocker_tile(3,
		false))

	assert !has_corridor_wall(snapshot, 1)
}

fn test_corridor_wall_segments_ignore_far_only_blocker_in_open_corridor() {
	snapshot := far_only_open_projection_snapshot(side_blocker_tile(1, false), side_floor_tile(3))

	assert !has_corridor_wall(snapshot, -1)
}

fn test_corridor_wall_segment_points_use_layer_edges() {
	left := corridor_wall_segment_points(2, -1)
	right := corridor_wall_segment_points(2, 1)
	near := layer_rect(2)
	far := layer_rect(3)

	assert left == [f32(near.x), f32(near.y), f32(far.x), f32(far.y), f32(far.x), f32(far.y + far.h),
		f32(near.x), f32(near.y + near.h)]
	assert right == [f32(far.x + far.w), f32(far.y), f32(near.x + near.w), f32(near.y),
		f32(near.x + near.w), f32(near.y + near.h), f32(far.x + far.w), f32(far.y + far.h)]
}

fn test_corridor_wall_segments_adjacent_only_does_not_force_depth_three() {
	snapshot := adjacent_corridor_projection_snapshot(adjacent_blocker_tile(1, false),
		adjacent_floor_tile(3))
	segments := corridor_wall_segments(snapshot, 5, -1)
	points := segments[0].points
	far := layer_rect(1)
	forced_old_depth := layer_rect(3)

	assert segments.len == 1
	assert points.len == 8
	assert points[0] == f32(view_x)
	assert points[1] == f32(view_y)
	assert points[2] == f32(far.x)
	assert points[3] == f32(far.y)
	assert points[4] == f32(far.x)
	assert points[5] == f32(far.y + far.h)
	assert points[6] == f32(view_x)
	assert points[7] == f32(view_y + view_h)
	assert points[4] != f32(forced_old_depth.x)
	assert_left_segment_x_monotone(points)
}

fn test_corridor_wall_segments_depth_zero_right_mirrors_left() {
	snapshot := adjacent_corridor_projection_snapshot(adjacent_floor_tile(1), adjacent_blocker_tile(3,
		false))
	segments := corridor_wall_segments(snapshot, 5, 1)
	points := segments[0].points
	far := layer_rect(1)
	far_right := far.x + far.w

	assert segments.len == 1
	assert points.len == 8
	assert points[0] == f32(far_right)
	assert points[1] == f32(far.y)
	assert points[2] == f32(view_x + view_w)
	assert points[3] == f32(view_y)
	assert points[4] == points[2]
	assert points[5] == f32(view_y + view_h)
	assert points[6] == points[0]
	assert points[7] == f32(far.y + far.h)
	assert_right_segment_x_monotone(points)
}

fn test_corridor_wall_segments_continuous_run_produces_layer_segments() {
	snapshot := corridor_run_projection_snapshot(-1, 2, 0)
	segments := corridor_wall_segments(snapshot, 5, -1)
	far := layer_rect(3)

	assert segments.len == 3
	for segment in segments {
		assert segment.points.len == 8
	}
	assert segments[2].points[2] == f32(far.x)
	assert segments[2].points[3] == f32(far.y)
	assert segments[2].points[4] == f32(far.x)
	assert segments[2].points[5] == f32(far.y + far.h)
}

fn test_corridor_wall_segments_share_edges_between_depths() {
	segments := corridor_wall_segments(corridor_run_projection_snapshot(-1, 2, 0), 5, -1)

	assert segments.len == 3
	for i in 0 .. segments.len - 1 {
		nearer := segments[i]
		farther := segments[i + 1]
		assert nearer.points[2] == farther.points[0]
		assert nearer.points[3] == farther.points[1]
		assert nearer.points[4] == farther.points[6]
		assert nearer.points[5] == farther.points[7]
	}
}

fn test_corridor_wall_segments_stop_before_front_blockers_and_raccord() {
	for front_depth in [1, 2] {
		front := layer_rect(front_depth)
		left := corridor_wall_segments(front_with_corridor_runs_snapshot(front_depth, 4, -1), 5, -1)
		right := corridor_wall_segments(front_with_corridor_runs_snapshot(front_depth, -1, 4), 5, 1)

		assert left.len == front_depth
		assert right.len == front_depth
		assert_left_segment_far_edge(left[left.len - 1].points, front)
		assert_right_segment_far_edge(right[right.len - 1].points, front)
	}
	front := layer_rect(3)
	left := corridor_wall_segments(front_with_corridor_runs_snapshot(3, 4, -1), 5, -1)
	right := corridor_wall_segments(front_with_corridor_runs_snapshot(3, -1, 4), 5, 1)

	assert left.len == 3
	assert right.len == 3
	assert_left_segment_far_edge(left[left.len - 1].points, front)
	assert_right_segment_far_edge(right[right.len - 1].points, front)
}

fn test_corridor_wall_segments_reject_non_visible_adjacent_blockers() {
	discovered_only := adjacent_corridor_projection_snapshot(adjacent_blocker_tile(1, true),
		adjacent_blocker_tile(3, true))
	empty_or_hidden := adjacent_corridor_projection_snapshot(adjacent_floor_tile(1),
		adjacent_hidden_blocker_tile(3))

	assert !has_corridor_wall(discovered_only, -1)
	assert !has_corridor_wall(discovered_only, 1)
	assert !has_corridor_wall(empty_or_hidden, -1)
	assert !has_corridor_wall(empty_or_hidden, 1)
}

fn test_side_pos_at_depth_tracks_player_facing() {
	origin := dungeon_core.Pos{4, 4}
	north_left := side_pos_at_depth(origin, .north, 3, -1)
	north_right := side_pos_at_depth(origin, .north, 3, 1)
	east_right := side_pos_at_depth(origin, .east, 2, 1)

	assert north_left.x == 3
	assert north_left.y == 1
	assert north_right.x == 5
	assert north_right.y == 1
	assert east_right.x == 6
	assert east_right.y == 5
}

fn render_tile_for_fog_test(discovered bool, visible bool) dungeon_core.RenderTile {
	return dungeon_core.RenderTile{
		pos:             dungeon_core.Pos{0, 0}
		kind:            .wall
		material_id:     .wall_stone
		blocks_movement: true
		blocks_sight:    true
		discovered:      discovered
		visible:         visible
	}
}

fn has_corridor_wall(snapshot dungeon_core.RenderSnapshot, side int) bool {
	return corridor_wall_segments(snapshot, 5, side).len > 0
}

fn assert_left_segment_x_monotone(points []f32) {
	assert points.len == 8
	assert points[0] <= points[2]
	assert points[6] <= points[4]
}

fn assert_right_segment_x_monotone(points []f32) {
	assert points.len == 8
	assert points[0] <= points[2]
	assert points[6] <= points[4]
}

fn assert_left_segment_far_edge(points []f32, front ProjectionRect) {
	assert points.len == 8
	assert points[2] == f32(front.x)
	assert points[3] == f32(front.y)
	assert points[4] == f32(front.x)
	assert points[5] == f32(front.y + front.h)
}

fn assert_right_segment_far_edge(points []f32, front ProjectionRect) {
	assert points.len == 8
	front_right := f32(front.x + front.w)
	assert points[0] == front_right
	assert points[1] == f32(front.y)
	assert points[6] == front_right
	assert points[7] == f32(front.y + front.h)
}

fn wall_projection_snapshot(left dungeon_core.RenderTile, right dungeon_core.RenderTile) dungeon_core.RenderSnapshot {
	return projection_snapshot(true, left, right)
}

fn open_corridor_projection_snapshot(left dungeon_core.RenderTile, right dungeon_core.RenderTile) dungeon_core.RenderSnapshot {
	return projection_snapshot(false, left, right)
}

fn adjacent_corridor_projection_snapshot(left dungeon_core.RenderTile, right dungeon_core.RenderTile) dungeon_core.RenderSnapshot {
	mut snapshot := projection_snapshot(false, side_floor_tile(1), side_floor_tile(3))
	mut tiles := snapshot.tiles.clone()
	tiles[1 * snapshot.width + 1] = left
	tiles[3 * snapshot.width + 1] = right
	return dungeon_core.RenderSnapshot{
		width:  snapshot.width
		height: snapshot.height
		tiles:  tiles
		player: snapshot.player
		facing: snapshot.facing
	}
}

fn far_only_with_front_projection_snapshot(left dungeon_core.RenderTile, right dungeon_core.RenderTile) dungeon_core.RenderSnapshot {
	mut snapshot := projection_snapshot(true, side_floor_tile(1), side_floor_tile(3))
	mut tiles := snapshot.tiles.clone()
	tiles[1 * snapshot.width + 3] = left
	tiles[3 * snapshot.width + 3] = right
	return dungeon_core.RenderSnapshot{
		width:  snapshot.width
		height: snapshot.height
		tiles:  tiles
		player: snapshot.player
		facing: snapshot.facing
	}
}

fn far_only_open_projection_snapshot(left dungeon_core.RenderTile, right dungeon_core.RenderTile) dungeon_core.RenderSnapshot {
	mut snapshot := projection_snapshot(false, side_floor_tile(1), side_floor_tile(3))
	mut tiles := snapshot.tiles.clone()
	tiles[1 * snapshot.width + 3] = left
	tiles[3 * snapshot.width + 3] = right
	return dungeon_core.RenderSnapshot{
		width:  snapshot.width
		height: snapshot.height
		tiles:  tiles
		player: snapshot.player
		facing: snapshot.facing
	}
}

fn corridor_run_projection_snapshot(side int, end_depth int, front_depth int) dungeon_core.RenderSnapshot {
	width := 8
	height := 5
	player := dungeon_core.Pos{1, 2}
	mut tiles := []dungeon_core.RenderTile{cap: width * height}
	for y in 0 .. height {
		for x in 0 .. width {
			tiles << dungeon_core.RenderTile{
				pos:         dungeon_core.Pos{x, y}
				kind:        .floor
				material_id: .floor_flagstone
				discovered:  true
				visible:     true
			}
		}
	}
	for depth in 0 .. end_depth + 1 {
		pos := side_pos_at_depth(player, .east, depth, side)
		tiles[pos.y * width + pos.x] = visible_wall_tile_at(pos)
	}
	if front_depth > 0 {
		pos := step_from(player, .east, front_depth)
		tiles[pos.y * width + pos.x] = visible_wall_tile_at(pos)
	}
	return dungeon_core.RenderSnapshot{
		width:  width
		height: height
		tiles:  tiles
		player: player
		facing: .east
	}
}

fn front_with_corridor_runs_snapshot(front_depth int, left_end_depth int, right_end_depth int) dungeon_core.RenderSnapshot {
	width := 8
	height := 5
	player := dungeon_core.Pos{1, 2}
	mut tiles := []dungeon_core.RenderTile{cap: width * height}
	for y in 0 .. height {
		for x in 0 .. width {
			tiles << dungeon_core.RenderTile{
				pos:         dungeon_core.Pos{x, y}
				kind:        .floor
				material_id: .floor_flagstone
				discovered:  true
				visible:     true
			}
		}
	}
	if left_end_depth >= 0 {
		for depth in 0 .. left_end_depth + 1 {
			pos := side_pos_at_depth(player, .east, depth, -1)
			tiles[pos.y * width + pos.x] = visible_wall_tile_at(pos)
		}
	}
	if right_end_depth >= 0 {
		for depth in 0 .. right_end_depth + 1 {
			pos := side_pos_at_depth(player, .east, depth, 1)
			tiles[pos.y * width + pos.x] = visible_wall_tile_at(pos)
		}
	}
	if front_depth > 0 {
		pos := step_from(player, .east, front_depth)
		tiles[pos.y * width + pos.x] = visible_wall_tile_at(pos)
	}
	return dungeon_core.RenderSnapshot{
		width:  width
		height: height
		tiles:  tiles
		player: player
		facing: .east
	}
}

fn projection_snapshot(front_blocker bool, left dungeon_core.RenderTile, right dungeon_core.RenderTile) dungeon_core.RenderSnapshot {
	width := 7
	height := 5
	player := dungeon_core.Pos{1, 2}
	mut tiles := []dungeon_core.RenderTile{cap: width * height}
	for y in 0 .. height {
		for x in 0 .. width {
			tiles << dungeon_core.RenderTile{
				pos:         dungeon_core.Pos{x, y}
				kind:        .floor
				material_id: .floor_flagstone
				discovered:  true
				visible:     true
			}
		}
	}
	if front_blocker {
		tiles[2 * width + 4] = dungeon_core.RenderTile{
			pos:             dungeon_core.Pos{4, 2}
			kind:            .wall
			material_id:     .wall_stone
			blocks_movement: true
			blocks_sight:    true
			discovered:      true
			visible:         true
		}
	}
	tiles[1 * width + 4] = left
	tiles[3 * width + 4] = right
	return dungeon_core.RenderSnapshot{
		width:  width
		height: height
		tiles:  tiles
		player: player
		facing: .east
	}
}

fn visible_wall_tile_at(pos dungeon_core.Pos) dungeon_core.RenderTile {
	return dungeon_core.RenderTile{
		pos:             pos
		kind:            .wall
		material_id:     .wall_stone
		blocks_movement: true
		blocks_sight:    true
		discovered:      true
		visible:         true
	}
}

fn side_blocker_tile(y int, discovered_only bool) dungeon_core.RenderTile {
	return dungeon_core.RenderTile{
		pos:             dungeon_core.Pos{4, y}
		kind:            .wall
		material_id:     .wall_stone
		blocks_movement: true
		blocks_sight:    true
		discovered:      true
		visible:         !discovered_only
	}
}

fn hidden_wall_tile() dungeon_core.RenderTile {
	return dungeon_core.RenderTile{
		pos:             dungeon_core.Pos{4, 3}
		kind:            .wall
		material_id:     .wall_stone
		blocks_movement: true
		blocks_sight:    true
	}
}

fn side_floor_tile(y int) dungeon_core.RenderTile {
	return dungeon_core.RenderTile{
		pos:         dungeon_core.Pos{4, y}
		kind:        .floor
		material_id: .floor_flagstone
		discovered:  true
		visible:     true
	}
}

fn adjacent_blocker_tile(y int, discovered_only bool) dungeon_core.RenderTile {
	return dungeon_core.RenderTile{
		pos:             dungeon_core.Pos{1, y}
		kind:            .wall
		material_id:     .wall_stone
		blocks_movement: true
		blocks_sight:    true
		discovered:      true
		visible:         !discovered_only
	}
}

fn adjacent_hidden_blocker_tile(y int) dungeon_core.RenderTile {
	return dungeon_core.RenderTile{
		pos:             dungeon_core.Pos{1, y}
		kind:            .wall
		material_id:     .wall_stone
		blocks_movement: true
		blocks_sight:    true
	}
}

fn adjacent_floor_tile(y int) dungeon_core.RenderTile {
	return dungeon_core.RenderTile{
		pos:         dungeon_core.Pos{1, y}
		kind:        .floor
		material_id: .floor_flagstone
		discovered:  true
		visible:     true
	}
}
