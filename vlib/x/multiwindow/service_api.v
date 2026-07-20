module multiwindow

fn (app &App) ensure_mock_service_locked() ! {
	app.ensure_running_locked()!
	app.ensure_event_admission_open_locked()!
	if app.backend.kind != .mock {
		return error(err_capability_unsupported)
	}
}

fn (mut app App) enqueue_service_event_locked(event ServiceEvent) !u64 {
	token := app.reserve_event_delivery_tokens_locked(1)!
	sequenced := service_event_with_sequence(event, token)
	app.enqueue_reserved_event_locked(queued_service_event(sequenced), token)
	return token
}

fn (mut app App) enqueue_readback_event_locked(result ServiceReadbackResult) !u64 {
	token := app.reserve_event_delivery_tokens_locked(1)!
	app.enqueue_reserved_event_locked(queued_readback_event(result), token)
	return token
}

fn (mut app App) publish_mock_state_locked(index int, operation ServiceOperation) ! {
	state := app.services.windows[index].state
	token := app.reserve_event_delivery_tokens_locked(1)!
	sequenced_state := service_window_state_with_sequence(state, token)
	app.services.windows[index].state = sequenced_state
	app.enqueue_reserved_event_locked(queued_service_event(ServiceEvent{
		kind:      .state
		window:    app.services.windows[index].id
		sequence:  token
		state:     sequenced_state
		operation: operation
	}), token)
}

pub fn (app &App) service_window_state(id WindowId) !ServiceWindowState {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_running_locked()!
	index := app.services.window_index(id)!
	state := app.services.windows[index].state
	return service_window_state_with_sequence(state, state.sequence)
}

pub fn (app &App) service_monitor_ids() ![]ServiceMonitorId {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_running_locked()!
	mut ids := []ServiceMonitorId{cap: app.services.monitors.len}
	for monitor in app.services.monitors {
		if monitor.available {
			ids << monitor.id
		}
	}
	return ids
}

pub fn (app &App) service_monitor_info(id ServiceMonitorId) !ServiceMonitorInfo {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_running_locked()!
	index := app.services.monitor_index(id)!
	monitor := app.services.monitors[index]
	return ServiceMonitorInfo{
		id:        monitor.id
		name:      monitor.name
		geometry:  monitor.geometry
		work_area: monitor.work_area
		scale:     monitor.scale
		primary:   monitor.primary
		available: monitor.available
		sequence:  monitor.sequence
	}
}

pub fn (app &App) service_operation_capability(id WindowId, operation ServiceOperation) !ServiceOperationCapability {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_running_locked()!
	app.services.window_index(id)!
	return app.backend.service_operation_capability(id, operation)
}

pub fn (app &App) service_cursor_support(id WindowId, shape CursorShape) !ServiceSupportLevel {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_running_locked()!
	app.services.window_index(id)!
	return app.backend.cursor_support(shape)
}

pub fn (mut app App) service_show_window(id WindowId) ! {
	if app.service_operation_uses_mock(id, .show)! {
		app.update_mock_mapping(id, true, .show)!
		return
	}
	state := app.backend.service_show_window(id)!
	app.publish_native_state(id, .show, state)!
}

pub fn (mut app App) service_hide_window(id WindowId) ! {
	if app.service_operation_uses_mock(id, .hide)! {
		app.update_mock_mapping(id, false, .hide)!
		return
	}
	state := app.backend.service_hide_window(id)!
	app.publish_native_state(id, .hide, state)!
}

fn (mut app App) update_mock_mapping(id WindowId, visible bool, operation ServiceOperation) ! {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_mock_service_locked()!
	index := app.services.window_index(id)!
	app.services.windows[index].state = ServiceWindowState{
		...app.services.windows[index].state
		mapping:    if visible { .mapped } else { .unmapped }
		visibility: if visible { .visible } else { .hidden }
	}
	app.publish_mock_state_locked(index, operation)!
}

pub fn (mut app App) service_request_focus(id WindowId) ! {
	if !app.service_operation_uses_mock(id, .focus)! {
		state := app.backend.service_focus_window(id)!
		app.publish_native_state(id, .focus, state)!
		return
	}
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_mock_service_locked()!
	index := app.services.window_index(id)!
	for i in 0 .. app.services.windows.len {
		app.services.windows[i].state = ServiceWindowState{
			...app.services.windows[i].state
			active:  if i == index { .on } else { .off }
			focused: if i == index { .on } else { .off }
		}
	}
	app.publish_mock_state_locked(index, .focus)!
}

