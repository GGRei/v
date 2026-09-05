module builder

import os
import v.cflag
import v.pref

fn test_msvc_string_flags_uses_cached_thirdparty_obj_path() {
	obj_file := os.join_path(@VEXEROOT, 'thirdparty', 'mbedtls', 'library', 'bignum.o')
	mut builder := msvc_new_builder_for_args(['-cc', 'msvc', '-m32', msvc_hello_world_example()])
	cached_obj := builder.pref.cache_manager.mod_postfix_with_key2cpath('mbedtls', '.o',
		os.real_path(obj_file))
	expected_obj := builder.msvc_thirdparty_obj_path('mbedtls', obj_file, cached_obj)
	sflags := builder.msvc_string_flags([
		cflag.CFlag{
			mod:    'mbedtls'
			value:  obj_file
			cached: cached_obj
		},
	])
	assert sflags.other_flags == ['"${expected_obj}"']
}

fn test_msvc_string_flags_rewrites_obj_flags_through_cached_path() {
	test_dir := os.join_path(os.vtmp_dir(), 'builder_msvc_obj_flag_test_${os.getpid()}')
	obj_file := os.join_path(test_dir, 'gc.obj')
	os.mkdir_all(test_dir) or { panic(err) }
	os.write_file(obj_file, '') or { panic(err) }
	defer {
		os.rmdir_all(test_dir) or {}
	}
	mut builder := msvc_new_builder_for_args(['-cc', 'msvc', '-m64', msvc_hello_world_example()])
	builder.table.cflags = [
		cflag.CFlag{
			mod:   'builtin'
			value: obj_file
		},
	]
	flags := builder.get_os_cflags()
	expected_cached := builder.pref.cache_manager.mod_postfix_with_key2cpath('builtin', '.obj',
		os.real_path(obj_file))
	assert flags.len == 1
	assert flags[0].cached == expected_cached
	expected_obj := builder.msvc_thirdparty_obj_path('builtin', obj_file, expected_cached)
	sflags := builder.msvc_string_flags(flags)
	assert sflags.other_flags == ['"${expected_obj}"']
}

fn test_msvc_string_flags_selects_windows_libcrypto_without_legacy_crypto_name() {
	mut builder := msvc_new_builder_for_args(['-cc', 'msvc', '-os', 'windows', '-m64',
		msvc_hello_world_example()])
	builder.table.cflags = [
		cflag.CFlag{
			mod:   'crypto_test'
			os:    'windows'
			name:  '-l'
			value: 'libcrypto'
		},
		cflag.CFlag{
			mod:   'crypto_test'
			os:    'linux'
			name:  '-l'
			value: 'crypto'
		},
	]
	selected := builder.get_os_cflags()
	assert selected.len == 1
	assert selected[0].os == 'windows'
	assert selected[0].name == '-l'
	assert selected[0].value == 'libcrypto'
	sflags := builder.msvc_string_flags(selected)
	assert sflags.real_libs == ['libcrypto.lib']
	assert 'crypto.lib' !in sflags.real_libs
}

fn test_windows_tcc_link_flags_select_libcrypto_without_legacy_crypto_name() {
	mut builder := msvc_new_builder_for_args(['-cc', 'tcc', '-os', 'windows', '-m64',
		msvc_hello_world_example()])
	builder.table.cflags = [
		cflag.CFlag{
			mod:   'crypto_test'
			os:    'windows'
			name:  '-l'
			value: 'libcrypto'
		},
		cflag.CFlag{
			mod:   'crypto_test'
			os:    'linux'
			name:  '-l'
			value: 'crypto'
		},
	]
	selected := builder.get_os_cflags()
	assert selected.len == 1
	assert selected[0].os == 'windows'
	assert selected[0].name == '-l'
	assert selected[0].value == 'libcrypto'
	_, _, libs := selected.defines_others_libs()
	assert libs == ['-llibcrypto']
	assert '-lcrypto' !in libs
}

