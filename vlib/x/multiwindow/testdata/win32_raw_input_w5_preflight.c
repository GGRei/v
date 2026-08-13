#include <stdint.h>
#include <stdio.h>

#if defined(_WIN32)

#include "win32_raw_input_w5_preflight.h"

int main(void) {
	uint32_t stage = 0;
	uint32_t proof = 0;
	uint32_t cleanup = 0;
	uint32_t error_code = 0;
	uint32_t cleanup_error = 0;
	int result;
	fprintf(stderr,
		"PACKAGE2_W5_A0_IDENTITY=win32_raw_input_sendinput_preflight\n");
	fprintf(stderr, "PACKAGE2_W5_A0_FAMILY=raw_input_environment\n");
	fflush(stderr);
	result = v_multiwindow_test_win32_w5_a0_run(5000u, &stage, &proof,
		&cleanup, &error_code, &cleanup_error);
	if ((proof & V_MULTIWINDOW_W5_PROOF_SEND_INPUT) != 0) {
		fprintf(stderr,
			"PACKAGE2_W5_A0_REACHED=sendinput_rawinput_correlation\n");
	}
	if (result == 1) {
		fprintf(stderr,
			"PACKAGE2_W5_A0_SOURCE_OK=injected_mouse_extra_tag\n");
		fprintf(stderr,
			"PACKAGE2_W5_A0_RAW_OK=real_hrawinput_relative\n");
		fprintf(stderr, "PACKAGE2_W5_A0_CLEANUP_OK=restored\n");
		fprintf(stderr,
			"PACKAGE2_W5_A0_SUMMARY=accepted:1 rejected:0 total:1\n");
		fprintf(stderr,
			"PACKAGE2_W5_A0_TERMINAL=native_pass:raw_input_environment\n");
		fflush(stderr);
		return 0;
	}
	fprintf(stderr,
		"PACKAGE2_W5_INFRA=stage:%u error:%u proof:%u cleanup:%u cleanup_error:%u\n",
		stage, error_code, proof, cleanup, cleanup_error);
	fprintf(stderr,
		"PACKAGE2_W5_A0_TERMINAL=infra:raw_input_environment\n");
	fflush(stderr);
	return result < 0 ? 2 : 1;
}

#else

int main(void) {
	fprintf(stderr,
		"PACKAGE2_W5_A0_IDENTITY=win32_raw_input_sendinput_preflight\n");
	fprintf(stderr, "PACKAGE2_W5_A0_FAMILY=raw_input_environment\n");
	fprintf(stderr,
		"PACKAGE2_W5_INFRA=stage:2 error:50 proof:0 cleanup:127 cleanup_error:0\n");
	fprintf(stderr,
		"PACKAGE2_W5_A0_TERMINAL=infra:raw_input_environment\n");
	fflush(stderr);
	return 1;
}

#endif