pub fn (mut app App) service_raise_window(id WindowId) ! {
	if app.service_operation_uses_mock(id, .raise)! {
		app.publish_mock_unchanged_state(id, .raise)!
		return
	}
	state := app.backend.service_raise_window(id)!
	app.publish_native_state(id, .raise, state)!
}

pub fn (mut app App) service_set_position(id WindowId, x int, y int) ! {
	if !app.service_operation_uses_mock(id, .position)! {
		state := app.backend.service_set_window_position(id, x, y)!
		app.publish_native_state(id, .position, state)!
		return
	}
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_mock_service_locked()!
	index := app.services.window_index(id)!
	app.services.windows[index].state = ServiceWindowState{
		...app.services.windows[index].state
		position: ServicePosition{
			known: true
			x:     x
			y:     y
		}
	}
	app.publish_mock_state_locked(index, .position)!
}

pub fn (mut app App) service_minimize_window(id WindowId) ! {
	if app.service_operation_uses_mock(id, .minimize)! {
		app.update_mock_window_mode(id, .minimize)!
		return
	}
	state := app.backend.service_minimize_window(id)!
	app.publish_native_state(id, .minimize, state)!
}

pub fn (mut app App) service_maximize_window(id WindowId) ! {
	if app.service_operation_uses_mock(id, .maximize)! {
		app.update_mock_window_mode(id, .maximize)!
		return
	}
	state := app.backend.service_maximize_window(id)!
	app.publish_native_state(id, .maximize, state)!
}

pub fn (mut app App) service_restore_window(id WindowId) ! {
	if app.service_operation_uses_mock(id, .restore)! {
		app.update_mock_window_mode(id, .restore)!
		return
	}
	state := app.backend.service_restore_window(id)!
	app.publish_native_state(id, .restore, state)!
}

pub fn (mut app App) service_set_fullscreen(id WindowId, enabled bool) ! {
	if !app.service_operation_uses_mock(id, .fullscreen)! {
		state := app.backend.service_set_fullscreen(id, enabled)!
		app.publish_native_state(id, .fullscreen, state)!
		return
	}
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_mock_service_locked()!
	index := app.services.window_index(id)!
	app.services.windows[index].state = ServiceWindowState{
		...app.services.windows[index].state
		fullscreen: if enabled { .on } else { .off }
		minimized:  .off
		maximized:  .off
	}
	app.publish_mock_state_locked(index, .fullscreen)!
}

fn (mut app App) update_mock_window_mode(id WindowId, operation ServiceOperation) ! {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_mock_service_locked()!
	index := app.services.window_index(id)!
	app.services.windows[index].state = ServiceWindowState{
		...app.services.windows[index].state
		minimized:  if operation == .minimize { .on } else { .off }
		maximized:  if operation == .maximize { .on } else { .off }
		fullscreen: .off
		visibility: .visible
		mapping:    .mapped
	}
	app.publish_mock_state_locked(index, operation)!
}

fn (mut app App) publish_mock_unchanged_state(id WindowId, operation ServiceOperation) ! {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_mock_service_locked()!
	index := app.services.window_index(id)!
	app.publish_mock_state_locked(index, operation)!
}

pub fn (mut app App) service_set_mouse_lock(id WindowId, enabled bool) ! {
	if !app.service_operation_uses_mock(id, .mouse_lock)! {
		state := app.backend.service_set_mouse_lock(id, enabled)!
		app.publish_native_state(id, .mouse_lock, state)!
		return
	}
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_mock_service_locked()!
	index := app.services.window_index(id)!
	app.services.windows[index].state = ServiceWindowState{
		...app.services.windows[index].state
		mouse_locked: if enabled { .on } else { .off }
	}
	app.publish_mock_state_locked(index, .mouse_lock)!
}

fn (mut app App) service_operation_uses_mock(id WindowId, operation ServiceOperation) !bool {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_running_locked()!
	app.ensure_event_admission_open_locked()!
	app.services.window_index(id)!
	capability := app.backend.service_operation_capability(id, operation)
	if capability.support == .unsupported {
		return error(err_capability_unsupported)
	}
	return app.backend.kind == .mock
}

