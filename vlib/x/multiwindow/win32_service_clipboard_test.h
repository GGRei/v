#ifndef V_MULTIWINDOW_WIN32_SERVICE_CLIPBOARD_TEST_H
#define V_MULTIWINDOW_WIN32_SERVICE_CLIPBOARD_TEST_H

#if defined(_WIN32) && defined(V_MULTIWINDOW_WIN32_SERVICE_TEST)
#include <stdint.h>
#include <stddef.h>
#include <string.h>

#define V_MULTIWINDOW_WIN32_CLIPBOARD_TEST_MAX_BACKENDS 32
#define V_MULTIWINDOW_WIN32_CLIPBOARD_TEST_MAX_REQUESTS 128

typedef struct VMultiwindowWin32ClipboardTestRequest {
	uint64_t app;
	uint64_t serial;
	int attempts;
} VMultiwindowWin32ClipboardTestRequest;

typedef struct VMultiwindowWin32ClipboardTestState {
	void *backend;
	int use_injected_clock;
	int64_t now_ns;
	int fail_open_attempts;
	int attempts;
	void *last_open_owner;
	int owned_globals;
	int global_allocations;
	int global_transfers;
	int global_frees;
	int sequence_allocations;
	VMultiwindowWin32ClipboardTestRequest
		requests[V_MULTIWINDOW_WIN32_CLIPBOARD_TEST_MAX_REQUESTS];
	int request_count;
} VMultiwindowWin32ClipboardTestState;

static VMultiwindowWin32ClipboardTestState
	v_multiwindow_win32_clipboard_test_states[
		V_MULTIWINDOW_WIN32_CLIPBOARD_TEST_MAX_BACKENDS];

static inline VMultiwindowWin32ClipboardTestState *
v_multiwindow_win32_clipboard_test_state(void *backend, int create) {
	if (!backend) {
		return NULL;
	}
	VMultiwindowWin32ClipboardTestState *available = NULL;
	for (int index = 0;
		index < V_MULTIWINDOW_WIN32_CLIPBOARD_TEST_MAX_BACKENDS;
		index++) {
		VMultiwindowWin32ClipboardTestState *state =
			&v_multiwindow_win32_clipboard_test_states[index];
		if (state->backend == backend) {
			return state;
		}
		if (!available && !state->backend) {
			available = state;
		}
	}
	if (!create || !available) {
		return NULL;
	}
	available->backend = backend;
	return available;
}

static inline VMultiwindowWin32ClipboardTestRequest *
v_multiwindow_win32_clipboard_test_request(
	VMultiwindowWin32ClipboardTestState *state, uint64_t app,
	uint64_t serial, int create) {
	if (!state) {
		return NULL;
	}
	for (int index = 0; index < state->request_count; index++) {
		VMultiwindowWin32ClipboardTestRequest *request =
			&state->requests[index];
		if (request->app == app && request->serial == serial) {
			return request;
		}
	}
	if (!create || state->request_count >=
		V_MULTIWINDOW_WIN32_CLIPBOARD_TEST_MAX_REQUESTS) {
		return NULL;
	}
	VMultiwindowWin32ClipboardTestRequest *request =
		&state->requests[state->request_count++];
	request->app = app;
	request->serial = serial;
	return request;
}

static inline void v_multiwindow_win32_service_test_clipboard_configure(
	void *backend, int64_t now_ns, int fail_open_attempts) {
	VMultiwindowWin32ClipboardTestState *state =
		v_multiwindow_win32_clipboard_test_state(backend, 1);
	if (!state) {
		return;
	}
	memset(state, 0, sizeof(*state));
	state->backend = backend;
	state->use_injected_clock = 1;
	state->now_ns = now_ns;
	state->fail_open_attempts =
		fail_open_attempts > 0 ? fail_open_attempts : 0;
}

static inline void
v_multiwindow_win32_service_test_clipboard_set_now_ns(
	void *backend, int64_t now_ns) {
	VMultiwindowWin32ClipboardTestState *state =
		v_multiwindow_win32_clipboard_test_state(backend, 1);
	if (!state) {
		return;
	}
	state->use_injected_clock = 1;
	state->now_ns = now_ns;
}

