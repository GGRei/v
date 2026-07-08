module multiwindow

$if gg_multiwindow ? || x_multiwindow_render ? {
	import sokol.gfx
}

$if linux && sokol_wayland ? {
	#flag linux -lwayland-client
	#flag linux -lwayland-egl
	#flag linux -lEGL
	#flag linux -lGL
	#flag linux -I @VEXEROOT/thirdparty/sokol
	#flag linux @VMODROOT/vlib/x/multiwindow/wayland_xdg_shell_private.c
	#include <poll.h>
	#include <string.h>
	#include <wayland-client.h>
	#insert "@VMODROOT/vlib/x/multiwindow/wayland_backend_helpers.h"
}

const wayland_poll_in = i16(0x001)
const wayland_pointer_axis_vertical_scroll = u32(0)
const wayland_pointer_axis_horizontal_scroll = u32(1)
const wayland_pointer_button_state_released = u32(0)
const wayland_pointer_button_state_pressed = u32(1)
const wayland_keyboard_key_state_released = u32(0)
const wayland_keyboard_key_state_pressed = u32(1)
const wayland_seat_capability_pointer = u32(1)
const wayland_seat_capability_keyboard = u32(2)
const wayland_btn_left = u32(0x110)
const wayland_btn_right = u32(0x111)
const wayland_btn_middle = u32(0x112)
const wayland_invalid_mouse_button = 256
const wayland_scroll_scale = 10.0
const wayland_modifier_shift = u32(1)
const wayland_modifier_ctrl = u32(2)
const wayland_modifier_alt = u32(4)
const wayland_modifier_super = u32(8)
const wayland_modifier_lmb = u32(0x100)
const wayland_modifier_rmb = u32(0x200)
const wayland_modifier_mmb = u32(0x400)
const err_wayland_egl_config_failed = 'multiwindow: wayland egl config failed'
const err_wayland_egl_context_failed = 'multiwindow: wayland egl context failed'
const err_wayland_egl_display_failed = 'multiwindow: wayland egl display failed'
const err_wayland_egl_make_current_failed = 'multiwindow: wayland egl make current failed'
const err_wayland_egl_surface_failed = 'multiwindow: wayland egl surface failed'
const err_wayland_egl_swap_buffers_failed = 'multiwindow: wayland egl swap buffers failed'
const err_wayland_surface_not_configured = 'multiwindow: wayland surface is not configured'

@[heap]
struct WaylandWindowRecord {
	id           WindowId
	surface      voidptr
	xdg_surface  voidptr
	xdg_toplevel voidptr
mut:
	width                   int
	height                  int
	min_width               int
	min_height              int
	pending_toplevel_width  int
	pending_toplevel_height int
	configured              bool
	pending_egl_resize      bool
	pending_events          []WaylandNativeQueuedEvent
	mouse_x                 f32
	mouse_y                 f32
	mouse_dx                f32
	mouse_dy                f32
	mouse_pos_valid         bool
	wl_egl_window           voidptr
	egl_surface             voidptr
}

struct WaylandNativeQueuedEvent {
	sequence u64
	event    QueuedEvent
}

struct WaylandBackend {
mut:
	display            voidptr
	registry           voidptr
	compositor         voidptr
	compositor_name    u32
	compositor_version u32
	seat               voidptr
	seat_name          u32
	pointer            voidptr
	keyboard           voidptr
	wm_base            voidptr
	wm_base_name       u32
	egl_display        voidptr
	egl_config         voidptr
	egl_context        voidptr
	started            bool
	pointer_focus      WindowId
	pointer_focused    bool
	keyboard_focus     WindowId
	keyboard_focused   bool
	pointer_buttons    u32
	modifiers          u32
	keys_down          [512]bool
	windows            []&WaylandWindowRecord
}

@[markused]
fn (mut backend WaylandBackend) registry_listener_data() voidptr {
	return unsafe { voidptr(&backend) }
}

@[markused]
fn (record &WaylandWindowRecord) listener_data() voidptr {
	return unsafe { voidptr(record) }
}