fn test_msvc_string_flags_evaluates_ecdsa_search_path_macros() {
	source := os.read_file(os.join_path(@VEXEROOT, 'vlib', 'crypto', 'ecdsa', 'ecdsa.c.v')) or {
		panic(err)
	}
	paths := ['C:/Program Files/OpenSSL-Win64/include',
		'C:/Program Files/OpenSSL-Win64/lib/VC/x64/MD', 'C:/Program Files/OpenSSL/include',
		'C:/Program Files/OpenSSL/lib/VC/x64/MD']
	names := ['-I', '-L', '-I', '-L']
	mut directives := []string{}
	for line in source.split_into_lines() {
		if line.starts_with('#flag windows -I') || line.starts_with('#flag windows -L') {
			directives << line.all_after('#flag ')
		}
	}
	assert directives.len == 4
	for i, path in paths {
		assert directives[i] == 'windows ${names[i]}' + r'$when_first_existing' + "('${path}')"
	}
	root := os.join_path(os.vtmp_dir(), 'issue74 ecdsa MSVC ${os.getpid()}')
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	mut builder := msvc_new_builder_for_args(['-cc', 'msvc', '-os', 'windows', '-m64',
		msvc_hello_world_example()])
	for mask in 0 .. 16 {
		state := os.join_path(root, mask.str())
		mapped := [os.join_path(state, 'OpenSSL-Win64', 'include'),
			os.join_path(state, 'OpenSSL-Win64', 'lib', 'VC', 'x64', 'MD'),
			os.join_path(state, 'OpenSSL', 'include'),
			os.join_path(state, 'OpenSSL', 'lib', 'VC', 'x64', 'MD')]
		builder.table.cflags = []cflag.CFlag{}
		mut original := []cflag.CFlag{}
		mut expected_includes := []string{}
		mut expected_libraries := []string{}
		for i, path in mapped {
			if (mask & (1 << i)) != 0 {
				os.mkdir_all(path) or { panic(err) }
				original << cflag.CFlag{
					mod:   'crypto.ecdsa'
					os:    'windows'
					name:  names[i]
					value: path
				}
				if names[i] == '-I' {
					expected_includes << '/I"${os.real_path(path)}"'
				} else {
					expected_libraries << '/LIBPATH:"${os.real_path(path)}"'
					expected_libraries << '/LIBPATH:"${os.real_path(os.join_path(path,
						'msvc'))}"'
				}
			}
			builder.table.parse_cflag(directives[i].replace(paths[i], path), 'crypto.ecdsa',
				builder.pref.compile_defines_all) or { panic(err) }
		}
		if (mask & 5) == 5 {
			os.write_file(os.join_path(mapped[2], 'issue74_fallback.h'), '#define ISSUE74_FALLBACK 1\n') or {
				panic(err)
			}
			assert !os.exists(os.join_path(mapped[0], 'issue74_fallback.h'))
		}
		selected := builder.get_os_cflags()
		assert selected.len == 4
		actual := builder.msvc_string_flags(selected)
		expected := builder.msvc_string_flags(original)
		assert actual.inc_paths == expected_includes, 'mask ${mask}: ${actual.inc_paths}'
		assert actual.lib_paths == expected_libraries, 'mask ${mask}: ${actual.lib_paths}'
		assert actual.inc_paths == expected.inc_paths
		assert actual.lib_paths == expected.lib_paths
		assert actual.real_libs == expected.real_libs && actual.real_libs.len == 0
		assert actual.defines == expected.defines && actual.defines.len == 0
		assert actual.other_flags == expected.other_flags && actual.other_flags.len == 0
		for i, flag in selected {
			assert flag.name == names[i] && flag.os == 'windows'
			assert flag.value == r'$when_first_existing' + "('${mapped[i]}')"
		}
	}
}

