#ifndef V_GG_MULTIWINDOW_GL_READBACK_HELPERS_H
#define V_GG_MULTIWINDOW_GL_READBACK_HELPERS_H

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

enum {
	V_GG_MULTIWINDOW_GL_READBACK_OK = 0,
	V_GG_MULTIWINDOW_GL_READBACK_INVALID = 1,
	V_GG_MULTIWINDOW_GL_READBACK_UNSUPPORTED = 2,
	V_GG_MULTIWINDOW_GL_READBACK_FAILED = 3,
};

static inline int v_gg_multiwindow_gl_readback_window_rgba8(int framebuffer_height,
	int x, int y, int width, int height, uint8_t *pixels, size_t pixels_len) {
#if defined(SOKOL_GLCORE) || defined(SOKOL_GLES3)
	if (framebuffer_height <= 0 || x < 0 || y < 0 || width <= 0 || height <= 0 ||
		y + height > framebuffer_height || pixels == NULL ||
		pixels_len != (size_t)width * (size_t)height * 4) {
		return V_GG_MULTIWINDOW_GL_READBACK_INVALID;
	}

	GLint previous_pack_alignment = 0;
	glGetIntegerv(GL_PACK_ALIGNMENT, &previous_pack_alignment);
	glPixelStorei(GL_PACK_ALIGNMENT, 1);
	glReadPixels(x, framebuffer_height - y - height, width, height, GL_RGBA,
		GL_UNSIGNED_BYTE, pixels);
	GLenum error = glGetError();
	glPixelStorei(GL_PACK_ALIGNMENT, previous_pack_alignment);
	if (error != GL_NO_ERROR) {
		return V_GG_MULTIWINDOW_GL_READBACK_FAILED;
	}

	size_t row_bytes = (size_t)width * 4;
	uint8_t *row = (uint8_t *)malloc(row_bytes);
	if (row == NULL) {
		return V_GG_MULTIWINDOW_GL_READBACK_FAILED;
	}
	for (int top = 0, bottom = height - 1; top < bottom; top++, bottom--) {
		uint8_t *top_row = pixels + (size_t)top * row_bytes;
		uint8_t *bottom_row = pixels + (size_t)bottom * row_bytes;
		memcpy(row, top_row, row_bytes);
		memcpy(top_row, bottom_row, row_bytes);
		memcpy(bottom_row, row, row_bytes);
	}
	free(row);
	return V_GG_MULTIWINDOW_GL_READBACK_OK;
#else
	(void)framebuffer_height;
	(void)x;
	(void)y;
	(void)width;
	(void)height;
	(void)pixels;
	(void)pixels_len;
	return V_GG_MULTIWINDOW_GL_READBACK_UNSUPPORTED;
#endif
}

static inline int v_gg_multiwindow_gl_readback_image_rgba8(uint32_t image_id,
	int image_height, int x, int y, int width, int height, uint8_t *pixels,
	size_t pixels_len) {
#if defined(SOKOL_GLCORE) || defined(SOKOL_GLES3)
	if (image_id == 0 || image_height <= 0 || x < 0 || y < 0 || width <= 0 ||
		height <= 0 || pixels == NULL || pixels_len != (size_t)width * (size_t)height * 4) {
		return V_GG_MULTIWINDOW_GL_READBACK_INVALID;
	}
	sg_image image = { image_id };
	if (sg_query_image_state(image) != SG_RESOURCESTATE_VALID) {
		return V_GG_MULTIWINDOW_GL_READBACK_INVALID;
	}
	sg_gl_image_info info = sg_gl_query_image_info(image);
	if (info.active_slot < 0 || info.active_slot >= SG_NUM_INFLIGHT_FRAMES ||
		info.tex[info.active_slot] == 0 || info.tex_target != GL_TEXTURE_2D ||
		info.msaa_render_buffer != 0) {
		return V_GG_MULTIWINDOW_GL_READBACK_UNSUPPORTED;
	}

	GLint previous_framebuffer = 0;
	GLint previous_read_buffer = 0;
	GLint previous_pack_alignment = 0;
	glGetIntegerv(GL_FRAMEBUFFER_BINDING, &previous_framebuffer);
	glGetIntegerv(GL_READ_BUFFER, &previous_read_buffer);
	glGetIntegerv(GL_PACK_ALIGNMENT, &previous_pack_alignment);

	GLuint framebuffer = 0;
	glGenFramebuffers(1, &framebuffer);
	if (framebuffer == 0) {
		return V_GG_MULTIWINDOW_GL_READBACK_FAILED;
	}
	glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, info.tex_target,
		info.tex[info.active_slot], 0);
	if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
		glBindFramebuffer(GL_FRAMEBUFFER, (GLuint)previous_framebuffer);
		glDeleteFramebuffers(1, &framebuffer);
		return V_GG_MULTIWINDOW_GL_READBACK_FAILED;
	}

	glReadBuffer(GL_COLOR_ATTACHMENT0);
	glPixelStorei(GL_PACK_ALIGNMENT, 1);
	glReadPixels(x, image_height - y - height, width, height, GL_RGBA,
		GL_UNSIGNED_BYTE, pixels);
	GLenum error = glGetError();
	glPixelStorei(GL_PACK_ALIGNMENT, previous_pack_alignment);
	glBindFramebuffer(GL_FRAMEBUFFER, (GLuint)previous_framebuffer);
	glReadBuffer((GLenum)previous_read_buffer);
	glDeleteFramebuffers(1, &framebuffer);
	if (error != GL_NO_ERROR) {
		return V_GG_MULTIWINDOW_GL_READBACK_FAILED;
	}

	size_t row_bytes = (size_t)width * 4;
	uint8_t *row = (uint8_t *)malloc(row_bytes);
	if (row == NULL) {
		return V_GG_MULTIWINDOW_GL_READBACK_FAILED;
	}
	for (int top = 0, bottom = height - 1; top < bottom; top++, bottom--) {
		uint8_t *top_row = pixels + (size_t)top * row_bytes;
		uint8_t *bottom_row = pixels + (size_t)bottom * row_bytes;
		memcpy(row, top_row, row_bytes);
		memcpy(top_row, bottom_row, row_bytes);
		memcpy(bottom_row, row, row_bytes);
	}
	free(row);
	return V_GG_MULTIWINDOW_GL_READBACK_OK;
#else
	(void)image_id;
	(void)image_height;
	(void)x;
	(void)y;
	(void)width;
	(void)height;
	(void)pixels;
	(void)pixels_len;
	return V_GG_MULTIWINDOW_GL_READBACK_UNSUPPORTED;
#endif
}

#endif
