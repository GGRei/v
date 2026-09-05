import os
import rand
import v3.cmdexec

const for_in_review_vexe = @VEXE
const for_in_review_tests_dir = os.dir(@FILE)
const for_in_review_v3_dir = os.dir(for_in_review_tests_dir)
const for_in_review_vlib_dir = os.dir(for_in_review_v3_dir)
const for_in_review_v3_src = os.join_path(for_in_review_v3_dir, 'v3.v')

fn for_in_review_v3_bin_path() string {
	return for_in_review_executable(os.join_path(os.temp_dir(), 'v3_for_in_review_test'))
}

fn for_in_review_executable(path string) string {
	$if windows {
		return path + '.exe'
	}
	return path
}

fn for_in_review_c_compiler_args() []string {
	cc := os.getenv('ISSUE74_V3_DRIVER_TEST_CC')
	cxx := os.getenv('ISSUE74_V3_DRIVER_TEST_CXX')
	if cc.len == 0 && cxx.len == 0 {
		return []string{}
	}
	assert os.is_abs_path(cc) && os.is_file(cc), 'invalid fixture C compiler: ${cc}'
	assert os.is_abs_path(cxx) && os.is_file(cxx), 'invalid fixture C++ compiler: ${cxx}'
	return ['-cc', cc, '-c++', cxx]
}

fn testsuite_begin() {
	v3_bin := for_in_review_v3_bin_path()
	if os.exists(v3_bin) {
		os.rm(v3_bin) or {}
	}
}

fn build_v3_for_in_review() string {
	v3_bin := for_in_review_v3_bin_path()
	if os.exists(v3_bin) {
		return v3_bin
	}
	mut args := ['-old-compiler', '-gc', 'none']
	args << for_in_review_c_compiler_args()
	args << ['-path', '${for_in_review_vlib_dir}|@vlib|@vmodules', '-o', v3_bin,
		for_in_review_v3_src]
	build := cmdexec.run(for_in_review_vexe, args)
	assert build.exit_code == 0, build.output
	assert os.is_file(v3_bin), v3_bin
	return v3_bin
}

fn for_in_review_temp_path(name string) string {
	return os.join_path(os.temp_dir(), 'v3_${name}_${os.getpid()}_${rand.ulid()}')
}

fn for_in_review_run_good(v3_bin string, name string, src string) string {
	out := for_in_review_temp_path(name)
	src_path := out + '.v'
	os.write_file(src_path, src) or { panic(err) }
	compile := os.execute('${v3_bin} ${src_path} -b c -o ${out}')
	assert compile.exit_code == 0, '${name}: compile failed\n${compile.output}'
	assert !compile.output.contains('C compilation failed'), '${name}: C compilation failed\n${compile.output}'
	run := os.execute(out)
	assert run.exit_code == 0, '${name}: run failed\n${run.output}'
	return run.output.trim_space()
}

fn for_in_review_run_bad(v3_bin string, name string, src string, expected string) {
	out := for_in_review_temp_path(name)
	src_path := out + '.v'
	os.write_file(src_path, src) or { panic(err) }
	result := os.execute('${v3_bin} ${src_path} -b c -o ${out}')
	assert result.exit_code != 0, '${name}: expected failure, got success\n${result.output}'
	assert result.output.contains(expected), '${name}: expected `${expected}` in\n${result.output}'
	assert !result.output.contains('C compilation failed'), '${name}: reached C compilation\n${result.output}'
}

fn test_pointer_conditions_reject_plain_if_and_for() {
	v3_bin := build_v3_for_in_review()
	for_in_review_run_bad(v3_bin, 'pointer_if_condition',
		'fn main() {\n\tx := 1\n\tp := &x\n\tif p {\n\t\tprintln("bad")\n\t}\n}\n',
		'non-bool type `&int` used as if condition')
	for_in_review_run_bad(v3_bin, 'pointer_for_condition',
		'fn main() {\n\tx := 1\n\tp := &x\n\tfor p {\n\t\tbreak\n\t}\n}\n',
		'if condition must be `bool`, not `&int`')
}

