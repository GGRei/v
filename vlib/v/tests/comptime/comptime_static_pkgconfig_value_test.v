import os

fn test_static_pkgconfig_compiler_value_is_canonical_in_a_dynamic_build() {
	assert !$d('v:static_pkgconfig', true)
	mut selected := ''
	$if $d('v:static_pkgconfig', true) {
		selected = 'static'
	} $else {
		selected = 'dynamic'
	}
	assert selected == 'dynamic'
	mut compound_selected := false
	$if !$d('v:static_pkgconfig', true) && !js {
		compound_selected = true
	}
	assert compound_selected
}

fn test_static_pkgconfig_compiler_owned_names_cannot_be_overridden() {
	tmp_dir := os.join_path(os.vtmp_dir(), 'v_static_pkgconfig_value_${os.getpid()}')
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	source_path := os.join_path(tmp_dir, 'main.v')
	os.write_file(source_path, 'fn main() {}\n') or { panic(err) }
	for define in [
		'v:static_pkgconfig',
		'v:static_pkgconfig=true',
		'v:static_pkgconfig=false',
		'v_static_pkgconfig',
		'v_static_pkgconfig=true',
		'v_static_pkgconfig=false',
	] {
		res :=
			os.execute('${os.quoted_path(@VEXE)} -d ${define} -check ${os.quoted_path(source_path)}')
		assert res.exit_code != 0, define
		assert res.output.contains('is a read-only compiler value'), '${define}: ${res.output}'
	}
}