$if linux && sokol_wayland ? {
	struct C.pollfd {
	mut:
		fd      int
		events  i16
		revents i16
	}

	struct C.wl_display {}

	struct C.wl_registry {}

	struct C.wl_compositor {}

	struct C.wl_seat {}

	struct C.wl_pointer {}

	struct C.wl_keyboard {}

	struct C.wl_surface {}

	struct C.wl_output {}

	struct C.wl_array {
		size  usize
		alloc usize
		data  voidptr
	}

	struct C.xdg_wm_base {}

	struct C.xdg_surface {}

	struct C.xdg_toplevel {}

	fn C.poll(fds &C.pollfd, nfds u64, timeout int) int
	fn C.strcmp(a &char, b &char) int
	fn C.v_multiwindow_wayland_compositor_bind_version(version u32) u32
	fn C.v_multiwindow_wayland_bind_compositor(registry &C.wl_registry, name u32, version u32) voidptr
	fn C.v_multiwindow_wayland_bind_xdg_wm_base(registry &C.wl_registry, name u32) voidptr
	fn C.v_multiwindow_wayland_bind_seat(registry &C.wl_registry, name u32, version u32) voidptr
	fn C.v_multiwindow_wayland_next_event_sequence() u64
	fn C.v_multiwindow_wayland_add_registry_listener(registry &C.wl_registry, data voidptr) int
	fn C.v_multiwindow_wayland_add_xdg_wm_base_listener(wm_base &C.xdg_wm_base, data voidptr) int
	fn C.v_multiwindow_wayland_add_xdg_surface_listener(xdg_surface &C.xdg_surface, data voidptr) int
	fn C.v_multiwindow_wayland_add_xdg_toplevel_listener(toplevel &C.xdg_toplevel, data voidptr) int
	fn C.v_multiwindow_wayland_add_seat_listener(seat &C.wl_seat, data voidptr) int
	fn C.v_multiwindow_wayland_seat_get_pointer(seat &C.wl_seat) voidptr
	fn C.v_multiwindow_wayland_seat_get_keyboard(seat &C.wl_seat) voidptr
	fn C.v_multiwindow_wayland_add_pointer_listener(pointer &C.wl_pointer, data voidptr) int
	fn C.v_multiwindow_wayland_add_keyboard_listener(keyboard &C.wl_keyboard, data voidptr) int
	fn C.v_multiwindow_wayland_pointer_destroy(pointer &C.wl_pointer)
	fn C.v_multiwindow_wayland_keyboard_destroy(keyboard &C.wl_keyboard)
	fn C.v_multiwindow_wayland_seat_destroy(seat &C.wl_seat)
	fn C.wl_display_connect(name &char) &C.wl_display
	fn C.wl_display_disconnect(display &C.wl_display)
	fn C.wl_display_get_fd(display &C.wl_display) int
	fn C.wl_display_get_registry(display &C.wl_display) &C.wl_registry
	fn C.wl_display_prepare_read(display &C.wl_display) int
	fn C.wl_display_cancel_read(display &C.wl_display)
	fn C.wl_display_read_events(display &C.wl_display) int
	fn C.wl_display_dispatch_pending(display &C.wl_display) int
	fn C.wl_display_roundtrip(display &C.wl_display) int
	fn C.wl_display_flush(display &C.wl_display) int
	fn C.wl_registry_destroy(registry &C.wl_registry)
	fn C.wl_compositor_create_surface(compositor &C.wl_compositor) &C.wl_surface
	fn C.wl_compositor_destroy(compositor &C.wl_compositor)
	fn C.wl_surface_commit(surface &C.wl_surface)
	fn C.wl_surface_destroy(surface &C.wl_surface)
	fn C.v_multiwindow_wayland_xdg_wm_base_get_xdg_surface(wm_base &C.xdg_wm_base, surface &C.wl_surface) &C.xdg_surface
	fn C.v_multiwindow_wayland_xdg_wm_base_destroy(wm_base &C.xdg_wm_base)
	fn C.v_multiwindow_wayland_xdg_wm_base_pong(wm_base &C.xdg_wm_base, serial u32)
	fn C.v_multiwindow_wayland_xdg_surface_get_toplevel(xdg_surface &C.xdg_surface) &C.xdg_toplevel
	fn C.v_multiwindow_wayland_xdg_surface_ack_configure(xdg_surface &C.xdg_surface, serial u32)
	fn C.v_multiwindow_wayland_xdg_surface_destroy(xdg_surface &C.xdg_surface)
	fn C.v_multiwindow_wayland_xdg_toplevel_set_title(toplevel &C.xdg_toplevel, title &char)
	fn C.v_multiwindow_wayland_xdg_toplevel_set_app_id(toplevel &C.xdg_toplevel, app_id &char)
	fn C.v_multiwindow_wayland_xdg_toplevel_set_min_size(toplevel &C.xdg_toplevel, width i32, height i32)
	fn C.v_multiwindow_wayland_xdg_toplevel_set_max_size(toplevel &C.xdg_toplevel, width i32, height i32)
	fn C.v_multiwindow_wayland_xdg_toplevel_set_fullscreen(toplevel &C.xdg_toplevel, output &C.wl_output)
	fn C.v_multiwindow_wayland_xdg_toplevel_destroy(toplevel &C.xdg_toplevel)
	fn C.v_multiwindow_wayland_egl_get_display(display &C.wl_display) voidptr
	fn C.v_multiwindow_wayland_egl_initialize(egl_display voidptr) int
	fn C.v_multiwindow_wayland_egl_bind_opengl_api() int
	fn C.v_multiwindow_wayland_egl_choose_config(egl_display voidptr, out_config &voidptr) int
	fn C.v_multiwindow_wayland_egl_create_context(egl_display voidptr, egl_config voidptr) voidptr
	fn C.v_multiwindow_wayland_egl_create_window(surface &C.wl_surface, width int, height int) voidptr
	fn C.v_multiwindow_wayland_egl_resize_window(egl_window voidptr, width int, height int)
	fn C.v_multiwindow_wayland_egl_destroy_window(egl_window voidptr)
	fn C.v_multiwindow_wayland_egl_create_window_surface(egl_display voidptr, egl_config voidptr, egl_window voidptr) voidptr
	fn C.v_multiwindow_wayland_egl_make_current(egl_display voidptr, egl_surface voidptr, egl_context voidptr) int
	fn C.v_multiwindow_wayland_egl_clear_current(egl_display voidptr)
	fn C.v_multiwindow_wayland_egl_swap_buffers(egl_display voidptr, egl_surface voidptr) int
	fn C.v_multiwindow_wayland_egl_destroy_surface(egl_display voidptr, egl_surface voidptr)
	fn C.v_multiwindow_wayland_egl_destroy_context(egl_display voidptr, egl_context voidptr)
	fn C.v_multiwindow_wayland_egl_terminate(egl_display voidptr)

	@[export: 'v_multiwindow_wayland_registry_handle_global']
	@[markused]
	fn wayland_registry_handle_global(data voidptr, registry &C.wl_registry, name u32, iface &char, version u32) {
		if data == unsafe { nil } {
			return
		}
		mut backend := unsafe { &WaylandBackend(data) }
		if C.strcmp(iface, c'wl_compositor') == 0 {
			backend.compositor = C.v_multiwindow_wayland_bind_compositor(registry, name, version)
			backend.compositor_name = name
			backend.compositor_version = C.v_multiwindow_wayland_compositor_bind_version(version)
		} else if C.strcmp(iface, c'xdg_wm_base') == 0 {
			backend.wm_base = C.v_multiwindow_wayland_bind_xdg_wm_base(registry, name)
			backend.wm_base_name = name
		} else if C.strcmp(iface, c'wl_seat') == 0 && backend.seat == unsafe { nil } {
			backend.seat = C.v_multiwindow_wayland_bind_seat(registry, name, version)
			backend.seat_name = name
		}
	}

	@[export: 'v_multiwindow_wayland_registry_handle_global_remove']
	@[markused]
	fn wayland_registry_handle_global_remove(data voidptr, registry &C.wl_registry, name u32) {
		_ = registry
		if data == unsafe { nil } {
			return
		}
		mut backend := unsafe { &WaylandBackend(data) }
		if name == backend.seat_name {
			backend.seat_name = 0
			backend.destroy_seat_devices()
			if backend.seat != unsafe { nil } {
				C.v_multiwindow_wayland_seat_destroy(unsafe { &C.wl_seat(backend.seat) })
				backend.seat = unsafe { nil }
			}
		} else if name == backend.wm_base_name {
			backend.wm_base_name = 0
			if backend.destroy_removed_wm_base_if_unused() {
				return
			}
		} else if name == backend.compositor_name {
			backend.compositor_name = 0
			if backend.compositor != unsafe { nil } {
				if backend.compositor_version >= u32(4) {
					C.wl_compositor_destroy(unsafe { &C.wl_compositor(backend.compositor) })
				}
				backend.compositor = unsafe { nil }
				backend.compositor_version = 0
			}
		}
	}

	@[export: 'v_multiwindow_wayland_xdg_wm_base_ping']
	@[markused]
	fn wayland_xdg_wm_base_ping(data voidptr, wm_base voidptr, serial u32) {
		_ = data
		C.v_multiwindow_wayland_xdg_wm_base_pong(unsafe { &C.xdg_wm_base(wm_base) }, serial)
	}

	@[export: 'v_multiwindow_wayland_xdg_surface_configure']
	@[markused]
	fn wayland_xdg_surface_configure(data voidptr, xdg_surface voidptr, serial u32) {
		if data == unsafe { nil } {
			return
		}
		mut record := unsafe { &WaylandWindowRecord(data) }
		mut width := record.width
		mut height := record.height
		if record.pending_toplevel_width > 0 {
			width = record.pending_toplevel_width
		}
		if record.pending_toplevel_height > 0 {
			height = record.pending_toplevel_height
		}
		if width <= 0 {
			width = 1
		}
		if height <= 0 {
			height = 1
		}
		width = window_extent_for_minimum(width, record.min_width)
		height = window_extent_for_minimum(height, record.min_height)
		should_queue_resize := record.configured
			&& (record.width != width || record.height != height)
		record.width = width
		record.height = height
		record.pending_toplevel_width = 0
		record.pending_toplevel_height = 0
		record.configured = true
		if should_queue_resize {
			record.pending_egl_resize = true
			record.enqueue_resize_events(C.v_multiwindow_wayland_next_event_sequence())
		}
		C.v_multiwindow_wayland_xdg_surface_ack_configure(unsafe {
			&C.xdg_surface(xdg_surface)
		}, serial)
	}

	@[export: 'v_multiwindow_wayland_xdg_toplevel_configure']
	@[markused]
	fn wayland_xdg_toplevel_configure(data voidptr, toplevel voidptr, width int, height int, states &C.wl_array) {
		_ = toplevel
		_ = states
		if data == unsafe { nil } {
			return
		}
		mut record := unsafe { &WaylandWindowRecord(data) }
		if width > 0 {
			record.pending_toplevel_width = width
		} else {
			record.pending_toplevel_width = 0
		}
		if height > 0 {
			record.pending_toplevel_height = height
		} else {
			record.pending_toplevel_height = 0
		}
	}

	@[export: 'v_multiwindow_wayland_xdg_toplevel_close']
	@[markused]
	fn wayland_xdg_toplevel_close(data voidptr, toplevel voidptr) {
		_ = toplevel
		if data == unsafe { nil } {
			return
		}
		mut record := unsafe { &WaylandWindowRecord(data) }
		record.enqueue_native_event(C.v_multiwindow_wayland_next_event_sequence(), queued_lifecycle_event(Event{
			kind:      .window_close_requested
			window_id: record.id
		}))
	}

	@[export: 'v_multiwindow_wayland_seat_capabilities']
	@[markused]
	fn wayland_seat_capabilities(data voidptr, seat voidptr, caps u32) {
		if data == unsafe { nil } || seat == unsafe { nil } {
			return
		}
		mut backend := unsafe { &WaylandBackend(data) }
		if (caps & wayland_seat_capability_pointer) != 0 {
			if backend.pointer == unsafe { nil } {
				pointer := C.v_multiwindow_wayland_seat_get_pointer(unsafe { &C.wl_seat(seat) })
				if pointer != unsafe { nil }
					&& C.v_multiwindow_wayland_add_pointer_listener(unsafe { &C.wl_pointer(pointer) }, data) == 0 {
					backend.pointer = pointer
				} else if pointer != unsafe { nil } {
					C.v_multiwindow_wayland_pointer_destroy(unsafe { &C.wl_pointer(pointer) })
				}
			}
		} else if backend.pointer != unsafe { nil } {
			C.v_multiwindow_wayland_pointer_destroy(unsafe { &C.wl_pointer(backend.pointer) })
			backend.pointer = unsafe { nil }
			backend.pointer_focused = false
			backend.pointer_buttons = 0
		}
		if (caps & wayland_seat_capability_keyboard) != 0 {
			if backend.keyboard == unsafe { nil } {
				keyboard := C.v_multiwindow_wayland_seat_get_keyboard(unsafe { &C.wl_seat(seat) })
				if keyboard != unsafe { nil }
					&& C.v_multiwindow_wayland_add_keyboard_listener(unsafe { &C.wl_keyboard(keyboard) }, data) == 0 {
					backend.keyboard = keyboard
				} else if keyboard != unsafe { nil } {
					C.v_multiwindow_wayland_keyboard_destroy(unsafe { &C.wl_keyboard(keyboard) })
				}
			}
		} else if backend.keyboard != unsafe { nil } {
			C.v_multiwindow_wayland_keyboard_destroy(unsafe { &C.wl_keyboard(backend.keyboard) })
			backend.keyboard = unsafe { nil }
			backend.keyboard_focused = false
			backend.modifiers = 0
			backend.clear_keys_down()
		}
	}

	@[export: 'v_multiwindow_wayland_seat_name']
	@[markused]
	fn wayland_seat_name(data voidptr, seat voidptr, name &char) {
		_ = data
		_ = seat
		_ = name
	}

	@[export: 'v_multiwindow_wayland_pointer_enter']
	@[markused]
	fn wayland_pointer_enter(data voidptr, pointer voidptr, serial u32, surface voidptr, x f64, y f64) {
		_ = pointer
		_ = serial
		if data == unsafe { nil } || surface == unsafe { nil } {
			return
		}
		mut backend := unsafe { &WaylandBackend(data) }
		index := backend.window_record_index_for_surface(surface) or { return }
		mut record := backend.windows[index]
		backend.pointer_focus = record.id
		backend.pointer_focused = true
		record.update_mouse_position(f32(x), f32(y), true)
		record.enqueue_native_event(C.v_multiwindow_wayland_next_event_sequence(), queued_input_event(record.input_event(.mouse_enter,
			backend.event_modifiers())))
	}

	@[export: 'v_multiwindow_wayland_pointer_leave']
	@[markused]
	fn wayland_pointer_leave(data voidptr, pointer voidptr, serial u32, surface voidptr) {
		_ = pointer
		_ = serial
		if data == unsafe { nil } || surface == unsafe { nil } {
			return
		}
		mut backend := unsafe { &WaylandBackend(data) }
		index := backend.window_record_index_for_surface(surface) or { return }
		mut record := backend.windows[index]
		record.enqueue_native_event(C.v_multiwindow_wayland_next_event_sequence(), queued_input_event(record.input_event(.mouse_leave,
			backend.event_modifiers())))
		if backend.pointer_focused && backend.pointer_focus == record.id {
			backend.pointer_focused = false
		}
	}

	@[export: 'v_multiwindow_wayland_pointer_motion']
	@[markused]
	fn wayland_pointer_motion(data voidptr, pointer voidptr, time u32, x f64, y f64) {
		_ = pointer
		_ = time
		if data == unsafe { nil } {
			return
		}
		mut backend := unsafe { &WaylandBackend(data) }
		index := backend.pointer_focus_record_index() or { return }
		mut record := backend.windows[index]
		record.update_mouse_position(f32(x), f32(y), false)
		record.enqueue_native_event(C.v_multiwindow_wayland_next_event_sequence(), queued_input_event(record.input_event(.mouse_move,
			backend.event_modifiers())))
	}

	@[export: 'v_multiwindow_wayland_pointer_button']
	@[markused]
	fn wayland_pointer_button(data voidptr, pointer voidptr, serial u32, time u32, button u32, state u32) {
		_ = pointer
		_ = serial
		_ = time
		if data == unsafe { nil } {
			return
		}
		mouse_button := wayland_mouse_button(button)
		if mouse_button == wayland_invalid_mouse_button {
			return
		}
		mut backend := unsafe { &WaylandBackend(data) }
		index := backend.pointer_focus_record_index() or { return }
		modifier := wayland_mouse_modifier(button)
		if state == wayland_pointer_button_state_pressed {
			backend.pointer_buttons |= modifier
		} else if state == wayland_pointer_button_state_released {
			backend.pointer_buttons &= ~modifier
		} else {
			return
		}
		mut record := backend.windows[index]
		input_kind := if state == wayland_pointer_button_state_pressed {
			InputEventKind.mouse_down
		} else {
			InputEventKind.mouse_up
		}
		input := record.input_event_with_payload(input_kind, backend.event_modifiers(), 0, false,
			mouse_button, 0, 0)
		record.enqueue_native_event(C.v_multiwindow_wayland_next_event_sequence(),
			queued_input_event(input))
	}

	@[export: 'v_multiwindow_wayland_pointer_axis']
	@[markused]
	fn wayland_pointer_axis(data voidptr, pointer voidptr, time u32, axis u32, value f64) {
		_ = pointer
		_ = time
		if data == unsafe { nil } {
			return
		}
		mut backend := unsafe { &WaylandBackend(data) }
		index := backend.pointer_focus_record_index() or { return }
		mut record := backend.windows[index]
		mut scroll_x := f32(0)
		mut scroll_y := f32(0)
		if axis == wayland_pointer_axis_vertical_scroll {
			scroll_y = -f32(value) / f32(wayland_scroll_scale)
		} else if axis == wayland_pointer_axis_horizontal_scroll {
			scroll_x = f32(value) / f32(wayland_scroll_scale)
		} else {
			return
		}
		input := record.input_event_with_payload(.mouse_scroll, backend.event_modifiers(), 0,
			false, wayland_invalid_mouse_button, scroll_x, scroll_y)
		record.enqueue_native_event(C.v_multiwindow_wayland_next_event_sequence(),
			queued_input_event(input))
	}

	@[export: 'v_multiwindow_wayland_keyboard_enter']
	@[markused]
	fn wayland_keyboard_enter(data voidptr, keyboard voidptr, serial u32, surface voidptr) {
		_ = keyboard
		_ = serial
		if data == unsafe { nil } || surface == unsafe { nil } {
			return
		}
		mut backend := unsafe { &WaylandBackend(data) }
		index := backend.window_record_index_for_surface(surface) or { return }
		mut record := backend.windows[index]
		backend.keyboard_focus = record.id
		backend.keyboard_focused = true
		record.enqueue_native_event(C.v_multiwindow_wayland_next_event_sequence(), queued_input_event(record.input_event(.focused,
			backend.event_modifiers())))
	}

	@[export: 'v_multiwindow_wayland_keyboard_leave']
	@[markused]
	fn wayland_keyboard_leave(data voidptr, keyboard voidptr, serial u32, surface voidptr) {
		_ = keyboard
		_ = serial
		if data == unsafe { nil } || surface == unsafe { nil } {
			return
		}
		mut backend := unsafe { &WaylandBackend(data) }
		index := backend.window_record_index_for_surface(surface) or { return }
		mut record := backend.windows[index]
		record.enqueue_native_event(C.v_multiwindow_wayland_next_event_sequence(), queued_input_event(record.input_event(.unfocused,
			backend.event_modifiers())))
		if backend.keyboard_focused && backend.keyboard_focus == record.id {
			backend.keyboard_focused = false
		}
		backend.modifiers = 0
		backend.clear_keys_down()
	}

	@[export: 'v_multiwindow_wayland_keyboard_key']
	@[markused]
	fn wayland_keyboard_key(data voidptr, keyboard voidptr, serial u32, time u32, key u32, state u32) {
		_ = keyboard
		_ = serial
		_ = time
		if data == unsafe { nil } {
			return
		}
		mut backend := unsafe { &WaylandBackend(data) }
		key_code := wayland_key_code(key)
		if key_code == 0 {
			return
		}
		index := backend.keyboard_focus_record_index() or { return }
		key_index := if key_code >= 0 && key_code < 512 { key_code } else { 0 }
		key_repeat := state == wayland_keyboard_key_state_pressed && key_index > 0
			&& backend.keys_down[key_index]
		if state == wayland_keyboard_key_state_pressed {
			if key_index > 0 {
				backend.keys_down[key_index] = true
			}
			backend.update_modifier_for_key(key_code, true)
		} else if state == wayland_keyboard_key_state_released {
			if key_index > 0 {
				backend.keys_down[key_index] = false
			}
			backend.update_modifier_for_key(key_code, false)
		} else {
			return
		}
		mut record := backend.windows[index]
		input_kind := if state == wayland_keyboard_key_state_pressed {
			InputEventKind.key_down
		} else {
			InputEventKind.key_up
		}
		input := record.input_event_with_payload(input_kind, backend.event_modifiers(), key_code,
			key_repeat, wayland_invalid_mouse_button, 0, 0)
		record.enqueue_native_event(C.v_multiwindow_wayland_next_event_sequence(),
			queued_input_event(input))
	}

	@[export: 'v_multiwindow_wayland_keyboard_modifiers']
	@[markused]
	fn wayland_keyboard_modifiers(data voidptr, keyboard voidptr, serial u32, mods_depressed u32, mods_latched u32, mods_locked u32, group u32) {
		_ = data
		_ = keyboard
		_ = serial
		// These masks are keymap-specific without xkb; modifiers stay physical key based.
		_ = mods_depressed
		_ = mods_latched
		_ = mods_locked
		_ = group
	}
}