fn test_c_style_for_accepts_pointer_condition() {
	v3_bin := build_v3_for_in_review()
	out := for_in_review_run_good(v3_bin, 'c_style_pointer_condition',
		'fn main() {\n\tmut x := 1\n\tmut p := &x\n\tmut count := 0\n\tfor ; p; p = unsafe { nil } {\n\t\tcount++\n\t}\n\tprintln(count)\n}\n')
	assert out == '1'
}

fn test_optional_array_for_in_skips_none_payload() {
	v3_bin := build_v3_for_in_review()
	out := for_in_review_run_good(v3_bin, 'optional_array_for_in_guard',
		'fn maybe_values(ok bool) ?[]int {\n\tif !ok {\n\t\treturn none\n\t}\n\treturn [1, 2, 3]\n}\n\nfn main() {\n\tmut total := 0\n\tfor value in maybe_values(false) {\n\t\ttotal += value\n\t}\n\tprintln(int_str(total))\n\tfor value in maybe_values(true) {\n\t\ttotal += value\n\t}\n\tprintln(int_str(total))\n}\n')
	assert out == '0\n6'
}

fn test_optional_map_for_in_is_rejected_before_codegen() {
	v3_bin := build_v3_for_in_review()
	for_in_review_run_bad(v3_bin, 'optional_map_for_in',
		'fn maybe_values() ?map[string]int {\n\treturn none\n}\n\nfn main() {\n\tfor key, value in maybe_values() {\n\t\tprintln(key + int_str(value))\n\t}\n}\n',
		'for in: cannot index `?map[string]int`')
}

fn test_values_copied_from_temporary_map_remain_valid() {
	v3_bin := build_v3_for_in_review()
	out := for_in_review_run_good(v3_bin, 'temporary_map_for_in_value_lifetime',
		"fn entries(lang string) map[string]string {\n\treturn {'message': lang.repeat(64)}\n}\n\nfn main() {\n\tmut translations := map[string]map[string]string{}\n\tfor lang in ['en', 'fr', 'de', 'es'] {\n\t\tfor key, value in entries(lang) {\n\t\t\ttranslations[lang][key] = value\n\t\t}\n\t}\n\tprintln(translations['en']['message'] == 'en'.repeat(64))\n}\n")
	assert out == 'true'
}

fn test_custom_iterator_pointer_for_in_uses_single_indirection() {
	v3_bin := build_v3_for_in_review()
	out := for_in_review_run_good(v3_bin, 'custom_iterator_pointer',
		'struct Counter {\nmut:\n\tn int\n}\n\nfn (mut c Counter) next() ?int {\n\tif c.n >= 3 {\n\t\treturn none\n\t}\n\tc.n++\n\treturn c.n\n}\n\nfn main() {\n\tmut c := Counter{}\n\tfor x in &c {\n\t\tprintln(x)\n\t}\n\tprintln("count: \${c.n}")\n}\n')
	assert out == '1\n2\n3\ncount: 3'
}

// Evidence bounds apply after capture. Process deadlines remain the existing
// CI job deadlines; these helpers do not introduce a process-output limiter.
fn for_in_review_capture_text(root string, name string, text string) bool {
	if text.len > 8 * 1024 * 1024 {
		eprintln('ReverseIterator evidence exceeds 8 MiB: ${name}')
		return false
	}
	os.write_file(os.join_path(root, name), text) or {
		eprintln('cannot write ReverseIterator evidence ${name}: ${err}')
		return false
	}
	return true
}

fn for_in_review_capture_c(root string, name string, source string) bool {
	if !os.is_file(source) || os.is_link(source) || os.file_size(source) > 8 * 1024 * 1024 {
		eprintln('missing, unsafe, or oversized ReverseIterator C evidence: ${source}')
		return false
	}
	content := os.read_file(source) or { return false }
	return for_in_review_capture_text(root, name, content)
}