fn test_msvc_string_flags_path_macros_preserve_required_fallback_and_other_flags() {
	root := os.join_path(os.vtmp_dir(), 'issue74 MSVC required paths ${os.getpid()}')
	first := os.join_path(root, 'first existing')
	second := os.join_path(root, 'second existing')
	missing := os.join_path(root, 'not present')
	os.mkdir_all(first) or { panic(err) }
	os.mkdir_all(second) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	literal := 'ISSUE74_LITERAL=' + r'$first_existing' + "('${missing}')"
	mut builder := msvc_new_builder_for_args(['-cc', 'msvc', '-os', 'windows', '-m64',
		msvc_hello_world_example()])
	sflags := builder.msvc_string_flags([
		cflag.CFlag{
			name:  '-I'
			value: r'$first_existing' + "('${missing}', '${first}', '${second}')"
		},
		cflag.CFlag{
			name:  '-L'
			value: r'$first_existing' + "('${first}', '${second}')"
		},
		cflag.CFlag{
			name:  '-I'
			value: missing
		},
		cflag.CFlag{
			name:  '-D'
			value: literal
		},
		cflag.CFlag{
			value: '/NODEFAULTLIB'
		},
	])
	assert sflags.inc_paths == ['/I"${os.real_path(first)}"', '/I"${os.real_path(missing)}"']
	assert sflags.lib_paths == [
		'/LIBPATH:"${os.real_path(first)}"',
		'/LIBPATH:"${os.real_path(os.join_path(first, 'msvc'))}"',
	]
	assert sflags.defines == ['/D${literal}']
	assert sflags.other_flags == ['/NODEFAULTLIB']
	assert sflags.real_libs.len == 0
}

fn test_msvc_ordered_pkgconfig_linker_args_routes_static_paths_and_libs() {
	mut builder := msvc_new_builder_for_args(['-cc', 'msvc', '-m64', msvc_hello_world_example()])
	lib_dir := os.join_path(os.getwd(), 'msvc_pkgconfig_static_libs')
	builder.table.parse_pkgconfig_link_flags(['-L${lib_dir}', '-lissue74_public', '-lissue74_private'],
		'main', builder.pref.compile_defines_all) or { panic(err) }

	assert builder.get_os_cflags() == []
	assert builder.msvc_ordered_pkgconfig_linker_args() == [
		'/LIBPATH:"${os.real_path(lib_dir)}"',
		'/LIBPATH:"${os.real_path(os.join_path(lib_dir, 'msvc'))}"',
		'issue74_public.lib',
		'issue74_private.lib',
	]
}

fn test_msvc_ordered_pkgconfig_linker_args_preserves_segment_order_and_repetition() {
	mut builder := msvc_new_builder_for_args(['-cc', 'msvc', '-m64', msvc_hello_world_example()])
	builder.table.parse_pkgconfig_link_flags(['-lissue74_a', '-lissue74_b', '-lissue74_a'], 'main',
		builder.pref.compile_defines_all) or { panic(err) }
	builder.table.parse_pkgconfig_link_flags(['-lissue74_c', '-lissue74_a'], 'main',
		builder.pref.compile_defines_all) or { panic(err) }

	assert builder.msvc_ordered_pkgconfig_linker_args() == [
		'issue74_a.lib',
		'issue74_b.lib',
		'issue74_a.lib',
		'issue74_c.lib',
		'issue74_a.lib',
	]
}

fn test_msvc_ordered_pkgconfig_linker_args_preserves_single_segment_token_order() {
	mut builder := msvc_new_builder_for_args(['-cc', 'msvc', '-m64', msvc_hello_world_example()])
	lib_dir := os.join_path(os.getwd(), 'msvc_pkgconfig_ordered_libs')
	builder.table.parse_pkgconfig_link_flags(['-L${lib_dir}', 'issue74_direct.LIB', '-lissue74_a',
		'-Wl,--start-group', '-lissue74_b', 'issue74_repeat.LIB', '-lissue74_a', '-Wl,--end-group',
		'issue74_tail.LIB'], 'main', builder.pref.compile_defines_all) or { panic(err) }

	args := builder.msvc_ordered_pkgconfig_linker_args()
	assert args == [
		'/LIBPATH:"${os.real_path(lib_dir)}"',
		'/LIBPATH:"${os.real_path(os.join_path(lib_dir, 'msvc'))}"',
		'issue74_direct.LIB',
		'issue74_a.lib',
		'issue74_b.lib',
		'issue74_repeat.LIB',
		'issue74_a.lib',
		'issue74_tail.LIB',
	]
	assert !args.any(it.contains('start-group') || it.contains('end-group'))
}