fn new_wayland_backend() WaylandBackend {
	return WaylandBackend{}
}

fn (backend &WaylandBackend) ensure_supported() ! {
	$if linux && sokol_wayland ? {
		return
	} $else {
		return error(err_backend_unsupported)
	}
}

fn (backend &WaylandBackend) capabilities() Capabilities {
	return Capabilities{
		backend:            .wayland
		mock:               false
		native:             true
		multi_window:       true
		owner_queue:        true
		explicit_swapchain: backend.renderer_ready()
		wayland:            true
		gl:                 backend.renderer_ready()
		input_events:       true
		mouse_events:       true
		keyboard_events:    true
		text_events:        false
		focus_events:       true
		drop_events:        false
		touch_events:       false
	}
}

fn (mut backend WaylandBackend) start(require_renderer bool) ! {
	$if linux && sokol_wayland ? {
		if backend.started {
			return
		}
		display := C.wl_display_connect(unsafe { nil })
		if display == unsafe { nil } {
			return error(err_wayland_connect_failed)
		}
		registry := C.wl_display_get_registry(display)
		if registry == unsafe { nil } {
			C.wl_display_disconnect(display)
			return error(err_wayland_registry_failed)
		}
		backend.display = unsafe { voidptr(display) }
		backend.registry = unsafe { voidptr(registry) }
		if C.v_multiwindow_wayland_add_registry_listener(registry, backend.registry_listener_data()) < 0 {
			backend.close_connection()
			return error(err_wayland_registry_failed)
		}
		if C.wl_display_roundtrip(display) < 0 {
			backend.close_connection()
			return error(err_wayland_dispatch_failed)
		}
		if backend.compositor == unsafe { nil } || backend.compositor_name == 0
			|| backend.wm_base == unsafe { nil } || backend.wm_base_name == 0 {
			backend.close_connection()
			return error(err_wayland_required_globals_missing)
		}
		wm_base := unsafe { &C.xdg_wm_base(backend.wm_base) }
		if C.v_multiwindow_wayland_add_xdg_wm_base_listener(wm_base, unsafe { nil }) < 0 {
			backend.close_connection()
			return error(err_wayland_registry_failed)
		}
		if backend.seat != unsafe { nil } {
			if C.v_multiwindow_wayland_add_seat_listener(unsafe { &C.wl_seat(backend.seat) },
				backend.registry_listener_data()) < 0 {
				backend.close_connection()
				return error(err_wayland_registry_failed)
			}
			if C.wl_display_roundtrip(display) < 0 {
				backend.close_connection()
				return error(err_wayland_dispatch_failed)
			}
		}
		if require_renderer {
			backend.init_renderer() or {
				backend.close_connection()
				return err
			}
		}
		backend.started = true
		return
	} $else {
		_ = require_renderer
		return error(err_backend_unsupported)
	}
}

