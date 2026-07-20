module multiwindow

pub enum ServiceSupportLevel {
	unsupported
	available
	conditional
}

pub enum ServiceObservedBool {
	unknown
	off
	on
}

pub enum ServiceMappingState {
	unknown
	unmapped
	mapped
}

pub enum ServiceVisibilityState {
	unknown
	hidden
	visible
	occluded
}

pub enum ServiceOperation {
	show
	hide
	focus
	raise
	position
	minimize
	maximize
	restore
	fullscreen
	clipboard_read
	clipboard_write
	portal_parent
	native_borrow
	mouse_lock
	titlebar_appearance
	image_readback
	window_capture
}

pub enum ServiceEventKind {
	state
	metrics
	capability
	monitor
	clipboard
	portal_parent
}

pub enum ServiceStatus {
	ready
	cancelled
	failed
}

pub enum ServiceTitlebarAppearance {
	system
	light
	dark
}

pub struct ServiceOperationCapability {
pub:
	support              ServiceSupportLevel
	asynchronous         bool
	requires_user_action bool
	state_observable     bool
}

pub struct ServiceMonitorId {
	app_instance u64
	slot         int
	generation   u32
}

pub fn (id ServiceMonitorId) str() string {
	return 'ServiceMonitorId(${id.app_instance}:${id.slot}:${id.generation})'
}

pub fn (id ServiceMonitorId) app_instance_for_gg() u64 {
	return id.app_instance
}

pub fn (id ServiceMonitorId) slot_for_gg() int {
	return id.slot
}

pub fn (id ServiceMonitorId) generation_for_gg() u32 {
	return id.generation
}

pub fn service_monitor_id_from_gg(app_instance u64, slot int, generation u32) ServiceMonitorId {
	return ServiceMonitorId{
		app_instance: app_instance
		slot:         slot
		generation:   generation
	}
}

pub struct ServicePosition {
pub:
	known bool
	x     int
	y     int
}

pub struct ServiceRect {
pub:
	x      int
	y      int
	width  int
	height int
}

pub struct ServiceKnownRect {
pub:
	known bool
	value ServiceRect
}

pub struct ServiceKnownScale {
pub:
	known bool
	value f32
}

pub struct ServiceMonitorInfo {
pub:
	id        ServiceMonitorId
	name      string
	geometry  ServiceKnownRect
	work_area ServiceKnownRect
	scale     ServiceKnownScale
	primary   ServiceObservedBool
	available bool
	sequence  u64
}

pub struct ServiceWindowState {
pub:
	mapping      ServiceMappingState
	visibility   ServiceVisibilityState
	active       ServiceObservedBool
	focused      ServiceObservedBool
	minimized    ServiceObservedBool
	maximized    ServiceObservedBool
	fullscreen   ServiceObservedBool
	mouse_locked ServiceObservedBool
	position     ServicePosition
	monitor_ids  []ServiceMonitorId
	sequence     u64
}

pub struct ServiceRequestId {
	app_instance u64
	serial       u64
}

pub fn (id ServiceRequestId) str() string {
	return 'ServiceRequestId(${id.app_instance}:${id.serial})'
}

pub fn (id ServiceRequestId) app_instance_for_gg() u64 {
	return id.app_instance
}

pub fn (id ServiceRequestId) serial_for_gg() u64 {
	return id.serial
}

pub struct ServicePortalLeaseId {
	app_instance u64
	serial       u64
}

pub fn (id ServicePortalLeaseId) app_instance_for_gg() u64 {
	return id.app_instance
}

pub fn (id ServicePortalLeaseId) serial_for_gg() u64 {
	return id.serial
}

pub fn service_portal_lease_id_from_gg(app_instance u64, serial u64) ServicePortalLeaseId {
	return ServicePortalLeaseId{
		app_instance: app_instance
		serial:       serial
	}
}

pub struct ServiceClipboardResult {
pub:
	id     ServiceRequestId
	window WindowId
	status ServiceStatus
	text   string
	error  string
}