fn (mut app App) publish_native_state(id WindowId, operation ServiceOperation, observed ServiceWindowState) ! {
	if app.backend.service_state_publication_is_deferred(id, operation) {
		return
	}
	if !service_window_state_has_observation(observed) {
		return
	}
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_running_locked()!
	app.ensure_event_admission_open_locked()!
	index := app.services.window_index(id)!
	app.services.windows[index].state = merge_service_window_state(app.services.windows[index].state,
		observed)
	app.publish_mock_state_locked(index, operation)!
}

fn service_window_state_has_observation(state ServiceWindowState) bool {
	return state.mapping != .unknown || state.visibility != .unknown || state.active != .unknown
		|| state.focused != .unknown || state.minimized != .unknown || state.maximized != .unknown
		|| state.fullscreen != .unknown || state.mouse_locked != .unknown || state.position.known
		|| state.monitor_ids.len != 0
}

fn merge_service_window_state(current ServiceWindowState, observed ServiceWindowState) ServiceWindowState {
	return ServiceWindowState{
		mapping:      if observed.mapping == .unknown { current.mapping } else { observed.mapping }
		visibility:   if observed.visibility == .unknown {
			current.visibility
		} else {
			observed.visibility
		}
		active:       if observed.active == .unknown { current.active } else { observed.active }
		focused:      if observed.focused == .unknown { current.focused } else { observed.focused }
		minimized:    if observed.minimized == .unknown {
			current.minimized
		} else {
			observed.minimized
		}
		maximized:    if observed.maximized == .unknown {
			current.maximized
		} else {
			observed.maximized
		}
		fullscreen:   if observed.fullscreen == .unknown {
			current.fullscreen
		} else {
			observed.fullscreen
		}
		mouse_locked: if observed.mouse_locked == .unknown {
			current.mouse_locked
		} else {
			observed.mouse_locked
		}
		position:     if observed.position.known { observed.position } else { current.position }
		monitor_ids:  if observed.monitor_ids.len != 0 {
			observed.monitor_ids.clone()
		} else {
			current.monitor_ids.clone()
		}
		sequence:     current.sequence
	}
}

fn service_window_state_observation_equal(left ServiceWindowState, right ServiceWindowState) bool {
	if left.mapping != right.mapping || left.visibility != right.visibility
		|| left.active != right.active || left.focused != right.focused
		|| left.minimized != right.minimized || left.maximized != right.maximized
		|| left.fullscreen != right.fullscreen || left.mouse_locked != right.mouse_locked
		|| left.position != right.position || left.monitor_ids.len != right.monitor_ids.len {
		return false
	}
	for index, monitor in left.monitor_ids {
		if monitor != right.monitor_ids[index] {
			return false
		}
	}
	return true
}

pub fn (mut app App) service_set_titlebar_appearance(id WindowId, appearance ServiceTitlebarAppearance) ! {
	if !app.service_operation_uses_mock(id, .titlebar_appearance)! {
		app.backend.service_set_titlebar_appearance(id, appearance)!
		return
	}
	app.publish_mock_unchanged_state(id, .titlebar_appearance)!
}

pub fn (mut app App) service_request_clipboard_text(id WindowId) !ServiceRequestId {
	if app.service_operation_uses_mock(id, .clipboard_read)! {
		return app.complete_mock_clipboard(id, false, '')!
	}
	request := app.begin_native_clipboard_request(id, .clipboard_read)!
	start := app.backend.service_request_clipboard_text(id, request) or {
		app.rollback_native_service_request(request)
		return err
	}
	if start.completed {
		app.complete_native_clipboard_request(request, id, .clipboard_read, start.text)!
	}
	return request
}

pub fn (mut app App) service_set_clipboard_text(id WindowId, text string) !ServiceRequestId {
	if app.service_operation_uses_mock(id, .clipboard_write)! {
		return app.complete_mock_clipboard(id, true, text)!
	}
	request := app.begin_native_clipboard_request(id, .clipboard_write)!
	start := app.backend.service_set_clipboard_text(id, request, text) or {
		app.rollback_native_service_request(request)
		return err
	}
	if start.completed {
		app.complete_native_clipboard_request(request, id, .clipboard_write, start.text)!
	}
	return request
}