fn (backend &WaylandBackend) renderer_ready() bool {
	return backend.egl_display != unsafe { nil } && backend.egl_config != unsafe { nil }
		&& backend.egl_context != unsafe { nil }
}

fn (mut backend WaylandBackend) init_renderer() ! {
	$if linux && sokol_wayland ? {
		if backend.renderer_ready() {
			return
		}
		if backend.display == unsafe { nil } {
			return error(err_wayland_connect_failed)
		}
		display := unsafe { &C.wl_display(backend.display) }
		egl_display := C.v_multiwindow_wayland_egl_get_display(display)
		if egl_display == unsafe { nil } {
			return error(err_wayland_egl_display_failed)
		}
		if C.v_multiwindow_wayland_egl_initialize(egl_display) == 0 {
			return error(err_wayland_egl_display_failed)
		}
		if C.v_multiwindow_wayland_egl_bind_opengl_api() == 0 {
			C.v_multiwindow_wayland_egl_terminate(egl_display)
			return error(err_wayland_egl_context_failed)
		}
		mut egl_config := voidptr(unsafe { nil })
		if C.v_multiwindow_wayland_egl_choose_config(egl_display, &egl_config) == 0 {
			C.v_multiwindow_wayland_egl_terminate(egl_display)
			return error(err_wayland_egl_config_failed)
		}
		egl_context := C.v_multiwindow_wayland_egl_create_context(egl_display, egl_config)
		if egl_context == unsafe { nil } {
			C.v_multiwindow_wayland_egl_terminate(egl_display)
			return error(err_wayland_egl_context_failed)
		}
		backend.egl_display = egl_display
		backend.egl_config = egl_config
		backend.egl_context = egl_context
		return
	} $else {
		return error(err_backend_unsupported)
	}
}

