import os
import v3.cmdexec
import v3.parser
import v3.pref
import v3.transform
import v3.types

const interface_fn_tests_dir = os.dir(@FILE)
const interface_fn_v3_dir = os.dir(interface_fn_tests_dir)
const interface_fn_vlib_dir = os.dir(interface_fn_v3_dir)
const interface_fn_v3_src = os.join_path(interface_fn_v3_dir, 'v3.v')
const interface_fn_v3_bin = interface_fn_executable(os.join_path(os.temp_dir(), 'v3_interface_fn_${os.getpid()}'))

fn interface_fn_executable(path string) string {
	$if windows {
		return path + '.exe'
	}
	return path
}

fn interface_fn_c_compiler_args() []string {
	cc := os.getenv('ISSUE74_V3_DRIVER_TEST_CC')
	cxx := os.getenv('ISSUE74_V3_DRIVER_TEST_CXX')
	if cc.len == 0 && cxx.len == 0 {
		return []string{}
	}
	assert os.is_abs_path(cc) && os.is_file(cc), 'invalid fixture C compiler: ${cc}'
	assert os.is_abs_path(cxx) && os.is_file(cxx), 'invalid fixture C++ compiler: ${cxx}'
	return ['-cc', cc, '-c++', cxx]
}

fn build_interface_fn_v3() string {
	if os.is_executable(interface_fn_v3_bin) {
		return interface_fn_v3_bin
	}
	mut args := ['-old-compiler', '-gc', 'none']
	args << interface_fn_c_compiler_args()
	args << ['-path', '${interface_fn_vlib_dir}|@vlib|@vmodules', '-o', interface_fn_v3_bin,
		interface_fn_v3_src]
	build := cmdexec.run(@VEXE, args)
	assert build.exit_code == 0, build.output
	assert os.is_file(interface_fn_v3_bin), interface_fn_v3_bin
	return interface_fn_v3_bin
}

fn write_interface_fn_project() string {
	root := os.join_path(os.temp_dir(), 'v3_interface_fn_project_${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(os.join_path(root, 'core')) or { panic(err) }
	os.write_file(os.join_path(root, 'core', 'core.v'),
		'module core\n\npub interface EventData {}\n\npub interface Connector {\n\tconnect(handler fn (EventData))\n}\n\npub fn use_connector(connector Connector) {\n\tconnector.connect(fn (event EventData) {})\n}\n') or {
		panic(err)
	}
	os.write_file(os.join_path(root, 'main.v'),
		'module main\n\nimport core\n\nstruct App {}\n\nfn (app App) connect(handler fn (core.EventData)) {}\n\nfn main() {\n\tcore.use_connector(App{})\n\tprint("ok")\n}\n') or {
		panic(err)
	}
	return root
}

// https://github.com/vlang/v/issues/28042
fn test_interface_method_fn_parameter_uses_c_typedef() {
	v3_bin := build_interface_fn_v3()
	root := write_interface_fn_project()
	defer {
		os.rm(v3_bin) or {}
		os.rmdir_all(root) or {}
	}
	output := os.join_path(root, 'interface_fn_parameter')
	compile := os.execute('${os.quoted_path(v3_bin)} -nocache -b c -o ${os.quoted_path(output)} ${os.quoted_path(os.join_path(root,
		'main.v'))}')
	assert compile.exit_code == 0, compile.output
	assert !compile.output.contains('C compilation failed'), compile.output
	run := os.execute(os.quoted_path(output))
	assert run.exit_code == 0, run.output
	assert run.output == 'ok'
}