fn (mut app App) complete_mock_clipboard(id WindowId, write bool, text string) !ServiceRequestId {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_mock_service_locked()!
	app.services.window_index(id)!
	request := app.services.take_request_id()!
	if write {
		app.services.clipboard_text = text.clone()
	}
	result := ServiceClipboardResult{
		id:     request
		window: id
		status: .ready
		text:   app.services.clipboard_text.clone()
	}
	app.services.pending << PendingServiceRequest{
		id:       request
		window:   id
		kind:     if write { .clipboard_write } else { .clipboard_read }
		terminal: true
	}
	app.enqueue_service_event_locked(ServiceEvent{
		kind:      .clipboard
		window:    id
		operation: if write { .clipboard_write } else { .clipboard_read }
		clipboard: result
	})!
	return request
}

fn (mut app App) begin_native_clipboard_request(id WindowId, kind PendingServiceKind) !ServiceRequestId {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_running_locked()!
	app.ensure_event_admission_open_locked()!
	app.services.window_index(id)!
	request := app.services.take_request_id()!
	app.services.pending << PendingServiceRequest{
		id:     request
		window: id
		kind:   kind
	}
	return request
}

fn (mut app App) rollback_native_service_request(id ServiceRequestId) {
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	for index, request in app.services.pending {
		if request.id == id && !request.terminal {
			app.services.pending.delete(index)
			return
		}
	}
}

fn (mut app App) complete_native_clipboard_request(id ServiceRequestId, window WindowId, operation ServiceOperation, text string) ! {
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_running_locked()!
	app.ensure_event_admission_open_locked()!
	for index, request in app.services.pending {
		if request.id != id || request.window != window || request.terminal {
			continue
		}
		app.services.pending[index].terminal = true
		app.enqueue_service_event_locked(ServiceEvent{
			kind:      .clipboard
			window:    window
			operation: operation
			clipboard: ServiceClipboardResult{
				id:     id
				window: window
				status: .ready
				text:   text.clone()
			}
		})!
		return
	}
	return error(err_service_request_stale)
}

pub fn (mut app App) service_request_portal_parent(id WindowId) !ServiceRequestId {
	if app.service_operation_uses_mock(id, .portal_parent)! {
		request, lease := app.begin_portal_parent_request(id)!
		app.complete_portal_parent_request(request, id, lease, 'mock:${id.str()}')!
		return request
	}
	request, lease := app.begin_portal_parent_request(id)!
	start := app.backend.service_start_portal_parent(id, request, lease) or {
		app.rollback_portal_parent_request(request, lease)
		return err
	}
	if start.completed {
		app.complete_portal_parent_request(request, id, lease, start.identifier)!
	}
	return request
}

fn (mut app App) begin_portal_parent_request(id WindowId) !(ServiceRequestId, ServicePortalLeaseId) {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_running_locked()!
	app.ensure_event_admission_open_locked()!
	app.services.window_index(id)!
	request := app.services.take_request_id()!
	lease := ServicePortalLeaseId{
		app_instance: app.instance_id
		serial:       request.serial
	}
	app.services.portal_leases << ServicePortalLease{
		id:     lease
		window: id
	}
	app.services.pending << PendingServiceRequest{
		id:     request
		window: id
		kind:   .portal_parent
	}
	return request, lease
}

fn (mut app App) complete_portal_parent_request(request ServiceRequestId, id WindowId, lease ServicePortalLeaseId, identifier string) ! {
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_running_locked()!
	app.ensure_event_admission_open_locked()!
	mut matched := false
	for index, pending in app.services.pending {
		if pending.id == request && pending.window == id && pending.kind == .portal_parent
			&& !pending.terminal {
			app.services.pending[index].terminal = true
			matched = true
			break
		}
	}
	if !matched {
		return error(err_service_request_stale)
	}
	app.enqueue_service_event_locked(ServiceEvent{
		kind:          .portal_parent
		window:        id
		operation:     .portal_parent
		portal_parent: ServicePortalParentResult{
			id:         request
			window:     id
			status:     .ready
			lease:      lease
			identifier: identifier
		}
	})!
}

fn (mut app App) rollback_portal_parent_request(request ServiceRequestId, lease ServicePortalLeaseId) {
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	for index, pending in app.services.pending {
		if pending.id == request && !pending.terminal {
			app.services.pending.delete(index)
			break
		}
	}
	for index, current in app.services.portal_leases {
		if current.id == lease {
			app.services.portal_leases.delete(index)
			return
		}
	}
}