fn test_msvc_ordered_pkgconfig_linker_args_preserves_native_slash_flags() {
	mut builder := msvc_new_builder_for_args(['-cc', 'msvc', '-m64', msvc_hello_world_example()])
	output_dir := os.join_path(os.getwd(), 'msvc pkgconfig native flags')
	pdb_path := os.join_path(output_dir, 'issue74 output.pdb')
	direct_lib := os.join_path(output_dir, 'issue74 direct.LIB')
	builder.table.parse_pkgconfig_link_flags(['-lissue74_a', '/NODEFAULTLIB', '/OPT:REF',
		'/PDB:"${pdb_path}"', '/WHOLEARCHIVE:issue74_whole.lib', '"${direct_lib}"',
		'-Wl,--start-group', '--as-needed', '-lissue74_b', '-Wl,--end-group', '/OPT:REF',
		'-lissue74_a'], 'main', builder.pref.compile_defines_all) or { panic(err) }

	args := builder.msvc_ordered_pkgconfig_linker_args()
	assert args == [
		'issue74_a.lib',
		'/NODEFAULTLIB',
		'/OPT:REF',
		'/PDB:"${pdb_path}"',
		'/WHOLEARCHIVE:issue74_whole.lib',
		'"${direct_lib}"',
		'issue74_b.lib',
		'/OPT:REF',
		'issue74_a.lib',
	]
	assert !args.any(it.contains('start-group') || it.contains('end-group') || it == '--as-needed')
}

fn test_msvc_ordered_pkgconfig_linker_args_quotes_only_decoded_slash_option_operands() {
	pdb_path := r'C:\Issue74 Output\app.pdb'
	whole_archive_path := r'C:\Issue74 Libraries\whole.lib'
	decoded_pdb := '/PDB:${pdb_path}'
	decoded_whole_archive := '/WHOLEARCHIVE:${whole_archive_path}'
	quoted_pdb := '/PDB:"${pdb_path}"'
	equals_pdb := '/PDB=${pdb_path}'

	assert quote_spaced_ordered_pkgconfig_operand(cflag.CFlag{
		value: decoded_pdb
	}, true).value == '/PDB:"${pdb_path}"'
	assert quote_spaced_ordered_pkgconfig_operand(cflag.CFlag{
		value: decoded_whole_archive
	}, true).value == '/WHOLEARCHIVE:"${whole_archive_path}"'
	assert quote_spaced_ordered_pkgconfig_operand(cflag.CFlag{
		value: quoted_pdb
	}, true).value == quoted_pdb
	assert quote_spaced_ordered_pkgconfig_operand(cflag.CFlag{
		value: equals_pdb
	}, true).value == equals_pdb
	assert quote_spaced_ordered_pkgconfig_operand(cflag.CFlag{
		value: '/OPT:REF'
	}, true).value == '/OPT:REF'

	mut builder := msvc_new_builder_for_args(['-cc', 'msvc', '-m64', msvc_hello_world_example()])
	builder.table.parse_pkgconfig_link_flags([
		decoded_pdb,
		decoded_whole_archive,
		quoted_pdb,
		'/OPT:REF',
		'-lVersion',
	], 'main', builder.pref.compile_defines_all) or { panic(err) }
	assert builder.msvc_ordered_pkgconfig_linker_args() == [
		'/PDB:"${pdb_path}"',
		'/WHOLEARCHIVE:"${whole_archive_path}"',
		quoted_pdb,
		'/OPT:REF',
		'Version.lib',
	]
}

