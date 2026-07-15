#include <stddef.h>

_Static_assert(sizeof(VMultiwindowNativePrimitive) == (13 * sizeof(uint64_t)),
	"portable native primitive ABI layout changed");
_Static_assert(offsetof(VMultiwindowNativePrimitive, valid_mask) == 0,
	"native primitive validity mask must remain first");
_Static_assert(offsetof(VMultiwindowNativePrimitive, return_value) == 8,
	"native primitive return offset changed");
_Static_assert(offsetof(VMultiwindowNativePrimitive, handle) == 16,
	"native primitive handle offset changed");
_Static_assert(offsetof(VMultiwindowNativePrimitive, egl_error) == 24,
	"native primitive EGL offset changed");
_Static_assert(offsetof(VMultiwindowNativePrimitive, native_errno) == 32,
	"native primitive errno offset changed");
_Static_assert(offsetof(VMultiwindowNativePrimitive, wayland_display_error) == 40,
	"native primitive Wayland offset changed");
_Static_assert(offsetof(VMultiwindowNativePrimitive, dxgi_removal_reason) == 48,
	"native primitive DXGI offset changed");
_Static_assert(offsetof(VMultiwindowNativePrimitive, observed_count) == 56,
	"native primitive count offset changed");
_Static_assert(offsetof(VMultiwindowNativePrimitive, observed_flags) == 64,
	"native primitive flags offset changed");
_Static_assert(offsetof(VMultiwindowNativePrimitive, selected_value) == 72,
	"native primitive selected-value offset changed");
_Static_assert(offsetof(VMultiwindowNativePrimitive, object_identity_0) == 80,
	"native primitive first identity offset changed");
_Static_assert(offsetof(VMultiwindowNativePrimitive, object_identity_1) == 88,
	"native primitive second identity offset changed");
_Static_assert(offsetof(VMultiwindowNativePrimitive, object_identity_2) == 96,
	"native primitive third identity offset changed");

size_t v_multiwindow_test_common_native_primitive_size(void) {
	return sizeof(VMultiwindowNativePrimitive);
}

uint64_t v_multiwindow_test_common_native_primitive_mask(void) {
	return V_MULTIWINDOW_NATIVE_VALID_RETURN_VALUE |
		V_MULTIWINDOW_NATIVE_VALID_HANDLE |
		V_MULTIWINDOW_NATIVE_VALID_EGL_ERROR |
		V_MULTIWINDOW_NATIVE_VALID_ERRNO |
		V_MULTIWINDOW_NATIVE_VALID_WAYLAND_DISPLAY_ERROR |
		V_MULTIWINDOW_NATIVE_VALID_DXGI_REMOVAL_REASON |
		V_MULTIWINDOW_NATIVE_VALID_OBSERVED_COUNT |
		V_MULTIWINDOW_NATIVE_VALID_OBSERVED_FLAGS |
		V_MULTIWINDOW_NATIVE_VALID_SELECTED_VALUE |
		V_MULTIWINDOW_NATIVE_VALID_OBJECT_IDENTITY_0 |
		V_MULTIWINDOW_NATIVE_VALID_OBJECT_IDENTITY_1 |
		V_MULTIWINDOW_NATIVE_VALID_OBJECT_IDENTITY_2;
}