// Preserve the real implementation order: the first method key is the one
// considered by Cgen, including any existing snapshot order. Do not sort it.
fn interface_fn_reader_metadata(tc &types.TypeChecker, stage string) (string, bool) {
	mut report := '${stage}: homonym_metadata=${tc.interface_metadata_name('a_records.Reader')}\n'
	mut valid := tc.interface_metadata_name('a_records.Reader') == 'a_records.Reader'
	for iface in ['stream.Reader', 'a_records.LineReader'] {
		decl_key := tc.interface_method_signature_key(iface, 'read') or { '${iface}.read' }
		decl_params := tc.fn_param_types[decl_key] or { []types.Type{} }
		impls := tc.interface_impl_names(iface)
		mut first_key := ''
		for concrete in impls {
			key := '${concrete}.read'
			if key in tc.fn_param_types {
				first_key = key
				break
			}
		}
		first_params := tc.fn_param_types[first_key] or { []types.Type{} }
		report += '${stage}: iface=${iface} decl_key=${decl_key} decl_params=${decl_params} impls=${impls} first_key=${first_key} first_params=${first_params}\n'
		if ret := tc.fn_ret_types[decl_key] {
			report += '${stage}: decl_return=${ret}\n'
		}
		if ret := tc.fn_ret_types[first_key] {
			report += '${stage}: first_return=${ret}\n'
		}
		if iface == 'stream.Reader' {
			valid = valid && decl_params.len == 2 && 'a_records.Reader' !in impls
				&& 'z_memory.MemoryReader' in impls
		} else {
			valid = valid && decl_params.len == 1 && 'a_records.Reader' in impls
		}
	}
	return report, valid
}

// These are post-capture evidence limits, not process-output or time limits.
// The existing CI job supplies the process deadline; no runner is introduced.
fn interface_fn_capture_text(root string, name string, text string) bool {
	if text.len > 8 * 1024 * 1024 {
		eprintln('Reader evidence exceeds 8 MiB: ${name}')
		return false
	}
	os.write_file(os.join_path(root, name), text) or {
		eprintln('cannot write Reader evidence ${name}: ${err}')
		return false
	}
	return true
}

fn interface_fn_capture_c(root string, name string, source string) bool {
	if !os.is_file(source) || os.is_link(source) || os.file_size(source) > 8 * 1024 * 1024 {
		eprintln('missing, unsafe, or oversized Reader C evidence: ${source}')
		return false
	}
	content := os.read_file(source) or { return false }
	return interface_fn_capture_text(root, name, content)
}

