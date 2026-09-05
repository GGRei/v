import os
import v3.cmdexec

const sife_vexe = @VEXE
const sife_tests_dir = os.dir(@FILE)
const sife_v3_dir = os.dir(sife_tests_dir)
const sife_vlib_dir = os.dir(sife_v3_dir)
const sife_v3_src = os.join_path(sife_v3_dir, 'v3.v')

fn sife_c_compiler_args() []string {
	cc := os.getenv('ISSUE74_V3_DRIVER_TEST_CC')
	cxx := os.getenv('ISSUE74_V3_DRIVER_TEST_CXX')
	if cc.len == 0 && cxx.len == 0 {
		return []string{}
	}
	assert os.is_abs_path(cc) && os.is_file(cc), 'invalid fixture C compiler: ${cc}'
	assert os.is_abs_path(cxx) && os.is_file(cxx), 'invalid fixture C++ compiler: ${cxx}'
	return ['-cc', cc, '-c++', cxx]
}

fn sife_executable(path string) string {
	$if windows {
		return path + '.exe'
	}
	return path
}

fn sife_build_v3() string {
	pid := os.getpid()
	v3_bin := sife_executable(os.join_path(os.temp_dir(), 'v3_struct_init_embed_fixed_array_test_${pid}'))
	os.rm(v3_bin) or {}
	mut args := ['-old-compiler', '-gc', 'none']
	args << sife_c_compiler_args()
	args << ['-path', '${sife_vlib_dir}|@vlib|@vmodules', '-o', v3_bin, sife_v3_src]
	build := cmdexec.run(sife_vexe, args)
	assert build.exit_code == 0, build.output
	assert os.is_file(v3_bin), v3_bin
	return v3_bin
}

fn sife_write_file(root string, rel string, source string) {
	path := os.join_path(root, rel)
	os.mkdir_all(os.dir(path)) or { panic(err) }
	os.write_file(path, source) or { panic(err) }
}

fn sife_run_project(v3_bin string, name string, files map[string]string) string {
	pid := os.getpid()
	root := os.join_path(os.temp_dir(), 'v3_${name}_${pid}_project')
	os.rmdir_all(root) or {}
	os.mkdir_all(root) or { panic(err) }
	os.write_file(os.join_path(root, 'v.mod'), "Module { name: '${name}' }\n") or { panic(err) }
	for rel, source in files {
		sife_write_file(root, rel, source)
	}
	bin := sife_executable(os.join_path(os.temp_dir(), 'v3_${name}_${pid}'))
	mut args := sife_c_compiler_args()
	args << ['-b', 'c', '-o', bin, os.join_path(root, 'main.v')]
	compile := cmdexec.run(v3_bin, args)
	assert compile.exit_code == 0, compile.output
	assert !compile.output.contains('C compilation failed'), compile.output
	run := cmdexec.run(bin, [])
	assert run.exit_code == 0, run.output
	return run.output.trim_space()
}

// A struct that both embeds a type and has a fixed-array field routes its initializer through
// the fixed-array helper (a compound literal plus a memcpy tail, because C compound literals
// cannot assign array members). The embedded-field key (`Ctx: c`) is a short name whose C field
// name comes from the embed type (`base__Ctx`), not the source key, and it is not in the
// helper's `allowed_fields` set. Without mirroring the embedded-key branch in the fixed-array
// helper the embed initializer is dropped (or emitted under a non-existent `.Ctx` designator),
// leaving the embedded struct at its defaults. Here the embed carries `code: 9`, so a dropped
// initializer would surface as `code=0`.
fn test_struct_init_embed_plus_fixed_array_sets_both() {
	v3_bin := sife_build_v3()
	out := sife_run_project(v3_bin, 'struct_init_embed_fixed_array', {
		'base/base.v': 'module base\n\npub struct Ctx {\npub mut:\n\tcode int\n}\n'
		'main.v':      "module main\n\nimport base\n\nstruct Outer {\n\tbase.Ctx\nmut:\n\tids [2]int\n}\n\nfn main() {\n\tc := base.Ctx{\n\t\tcode: 9\n\t}\n\to := Outer{\n\t\tCtx:  c\n\t\tids:  [4, 5]!\n\t}\n\tprintln('code=\${o.code} ids=\${o.ids[0]},\${o.ids[1]}')\n}\n"
	})
	assert out == 'code=9 ids=4,5'
}

// This capture limit applies after cmdexec has collected the process output.
// Process duration is bounded by the existing CI job, not by a new test runner.
fn sife_capture_text(root string, name string, text string) bool {
	if text.len > 8 * 1024 * 1024 {
		eprintln('fixed-array evidence exceeds 8 MiB: ${name}')
		return false
	}
	os.write_file(os.join_path(root, name), text) or {
		eprintln('cannot write fixed-array evidence ${name}: ${err}')
		return false
	}
	return true
}