pub fn (mut app App) service_release_portal_parent(id ServicePortalLeaseId) ! {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	app.ensure_running_locked() or {
		app.state_mutex.unlock()
		return err
	}
	if id.app_instance != app.instance_id {
		app.state_mutex.unlock()
		return error(err_app_identity_mismatch)
	}
	mut found := false
	for lease in app.services.portal_leases {
		if lease.id == id {
			found = true
			break
		}
	}
	app.state_mutex.unlock()
	if !found {
		return error(err_service_request_stale)
	}
	if app.backend.kind != .mock {
		app.backend.service_release_portal_parent(id)!
	}
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	for index, lease in app.services.portal_leases {
		if lease.id == id {
			app.services.portal_leases.delete(index)
			return
		}
	}
	return error(err_service_request_stale)
}

pub fn (mut app App) service_request_window_readback(id WindowId, width int, height int, submitted_frame u64) !ServiceReadbackId {
	return app.service_request_window_readback_region(id, 0, 0, width, height, submitted_frame)!
}

pub fn (mut app App) service_begin_window_readback(id WindowId) !ServiceReadbackId {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_running_locked()!
	app.ensure_event_admission_open_locked()!
	app.services.window_index(id)!
	readback := app.services.take_readback_id(id)!
	app.services.readbacks << PendingReadbackRequest{
		id: readback
	}
	return readback
}

fn (app &App) pending_readback_index_locked(readback ServiceReadbackId) !int {
	if readback.app_instance != app.instance_id || readback.window.app_instance != app.instance_id {
		return error(err_app_identity_mismatch)
	}
	app.services.window_index(readback.window)!
	for index, pending in app.services.readbacks {
		if pending.id == readback {
			if pending.terminal {
				return error(err_service_request_stale)
			}
			return index
		}
	}
	return error(err_service_request_stale)
}

pub fn (mut app App) service_stage_window_readback_for_gg(readback ServiceReadbackId, x int, y int, width int, height int, producing_frame u64) ! {
	app.assert_owner_thread()!
	if x < 0 || y < 0 || width <= 0 || height <= 0 || producing_frame == 0 {
		return error(err_readback_invalid)
	}
	app.state_mutex.lock()
	app.ensure_running_locked() or {
		app.state_mutex.unlock()
		return err
	}
	app.ensure_event_admission_open_locked() or {
		app.state_mutex.unlock()
		return err
	}
	app.pending_readback_index_locked(readback) or {
		app.state_mutex.unlock()
		return err
	}
	app.state_mutex.unlock()
	app.backend.service_stage_window_readback(readback, x, y, width, height, producing_frame)!
}

pub fn (mut app App) service_stage_image_readback_for_gg(readback ServiceReadbackId, image_id u32, x int, y int, width int, height int, producing_frame u64) ! {
	app.assert_owner_thread()!
	if image_id == 0 || x < 0 || y < 0 || width <= 0 || height <= 0 || producing_frame == 0 {
		return error(err_readback_invalid)
	}
	app.state_mutex.lock()
	app.ensure_running_locked() or {
		app.state_mutex.unlock()
		return err
	}
	app.ensure_event_admission_open_locked() or {
		app.state_mutex.unlock()
		return err
	}
	app.pending_readback_index_locked(readback) or {
		app.state_mutex.unlock()
		return err
	}
	app.state_mutex.unlock()
	app.backend.service_stage_image_readback(readback, image_id, x, y, width, height,
		producing_frame)!
}

pub fn (mut app App) service_arm_image_readback_pass_for_gg(id WindowId, image_id u32, pass_serial u64, producing_frame u64) ! {
	app.assert_owner_thread()!
	if image_id == 0 || pass_serial == 0 || producing_frame == 0 {
		return error(err_readback_invalid)
	}
	app.state_mutex.lock()
	app.ensure_running_locked() or {
		app.state_mutex.unlock()
		return err
	}
	app.ensure_event_admission_open_locked() or {
		app.state_mutex.unlock()
		return err
	}
	app.services.window_index(id) or {
		app.state_mutex.unlock()
		return err
	}
	app.state_mutex.unlock()
	app.backend.service_arm_image_readback_pass(id, image_id, pass_serial, producing_frame)!
}

