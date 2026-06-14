module pref

fn test_source_files_from_args_skips_autofree_boolean_flag() {
	files := source_files_from_args(['-autofree', '-o', 'app', 'main.v'])
	assert files == ['main.v']
}

fn test_new_preferences_from_args_parses_autofree_flag() {
	prefs := new_preferences_from_args(['-autofree', 'main.v'])
	assert prefs.autofree
	assert !prefs.ownership
	assert 'autofree' !in prefs.explicit_user_defines
}

fn test_d_autofree_does_not_enable_autofree_mode() {
	prefs := new_preferences_from_args(['-d', 'autofree', 'main.v'])
	assert !prefs.autofree
	assert 'autofree' in prefs.user_defines
	assert 'autofree' in prefs.explicit_user_defines
}

fn test_new_preferences_using_options_accepts_only_single_dash_autofree() {
	prefs := new_preferences_using_options(['--cleanc', '-autofree'])
	assert prefs.autofree
	assert !prefs.ownership

	long_flag_prefs := new_preferences_using_options(['--cleanc', '--autofree'])
	assert !long_flag_prefs.autofree

	bare_token_prefs := new_preferences_using_options(['--cleanc', 'autofree'])
	assert !bare_token_prefs.autofree
}

fn test_v2_self_compile_target_keeps_autofree_enabled() {
	prefs := new_preferences_from_args(['-autofree', 'cmd/v2/v2.v'])
	assert prefs.autofree
	assert !prefs.ownership
	assert 'autofree' !in prefs.explicit_user_defines
}

fn test_v2_self_compile_target_without_flag_keeps_autofree_disabled() {
	prefs := new_preferences_from_args(['cmd/v2/v2.v'])
	assert !prefs.autofree
	assert !prefs.ownership
	assert 'autofree' !in prefs.explicit_user_defines
}