fn test_homonymous_struct_does_not_replace_interface_method_signature() {
	root := os.join_path(os.vtmp_dir(), 'v3_reader_homonym_${os.getpid()}')
	os.mkdir_all(root) or { panic(err) }
	os.write_file(os.join_path(root, 'v.mod'), "Module { name: 'reader_homonym' }\n") or {
		panic(err)
	}
	files := {
		'a_records/records.v': 'module a_records

pub struct Reader {}

pub fn (reader Reader) read() ![]string {
	return [\'first\', \'second\']
}

pub interface LineReader {
	read() ![]string
}

pub fn read_lines(reader LineReader) ![]string {
	return reader.read()
}
'
		'stream/stream.v': 'module stream

pub interface Reader {
mut:
	read(mut buf []u8) !int
}

pub fn consume(mut reader Reader, mut buf []u8) !int {
	return reader.read(mut buf)
}
'
		'z_memory/memory.v': 'module z_memory

pub struct MemoryReader {}

pub fn (mut reader MemoryReader) read(mut buf []u8) !int {
	buf[0] = 42
	return 1
}
'
		'main.v': 'module main

import a_records
import stream
import z_memory

fn main() {
	lines := a_records.read_lines(a_records.Reader{}) or { panic(err) }
	if lines.len != 2 || lines[0] != \'first\' || lines[1] != \'second\' {
		panic(\'zero-argument Reader changed\')
	}
	mut reader := z_memory.MemoryReader{}
	mut buf := []u8{len: 1}
	n := stream.consume(mut reader, mut buf) or { panic(err) }
	if n != 1 || buf[0] != 42 {
		panic(\'mutable Reader argument changed\')
	}
	println(\'reader-homonym-ok\')
}
'
	}
	mut source_paths := []string{}
	mut fixture := "// v.mod\nModule { name: 'reader_homonym' }\n"
	for rel in ['a_records/records.v', 'stream/stream.v', 'z_memory/memory.v', 'main.v'] {
		path := os.join_path(root, rel)
		os.mkdir_all(os.dir(path)) or { panic(err) }
		os.write_file(path, files[rel]) or { panic(err) }
		source_paths << path
		fixture += '\n// ${rel}\n${files[rel]}'
	}
	runner_temp := os.getenv('RUNNER_TEMP')
	evidence_base := if runner_temp.len > 0 { runner_temp } else { os.vtmp_dir() }
	evidence := os.join_path(evidence_base, 'issue74-reader-evidence')
	assert !os.is_link(evidence), evidence
	os.mkdir_all(evidence) or { panic(err) }
	mut capture_ok := interface_fn_capture_text(evidence, 'fixture.txt', fixture)
	mut p := parser.Parser.new(pref.new_preferences())
	mut a := p.parse_files(source_paths)
	mut tc := types.TypeChecker.new(a)
	tc.collect(a)
	tc.annotate_types()
	before_report, before_ok := interface_fn_reader_metadata(&tc, 'before_transform')
	transform.transform(mut a, &tc)
	tc.annotate_types()
	after_report, after_ok := interface_fn_reader_metadata(&tc, 'after_transform')
	mut report := before_report + after_report
	v3_bin := build_interface_fn_v3()
	cc_args := interface_fn_c_compiler_args()
	selected_cc := os.getenv('ISSUE74_V3_DRIVER_TEST_CC')
	mut link_args := []string{}
	if selected_cc.replace('\\', '/').to_lower().ends_with('/ucrt64/bin/clang.exe') {
		fixture_lld_path := os.join_path(os.dir(selected_cc), 'ld.lld.exe')
		assert os.is_file(fixture_lld_path), 'missing selected LLVM linker: ${fixture_lld_path}'
		link_args = ['-ldflags', '-fuse-ld=lld']
	}
	old_vtmp := os.getenv('VTMP')
	defer {
		os.setenv('VTMP', old_vtmp, true)
	}
	mut passed := true
	for generation in ['v1', 'v3'] {
		generation_dir := os.join_path(root, generation)
		os.mkdir_all(generation_dir) or { panic(err) }
		os.setenv('VTMP', generation_dir, true)
		bin := interface_fn_executable(os.join_path(generation_dir, 'reader_homonym'))
		compiler := if generation == 'v1' { @VEXE } else { v3_bin }
		mut args := if generation == 'v1' { ['-old-compiler'] } else { []string{} }
		args << ['-gc', 'none', '-prod', '-showcc', '-keepc', '-no-retry-compilation', '-b', 'c']
		args << cc_args
		args << link_args
		args << ['-path', '${root}|${interface_fn_vlib_dir}|@vlib|@vmodules', '-o', bin,
			os.join_path(root, 'main.v')]
		command := cmdexec.display(compiler, args)
		compile := cmdexec.run(compiler, args)
		compile_log := '${command}\ncompile_rc=${compile.exit_code}\n${compile.output}'
		if !interface_fn_capture_text(evidence, '${generation}-compile.log', compile_log) {
			capture_ok = false
		}
		mut c_path := bin + '.c'
		if generation == 'v1' {
			candidates := os.ls(generation_dir) or { []string{} }
			mut matches := []string{}
			for candidate in candidates {
				if candidate.starts_with(os.file_name(bin) + '.') && candidate.ends_with('.tmp.c') {
					matches << os.join_path(generation_dir, candidate)
				}
			}
			c_path = if matches.len == 1 { matches[0] } else { '' }
		}
		if !interface_fn_capture_c(evidence, '${generation}.c', c_path) {
			capture_ok = false
		}
		mut run_code := -1
		mut run_output := 'not executed: compilation failed or executable missing\n'
		if compile.exit_code == 0 && os.is_file(bin) {
			run := cmdexec.run(bin, [])
			run_code = run.exit_code
			run_output = run.output
		}
		if !interface_fn_capture_text(evidence, '${generation}-run.log', 'run_rc=${run_code}\n${run_output}') {
			capture_ok = false
		}
		ok := compile.exit_code == 0 && run_code == 0
			&& run_output.replace('\r\n', '\n') == 'reader-homonym-ok\n'
		passed = passed && ok
		report += '${generation}: compile_rc=${compile.exit_code} run_rc=${run_code} passed=${ok} c=${c_path}\n'
	}
	// Eight text files, each <=8 MiB: no binaries and at most 64 MiB per artifact.
	report += 'metadata_before_ok=${before_ok} metadata_after_ok=${after_ok} capture_complete=${capture_ok}\n'
	if !interface_fn_capture_text(evidence, 'results.txt', report) {
		capture_ok = false
	}
	eprintln(report)
	assert capture_ok, 'Reader evidence capture failed; ${report}'
	assert before_ok && after_ok, report
	assert passed, report
}