pub struct ServicePortalParentResult {
pub:
	id         ServiceRequestId
	window     WindowId
	status     ServiceStatus
	lease      ServicePortalLeaseId
	identifier string
	error      string
}

pub struct ServiceEvent {
pub:
	kind          ServiceEventKind
	window        WindowId
	sequence      u64
	state         ServiceWindowState
	metrics       RenderMetricsSnapshot
	operation     ServiceOperation
	capability    ServiceOperationCapability
	monitor       ServiceMonitorInfo
	monitors      []ServiceMonitorInfo
	clipboard     ServiceClipboardResult
	portal_parent ServicePortalParentResult
}

pub enum ServiceReadbackStatus {
	ready
	cancelled
	failed
}

pub struct ServiceReadbackId {
	app_instance u64
	serial       u64
	window       WindowId
}

pub fn (id ServiceReadbackId) app_instance_for_gg() u64 {
	return id.app_instance
}

pub fn (id ServiceReadbackId) serial_for_gg() u64 {
	return id.serial
}

pub fn (id ServiceReadbackId) window_for_gg() WindowId {
	return id.window
}

pub struct ServiceReadbackResult {
pub:
	id              ServiceReadbackId
	window          WindowId
	status          ServiceReadbackStatus
	submitted_frame u64
	width           int
	height          int
	stride          int
	pixels_rgba8    []u8
	error           string
}

pub enum NativeWindowBackend {
	mock
	x11
	wayland
	appkit
	win32
}

// NativeWindowBorrow is valid only while the callback passed to
// App.with_native_window_for_gg is executing.
pub struct NativeWindowBorrow {
	app_instance u64
	window       WindowId
	epoch        u64
	backend      NativeWindowBackend
	primary      voidptr
	secondary    u64
}

pub fn (borrow NativeWindowBorrow) app_instance_for_gg() u64 {
	return borrow.app_instance
}

pub fn (borrow NativeWindowBorrow) window_for_gg() WindowId {
	return borrow.window
}

pub fn (borrow NativeWindowBorrow) epoch_for_gg() u64 {
	return borrow.epoch
}

pub fn (borrow NativeWindowBorrow) backend_for_gg() NativeWindowBackend {
	return borrow.backend
}

pub fn (borrow NativeWindowBorrow) primary_for_gg() voidptr {
	return borrow.primary
}

pub fn (borrow NativeWindowBorrow) secondary_for_gg() u64 {
	return borrow.secondary
}

pub type NativeWindowBorrowCallback = fn (NativeWindowBorrow) !

fn service_window_state_with_sequence(state ServiceWindowState, sequence u64) ServiceWindowState {
	return ServiceWindowState{
		mapping:      state.mapping
		visibility:   state.visibility
		active:       state.active
		focused:      state.focused
		minimized:    state.minimized
		maximized:    state.maximized
		fullscreen:   state.fullscreen
		mouse_locked: state.mouse_locked
		position:     state.position
		monitor_ids:  state.monitor_ids.clone()
		sequence:     sequence
	}
}

fn service_monitor_info_with_sequence(info ServiceMonitorInfo, sequence u64) ServiceMonitorInfo {
	return ServiceMonitorInfo{
		id:        info.id
		name:      info.name
		geometry:  info.geometry
		work_area: info.work_area
		scale:     info.scale
		primary:   info.primary
		available: info.available
		sequence:  sequence
	}
}

fn service_event_with_sequence(event ServiceEvent, sequence u64) ServiceEvent {
	mut monitors := []ServiceMonitorInfo{cap: event.monitors.len}
	for monitor in event.monitors {
		monitors << service_monitor_info_with_sequence(monitor, sequence)
	}
	return ServiceEvent{
		kind:          event.kind
		window:        event.window
		sequence:      sequence
		state:         service_window_state_with_sequence(event.state, sequence)
		metrics:       RenderMetricsSnapshot{
			...event.metrics
			metrics_sequence: sequence
		}
		operation:     event.operation
		capability:    event.capability
		monitor:       service_monitor_info_with_sequence(event.monitor, sequence)
		monitors:      monitors
		clipboard:     event.clipboard
		portal_parent: event.portal_parent
	}
}
