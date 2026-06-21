module c

fn builtin_compat_code_with_used_fns(used_fn_names []string) string {
	mut g := FlatGen.new()
	g.has_builtins = true
	g.used_fn_names = used_fn_names.clone()
	g.builtin_compat_decls()
	return g.sb.str()
}

fn test_builtin_compat_emits_disabled_conditional_hook_shims_when_hooks_absent() {
	code := builtin_compat_code_with_used_fns([])
	assert code.contains('static inline void _ht_alloc(u8* p, ptrdiff_t n)')
	assert code.contains('static inline void _ht_free(void* p)')
	assert code.contains('static inline void trace_error(string x)')
	assert !code.contains('static inline void assert1')
}

fn test_builtin_compat_skips_conditional_hook_shims_when_real_hooks_are_used() {
	code := builtin_compat_code_with_used_fns(['_ht_alloc', '_ht_free', 'trace_error', 'assert1'])
	assert !code.contains('static inline void _ht_alloc')
	assert !code.contains('static inline void _ht_free')
	assert !code.contains('static inline void trace_error')
	assert !code.contains('static inline void assert1')
}