fn (mut backend WaylandBackend) shutdown_renderer() {
	$if linux && sokol_wayland ? {
		if backend.egl_display != unsafe { nil } {
			C.v_multiwindow_wayland_egl_clear_current(backend.egl_display)
			if backend.egl_context != unsafe { nil } {
				C.v_multiwindow_wayland_egl_destroy_context(backend.egl_display,
					backend.egl_context)
			}
			C.v_multiwindow_wayland_egl_terminate(backend.egl_display)
		}
		backend.egl_display = unsafe { nil }
		backend.egl_config = unsafe { nil }
		backend.egl_context = unsafe { nil }
	}
}

fn (mut backend WaylandBackend) create_window(id WindowId, config WindowConfig) !WindowSize {
	$if linux && sokol_wayland ? {
		if !backend.started || backend.display == unsafe { nil } {
			return error(err_wayland_connect_failed)
		}
		if backend.compositor == unsafe { nil } || backend.compositor_name == 0
			|| backend.wm_base == unsafe { nil } || backend.wm_base_name == 0 {
			return error(err_wayland_required_globals_missing)
		}
		if !config.visible {
			return error(err_capability_unsupported)
		}
		display := unsafe { &C.wl_display(backend.display) }
		compositor := unsafe { &C.wl_compositor(backend.compositor) }
		wm_base := unsafe { &C.xdg_wm_base(backend.wm_base) }
		surface := C.wl_compositor_create_surface(compositor)
		if surface == unsafe { nil } {
			return error(err_wayland_create_surface_failed)
		}
		xdg_surface := C.v_multiwindow_wayland_xdg_wm_base_get_xdg_surface(wm_base, surface)
		if xdg_surface == unsafe { nil } {
			C.wl_surface_destroy(surface)
			return error(err_wayland_create_surface_failed)
		}
		xdg_toplevel := C.v_multiwindow_wayland_xdg_surface_get_toplevel(xdg_surface)
		if xdg_toplevel == unsafe { nil } {
			C.v_multiwindow_wayland_xdg_surface_destroy(xdg_surface)
			C.wl_surface_destroy(surface)
			return error(err_wayland_create_surface_failed)
		}
		actual_size := window_size_for_config(config, config.width, config.height)
		record_min_width := if config.resizable { config.min_width } else { actual_size.width }
		record_min_height := if config.resizable { config.min_height } else { actual_size.height }
		mut record := &WaylandWindowRecord{
			id:           id
			surface:      unsafe { voidptr(surface) }
			xdg_surface:  unsafe { voidptr(xdg_surface) }
			xdg_toplevel: unsafe { voidptr(xdg_toplevel) }
			width:        actual_size.width
			height:       actual_size.height
			min_width:    record_min_width
			min_height:   record_min_height
		}
		if C.v_multiwindow_wayland_add_xdg_surface_listener(xdg_surface, record.listener_data()) < 0 {
			backend.destroy_window_record(record)
			return error(err_wayland_create_surface_failed)
		}
		if C.v_multiwindow_wayland_add_xdg_toplevel_listener(xdg_toplevel, record.listener_data()) < 0 {
			backend.destroy_window_record(record)
			return error(err_wayland_create_surface_failed)
		}
		C.v_multiwindow_wayland_xdg_toplevel_set_title(xdg_toplevel, &char(config.title.str))
		C.v_multiwindow_wayland_xdg_toplevel_set_app_id(xdg_toplevel, c'v.x.multiwindow')
		if config.min_width > 0 || config.min_height > 0 {
			C.v_multiwindow_wayland_xdg_toplevel_set_min_size(xdg_toplevel, i32(config.min_width),
				i32(config.min_height))
		}
		if !config.resizable {
			C.v_multiwindow_wayland_xdg_toplevel_set_min_size(xdg_toplevel, i32(actual_size.width),
				i32(actual_size.height))
			C.v_multiwindow_wayland_xdg_toplevel_set_max_size(xdg_toplevel, i32(actual_size.width),
				i32(actual_size.height))
		}
		if config.fullscreen {
			C.v_multiwindow_wayland_xdg_toplevel_set_fullscreen(xdg_toplevel, unsafe { nil })
		}
		backend.windows << record
		C.wl_surface_commit(surface)
		if C.wl_display_flush(display) < 0 {
			backend.remove_window_record(id)
			backend.destroy_window_record(record)
			_ = backend.destroy_removed_wm_base_if_unused()
			return error(err_wayland_flush_failed)
		}
		if C.wl_display_roundtrip(display) < 0 {
			backend.remove_window_record(id)
			backend.destroy_window_record(record)
			_ = backend.destroy_removed_wm_base_if_unused()
			return error(err_wayland_dispatch_failed)
		}
		return WindowSize{
			width:  record.width
			height: record.height
		}
	} $else {
		_ = id
		_ = config
		return error(err_backend_unsupported)
	}
}