pub fn (mut app App) service_resolve_readbacks_after_submit_for_gg(id WindowId, submitted_frame u64, submission_succeeded bool) ! {
	app.assert_owner_thread()!
	if submitted_frame == 0 {
		return error(err_readback_invalid)
	}
	app.state_mutex.lock()
	app.ensure_running_locked() or {
		app.state_mutex.unlock()
		return err
	}
	app.services.window_index(id) or {
		app.state_mutex.unlock()
		return err
	}
	app.state_mutex.unlock()
	app.backend.service_resolve_readbacks_after_submit(id, submitted_frame, submission_succeeded)!
}

pub fn (mut app App) service_abandon_window_readback_for_gg(readback ServiceReadbackId, message string) ! {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	app.ensure_running_locked() or {
		app.state_mutex.unlock()
		return err
	}
	app.pending_readback_index_locked(readback) or {
		app.state_mutex.unlock()
		return err
	}
	app.state_mutex.unlock()
	mut cancel_error := ''
	app.backend.service_cancel_readback(readback) or { cancel_error = err.msg() }
	app.service_fail_window_readback(readback, message)!
	if cancel_error != '' {
		return error(cancel_error)
	}
}

pub fn (mut app App) service_finish_window_readback(readback ServiceReadbackId, width int, height int, stride int, pixels []u8, submitted_frame u64) ! {
	if width <= 0 || height <= 0 || stride < width * 4
		|| u64(stride) * u64(height) != u64(pixels.len) {
		return error(err_readback_invalid)
	}
	app.finish_pending_window_readback(readback, ServiceReadbackResult{
		id:              readback
		window:          readback.window
		status:          .ready
		submitted_frame: submitted_frame
		width:           width
		height:          height
		stride:          stride
		pixels_rgba8:    pixels.clone()
	})!
}

pub fn (mut app App) service_fail_window_readback(readback ServiceReadbackId, message string) ! {
	app.finish_pending_window_readback(readback, ServiceReadbackResult{
		id:     readback
		window: readback.window
		status: .failed
		error:  message
	})!
}

fn (mut app App) finish_pending_window_readback(readback ServiceReadbackId, result ServiceReadbackResult) ! {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	app.ensure_running_locked()!
	app.ensure_event_admission_open_locked()!
	app.finish_pending_window_readback_locked(readback, result)!
}

fn (mut app App) finish_pending_window_readback_locked(readback ServiceReadbackId, result ServiceReadbackResult) ! {
	index := app.pending_readback_index_locked(readback)!
	app.enqueue_readback_event_locked(result)!
	app.services.readbacks[index].terminal = true
}

fn (mut app App) mark_pending_window_readback_terminal_locked(readback ServiceReadbackId) !int {
	index := app.pending_readback_index_locked(readback)!
	app.services.readbacks[index].terminal = true
	return index
}

pub fn (mut app App) service_request_window_readback_region(id WindowId, x int, y int, width int, height int, submitted_frame u64) !ServiceReadbackId {
	if x < 0 || y < 0 || width <= 0 || height <= 0 || u64(width) * u64(height) > u64(0x1fffffff) {
		return error(err_readback_invalid)
	}
	stride := width * 4
	pixels := if app.service_operation_uses_mock(id, .window_capture)! {
		[]u8{len: stride * height}
	} else {
		app.backend.service_window_readback(id, x, y, width, height)!
	}
	return app.service_complete_readback(id, width, height, stride, pixels, submitted_frame)!
}

pub fn (mut app App) service_complete_readback(id WindowId, width int, height int, stride int, pixels []u8, submitted_frame u64) !ServiceReadbackId {
	if width <= 0 || height <= 0 || stride < width * 4
		|| u64(stride) * u64(height) != u64(pixels.len) {
		return error(err_readback_invalid)
	}
	readback := app.service_begin_window_readback(id)!
	app.service_finish_window_readback(readback, width, height, stride, pixels, submitted_frame)!
	return readback
}