fn test_msvc_ordered_pkgconfig_linker_args_preserves_quoted_paths_with_spaces() {
	mut builder := msvc_new_builder_for_args(['-cc', 'msvc', '-m64', msvc_hello_world_example()])
	lib_dir := os.join_path(os.getwd(), 'msvc pkgconfig quoted libs')
	direct_lib := os.join_path(lib_dir, 'issue74 direct.LIB')
	builder.table.parse_pkgconfig_link_flags(['-L"${lib_dir}"', '"${direct_lib}"', '-lissue74_a',
		'"${direct_lib}"', 'issue74_plain.LIB'], 'main', builder.pref.compile_defines_all) or {
		panic(err)
	}

	assert builder.msvc_ordered_pkgconfig_linker_args() == [
		'/LIBPATH:"${os.real_path(lib_dir)}"',
		'/LIBPATH:"${os.real_path(os.join_path(lib_dir, 'msvc'))}"',
		'"${direct_lib}"',
		'issue74_a.lib',
		'"${direct_lib}"',
		'issue74_plain.LIB',
	]
}

fn test_msvc_ordered_pkgconfig_linker_args_preserves_decoded_paths_with_spaces() {
	mut builder := msvc_new_builder_for_args(['-cc', 'msvc', '-m64', msvc_hello_world_example()])
	lib_dir := os.join_path(os.getwd(), 'msvc pkgconfig decoded libs')
	direct_lib := os.join_path(lib_dir, 'issue74 direct.lib')
	builder.table.parse_pkgconfig_link_flags(['-L${lib_dir}', direct_lib, '-lVersion', direct_lib,
		'-lVersion'], 'main', builder.pref.compile_defines_all) or { panic(err) }

	assert builder.msvc_ordered_pkgconfig_linker_args() == [
		'/LIBPATH:"${os.real_path(lib_dir)}"',
		'/LIBPATH:"${os.real_path(os.join_path(lib_dir, 'msvc'))}"',
		'"${direct_lib}"',
		'Version.lib',
		'"${direct_lib}"',
		'Version.lib',
	]
}

fn test_msvc_ordered_pkgconfig_linker_args_ignores_spaced_gnu_linker_control() {
	mut builder := msvc_new_builder_for_args(['-cc', 'msvc', '-m64', msvc_hello_world_example()])
	builder.table.parse_pkgconfig_link_flags([
		r'-Wl,-rpath,C:\issue74 runtime libs',
		'-lVersion',
	], 'main', builder.pref.compile_defines_all) or { panic(err) }

	assert builder.msvc_ordered_pkgconfig_linker_args() == ['Version.lib']
}

fn test_msvc_ordered_pkgconfig_linker_args_keeps_dynamic_flags_on_legacy_path() {
	mut builder := msvc_new_builder_for_args(['-cc', 'msvc', '-m64', msvc_hello_world_example()])
	lib_dir := os.join_path(os.getwd(), 'msvc_pkgconfig_dynamic_libs')
	builder.table.parse_cflag_with_link_segment('/NODEFAULTLIB', 'main',
		builder.pref.compile_defines_all) or { panic(err) }
	builder.table.parse_cflag_with_link_segment('/OPT:NOREF', 'main',
		builder.pref.compile_defines_all) or { panic(err) }
	builder.table.parse_cflag_with_link_segment('-L${lib_dir} -lissue74_dynamic', 'main',
		builder.pref.compile_defines_all) or { panic(err) }
	builder.table.parse_pkgconfig_link_flags(['/OPT:REF', '-lissue74_static'], 'main',
		builder.pref.compile_defines_all) or { panic(err) }

	legacy := builder.msvc_string_flags(builder.get_os_cflags())
	assert legacy.lib_paths == [
		'/LIBPATH:"${os.real_path(lib_dir)}"',
		'/LIBPATH:"${os.real_path(os.join_path(lib_dir, 'msvc'))}"',
	]
	assert legacy.real_libs == ['issue74_dynamic.lib']
	assert legacy.other_flags == ['/NODEFAULTLIB', '/OPT:NOREF']
	assert builder.msvc_ordered_pkgconfig_linker_args() == ['/OPT:REF', 'issue74_static.lib']
}

fn msvc_new_builder_for_args(args []string) Builder {
	mut full_args := ['']
	full_args << args
	prefs, _ := pref.parse_args_and_show_errors([], full_args, false)
	return new_builder(prefs)
}

fn msvc_hello_world_example() string {
	return os.join_path(@VEXEROOT, 'examples', 'hello_world.v')
}