fn (mut backend WaylandBackend) destroy_window(id WindowId) ! {
	$if linux && sokol_wayland ? {
		index := backend.window_record_index(id) or { return error(err_window_not_found) }
		mut record := backend.windows[index]
		backend.destroy_window_record(record)
		backend.windows.delete(index)
		_ = backend.destroy_removed_wm_base_if_unused()
		if backend.started && backend.display != unsafe { nil } {
			display := unsafe { &C.wl_display(backend.display) }
			if C.wl_display_flush(display) < 0 {
				return error(err_wayland_flush_failed)
			}
		}
		return
	} $else {
		_ = id
		return error(err_backend_unsupported)
	}
}

fn (mut backend WaylandBackend) set_window_title(id WindowId, title string) ! {
	$if linux && sokol_wayland ? {
		index := backend.window_record_index(id) or { return error(err_window_not_found) }
		if !backend.started || backend.display == unsafe { nil } {
			return error(err_wayland_connect_failed)
		}
		record := backend.windows[index]
		if record.xdg_toplevel == unsafe { nil } {
			return error(err_window_not_found)
		}
		C.v_multiwindow_wayland_xdg_toplevel_set_title(unsafe {
			&C.xdg_toplevel(record.xdg_toplevel)
		}, &char(title.str))
		display := unsafe { &C.wl_display(backend.display) }
		if C.wl_display_flush(display) < 0 {
			return error(err_wayland_flush_failed)
		}
		return
	} $else {
		_ = id
		_ = title
		return error(err_backend_unsupported)
	}
}

fn (mut backend WaylandBackend) resize_window(id WindowId, width int, height int) !WindowSize {
	$if linux && sokol_wayland ? {
		_ = width
		_ = height
		backend.window_record_index(id) or { return error(err_window_not_found) }
		return error(err_capability_unsupported)
	} $else {
		_ = id
		_ = width
		_ = height
		return error(err_backend_unsupported)
	}
}

fn (mut backend WaylandBackend) poll_events() ![]Event {
	queued_events := backend.poll_queued_events()!
	mut events := []Event{cap: queued_events.len}
	for event in queued_events {
		if event.kind == .lifecycle {
			events << event.lifecycle
		}
	}
	return events
}

fn (mut backend WaylandBackend) poll_queued_events() ![]QueuedEvent {
	mut native_events := []WaylandNativeQueuedEvent{}
	$if linux && sokol_wayland ? {
		if !backend.started || backend.display == unsafe { nil } {
			return []QueuedEvent{}
		}
		backend.dispatch_pending_nonblocking()!
		for _, mut record in backend.windows {
			for native_event in record.pending_events {
				native_events << native_event
			}
			record.pending_events.clear()
		}
	}
	wayland_sort_native_events(mut native_events)
	mut events := []QueuedEvent{cap: native_events.len}
	for native_event in native_events {
		events << native_event.event
	}
	return events
}

fn (mut record WaylandWindowRecord) enqueue_native_event(sequence u64, event QueuedEvent) {
	record.pending_events << WaylandNativeQueuedEvent{
		sequence: sequence
		event:    event
	}
}

fn (mut record WaylandWindowRecord) enqueue_resize_events(sequence u64) {
	record.enqueue_native_event(sequence, queued_lifecycle_event(Event{
		kind:      .window_resized
		window_id: record.id
		width:     record.width
		height:    record.height
	}))
	record.enqueue_native_event(sequence, queued_input_event(record.input_event(.resized, 0)))
}

fn (record &WaylandWindowRecord) input_event(kind InputEventKind, modifiers u32) InputEvent {
	return record.input_event_with_payload(kind, modifiers, 0, false, wayland_invalid_mouse_button,
		0, 0)
}

fn (record &WaylandWindowRecord) input_event_with_payload(kind InputEventKind, modifiers u32, key_code int, key_repeat bool, mouse_button int, scroll_x f32, scroll_y f32) InputEvent {
	return InputEvent{
		kind:               kind
		window_id:          record.id
		key_code:           key_code
		key_repeat:         key_repeat
		modifiers:          modifiers
		mouse_x:            record.mouse_x
		mouse_y:            record.mouse_y
		mouse_dx:           record.mouse_dx
		mouse_dy:           record.mouse_dy
		mouse_button:       mouse_button
		scroll_x:           scroll_x
		scroll_y:           scroll_y
		window_width:       record.width
		window_height:      record.height
		framebuffer_width:  record.width
		framebuffer_height: record.height
	}
}

fn (mut record WaylandWindowRecord) update_mouse_position(x f32, y f32, clear_delta bool) {
	if clear_delta || !record.mouse_pos_valid {
		record.mouse_dx = 0
		record.mouse_dy = 0
	} else {
		record.mouse_dx = x - record.mouse_x
		record.mouse_dy = y - record.mouse_y
	}
	record.mouse_x = x
	record.mouse_y = y
	record.mouse_pos_valid = true
}

fn wayland_sort_native_events(mut events []WaylandNativeQueuedEvent) {
	for i in 1 .. events.len {
		mut j := i
		for j > 0 && events[j - 1].sequence > events[j].sequence {
			event := events[j]
			events[j] = events[j - 1]
			events[j - 1] = event
			j--
		}
	}
}

fn (backend &WaylandBackend) window_record_index_for_surface(surface voidptr) ?int {
	for i, record in backend.windows {
		if record.surface == surface {
			return i
		}
	}
	return none
}

fn (backend &WaylandBackend) pointer_focus_record_index() ?int {
	if !backend.pointer_focused {
		return none
	}
	return backend.window_record_index(backend.pointer_focus)
}

fn (backend &WaylandBackend) keyboard_focus_record_index() ?int {
	if !backend.keyboard_focused {
		return none
	}
	return backend.window_record_index(backend.keyboard_focus)
}

fn (backend &WaylandBackend) event_modifiers() u32 {
	return backend.modifiers | backend.pointer_buttons
}

fn (mut backend WaylandBackend) update_modifier_for_key(key_code int, down bool) {
	modifier := match key_code {
		340, 344 { wayland_modifier_shift }
		341, 345 { wayland_modifier_ctrl }
		342, 346 { wayland_modifier_alt }
		343, 347 { wayland_modifier_super }
		else { u32(0) }
	}

	if modifier == 0 {
		return
	}
	if down {
		backend.modifiers |= modifier
	} else {
		backend.modifiers &= ~modifier
	}
}

fn (mut backend WaylandBackend) clear_keys_down() {
	for i in 0 .. backend.keys_down.len {
		backend.keys_down[i] = false
	}
}

fn wayland_mouse_button(button u32) int {
	return match button {
		wayland_btn_left { 0 }
		wayland_btn_right { 1 }
		wayland_btn_middle { 2 }
		else { wayland_invalid_mouse_button }
	}
}

fn wayland_mouse_modifier(button u32) u32 {
	return match button {
		wayland_btn_left { wayland_modifier_lmb }
		wayland_btn_right { wayland_modifier_rmb }
		wayland_btn_middle { wayland_modifier_mmb }
		else { u32(0) }
	}
}

