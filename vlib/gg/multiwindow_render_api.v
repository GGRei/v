module gg

import sokol.gfx

fn multiwindow_render_value_guard() {
	$if !gg_multiwindow ? {
		panic(multiwindow_render_unavailable_message())
	}
}

pub fn (mut app App) request_redraw(id WindowId) ! {
	$if gg_multiwindow ? {
		app.request_redraw_managed(id)!
	} $else {
		_ = app
		_ = id
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (app &App) window_metrics(id WindowId) !WindowMetrics {
	$if gg_multiwindow ? {
		return app.window_metrics_managed(id)
	} $else {
		_ = app
		_ = id
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (app &App) window_render_target_info(id WindowId) !WindowRenderTargetInfo {
	$if gg_multiwindow ? {
		return app.window_render_target_info_managed(id)
	} $else {
		_ = app
		_ = id
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut app App) set_window_clear_color(id WindowId, color Color) ! {
	$if gg_multiwindow ? {
		app.set_window_clear_color_managed(id, color)!
	} $else {
		_ = app
		_ = id
		_ = color
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (app &App) window_readback_capabilities(id WindowId) !WindowReadbackCapabilities {
	$if gg_multiwindow ? {
		return app.window_readback_capabilities_managed(id)
	} $else {
		_ = app
		_ = id
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut app App) request_window_capture(id WindowId, config WindowReadbackConfig) !WindowReadbackId {
	$if gg_multiwindow ? {
		return app.request_window_capture_managed(id, config)
	} $else {
		_ = app
		_ = id
		_ = config
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (context &WindowInitContext) window_id() WindowId {
	multiwindow_render_value_guard()
	$if gg_multiwindow ? { context.validate_managed_or_panic() }
	return context.info.window
}

pub fn (context &WindowInitContext) metrics() WindowMetrics {
	multiwindow_render_value_guard()
	$if gg_multiwindow ? { context.validate_managed_or_panic() }
	return context.info.metrics
}

pub fn (context &WindowInitContext) render_target_info() WindowRenderTargetInfo {
	multiwindow_render_value_guard()
	$if gg_multiwindow ? { context.validate_managed_or_panic() }
	return context.info.target
}

pub fn (mut context WindowInitContext) with_resources(f WindowResourceFn) ! {
	$if gg_multiwindow ? {
		context.with_resources_managed(.init, f)!
	} $else {
		_ = context
		_ = f
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (context &WindowContext) frame_info() WindowFrameInfo {
	multiwindow_render_value_guard()
	$if gg_multiwindow ? { context.validate_managed_or_panic() }
	return context.info
}

pub fn (context &WindowContext) logical_size() WindowLogicalSize {
	multiwindow_render_value_guard()
	$if gg_multiwindow ? { context.validate_managed_or_panic() }
	return context.info.metrics.logical_size
}

pub fn (context &WindowContext) logical_bounds() WindowLogicalRect {
	size := context.logical_size()
	return WindowLogicalRect{
		width:  size.width
		height: size.height
	}
}

pub fn (context &WindowContext) pixel_bounds() WindowPixelRect {
	multiwindow_render_value_guard()
	$if gg_multiwindow ? { context.validate_managed_or_panic() }
	return WindowPixelRect{
		width:  context.info.metrics.framebuffer_size.width
		height: context.info.metrics.framebuffer_size.height
	}
}

pub fn (context &WindowContext) logical_to_pixel_rect(rect WindowLogicalRect) WindowPixelRect {
	$if gg_multiwindow ? {
		return context.logical_to_pixel_rect_managed(rect) or { panic(err.msg()) }
	} $else {
		_ = context
		_ = rect
		panic(multiwindow_render_unavailable_message())
	}
}

pub fn (context &WindowContext) pixel_to_logical_rect(rect WindowPixelRect) WindowLogicalRect {
	$if gg_multiwindow ? {
		return context.pixel_to_logical_rect_managed(rect) or { panic(err.msg()) }
	} $else {
		_ = context
		_ = rect
		panic(multiwindow_render_unavailable_message())
	}
}

pub fn (mut context WindowContext) with_resources(f WindowResourceFn) ! {
	$if gg_multiwindow ? {
		context.with_resources_managed(f)!
	} $else {
		_ = context
		_ = f
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut context WindowContext) with_offscreen(config WindowOffscreenPassConfig, f WindowPassFn) ! {
	$if gg_multiwindow ? {
		context.with_offscreen_managed(config, f)!
	} $else {
		_ = context
		_ = config
		_ = f
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut context WindowContext) with_swapchain(action gfx.PassAction, f WindowPassFn) ! {
	$if gg_multiwindow ? {
		context.with_swapchain_managed(action, f)!
	} $else {
		_ = context
		_ = action
		_ = f
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut context WindowContext) with_offscreen_sgl(config WindowOffscreenPassConfig, f WindowSglFn) ! {
	$if gg_multiwindow ? {
		context.with_offscreen_sgl_managed(config, f)!
	} $else {
		_ = context
		_ = config
		_ = f
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut context WindowContext) with_swapchain_sgl(action gfx.PassAction, f WindowSglFn) ! {
	$if gg_multiwindow ? {
		context.with_swapchain_sgl_managed(action, f)!
	} $else {
		_ = context
		_ = action
		_ = f
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut context WindowContext) request_image_readback(id WindowImageId, config WindowReadbackConfig) !WindowReadbackId {
	$if gg_multiwindow ? {
		return context.request_image_readback_managed(id, config)
	} $else {
		_ = context
		_ = id
		_ = config
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (context &WindowCleanupContext) window_id() WindowId {
	multiwindow_render_value_guard()
	$if gg_multiwindow ? { context.validate_managed_or_panic() }
	return context.info.window
}

pub fn (context &WindowCleanupContext) metrics() WindowMetrics {
	multiwindow_render_value_guard()
	$if gg_multiwindow ? { context.validate_managed_or_panic() }
	return context.info.metrics
}

pub fn (context &WindowCleanupContext) render_target_info() WindowRenderTargetInfo {
	multiwindow_render_value_guard()
	$if gg_multiwindow ? { context.validate_managed_or_panic() }
	return context.info.target
}

pub fn (context &WindowCleanupContext) reason() WindowCleanupReason {
	multiwindow_render_value_guard()
	$if gg_multiwindow ? { context.validate_managed_or_panic() }
	return context.cleanup_reason
}

pub fn (context &WindowCleanupContext) graphics_available() bool {
	multiwindow_render_value_guard()
	$if gg_multiwindow ? { context.validate_managed_or_panic() }
	return context.has_graphics
}

pub fn (mut context WindowCleanupContext) with_resources(f WindowResourceFn) ! {
	$if gg_multiwindow ? {
		context.with_resources_managed(.cleanup, f)!
	} $else {
		_ = context
		_ = f
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut context WindowCleanupContext) with_native_window(f NativeWindowBorrowFn) ! {
	$if gg_multiwindow ? {
		context.with_native_window_managed(f)!
	} $else {
		_ = context
		_ = f
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) make_buffer(desc &gfx.BufferDesc) !WindowBufferId {
	$if gg_multiwindow ? {
		return resources.make_buffer_managed(desc)
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) make_image(desc &gfx.ImageDesc) !WindowImageId {
	$if gg_multiwindow ? {
		return resources.make_image_managed(desc)
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) make_sampler(desc &gfx.SamplerDesc) !WindowSamplerId {
	$if gg_multiwindow ? {
		return resources.make_sampler_managed(desc)
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) make_shader(desc &gfx.ShaderDesc) !WindowShaderId {
	$if gg_multiwindow ? {
		return resources.make_shader_managed(desc)
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) make_pipeline(desc &gfx.PipelineDesc, shader WindowShaderId) !WindowPipelineId {
	$if gg_multiwindow ? {
		return resources.make_pipeline_managed(desc, shader)
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) make_attachments(config WindowAttachmentsConfig) !WindowAttachmentsId {
	$if gg_multiwindow ? {
		return resources.make_attachments_managed(config)
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) make_sgl_pipeline(desc &gfx.PipelineDesc) !WindowSglPipelineId {
	$if gg_multiwindow ? {
		return resources.make_sgl_pipeline_managed(desc)
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) make_sgl_pipeline_with_shader(desc &gfx.PipelineDesc, shader WindowShaderId) !WindowSglPipelineId {
	$if gg_multiwindow ? {
		return resources.make_sgl_pipeline_with_shader_managed(desc, shader)
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) update_buffer(id WindowBufferId, data &gfx.Range) ! {
	$if gg_multiwindow ? {
		resources.update_buffer_managed(id, data)!
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) append_buffer(id WindowBufferId, data &gfx.Range) !int {
	$if gg_multiwindow ? {
		return resources.append_buffer_managed(id, data)
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) update_image(id WindowImageId, data &gfx.ImageData) ! {
	$if gg_multiwindow ? {
		resources.update_image_managed(id, data)!
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) replace_image(id WindowImageId, desc &gfx.ImageDesc) !WindowImageId {
	$if gg_multiwindow ? {
		return resources.replace_image_managed(id, desc)
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) retire_buffer(id WindowBufferId) ! {
	$if gg_multiwindow ? {
		resources.retire_managed(buffer_resource_key(id), .buffer)!
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) retire_image(id WindowImageId) ! {
	$if gg_multiwindow ? {
		resources.retire_managed(image_resource_key(id), .image)!
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) retire_sampler(id WindowSamplerId) ! {
	$if gg_multiwindow ? {
		resources.retire_managed(sampler_resource_key(id), .sampler)!
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) retire_shader(id WindowShaderId) ! {
	$if gg_multiwindow ? {
		resources.retire_managed(shader_resource_key(id), .shader)!
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) retire_pipeline(id WindowPipelineId) ! {
	$if gg_multiwindow ? {
		resources.retire_managed(pipeline_resource_key(id), .pipeline)!
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) retire_attachments(id WindowAttachmentsId) ! {
	$if gg_multiwindow ? {
		resources.retire_managed(attachments_resource_key(id), .attachments)!
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut resources WindowResourceContext) retire_sgl_pipeline(id WindowSglPipelineId) ! {
	$if gg_multiwindow ? {
		resources.retire_managed(sgl_pipeline_resource_key(id), .sgl_pipeline)!
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut pass WindowPassContext) apply_pipeline(id WindowPipelineId) ! {
	$if gg_multiwindow ? {
		pass.apply_pipeline_managed(id)!
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut pass WindowPassContext) apply_bindings(bindings WindowBindings) ! {
	$if gg_multiwindow ? {
		pass.apply_bindings_managed(bindings)!
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut pass WindowPassContext) apply_uniforms(stage gfx.ShaderStage, block int, data &gfx.Range) ! {
	$if gg_multiwindow ? {
		pass.apply_uniforms_managed(stage, block, data)!
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut pass WindowPassContext) draw(base_element int, num_elements int, num_instances int) ! {
	$if gg_multiwindow ? {
		pass.draw_managed(base_element, num_elements, num_instances)!
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut pass WindowPassContext) apply_viewport(rect WindowPixelRect) ! {
	$if gg_multiwindow ? {
		pass.apply_viewport_managed(rect)!
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}

pub fn (mut pass WindowPassContext) apply_scissor(rect WindowPixelRect) ! {
	$if gg_multiwindow ? {
		pass.apply_scissor_managed(rect)!
	} $else {
		return error(multiwindow_render_unavailable_message())
	}
}
