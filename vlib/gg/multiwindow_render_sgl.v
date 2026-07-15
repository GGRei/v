module gg

$if gg_multiwindow ? {
	import sokol.sgl
}

fn multiwindow_sgl_api_guard() {
	$if !gg_multiwindow ? {
		panic(multiwindow_render_unavailable_message())
	}
}

pub fn (mut context WindowSglContext) defaults() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.defaults()
	}
}

pub fn (mut context WindowSglContext) viewport(x int, y int, width int, height int, origin_top_left bool) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.viewport(x, y, width, height, origin_top_left)
	}
}

pub fn (mut context WindowSglContext) scissor_rect(x int, y int, width int, height int, origin_top_left bool) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.scissor_rect(x, y, width, height, origin_top_left)
	}
}

pub fn (mut context WindowSglContext) scissor_rectf(x f32, y f32, width f32, height f32, origin_top_left bool) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.scissor_rectf(x, y, width, height, origin_top_left)
	}
}

pub fn (mut context WindowSglContext) enable_texture() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.enable_texture()
	}
}

pub fn (mut context WindowSglContext) disable_texture() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.disable_texture()
	}
}

pub fn (mut context WindowSglContext) load_default_pipeline() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.load_default_pipeline()
	}
}

pub fn (mut context WindowSglContext) default_pipeline() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.default_pipeline()
	}
}

pub fn (mut context WindowSglContext) push_pipeline() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.push_pipeline()
	}
}

pub fn (mut context WindowSglContext) pop_pipeline() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.pop_pipeline()
	}
}

pub fn (mut context WindowSglContext) matrix_mode_modelview() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.matrix_mode_modelview()
	}
}

pub fn (mut context WindowSglContext) matrix_mode_projection() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.matrix_mode_projection()
	}
}

pub fn (mut context WindowSglContext) matrix_mode_texture() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.matrix_mode_texture()
	}
}

pub fn (mut context WindowSglContext) load_identity() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.load_identity()
	}
}

pub fn (mut context WindowSglContext) load_matrix(matrix []f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.load_matrix(matrix)
	}
}

pub fn (mut context WindowSglContext) load_transpose_matrix(matrix []f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.load_transpose_matrix(matrix)
	}
}

pub fn (mut context WindowSglContext) mult_matrix(matrix []f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.mult_matrix(matrix)
	}
}

pub fn (mut context WindowSglContext) mult_transpose_matrix(matrix []f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.mult_transpose_matrix(matrix)
	}
}

pub fn (mut context WindowSglContext) rotate(angle_rad f32, x f32, y f32, z f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.rotate(angle_rad, x, y, z)
	}
}

pub fn (mut context WindowSglContext) scale(x f32, y f32, z f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.scale(x, y, z)
	}
}

pub fn (mut context WindowSglContext) translate(x f32, y f32, z f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.translate(x, y, z)
	}
}

pub fn (mut context WindowSglContext) frustum(left f32, right f32, bottom f32, top f32, near_plane f32, far_plane f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.frustum(left, right, bottom, top, near_plane, far_plane)
	}
}

pub fn (mut context WindowSglContext) ortho(left f32, right f32, bottom f32, top f32, near_plane f32, far_plane f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.ortho(left, right, bottom, top, near_plane, far_plane)
	}
}

pub fn (mut context WindowSglContext) perspective(fov_y f32, aspect f32, z_near f32, z_far f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.perspective(fov_y, aspect, z_near, z_far)
	}
}

pub fn (mut context WindowSglContext) lookat(eye_x f32, eye_y f32, eye_z f32, center_x f32, center_y f32, center_z f32, up_x f32, up_y f32, up_z f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.lookat(eye_x, eye_y, eye_z, center_x, center_y, center_z, up_x, up_y, up_z)
	}
}

pub fn (mut context WindowSglContext) push_matrix() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.push_matrix()
	}
}

pub fn (mut context WindowSglContext) pop_matrix() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.pop_matrix()
	}
}

pub fn (mut context WindowSglContext) t2f(u f32, v f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.t2f(u, v)
	}
}

pub fn (mut context WindowSglContext) c3f(red f32, green f32, blue f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.c3f(red, green, blue)
	}
}

pub fn (mut context WindowSglContext) c4f(red f32, green f32, blue f32, alpha f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.c4f(red, green, blue, alpha)
	}
}

pub fn (mut context WindowSglContext) c3b(red u8, green u8, blue u8) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.c3b(red, green, blue)
	}
}

pub fn (mut context WindowSglContext) c4b(red u8, green u8, blue u8, alpha u8) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.c4b(red, green, blue, alpha)
	}
}

pub fn (mut context WindowSglContext) c1i(rgba u32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.c1i(rgba)
	}
}

pub fn (mut context WindowSglContext) point_size(size f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.point_size(size)
	}
}

pub fn (mut context WindowSglContext) begin_points() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.begin_points()
	}
}

pub fn (mut context WindowSglContext) begin_lines() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.begin_lines()
	}
}

pub fn (mut context WindowSglContext) begin_line_strip() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.begin_line_strip()
	}
}

pub fn (mut context WindowSglContext) begin_triangles() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.begin_triangles()
	}
}

pub fn (mut context WindowSglContext) begin_triangle_strip() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.begin_triangle_strip()
	}
}

pub fn (mut context WindowSglContext) begin_quads() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.begin_quads()
	}
}