static inline void
v_multiwindow_win32_service_test_clipboard_use_real_clock(void *backend) {
	VMultiwindowWin32ClipboardTestState *state =
		v_multiwindow_win32_clipboard_test_state(backend, 0);
	if (state) {
		state->use_injected_clock = 0;
	}
}

static inline int64_t v_multiwindow_win32_clipboard_now_for_test(
	void *backend, int64_t real_now_ns) {
	VMultiwindowWin32ClipboardTestState *state =
		v_multiwindow_win32_clipboard_test_state(backend, 0);
	return state && state->use_injected_clock
		? state->now_ns : real_now_ns;
}

static inline int v_multiwindow_win32_clipboard_take_open_failure_for_test(
	VMultiwindowWin32ClipboardTestState *state) {
	if (!state || state->fail_open_attempts <= 0) {
		return 0;
	}
	state->fail_open_attempts--;
	return 1;
}

static inline void v_multiwindow_win32_clipboard_record_attempt_for_test(
	VMultiwindowWin32ClipboardTestState *state, uint64_t request_app,
	uint64_t request_serial, void *owner) {
	if (!state) {
		return;
	}
	state->attempts++;
	state->last_open_owner = owner;
	VMultiwindowWin32ClipboardTestRequest *request =
		v_multiwindow_win32_clipboard_test_request(state, request_app,
			request_serial, 1);
	if (request) {
		request->attempts++;
	}
}

static inline int v_multiwindow_win32_clipboard_write_for_test(
	void *backend, uint64_t request_app, uint64_t request_serial,
	void *owner, const uint16_t *text, size_t units) {
	VMultiwindowWin32ClipboardTestState *state =
		v_multiwindow_win32_clipboard_test_state(backend, 1);
	v_multiwindow_win32_clipboard_record_attempt_for_test(state,
		request_app, request_serial, owner);
	if (v_multiwindow_win32_clipboard_take_open_failure_for_test(state)) {
		return V_MULTIWINDOW_WIN32_CLIPBOARD_ATTEMPT_RETRY;
	}
	int status = v_multiwindow_win32_clipboard_write(owner, text, units);
	if (state) {
		if (status == V_MULTIWINDOW_WIN32_CLIPBOARD_ATTEMPT_READY) {
			state->global_allocations++;
			state->global_transfers++;
		} else if (status
			== V_MULTIWINDOW_WIN32_CLIPBOARD_ATTEMPT_CLEANED) {
			state->global_allocations++;
			state->global_frees++;
		}
	}
	if (status == V_MULTIWINDOW_WIN32_CLIPBOARD_ATTEMPT_CLEANED) {
		return V_MULTIWINDOW_WIN32_CLIPBOARD_ATTEMPT_FAILED;
	}
	return status;
}

static inline int v_multiwindow_win32_clipboard_read_for_test(
	void *backend, uint64_t request_app, uint64_t request_serial,
	void *owner, void **out_text, size_t *out_text_bytes) {
	VMultiwindowWin32ClipboardTestState *state =
		v_multiwindow_win32_clipboard_test_state(backend, 1);
	v_multiwindow_win32_clipboard_record_attempt_for_test(state,
		request_app, request_serial, owner);
	if (v_multiwindow_win32_clipboard_take_open_failure_for_test(state)) {
		if (out_text) {
			*out_text = NULL;
		}
		if (out_text_bytes) {
			*out_text_bytes = 0;
		}
		return V_MULTIWINDOW_WIN32_CLIPBOARD_ATTEMPT_RETRY;
	}
	return v_multiwindow_win32_clipboard_read(owner, out_text,
		out_text_bytes);
}

static inline void
v_multiwindow_win32_clipboard_record_sequence_for_test(void *backend) {
	VMultiwindowWin32ClipboardTestState *state =
		v_multiwindow_win32_clipboard_test_state(backend, 1);
	if (state) {
		state->sequence_allocations++;
	}
}