fn sife_capture_c(root string, name string, source string) bool {
	if !os.is_file(source) || os.is_link(source) || os.file_size(source) > 8 * 1024 * 1024 {
		eprintln('missing, unsafe, or oversized fixed-array C evidence: ${source}')
		return false
	}
	content := os.read_file(source) or { return false }
	return sife_capture_text(root, name, content)
}

fn test_struct_fixed_array_declared_defaults_survive_result_fallback() {
	root := os.join_path(os.vtmp_dir(), 'v3_fixed_array_declared_defaults_${os.getpid()}')
	os.mkdir_all(root) or { panic(err) }
	runner_temp := os.getenv('RUNNER_TEMP')
	evidence_base := if runner_temp.len > 0 { runner_temp } else { os.vtmp_dir() }
	evidence := os.join_path(evidence_base, 'issue74-fixed-array-evidence')
	assert !os.is_link(evidence), evidence
	os.mkdir_all(evidence) or { panic(err) }
	source := 'struct Shape {
	transform [6]f32 = [f32(1), 0, 0, 1, 0, 0]!
	labels [2]string = [\'a\', \'b\']!
}

fn absent() !Shape {
	return error(\'missing\')
}

fn main() {
	direct := Shape{}
	assert direct.transform[0] == 1 && direct.transform[3] == 1
	assert direct.labels[0] == \'a\' && direct.labels[1] == \'b\'
	explicit := Shape{
		transform: [f32(2), 0, 0, 2, 0, 0]!
		labels: [\'x\', \'y\']!
	}
	assert explicit.transform[0] == 2 && explicit.transform[3] == 2
	assert explicit.labels[0] == \'x\' && explicit.labels[1] == \'y\'
	fallback := absent() or { Shape{} }
	assert fallback.transform[0] == 1 && fallback.transform[3] == 1
	assert fallback.labels[0] == \'a\' && fallback.labels[1] == \'b\'
	println(\'fixed-default-ok\')
}
'
	source_path := os.join_path(root, 'main.v')
	os.write_file(source_path, source) or { panic(err) }
	mut capture_ok := sife_capture_text(evidence, 'fixture.v', source)
	v3_bin := sife_build_v3()
	cc_args := sife_c_compiler_args()
	old_vtmp := os.getenv('VTMP')
	defer {
		os.setenv('VTMP', old_vtmp, true)
	}
	mut report := 'compiler_source=${sife_v3_src}\nfixture=${source_path}\n'
	mut passed := true
	for generation in ['v1', 'v3'] {
		generation_dir := os.join_path(root, generation)
		os.mkdir_all(generation_dir) or { panic(err) }
		os.setenv('VTMP', generation_dir, true)
		bin := sife_executable(os.join_path(generation_dir, 'fixed_defaults'))
		compiler := if generation == 'v1' { sife_vexe } else { v3_bin }
		mut args := if generation == 'v1' { ['-old-compiler'] } else { []string{} }
		args << ['-gc', 'none', '-prod', '-showcc', '-keepc', '-no-retry-compilation', '-b', 'c']
		args << cc_args
		args << ['-path', '${sife_vlib_dir}|@vlib|@vmodules', '-o', bin, source_path]
		command := cmdexec.display(compiler, args)
		compile := cmdexec.run(compiler, args)
		compile_log := '${command}\ncompile_rc=${compile.exit_code}\n${compile.output}'
		if !sife_capture_text(evidence, '${generation}-compile.log', compile_log) {
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
		if !sife_capture_c(evidence, '${generation}.c', c_path) {
			capture_ok = false
		}
		mut run_code := -1
		mut run_output := 'not executed: compilation failed or executable missing\n'
		if compile.exit_code == 0 && os.is_file(bin) {
			run := cmdexec.run(bin, [])
			run_code = run.exit_code
			run_output = run.output
		}
		if !sife_capture_text(evidence, '${generation}-run.log', 'run_rc=${run_code}\n${run_output}') {
			capture_ok = false
		}
		ok := compile.exit_code == 0 && run_code == 0
			&& run_output.replace('\r\n', '\n') == 'fixed-default-ok\n'
		passed = passed && ok
		report += '${generation}: compile_rc=${compile.exit_code} run_rc=${run_code} passed=${ok} c=${c_path}\n'
	}
	// Exactly eight text files, each <=8 MiB: the artifact total is <=64 MiB.
	report += 'capture_complete=${capture_ok}\n'
	if !sife_capture_text(evidence, 'results.txt', report) {
		capture_ok = false
	}
	eprintln(report)
	assert capture_ok, 'fixed-array evidence capture failed; ${report}'
	assert passed, report
}
