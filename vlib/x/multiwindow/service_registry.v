module multiwindow

enum PendingServiceKind {
	clipboard_read
	clipboard_write
	portal_parent
}

struct ServiceWindowRecord {
	id WindowId
mut:
	owner         ?WindowId
	modal         bool
	state         ServiceWindowState
	metrics       RenderMetricsSnapshot
	borrow_epochs []u64
}

struct PendingServiceRequest {
	id     ServiceRequestId
	window WindowId
	kind   PendingServiceKind
mut:
	terminal bool
}

struct PendingReadbackRequest {
	id ServiceReadbackId
mut:
	terminal bool
}

struct ServicePortalLease {
	id     ServicePortalLeaseId
	window WindowId
}

struct ServiceRegistry {
mut:
	app_instance      u64
	windows           []ServiceWindowRecord
	monitors          []ServiceMonitorInfo
	next_request      u64 = 1
	next_borrow_epoch u64 = 1
	clipboard_text    string
	pending           []PendingServiceRequest
	readbacks         []PendingReadbackRequest
	portal_leases     []ServicePortalLease
}

fn new_service_registry(app_instance u64, backend BackendKind) ServiceRegistry {
	if backend != .mock {
		return ServiceRegistry{
			app_instance: app_instance
		}
	}
	monitor_id := ServiceMonitorId{
		app_instance: app_instance
		slot:         0
		generation:   1
	}
	return ServiceRegistry{
		app_instance: app_instance
		monitors:     [
			ServiceMonitorInfo{
				id:        monitor_id
				name:      'mock-primary'
				geometry:  ServiceKnownRect{
					known: true
					value: ServiceRect{
						width:  1920
						height: 1080
					}
				}
				work_area: ServiceKnownRect{
					known: true
					value: ServiceRect{
						width:  1920
						height: 1040
					}
				}
				scale:     ServiceKnownScale{
					known: true
					value: 1.0
				}
				primary:   .on
				available: true
			},
		]
	}
}

fn (registry &ServiceRegistry) window_index(id WindowId) !int {
	if id.app_instance != registry.app_instance {
		return error(err_app_identity_mismatch)
	}
	for index, record in registry.windows {
		if record.id == id {
			return index
		}
	}
	return error(err_stale_window)
}

fn (registry &ServiceRegistry) monitor_index(id ServiceMonitorId) !int {
	if id.app_instance != registry.app_instance {
		return error(err_app_identity_mismatch)
	}
	if id.slot < 0 || id.slot >= registry.monitors.len || registry.monitors[id.slot].id != id {
		return error(err_service_request_stale)
	}
	return id.slot
}

fn (mut registry ServiceRegistry) replace_monitors(monitors []ServiceMonitorInfo) {
	registry.monitors = monitors.clone()
}

fn service_monitor_info_for_slot(info ServiceMonitorInfo, app_instance u64, slot int, generation u32, available bool, sequence u64) ServiceMonitorInfo {
	return ServiceMonitorInfo{
		id:        ServiceMonitorId{
			app_instance: app_instance
			slot:         slot
			generation:   generation
		}
		name:      info.name
		geometry:  info.geometry
		work_area: info.work_area
		scale:     info.scale
		primary:   info.primary
		available: available
		sequence:  sequence
	}
}

fn (mut registry ServiceRegistry) reconcile_monitor_snapshot(snapshot []ServiceMonitorInfo, sequence u64) []ServiceMonitorInfo {
	mut seen := []bool{len: registry.monitors.len}
	for candidate in snapshot {
		mut slot := -1
		for index, current in registry.monitors {
			if !seen[index] && current.name == candidate.name && current.available {
				slot = index
				break
			}
		}
		if slot < 0 {
			for index, current in registry.monitors {
				if !seen[index] && current.name == candidate.name && !current.available
					&& current.id.generation < u32(0xffffffff) {
					slot = index
					break
				}
			}
		}
		if slot < 0 {
			for index, current in registry.monitors {
				if !seen[index] && !current.available && current.id.generation < u32(0xffffffff) {
					slot = index
					break
				}
			}
		}
		if slot < 0 {
			slot = registry.monitors.len
			registry.monitors << service_monitor_info_for_slot(candidate, registry.app_instance,
				slot, 1, true, sequence)
			seen << true
			continue
		}
		current := registry.monitors[slot]
		generation := if current.available {
			current.id.generation
		} else {
			current.id.generation + 1
		}
		registry.monitors[slot] = service_monitor_info_for_slot(candidate, registry.app_instance,
			slot, generation, true, sequence)
		seen[slot] = true
	}
	for index, current in registry.monitors {
		if index < seen.len && !seen[index] && current.available {
			registry.monitors[index] = service_monitor_info_for_slot(current,
				registry.app_instance, index, current.id.generation, false, sequence)
		}
	}
	mut available := []ServiceMonitorInfo{}
	for monitor in registry.monitors {
		if monitor.available {
			available << monitor
		}
	}
	return available
}