static inline int v_multiwindow_win32_service_test_clipboard_attempts(
	void *backend) {
	VMultiwindowWin32ClipboardTestState *state =
		v_multiwindow_win32_clipboard_test_state(backend, 0);
	return state ? state->attempts : 0;
}

static inline int
v_multiwindow_win32_service_test_clipboard_request_attempts(
	void *backend, uint64_t request_app, uint64_t request_serial) {
	VMultiwindowWin32ClipboardTestState *state =
		v_multiwindow_win32_clipboard_test_state(backend, 0);
	VMultiwindowWin32ClipboardTestRequest *request =
		v_multiwindow_win32_clipboard_test_request(state, request_app,
			request_serial, 0);
	return request ? request->attempts : 0;
}

static inline void *
v_multiwindow_win32_service_test_clipboard_last_open_owner(
	void *backend) {
	VMultiwindowWin32ClipboardTestState *state =
		v_multiwindow_win32_clipboard_test_state(backend, 0);
	return state ? state->last_open_owner : NULL;
}

static inline int
v_multiwindow_win32_service_test_clipboard_owned_globals(void *backend) {
	VMultiwindowWin32ClipboardTestState *state =
		v_multiwindow_win32_clipboard_test_state(backend, 0);
	return state ? state->owned_globals : 0;
}

static inline int
v_multiwindow_win32_service_test_clipboard_global_allocations(
	void *backend) {
	VMultiwindowWin32ClipboardTestState *state =
		v_multiwindow_win32_clipboard_test_state(backend, 0);
	return state ? state->global_allocations : 0;
}

static inline int
v_multiwindow_win32_service_test_clipboard_global_transfers(
	void *backend) {
	VMultiwindowWin32ClipboardTestState *state =
		v_multiwindow_win32_clipboard_test_state(backend, 0);
	return state ? state->global_transfers : 0;
}

static inline int
v_multiwindow_win32_service_test_clipboard_global_frees(void *backend) {
	VMultiwindowWin32ClipboardTestState *state =
		v_multiwindow_win32_clipboard_test_state(backend, 0);
	return state ? state->global_frees : 0;
}

static inline int
v_multiwindow_win32_service_test_clipboard_sequence_allocations(
	void *backend) {
	VMultiwindowWin32ClipboardTestState *state =
		v_multiwindow_win32_clipboard_test_state(backend, 0);
	return state ? state->sequence_allocations : 0;
}

static inline int64_t
v_multiwindow_win32_service_test_clipboard_timeout_ns(void *backend) {
	(void)backend;
	return INT64_C(2000000000);
}

static int x__multiwindow__win32_service_test_clipboard_pending_count(
	void *backend);
static int64_t
x__multiwindow__win32_service_test_clipboard_pending_deadline_ns(
	void *backend, int index);
static int
x__multiwindow__win32_service_test_clipboard_pending_write_matches(
	void *backend, int index, uint64_t request_app,
	uint64_t request_serial, uint64_t window_app, int window_slot,
	uint32_t window_generation, uint16_t *text, size_t units);

static inline int
v_multiwindow_win32_service_test_clipboard_pending_count(void *backend) {
	return x__multiwindow__win32_service_test_clipboard_pending_count(
		backend);
}

static inline int64_t
v_multiwindow_win32_service_test_clipboard_pending_deadline_ns(
	void *backend, int index) {
	return
		x__multiwindow__win32_service_test_clipboard_pending_deadline_ns(
			backend, index);
}

static inline int
v_multiwindow_win32_service_test_clipboard_pending_write_matches(
	void *backend, int index, uint64_t request_app,
	uint64_t request_serial, uint64_t window_app, int window_slot,
	uint32_t window_generation, uint16_t *text, size_t units) {
	return
		x__multiwindow__win32_service_test_clipboard_pending_write_matches(
			backend, index, request_app, request_serial, window_app,
			window_slot, window_generation, text, units);
}
#endif

#endif
