module main

import veb

struct FasthttpVisibilityApp {}

struct FasthttpVisibilityContext {
	veb.Context
}

fn compile_veb_run_at_with_fasthttp_backend(mut app FasthttpVisibilityApp) ! {
	veb.run_at[FasthttpVisibilityApp, FasthttpVisibilityContext](mut app, port: 0)!
}

fn test_veb_run_at_typechecks_with_fasthttp_backend() {
	assert true
}