pub fn (mut app App) with_native_window_for_gg(id WindowId, callback NativeWindowBorrowCallback) ! {
	app.assert_owner_thread()!
	if callback == unsafe { nil } {
		return error(err_native_borrow_nil_callback)
	}
	app.state_mutex.lock()
	app.ensure_running_locked() or {
		app.state_mutex.unlock()
		return err
	}
	app.services.window_index(id) or {
		app.state_mutex.unlock()
		return err
	}
	capability := app.backend.service_operation_capability(id, .native_borrow)
	app.state_mutex.unlock()
	if capability.support == .unsupported {
		return error(err_capability_unsupported)
	}
	borrow := app.backend.service_native_window_borrow(id)!
	app.with_native_window_borrow(id, borrow.backend, borrow.primary, borrow.secondary, callback)!
}

fn (mut app App) with_native_window_borrow_for_test(id WindowId, callback NativeWindowBorrowCallback) ! {
	app.with_native_window_borrow(id, .mock, unsafe { nil }, 0, callback)!
}

fn (mut app App) with_native_window_borrow(id WindowId, backend NativeWindowBackend, primary voidptr, secondary u64, callback NativeWindowBorrowCallback) ! {
	app.assert_owner_thread()!
	if callback == unsafe { nil } {
		return error(err_native_borrow_nil_callback)
	}
	app.state_mutex.lock()
	app.ensure_running_locked() or {
		app.state_mutex.unlock()
		return err
	}
	index := app.services.window_index(id) or {
		app.state_mutex.unlock()
		return err
	}
	epoch := app.services.take_borrow_epoch() or {
		app.state_mutex.unlock()
		return err
	}
	app.services.windows[index].borrow_epochs << epoch
	app.native_borrow_depth++
	borrow := NativeWindowBorrow{
		app_instance: app.instance_id
		window:       id
		epoch:        epoch
		backend:      backend
		primary:      primary
		secondary:    secondary
	}
	app.state_mutex.unlock()

	mut callback_error := IError(none)
	callback(borrow) or { callback_error = err }

	app.state_mutex.lock()
	if current_index := app.services.window_index(id) {
		for epoch_index, active_epoch in app.services.windows[current_index].borrow_epochs {
			if active_epoch == epoch {
				app.services.windows[current_index].borrow_epochs.delete(epoch_index)
				break
			}
		}
	}
	if app.native_borrow_depth > 0 {
		app.native_borrow_depth--
	}
	flush := app.native_borrow_depth == 0
	app.state_mutex.unlock()
	if flush {
		app.flush_deferred_native_transitions()!
	}
	if callback_error !is none {
		return callback_error
	}
}

pub fn (app &App) validate_native_borrow_for_gg(id WindowId, epoch u64) !NativeWindowBackend {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	index := app.services.window_index(id)!
	record := app.services.windows[index]
	if epoch == 0 || epoch !in record.borrow_epochs {
		return error(err_native_borrow_stale)
	}
	return native_window_backend_for_kind(app.backend.kind)
}

fn native_window_backend_for_kind(kind BackendKind) NativeWindowBackend {
	return match kind {
		.x11 { .x11 }
		.wayland { .wayland }
		.appkit { .appkit }
		.win32 { .win32 }
		else { .mock }
	}
}

fn (mut app App) defer_native_destroy(id WindowId) !bool {
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	if app.native_borrow_depth == 0 {
		return false
	}
	app.services.window_index(id)!
	if id !in app.deferred_native_windows {
		app.deferred_native_windows << id
	}
	return true
}

fn (mut app App) defer_native_stop() bool {
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	if app.native_borrow_depth == 0 {
		return false
	}
	app.deferred_native_stop = true
	return true
}

fn (mut app App) flush_deferred_native_transitions() ! {
	app.state_mutex.lock()
	if app.native_borrow_depth != 0 {
		app.state_mutex.unlock()
		return
	}
	stop := app.deferred_native_stop
	windows := app.deferred_native_windows.clone()
	app.deferred_native_stop = false
	app.deferred_native_windows.clear()
	app.state_mutex.unlock()
	if stop {
		app.stop()!
		return
	}
	for id in windows {
		if app.window_exists(id) {
			app.destroy_window(id)!
		}
	}
}

struct WindowServiceCancellationPlan {
	window           WindowId
	service_indices  []int
	readback_indices []int
	service_events   []ServiceEvent
	readback_events  []ServiceReadbackResult
	first_token      u64
}

fn (mut app App) prepare_window_service_cancellation_locked(id WindowId) !WindowServiceCancellationPlan {
	plan := app.collect_window_service_cancellation_locked(id)!
	first := app.reserve_event_delivery_tokens_locked(plan.service_events.len +
		plan.readback_events.len)!
	return WindowServiceCancellationPlan{
		...plan
		first_token: first
	}
}

