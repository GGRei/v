module fastcdriver

import os

fn test_fastc_tcc_backtrace_enabled() {
	assert !fastc_tcc_backtrace_enabled('macos', 'arm64')
	assert fastc_tcc_backtrace_enabled('macos', 'amd64')
	assert fastc_tcc_backtrace_enabled('linux', 'arm64')
	assert fastc_tcc_backtrace_enabled('linux', 'amd64')
}

fn test_fastc_canonical_vroot_resolves_symlinked_checkout() {
	root := os.join_path(os.temp_dir(), 'fastc_canonical_vroot_${os.getpid()}')
	os.rmdir_all(root) or {}
	real_root := os.join_path(root, 'real')
	linked_root := os.join_path(root, 'linked')
	os.mkdir_all(os.join_path(real_root, 'vlib', 'builtin')) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	os.symlink(real_root, linked_root) or { return }
	assert fastc_canonical_vroot(linked_root) == os.real_path(real_root)
}

fn test_fastc_is_v3_entry_accepts_exact_native_entry() {
	assert fastc_is_v3_entry('/checkout/vlib/v3/v3.v')
	$if windows {
		assert fastc_is_v3_entry(r'C:\checkout\vlib\v3\v3.v')
	} $else {
		assert !fastc_is_v3_entry(r'C:\checkout\vlib\v3\v3.v')
	}
	assert !fastc_is_v3_entry('/checkout/vlib/v3/v3.v.bak')
	assert !fastc_is_v3_entry('/checkout/vlib/v3/not_v3.v')
	assert !fastc_is_v3_entry(r'C:\checkout\vlib\v3\v3.v.bak')
	assert !fastc_is_v3_entry(r'C:\checkout\vlib\v3\not_v3.v')
}

fn test_fastc_vroot_for_input_replaces_nonempty_only_when_building_v() {
	root := os.join_path(os.temp_dir(), 'fastc_vroot_for_input_${os.getpid()}')
	real_root := os.join_path(root, 'checkout')
	real_entry := os.join_path(real_root, 'vlib', 'v3', 'v3.v')
	os.mkdir_all(os.dir(real_entry)) or { panic(err) }
	os.write_file(real_entry, 'module main\n') or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	canonical_entry := os.real_path(real_entry)
	wrong_nonempty := os.join_path(root, 'wrong')
	assert fastc_vroot_for_input(wrong_nonempty, canonical_entry,
		fastc_is_v3_entry(canonical_entry)) == os.real_path(real_root)
	lookalike := '${canonical_entry}.bak'
	assert fastc_vroot_for_input(wrong_nonempty, lookalike, fastc_is_v3_entry(lookalike)) == wrong_nonempty
}

fn test_fastc_parse_bench_child_output() {
	sample := fastc_parse_bench_child_output('notice\nfastc-bench-child 50123 170 64516\n') or {
		assert false, 'expected benchmark sample'
		return
	}
	assert sample.gen_us == 50123
	assert sample.files == 170
	assert sample.lines == 64516
}

fn assert_in_place_self_chain_survives(compiler_name string) {
	dir := os.join_path(os.temp_dir(), 'fastc_self_${compiler_name}_chain_${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir) or { assert false, err.msg() }
	defer {
		os.rmdir_all(dir) or {}
	}
	compiler := os.join_path_single(dir, compiler_name)
	os.write_file(compiler, 'GEN0') or { assert false, err.msg() }
	replacement := self_replacement_path(compiler)
	assert replacement != compiler
	assert os.dir(replacement) == dir
	for generation in 1 .. 3 {
		os.write_file(replacement, 'GEN${generation}') or { assert false, err.msg() }
		replace_self_compiler(compiler, replacement)
		assert os.read_file(compiler) or { '' } == 'GEN${generation}'
		assert !os.exists(replacement)
	}
	assert os.read_file(compiler) or { '' } == 'GEN2'
	mut entries := os.ls(dir) or { []string{} }
	entries.sort()
	backup_name := if os.user_os() == 'windows' { 'v_old.exe' } else { 'v_old' }
	if compiler_name == backup_name {
		assert entries == [compiler_name], entries.str()
	} else {
		assert os.read_file(os.join_path_single(dir, backup_name)) or { '' } == 'GEN1'
		assert entries == [compiler_name, backup_name], entries.str()
	}
}

fn test_in_place_self_chain_survives_a_compiler_named_v2() {
	assert_in_place_self_chain_survives(if os.user_os() == 'windows' { 'v2.exe' } else { 'v2' })
}

fn test_in_place_self_chain_survives_a_compiler_named_v_old() {
	assert_in_place_self_chain_survives(if os.user_os() == 'windows' {
		'v_old.exe'
	} else {
		'v_old'
	})
}
