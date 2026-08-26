module pref

fn test_static_pkgconfig_compiler_owned_names_are_narrowly_reserved() {
	assert is_compiler_owned_define('v:static_pkgconfig')
	assert is_compiler_owned_define('v_static_pkgconfig')
	assert !is_compiler_owned_define('static_pkgconfig')
	assert !is_compiler_owned_define('v:flag:doc_attr')
	assert !is_compiler_owned_define('v:user_value')
}