fn (mut app App) collect_window_service_cancellation_locked(id WindowId) !WindowServiceCancellationPlan {
	app.services.window_index(id)!
	return app.collect_present_window_service_cancellation_locked(id)
}

// The caller has already proved the service record. Keeping this collector
// infallible preserves native batch admission after earlier events mutate state.
fn (mut app App) collect_present_window_service_cancellation_locked(id WindowId) WindowServiceCancellationPlan {
	mut service_indices := []int{}
	mut service_events := []ServiceEvent{}
	for i, request in app.services.pending {
		if request.window != id || request.terminal {
			continue
		}
		service_indices << i
		if request.kind == .portal_parent {
			service_events << ServiceEvent{
				kind:          .portal_parent
				window:        id
				operation:     .portal_parent
				portal_parent: ServicePortalParentResult{
					id:     request.id
					window: id
					status: .cancelled
				}
			}
		} else {
			service_events << ServiceEvent{
				kind:      .clipboard
				window:    id
				operation: if request.kind == .clipboard_write {
					.clipboard_write
				} else {
					.clipboard_read
				}
				clipboard: ServiceClipboardResult{
					id:     request.id
					window: id
					status: .cancelled
				}
			}
		}
	}
	mut readback_indices := []int{}
	mut readback_events := []ServiceReadbackResult{}
	for i, request in app.services.readbacks {
		if request.id.window != id || request.terminal {
			continue
		}
		readback_indices << i
		readback_events << ServiceReadbackResult{
			id:     request.id
			window: id
			status: .cancelled
		}
	}
	return WindowServiceCancellationPlan{
		window:           id
		service_indices:  service_indices
		readback_indices: readback_indices
		service_events:   service_events
		readback_events:  readback_events
	}
}

fn (mut app App) commit_window_service_cancellation_locked(plan WindowServiceCancellationPlan) {
	for index in plan.service_indices {
		app.services.pending[index].terminal = true
	}
	for index in plan.readback_indices {
		app.services.readbacks[index].terminal = true
	}
	mut offset := 0
	for event in plan.service_events {
		token := plan.first_token + u64(offset)
		app.enqueue_reserved_event_locked(queued_service_event(service_event_with_sequence(event,
			token)), token)
		offset++
	}
	for event in plan.readback_events {
		token := plan.first_token + u64(offset)
		app.enqueue_reserved_event_locked(queued_readback_event(event), token)
		offset++
	}
	mut retained_leases := []ServicePortalLease{cap: app.services.portal_leases.len}
	for lease in app.services.portal_leases {
		if lease.window != plan.window {
			retained_leases << lease
		}
	}
	app.services.portal_leases = retained_leases
}

pub fn (mut app App) drain_service_events() ![]ServiceEvent {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	if app.event_dispatch_active {
		return error(err_event_dispatch_active)
	}
	mut selected := []ServiceEvent{}
	mut delivered := []QueuedEvent{}
	for event in app.events {
		if app.queued_event_blocked_by_teardown_locked(event) || event.kind != .service {
			break
		}
		selected << event.service
		delivered << event
	}
	for event in delivered {
		app.validate_queued_delivery_locked(event)!
		app.complete_queued_delivery_locked(event)
	}
	app.events = app.events[delivered.len..].clone()
	app.release_terminal_delivery_storage_locked()
	return selected
}

pub fn (mut app App) drain_readback_events() ![]ServiceReadbackResult {
	app.assert_owner_thread()!
	app.state_mutex.lock()
	defer {
		app.state_mutex.unlock()
	}
	if app.event_dispatch_active {
		return error(err_event_dispatch_active)
	}
	mut selected := []ServiceReadbackResult{}
	mut delivered := []QueuedEvent{}
	for event in app.events {
		if app.queued_event_blocked_by_teardown_locked(event) || event.kind != .readback {
			break
		}
		selected << event.readback
		delivered << event
	}
	for event in delivered {
		app.validate_queued_delivery_locked(event)!
		app.complete_queued_delivery_locked(event)
	}
	app.events = app.events[delivered.len..].clone()
	app.release_terminal_delivery_storage_locked()
	return selected
}