pub fn (mut context WindowSglContext) v2f(x f32, y f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v2f(x, y)
	}
}

pub fn (mut context WindowSglContext) v3f(x f32, y f32, z f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v3f(x, y, z)
	}
}

pub fn (mut context WindowSglContext) v2f_t2f(x f32, y f32, u f32, v f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v2f_t2f(x, y, u, v)
	}
}

pub fn (mut context WindowSglContext) v3f_t2f(x f32, y f32, z f32, u f32, v f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v3f_t2f(x, y, z, u, v)
	}
}

pub fn (mut context WindowSglContext) v2f_c3f(x f32, y f32, red f32, green f32, blue f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v2f_c3f(x, y, red, green, blue)
	}
}

pub fn (mut context WindowSglContext) v2f_c3b(x f32, y f32, red u8, green u8, blue u8) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v2f_c3b(x, y, red, green, blue)
	}
}

pub fn (mut context WindowSglContext) v2f_c4f(x f32, y f32, red f32, green f32, blue f32, alpha f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v2f_c4f(x, y, red, green, blue, alpha)
	}
}

pub fn (mut context WindowSglContext) v2f_c4b(x f32, y f32, red u8, green u8, blue u8, alpha u8) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v2f_c4b(x, y, red, green, blue, alpha)
	}
}

pub fn (mut context WindowSglContext) v2f_c1i(x f32, y f32, rgba u32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v2f_c1i(x, y, rgba)
	}
}

pub fn (mut context WindowSglContext) v3f_c3f(x f32, y f32, z f32, red f32, green f32, blue f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v3f_c3f(x, y, z, red, green, blue)
	}
}

pub fn (mut context WindowSglContext) v3f_c3b(x f32, y f32, z f32, red u8, green u8, blue u8) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v3f_c3b(x, y, z, red, green, blue)
	}
}

pub fn (mut context WindowSglContext) v3f_c4f(x f32, y f32, z f32, red f32, green f32, blue f32, alpha f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v3f_c4f(x, y, z, red, green, blue, alpha)
	}
}

pub fn (mut context WindowSglContext) v3f_c4b(x f32, y f32, z f32, red u8, green u8, blue u8, alpha u8) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v3f_c4b(x, y, z, red, green, blue, alpha)
	}
}

pub fn (mut context WindowSglContext) v3f_c1i(x f32, y f32, z f32, rgba u32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v3f_c1i(x, y, z, rgba)
	}
}

pub fn (mut context WindowSglContext) v2f_t2f_c3f(x f32, y f32, u f32, v f32, red f32, green f32, blue f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v2f_t2f_c3f(x, y, u, v, red, green, blue)
	}
}

pub fn (mut context WindowSglContext) v2f_t2f_c3b(x f32, y f32, u f32, v f32, red u8, green u8, blue u8) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v2f_t2f_c3b(x, y, u, v, red, green, blue)
	}
}

pub fn (mut context WindowSglContext) v2f_t2f_c4f(x f32, y f32, u f32, v f32, red f32, green f32, blue f32, alpha f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v2f_t2f_c4f(x, y, u, v, red, green, blue, alpha)
	}
}

pub fn (mut context WindowSglContext) v2f_t2f_c4b(x f32, y f32, u f32, v f32, red u8, green u8, blue u8, alpha u8) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v2f_t2f_c4b(x, y, u, v, red, green, blue, alpha)
	}
}

pub fn (mut context WindowSglContext) v2f_t2f_c1i(x f32, y f32, u f32, v f32, rgba u32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v2f_t2f_c1i(x, y, u, v, rgba)
	}
}

pub fn (mut context WindowSglContext) v3f_t2f_c3f(x f32, y f32, z f32, u f32, v f32, red f32, green f32, blue f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v3f_t2f_c3f(x, y, z, u, v, red, green, blue)
	}
}

pub fn (mut context WindowSglContext) v3f_t2f_c3b(x f32, y f32, z f32, u f32, v f32, red u8, green u8, blue u8) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v3f_t2f_c3b(x, y, z, u, v, red, green, blue)
	}
}

pub fn (mut context WindowSglContext) v3f_t2f_c4f(x f32, y f32, z f32, u f32, v f32, red f32, green f32, blue f32, alpha f32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v3f_t2f_c4f(x, y, z, u, v, red, green, blue, alpha)
	}
}

pub fn (mut context WindowSglContext) v3f_t2f_c4b(x f32, y f32, z f32, u f32, v f32, red u8, green u8, blue u8, alpha u8) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v3f_t2f_c4b(x, y, z, u, v, red, green, blue, alpha)
	}
}

pub fn (mut context WindowSglContext) v3f_t2f_c1i(x f32, y f32, z f32, u f32, v f32, rgba u32) {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.v3f_t2f_c1i(x, y, z, u, v, rgba)
	}
}

pub fn (mut context WindowSglContext) end() {
	multiwindow_sgl_api_guard()
	$if gg_multiwindow ? {
		context.activate_sgl_managed_or_panic()
		sgl.end()
	}
}

pub fn (mut context WindowSglContext) texture(image WindowImageId, sampler WindowSamplerId) ! {
	$if gg_multiwindow ? {
		context.texture_managed(image, sampler)!
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut context WindowSglContext) load_pipeline(id WindowSglPipelineId) ! {
	$if gg_multiwindow ? {
		context.load_pipeline_managed(id)!
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}
