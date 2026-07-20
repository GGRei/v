module gg

// WindowSupportLevel reports whether a native operation is usable for one
// live window on the selected backend.
pub enum WindowSupportLevel {
	unsupported
	available
	conditional
}

// WindowObservedBool distinguishes an observed false value from unavailable
// native state.
pub enum WindowObservedBool {
	unknown
	off
	on
}

pub enum WindowMappingState {
	unknown
	unmapped
	mapped
}

pub enum WindowVisibilityState {
	unknown
	hidden
	visible
	occluded
}

// WindowOperation identifies a runtime native-window service.
pub enum WindowOperation {
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

pub enum WindowServiceEventKind {
	state
	metrics
	capability
	monitor
	clipboard
	portal_parent
}

pub enum WindowServiceStatus {
	ready
	cancelled
	failed
}

// WindowTitlebarAppearance requests the platform default or a light/dark
// native titlebar where the backend exposes such an operation.
pub enum WindowTitlebarAppearance {
	system
	light
	dark
}

pub struct WindowOperationCapability {
pub:
	support              WindowSupportLevel
	asynchronous         bool
	requires_user_action bool
	state_observable     bool
}

// WindowMonitorId is an opaque generation-checked monitor identity.
pub struct WindowMonitorId {
	app_instance u64
	slot         int
	generation   u32
}

pub fn (id WindowMonitorId) str() string {
	return 'WindowMonitorId(${id.app_instance}:${id.slot}:${id.generation})'
}

pub struct WindowPosition {
pub:
	known bool
	x     int
	y     int
}

pub struct WindowRect {
pub:
	x      int
	y      int
	width  int
	height int
}

pub struct WindowKnownRect {
pub:
	known bool
	value WindowRect
}

pub struct WindowKnownScale {
pub:
	known bool
	value f32
}

pub struct WindowMonitorInfo {
pub:
	id        WindowMonitorId
	name      string
	geometry  WindowKnownRect
	work_area WindowKnownRect
	scale     WindowKnownScale
	primary   WindowObservedBool
	available bool
	sequence  u64
}

pub struct WindowState {
pub:
	mapping      WindowMappingState
	visibility   WindowVisibilityState
	active       WindowObservedBool
	focused      WindowObservedBool
	minimized    WindowObservedBool
	maximized    WindowObservedBool
	fullscreen   WindowObservedBool
	mouse_locked WindowObservedBool
	position     WindowPosition
	monitor_ids  []WindowMonitorId
	sequence     u64
}

// ClipboardRequestId identifies one accepted asynchronous clipboard request.
pub struct ClipboardRequestId {
	app_instance u64
	serial       u64
}

pub fn (id ClipboardRequestId) str() string {
	return 'ClipboardRequestId(${id.app_instance}:${id.serial})'
}

// PortalParentRequestId identifies one accepted native-parent request.
pub struct PortalParentRequestId {
	app_instance u64
	serial       u64
}

pub fn (id PortalParentRequestId) str() string {
	return 'PortalParentRequestId(${id.app_instance}:${id.serial})'
}

// PortalParentLeaseId identifies a portal parent export until explicit release.
pub struct PortalParentLeaseId {
	app_instance u64
	serial       u64
}

pub fn (id PortalParentLeaseId) str() string {
	return 'PortalParentLeaseId(${id.app_instance}:${id.serial})'
}

pub struct ClipboardResult {
pub:
	id     ClipboardRequestId
	window WindowId
	status WindowServiceStatus
	text   string
	error  string
}

pub struct PortalParentResult {
pub:
	id         PortalParentRequestId
	window     WindowId
	status     WindowServiceStatus
	lease      PortalParentLeaseId
	identifier string
	error      string
}

pub struct WindowServiceEvent {
pub:
	kind          WindowServiceEventKind
	window        WindowId
	sequence      u64
	state         WindowState
	metrics       WindowMetrics
	operation     WindowOperation
	capability    WindowOperationCapability
	monitor       WindowMonitorInfo
	monitors      []WindowMonitorInfo
	clipboard     ClipboardResult
	portal_parent PortalParentResult
}

pub enum WindowQueuedEventKind {
	lifecycle
	input
	service
	readback
}

// WindowQueuedEvent is the canonical ordered delivery envelope for package-1
// and package-2 events. Advanced text input adds its payload in package 3.
pub struct WindowQueuedEvent {
pub:
	kind      WindowQueuedEventKind
	sequence  u64
	lifecycle WindowEvent
	input     WindowInputEvent
	service   WindowServiceEvent
	readback  WindowReadbackResult
}

pub type Win32NativeWindowFn = fn (hwnd voidptr) !

pub type AppKitNativeWindowFn = fn (ns_window voidptr) !

pub type X11NativeWindowFn = fn (display voidptr, window u64) !

pub type WaylandNativeWindowFn = fn (display voidptr, surface voidptr) !

pub type WindowServiceFn = fn (event WindowServiceEvent, mut app App) !