fn (mut registry ServiceRegistry) register_window(id WindowId, config WindowConfig, size WindowSize, mock bool) {
	monitor_ids := if mock && registry.monitors.len > 0 {
		[registry.monitors[0].id]
	} else {
		[]ServiceMonitorId{}
	}
	registry.windows << ServiceWindowRecord{
		id:      id
		owner:   config.owner
		modal:   config.modal
		state:   ServiceWindowState{
			mapping:      if mock {
				if config.visible {
					ServiceMappingState.mapped
				} else {
					ServiceMappingState.unmapped
				}
			} else {
				ServiceMappingState.unknown
			}
			visibility:   if mock {
				if config.visible {
					ServiceVisibilityState.visible
				} else {
					ServiceVisibilityState.hidden
				}
			} else {
				ServiceVisibilityState.unknown
			}
			active:       if mock { .off } else { .unknown }
			focused:      if mock { .off } else { .unknown }
			minimized:    if mock { .off } else { .unknown }
			maximized:    if mock { .off } else { .unknown }
			fullscreen:   if mock {
				if config.fullscreen { ServiceObservedBool.on } else { ServiceObservedBool.off }
			} else {
				ServiceObservedBool.unknown
			}
			mouse_locked: if mock { .off } else { .unknown }
			position:     ServicePosition{}
			monitor_ids:  monitor_ids
		}
		metrics: if mock {
			RenderMetricsSnapshot{
				logical_width:        f32(size.width)
				logical_height:       f32(size.height)
				framebuffer_width:    size.width
				framebuffer_height:   size.height
				dpi_scale:            1.0
				metrics_available:    true
				conversion_available: true
			}
		} else {
			RenderMetricsSnapshot{}
		}
	}
}

fn (registry &ServiceRegistry) child_first_all() ![]WindowId {
	mut order := []WindowId{}
	mut visiting := map[string]bool{}
	mut visited := map[string]bool{}
	for record in registry.windows {
		if record.owner == none {
			registry.append_child_first(record.id, mut visiting, mut visited, mut order)!
		}
	}
	for record in registry.windows {
		registry.append_child_first(record.id, mut visiting, mut visited, mut order)!
	}
	return order
}

fn (mut registry ServiceRegistry) remove_window(id WindowId) ! {
	index := registry.window_index(id)!
	if registry.windows[index].borrow_epochs.len != 0 {
		return error(err_native_borrow_active)
	}
	registry.windows.delete(index)
	mut retained_leases := []ServicePortalLease{cap: registry.portal_leases.len}
	for lease in registry.portal_leases {
		if lease.window != id {
			retained_leases << lease
		}
	}
	registry.portal_leases = retained_leases
}

fn (registry &ServiceRegistry) ensure_no_active_borrows(id WindowId) ! {
	index := registry.window_index(id)!
	if registry.windows[index].borrow_epochs.len != 0 {
		return error(err_native_borrow_active)
	}
}

fn (registry &ServiceRegistry) child_first_order(root WindowId) ![]WindowId {
	registry.window_index(root)!
	mut order := []WindowId{}
	mut visiting := map[string]bool{}
	mut visited := map[string]bool{}
	registry.append_child_first(root, mut visiting, mut visited, mut order)!
	return order
}

fn (registry &ServiceRegistry) append_child_first(id WindowId, mut visiting map[string]bool, mut visited map[string]bool, mut order []WindowId) ! {
	key := id.str()
	if visiting[key] {
		return error(err_owner_relation_invalid)
	}
	if visited[key] {
		return
	}
	registry.window_index(id)!
	visiting[key] = true
	for record in registry.windows {
		if owner := record.owner {
			if owner == id {
				registry.append_child_first(record.id, mut visiting, mut visited, mut order)!
			}
		}
	}
	visiting.delete(key)
	visited[key] = true
	order << id
}

fn (registry &ServiceRegistry) validate_owner(owner ?WindowId) ! {
	if configured := owner {
		registry.window_index(configured)!
		mut current := configured
		mut seen := map[string]bool{}
		for {
			key := current.str()
			if seen[key] {
				return error(err_owner_relation_invalid)
			}
			seen[key] = true
			index := registry.window_index(current)!
			next := registry.windows[index].owner or { break }
			current = next
		}
	}
}

fn (mut registry ServiceRegistry) take_request_id() !ServiceRequestId {
	serial := registry.next_request
	if serial == 0 {
		return error(err_service_request_exhausted)
	}
	registry.next_request = if serial == u64(0xffffffffffffffff) { u64(0) } else { serial + 1 }
	return ServiceRequestId{
		app_instance: registry.app_instance
		serial:       serial
	}
}

fn (mut registry ServiceRegistry) take_readback_id(window WindowId) !ServiceReadbackId {
	request := registry.take_request_id()!
	return ServiceReadbackId{
		app_instance: request.app_instance
		serial:       request.serial
		window:       window
	}
}

fn (mut registry ServiceRegistry) take_borrow_epoch() !u64 {
	epoch := registry.next_borrow_epoch
	if epoch == 0 {
		return error(err_service_request_exhausted)
	}
	registry.next_borrow_epoch = if epoch == u64(0xffffffffffffffff) { u64(0) } else { epoch + 1 }
	return epoch
}
