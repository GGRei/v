module multiwindow

$if windows {
	#flag windows -DV_MULTIWINDOW_WIN32_RENDER_METRICS_TEST

	fn C.v_multiwindow_test_win32_configure_render_fixture(client_width int, client_height int, visible int, minimized int, dpi u32, conversion_mode int)
	fn C.v_multiwindow_test_win32_reset_render_fixture()
}

$if gg_multiwindow ? || x_multiwindow_render ? {
	$if windows && sokol_d3d11 ? {
		fn win32_logical_conversion_error_for_test(backend &Win32Backend, id WindowId) string {
			backend.logical_to_pixel_rect(id, 1, 2, 3, 4) or { return err.msg() }
			return ''
		}

		fn win32_pixel_conversion_error_for_test(backend &Win32Backend, id WindowId) string {
			backend.pixel_to_logical_rect(id, 1, 2, 3, 4) or { return err.msg() }
			return ''
		}
	}
}

fn test_win32_render_readiness_does_not_depend_on_coordinate_conversion() {
	$if gg_multiwindow ? || x_multiwindow_render ? {
		$if windows && sokol_d3d11 ? {
			id := WindowId{
				app_instance: 1
				slot:         0
				generation:   1
			}
			mut native_window_sentinel := 0
			record := &Win32WindowRecord{
				id:   id
				hwnd: voidptr(&native_window_sentinel)
			}
			backend := Win32Backend{
				windows: [record]
			}
			for conversion_mode in [1, 2] {
				C.v_multiwindow_test_win32_configure_render_fixture(640, 480, 1, 0, 192,
					conversion_mode)
				mut visible := 0
				mut minimized := 0
				mut logical_width := 0
				mut logical_height := 0
				mut framebuffer_width := 0
				mut framebuffer_height := 0
				mut dpi_scale := f32(0)
				mut conversion_available := 0
				available := C.v_multiwindow_win32_render_snapshot(record.hwnd, &visible,
					&minimized, &logical_width, &logical_height, &framebuffer_width,
					&framebuffer_height, &dpi_scale, &conversion_available) != 0
				assert available
				assert visible == 1
				assert minimized == 0
				assert logical_width == 320
				assert logical_height == 240
				assert framebuffer_width == 640
				assert framebuffer_height == 480
				assert dpi_scale == f32(2)
				assert conversion_available == if conversion_mode == 2 {
					1
				} else {
					0
				}

				observation := win32_render_observation(available, visible, minimized,
					framebuffer_width, framebuffer_height, dpi_scale, conversion_available)
				update := win32_render_update(id, u64(conversion_mode), .ready, 1, false,
					observation)
				assert update.ready_credit
				assert update.block_reason == .none
				assert update.metrics.metrics_available
				assert update.metrics.logical_width == f32(320)
				assert update.metrics.logical_height == f32(240)
				assert update.metrics.framebuffer_width == 640
				assert update.metrics.framebuffer_height == 480
				assert update.metrics.dpi_scale == f32(2)
				assert update.metrics.conversion_available == (conversion_mode == 2)

				assert win32_logical_conversion_error_for_test(&backend, id) == err_render_conversion_unavailable
				assert win32_pixel_conversion_error_for_test(&backend, id) == err_render_conversion_unavailable
			}
			C.v_multiwindow_test_win32_reset_render_fixture()
		}
	}
}