fn test_reverse_iterator_preserves_parameter_and_recursive_field_element_types() {
	root := for_in_review_temp_path('reverse_iterator_types')
	os.mkdir_all(root) or { panic(err) }
	source := 'import arrays

struct Item {
	id int
}

struct Node {
	id int
	children []Node
}

fn item_id(item &Item) int {
	return item.id
}

fn node_id(node &Node) int {
	return node.id
}

fn parameter_order(items []Item) int {
	mut order := 0
	for item in arrays.reverse_iterator(items) {
		order = order * 10 + item_id(item)
	}
	return order
}

fn field_order(node &Node) int {
	mut order := 0
	for child in arrays.reverse_iterator(node.children) {
		order = order * 10 + node_id(child)
	}
	return order
}

fn main() {
	if parameter_order([Item{id: 1}, Item{id: 2}, Item{id: 3}]) != 321 {
		panic(\'parameter reverse order changed\')
	}
	root := Node{children: [Node{id: 4}, Node{id: 5}, Node{id: 6}]}
	if field_order(&root) != 654 {
		panic(\'recursive field reverse order changed\')
	}
	if parameter_order([]Item{}) != 0 || field_order(&Node{}) != 0 {
		panic(\'empty reverse iteration changed\')
	}
	println(\'reverse-iterator-types-ok\')
}
'
	source_path := os.join_path(root, 'main.v')
	os.write_file(source_path, source) or { panic(err) }
	runner_temp := os.getenv('RUNNER_TEMP')
	evidence_base := if runner_temp.len > 0 { runner_temp } else { os.vtmp_dir() }
	evidence := os.join_path(evidence_base, 'issue74-reverse-iterator-evidence')
	assert !os.is_link(evidence), evidence
	os.mkdir_all(evidence) or { panic(err) }
	mut capture_ok := for_in_review_capture_text(evidence, 'fixture.txt', source)
	v3_bin := build_v3_for_in_review()
	cc_args := for_in_review_c_compiler_args()
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
	mut report := ''
	for generation in ['v1', 'v3'] {
		generation_dir := os.join_path(root, generation)
		os.mkdir_all(generation_dir) or { panic(err) }
		os.setenv('VTMP', generation_dir, true)
		bin := for_in_review_executable(os.join_path(generation_dir, 'reverse_iterator_types'))
		compiler := if generation == 'v1' { for_in_review_vexe } else { v3_bin }
		mut args := if generation == 'v1' { ['-old-compiler'] } else { []string{} }
		args << ['-gc', 'none', '-prod', '-showcc', '-keepc', '-no-retry-compilation', '-b', 'c']
		args << cc_args
		args << link_args
		args << ['-path', '${for_in_review_vlib_dir}|@vlib|@vmodules', '-o', bin, source_path]
		command := cmdexec.display(compiler, args)
		compile := cmdexec.run(compiler, args)
		compile_log := '${command}\ncompile_rc=${compile.exit_code}\n${compile.output}'
		if !for_in_review_capture_text(evidence, '${generation}-compile.log', compile_log) {
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
		if !for_in_review_capture_c(evidence, '${generation}.c', c_path) {
			capture_ok = false
		}
		mut run_code := -1
		mut run_output := 'not executed: compilation failed or executable missing\n'
		if compile.exit_code == 0 && os.is_file(bin) {
			run := cmdexec.run(bin, [])
			run_code = run.exit_code
			run_output = run.output
		}
		if !for_in_review_capture_text(evidence, '${generation}-run.log', 'run_rc=${run_code}\n${run_output}') {
			capture_ok = false
		}
		ok := compile.exit_code == 0 && run_code == 0
			&& run_output.replace('\r\n', '\n') == 'reverse-iterator-types-ok\n'
		passed = passed && ok
		report += '${generation}: compile_rc=${compile.exit_code} run_rc=${run_code} passed=${ok} c=${c_path}\n'
	}
	// Eight text files, each <=8 MiB: no binaries and at most 64 MiB per artifact.
	report += 'capture_complete=${capture_ok}\n'
	if !for_in_review_capture_text(evidence, 'results.txt', report) {
		capture_ok = false
	}
	eprintln(report)
	assert capture_ok, 'ReverseIterator evidence capture failed; ${report}'
	assert passed, report
}