fn wayland_key_code(key u32) int {
	return match key {
		2 { 49 }
		3 { 50 }
		4 { 51 }
		5 { 52 }
		6 { 53 }
		7 { 54 }
		8 { 55 }
		9 { 56 }
		10 { 57 }
		11 { 48 }
		12 { 45 }
		13 { 61 }
		14 { 259 }
		15 { 258 }
		16 { 81 }
		17 { 87 }
		18 { 69 }
		19 { 82 }
		20 { 84 }
		21 { 89 }
		22 { 85 }
		23 { 73 }
		24 { 79 }
		25 { 80 }
		26 { 91 }
		27 { 93 }
		28 { 257 }
		29 { 341 }
		30 { 65 }
		31 { 83 }
		32 { 68 }
		33 { 70 }
		34 { 71 }
		35 { 72 }
		36 { 74 }
		37 { 75 }
		38 { 76 }
		39 { 59 }
		40 { 39 }
		41 { 96 }
		42 { 340 }
		43 { 92 }
		44 { 90 }
		45 { 88 }
		46 { 67 }
		47 { 86 }
		48 { 66 }
		49 { 78 }
		50 { 77 }
		51 { 44 }
		52 { 46 }
		53 { 47 }
		54 { 344 }
		55 { 332 }
		56 { 342 }
		57 { 32 }
		58 { 280 }
		59 { 290 }
		60 { 291 }
		61 { 292 }
		62 { 293 }
		63 { 294 }
		64 { 295 }
		65 { 296 }
		66 { 297 }
		67 { 298 }
		68 { 299 }
		69 { 282 }
		70 { 281 }
		71 { 327 }
		72 { 328 }
		73 { 329 }
		74 { 333 }
		75 { 324 }
		76 { 325 }
		77 { 326 }
		78 { 334 }
		79 { 321 }
		80 { 322 }
		81 { 323 }
		82 { 320 }
		83 { 330 }
		86 { 162 }
		87 { 300 }
		88 { 301 }
		96 { 335 }
		97 { 345 }
		98 { 331 }
		99 { 283 }
		100 { 346 }
		102 { 268 }
		103 { 265 }
		104 { 266 }
		105 { 263 }
		106 { 262 }
		107 { 269 }
		108 { 264 }
		109 { 267 }
		110 { 260 }
		111 { 261 }
		119 { 284 }
		125 { 343 }
		126 { 347 }
		else { 0 }
	}
}

fn (mut backend WaylandBackend) stop() ! {
	$if linux && sokol_wayland ? {
		backend.close_connection()
		return
	} $else {
		return error(err_backend_unsupported)
	}
}

fn (mut backend WaylandBackend) dispatch_pending_nonblocking() ! {
	$if linux && sokol_wayland ? {
		if backend.display == unsafe { nil } {
			return
		}
		display := unsafe { &C.wl_display(backend.display) }
		if C.wl_display_flush(display) < 0 {
			return error(err_wayland_flush_failed)
		}
		for {
			dispatched := C.wl_display_dispatch_pending(display)
			if dispatched < 0 {
				return error(err_wayland_dispatch_failed)
			}
			if dispatched == 0 {
				break
			}
		}
		for {
			prepare_result := C.wl_display_prepare_read(display)
			if prepare_result != 0 {
				dispatched := C.wl_display_dispatch_pending(display)
				if dispatched < 0 {
					return error(err_wayland_dispatch_failed)
				}
				if dispatched == 0 {
					break
				}
				continue
			}
			fd := C.wl_display_get_fd(display)
			mut poll_fd := C.pollfd{
				fd:      fd
				events:  wayland_poll_in
				revents: i16(0)
			}
			poll_result := C.poll(&poll_fd, u64(1), 0)
			if poll_result < 0 {
				C.wl_display_cancel_read(display)
				return error(err_wayland_dispatch_failed)
			}
			if poll_result == 0 || (poll_fd.revents & wayland_poll_in) == i16(0) {
				C.wl_display_cancel_read(display)
				break
			}
			if C.wl_display_read_events(display) < 0 {
				return error(err_wayland_dispatch_failed)
			}
			for {
				dispatched := C.wl_display_dispatch_pending(display)
				if dispatched < 0 {
					return error(err_wayland_dispatch_failed)
				}
				if dispatched == 0 {
					break
				}
			}
		}
	}
}

$if gg_multiwindow ? || x_multiwindow_render ? {
	fn (mut backend WaylandBackend) render_environment(id WindowId) !gfx.Environment {
		$if linux && sokol_wayland ? {
			index := backend.window_record_index(id) or { return error(err_window_not_found) }
			backend.prepare_render_window(index)!
			return gfx.Environment{
				defaults: gfx.EnvironmentDefaults{
					color_format: .rgba8
					depth_format: .depth_stencil
					sample_count: 1
				}
			}
		} $else {
			_ = id
			return error(err_backend_unsupported)
		}
	}

	fn (mut backend WaylandBackend) begin_render(id WindowId) !RenderFrame {
		$if linux && sokol_wayland ? {
			index := backend.window_record_index(id) or { return error(err_window_not_found) }
			backend.prepare_render_window(index)!
			record := backend.windows[index]
			return RenderFrame{
				window_id: id
				swapchain: backend.swapchain_for_record(record)
			}
		} $else {
			_ = id
			return error(err_backend_unsupported)
		}
	}

	fn (mut backend WaylandBackend) end_render(frame RenderFrame) ! {
		$if linux && sokol_wayland ? {
			index := backend.window_record_index(frame.window_id) or {
				return error(err_window_not_found)
			}
			record := backend.windows[index]
			backend.make_current(record)!
			if C.v_multiwindow_wayland_egl_swap_buffers(backend.egl_display, record.egl_surface) == 0 {
				return error(err_wayland_egl_swap_buffers_failed)
			}
			if backend.display != unsafe { nil } {
				display := unsafe { &C.wl_display(backend.display) }
				if C.wl_display_flush(display) < 0 {
					return error(err_wayland_flush_failed)
				}
			}
			return
		} $else {
			_ = frame
			return error(err_backend_unsupported)
		}
	}

	fn (mut backend WaylandBackend) prepare_render_window(index int) ! {
		$if linux && sokol_wayland ? {
			if !backend.renderer_ready() {
				return error(err_renderer_unsupported)
			}
			backend.ensure_configured(index)!
			backend.apply_pending_configure(index)!
			backend.ensure_window_render_target(index)!
			record := backend.windows[index]
			backend.make_current(record)!
			return
		} $else {
			_ = index
			return error(err_backend_unsupported)
		}
	}

	fn (mut backend WaylandBackend) ensure_configured(index int) ! {
		$if linux && sokol_wayland ? {
			mut record := backend.windows[index]
			if record.configured {
				return
			}
			backend.dispatch_pending_nonblocking()!
			if record.configured {
				return
			}
			if backend.display == unsafe { nil } {
				return error(err_wayland_connect_failed)
			}
			display := unsafe { &C.wl_display(backend.display) }
			if C.wl_display_roundtrip(display) < 0 {
				return error(err_wayland_dispatch_failed)
			}
			if !record.configured {
				return error(err_wayland_surface_not_configured)
			}
			return
		} $else {
			_ = index
			return error(err_backend_unsupported)
		}
	}

	fn (mut backend WaylandBackend) apply_pending_configure(index int) ! {
		$if linux && sokol_wayland ? {
			mut record := backend.windows[index]
			if !record.pending_egl_resize {
				return
			}
			if record.wl_egl_window != unsafe { nil } {
				C.v_multiwindow_wayland_egl_resize_window(record.wl_egl_window,
					safe_wayland_extent(record.width), safe_wayland_extent(record.height))
			}
			record.pending_egl_resize = false
			return
		} $else {
			_ = index
			return error(err_backend_unsupported)
		}
	}

	fn (mut backend WaylandBackend) ensure_window_render_target(index int) ! {
		$if linux && sokol_wayland ? {
			mut record := backend.windows[index]
			if record.wl_egl_window == unsafe { nil } {
				if record.surface == unsafe { nil } {
					return error(err_window_not_found)
				}
				egl_window := C.v_multiwindow_wayland_egl_create_window(unsafe {
					&C.wl_surface(record.surface)
				}, safe_wayland_extent(record.width), safe_wayland_extent(record.height))
				if egl_window == unsafe { nil } {
					return error(err_wayland_egl_surface_failed)
				}
				record.wl_egl_window = egl_window
			}
			if record.egl_surface == unsafe { nil } {
				egl_surface := C.v_multiwindow_wayland_egl_create_window_surface(backend.egl_display,
					backend.egl_config, record.wl_egl_window)
				if egl_surface == unsafe { nil } {
					return error(err_wayland_egl_surface_failed)
				}
				record.egl_surface = egl_surface
			}
			return
		} $else {
			_ = index
			return error(err_backend_unsupported)
		}
	}

	fn (mut backend WaylandBackend) make_current(record &WaylandWindowRecord) ! {
		$if linux && sokol_wayland ? {
			if !backend.renderer_ready() || record.egl_surface == unsafe { nil } {
				return error(err_renderer_unsupported)
			}
			if C.v_multiwindow_wayland_egl_make_current(backend.egl_display, record.egl_surface,
				backend.egl_context) == 0 {
				return error(err_wayland_egl_make_current_failed)
			}
			return
		} $else {
			_ = record
			return error(err_backend_unsupported)
		}
	}

	fn (backend &WaylandBackend) swapchain_for_record(record &WaylandWindowRecord) gfx.Swapchain {
		width := safe_wayland_extent(record.width)
		height := safe_wayland_extent(record.height)
		return gfx.Swapchain{
			width:        width
			height:       height
			sample_count: 1
			color_format: .rgba8
			depth_format: .depth_stencil
			gl:           gfx.GlSwapchain{
				framebuffer: 0
			}
		}
	}
}

fn safe_wayland_extent(value int) int {
	if value > 0 {
		return value
	}
	return 1
}

fn (mut backend WaylandBackend) close_connection() {
	$if linux && sokol_wayland ? {
		for backend.windows.len > 0 {
			record := backend.windows[0]
			backend.destroy_window_record(record)
			backend.windows.delete(0)
		}
		_ = backend.destroy_removed_wm_base_if_unused()
		backend.destroy_seat_devices()
		backend.shutdown_renderer()
		if backend.wm_base != unsafe { nil } {
			C.v_multiwindow_wayland_xdg_wm_base_destroy(unsafe { &C.xdg_wm_base(backend.wm_base) })
		}
		if backend.seat != unsafe { nil } {
			C.v_multiwindow_wayland_seat_destroy(unsafe { &C.wl_seat(backend.seat) })
		}
		if backend.compositor != unsafe { nil } && backend.compositor_version >= u32(4) {
			C.wl_compositor_destroy(unsafe { &C.wl_compositor(backend.compositor) })
		}
		if backend.registry != unsafe { nil } {
			C.wl_registry_destroy(unsafe { &C.wl_registry(backend.registry) })
		}
		if backend.display != unsafe { nil } {
			display := unsafe { &C.wl_display(backend.display) }
			C.wl_display_flush(display)
			C.wl_display_disconnect(display)
		}
		backend.display = unsafe { nil }
		backend.registry = unsafe { nil }
		backend.compositor = unsafe { nil }
		backend.compositor_name = 0
		backend.compositor_version = 0
		backend.seat = unsafe { nil }
		backend.seat_name = 0
		backend.wm_base = unsafe { nil }
		backend.wm_base_name = 0
		backend.started = false
	}
}

fn (mut backend WaylandBackend) destroy_removed_wm_base_if_unused() bool {
	$if linux && sokol_wayland ? {
		if backend.wm_base_name != 0 || backend.wm_base == unsafe { nil }
			|| backend.windows.len != 0 {
			return false
		}
		C.v_multiwindow_wayland_xdg_wm_base_destroy(unsafe { &C.xdg_wm_base(backend.wm_base) })
		backend.wm_base = unsafe { nil }
		return true
	}
	return false
}

fn (mut backend WaylandBackend) destroy_seat_devices() {
	$if linux && sokol_wayland ? {
		if backend.pointer != unsafe { nil } {
			C.v_multiwindow_wayland_pointer_destroy(unsafe { &C.wl_pointer(backend.pointer) })
		}
		if backend.keyboard != unsafe { nil } {
			C.v_multiwindow_wayland_keyboard_destroy(unsafe { &C.wl_keyboard(backend.keyboard) })
		}
		backend.pointer = unsafe { nil }
		backend.keyboard = unsafe { nil }
		backend.pointer_focused = false
		backend.keyboard_focused = false
		backend.pointer_buttons = 0
		backend.modifiers = 0
		backend.clear_keys_down()
	}
}

fn (mut backend WaylandBackend) destroy_window_record(record &WaylandWindowRecord) {
	$if linux && sokol_wayland ? {
		if backend.pointer_focused && backend.pointer_focus == record.id {
			backend.pointer_focused = false
		}
		if backend.keyboard_focused && backend.keyboard_focus == record.id {
			backend.keyboard_focused = false
			backend.clear_keys_down()
		}
		if backend.egl_display != unsafe { nil } && record.egl_surface != unsafe { nil } {
			C.v_multiwindow_wayland_egl_clear_current(backend.egl_display)
			C.v_multiwindow_wayland_egl_destroy_surface(backend.egl_display, record.egl_surface)
		}
		if record.wl_egl_window != unsafe { nil } {
			C.v_multiwindow_wayland_egl_destroy_window(record.wl_egl_window)
		}
		if record.xdg_toplevel != unsafe { nil } {
			C.v_multiwindow_wayland_xdg_toplevel_destroy(unsafe {
				&C.xdg_toplevel(record.xdg_toplevel)
			})
		}
		if record.xdg_surface != unsafe { nil } {
			C.v_multiwindow_wayland_xdg_surface_destroy(unsafe { &C.xdg_surface(record.xdg_surface) })
		}
		if record.surface != unsafe { nil } {
			C.wl_surface_destroy(unsafe { &C.wl_surface(record.surface) })
		}
	}
}

fn (backend &WaylandBackend) window_record_index(id WindowId) ?int {
	for i, record in backend.windows {
		if record.id == id {
			return i
		}
	}
	return none
}

fn (mut backend WaylandBackend) remove_window_record(id WindowId) {
	if index := backend.window_record_index(id) {
		backend.windows.delete(index)
	}
}
