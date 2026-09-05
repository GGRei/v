import os
import v3.cmdexec
import v3.flat
import v3.parser
import v3.pref
import v3.transform
import v3.types

const global_decl_vexe = @VEXE
const global_decl_tests_dir = os.dir(@FILE)
const global_decl_v3_dir = os.dir(global_decl_tests_dir)
const global_decl_vlib_dir = os.dir(global_decl_v3_dir)
const global_decl_v3_src = os.join_path(global_decl_v3_dir, 'v3.v')

fn global_decl_build_v3() string {
	v3_bin := global_decl_executable(os.join_path(os.temp_dir(), 'v3_global_decl_codegen_test'))
	os.rm(v3_bin) or {}
	mut args := ['-old-compiler', '-gc', 'none']
	args << global_decl_c_compiler_args()
	args << ['-path', '${global_decl_vlib_dir}|@vlib|@vmodules', '-o', v3_bin,
		global_decl_v3_src]
	build := cmdexec.run(global_decl_vexe, args)
	assert build.exit_code == 0, build.output
	assert os.is_file(v3_bin), v3_bin
	return v3_bin
}

fn global_decl_executable(path string) string {
	$if windows {
		return path + '.exe'
	}
	return path
}

fn global_decl_c_compiler_args() []string {
	cc := os.getenv('ISSUE74_V3_DRIVER_TEST_CC')
	cxx := os.getenv('ISSUE74_V3_DRIVER_TEST_CXX')
	if cc.len == 0 && cxx.len == 0 {
		return []string{}
	}
	assert os.is_abs_path(cc) && os.is_file(cc), 'invalid fixture C compiler: ${cc}'
	assert os.is_abs_path(cxx) && os.is_file(cxx), 'invalid fixture C++ compiler: ${cxx}'
	return ['-cc', cc, '-c++', cxx]
}

fn global_decl_run_good(v3_bin string, name string, source string) string {
	src := os.join_path(os.temp_dir(), 'v3_${name}.v')
	os.write_file(src, source) or { panic(err) }
	bin := os.join_path(os.temp_dir(), 'v3_${name}')
	compile := os.execute('${v3_bin} -enable-globals ${src} -b c -o ${bin}')
	assert compile.exit_code == 0, compile.output
	assert !compile.output.contains('C compilation failed'), compile.output
	run := os.execute(bin)
	assert run.exit_code == 0, run.output
	return run.output.trim_space()
}

fn global_decl_generate_c(v3_bin string, name string, source string) string {
	src := os.join_path(os.temp_dir(), 'v3_${name}.v')
	c_path := os.join_path(os.temp_dir(), 'v3_${name}.c')
	os.write_file(src, source) or { panic(err) }
	generate := os.execute('${v3_bin} -enable-globals -cc clang -o ${c_path} ${src}')
	assert generate.exit_code == 0, generate.output
	return os.read_file(c_path) or { panic(err) }
}

fn test_typed_global_initializers_in_group_keep_type_and_value() {
	v3_bin := global_decl_build_v3()
	out := global_decl_run_good(v3_bin, 'typed_global_initializers_in_group',
		'import sync.stdatomic\n\n__global (\n\tfirst_flag &stdatomic.AtomicVal[bool] = stdatomic.new_atomic(false)\n\tsecond_flag &stdatomic.AtomicVal[bool] = stdatomic.new_atomic(false)\n)\n\nfn main() {\n\tfirst_flag.store(true)\n\tprintln(first_flag.load())\n\tprintln(second_flag.load())\n\tsecond_flag.store(true)\n\tprintln(second_flag.load())\n}\n')
	assert out == 'true\nfalse\ntrue'
}

fn test_implicit_global_dynamic_array_is_initialized_before_append() {
	v3_bin := global_decl_build_v3()
	out := global_decl_run_good(v3_bin, 'implicit_global_dynamic_array',
		"struct Entry {\n\tname string\n}\n\n__global entries []Entry\n\nfn main() {\n\tentries << Entry{name: 'ok'}\n\tprintln(entries[0].name)\n}\n")
	assert out == 'ok'
}

fn test_implicit_global_containers_keep_synthesized_runtime_helpers() {
	v3_bin := global_decl_build_v3()
	out := global_decl_run_good(v3_bin, 'implicit_global_container_helpers',
		"__global names []string\n__global lookup map[string]int\n\nfn main() {\n\tprintln('ok')\n}\n")
	assert out == 'ok'
}

fn test_global_runtime_initializers_preserve_channels_arrays_and_fn_values() {
	v3_bin := global_decl_build_v3()
	out := global_decl_run_good(v3_bin, 'global_runtime_initializers',
		"__global (\n\tch chan int\n\tvalues = []int{len: 3, init: 7}\n\tcallback = fn (n int) int {\n\t\treturn n + 1\n\t}\n)\n\nfn send_value() {\n\tch <- 9\n}\n\nfn main() {\n\tt := spawn send_value()\n\tgot := <-ch\n\tt.wait()\n\tprintln(int_str(got))\n\tprintln(int_str(values.len) + ':' + int_str(values[2]))\n\tprintln(int_str(callback(4)))\n}\n")
	assert out == '9\n3:7\n5'
}

fn test_explicit_shared_and_fixed_array_global_initializers() {
	v3_bin := global_decl_build_v3()
	out := global_decl_run_good(v3_bin, 'shared_and_fixed_array_global_initializers',
		"struct Counter {\n\tvalue int\n}\n\n__global counter shared Counter = Counter{value: 7}\n__global fixed_values shared [2]int = [3, 4]!\n__global values = [][2]int{len: 1, init: [1, 2]!}\n\nfn main() {\n\tvalue := rlock counter {\n\t\tcounter.value\n\t}\n\tfixed_value := rlock fixed_values {\n\t\tfixed_values[0] * 10 + fixed_values[1]\n\t}\n\tprintln(int_str(value))\n\tprintln(int_str(fixed_value))\n\tprintln(int_str(values[0][0]) + ':' + int_str(values[0][1]))\n}\n")
	assert out == '7\n34\n1:2'
}

fn test_aliased_fixed_array_global_initializer_uses_copy() {
	v3_bin := global_decl_build_v3()
	out := global_decl_run_good(v3_bin, 'aliased_fixed_array_global_initializer',
		'type Pair = [2]int\n\n__global pair Pair = [2]int{init: 7}\n\nfn main() {\n\tprintln(int_str(pair[0]) + ":" + int_str(pair[1]))\n}\n')
	assert out == '7:7'
}

fn test_explicit_shared_array_constructor_preserves_length_capacity_and_initializer() {
	v3_bin := global_decl_build_v3()
	out := global_decl_run_good(v3_bin, 'shared_array_constructor_initializer', "__global values shared []int = []int{len: 2, cap: 4, init: 7}

fn main() {
	summary := rlock values {
		int_str(values.len) + ':' + int_str(values.cap) + ':' + int_str(values[0]) + ':' + int_str(values[1])
	}
	println(summary)
}
")
	assert out == '2:4:7:7'
}

fn test_shared_array_literal_preserves_left_to_right_evaluation() {
	v3_bin := global_decl_build_v3()
	source := '__global sequence int
__global values shared []int = [next(1), next(2)]

fn next(digit int) int {
	sequence = sequence * 10 + digit
	return sequence
}

fn main() {
	summary := rlock values {
		int_str(values[0]) + ":" + int_str(values[1])
	}
	println(summary + ":" + int_str(sequence))
}
'
	c_source := global_decl_generate_c(v3_bin, 'shared_array_literal_eval_order', source)
	assert c_source.contains('array_get(values->val, 0)) = next(1);'), c_source
	assert c_source.contains('array_get(values->val, 1)) = next(2);'), c_source
	out := global_decl_run_good(v3_bin, 'shared_array_literal_eval_order', source)
	assert out == '1:12:12'
}

fn test_implicit_shared_fixed_array_container_elements_are_initialized() {
	v3_bin := global_decl_build_v3()
	out := global_decl_run_good(v3_bin, 'implicit_shared_fixed_array_containers', "struct Config {
	value int = 7
}

__global slots shared [2]map[string]int
__global lists shared [2][]int
__global configs shared [2]Config

fn main() {
	lock slots {
		slots[0]['k'] = 1
	}
	lock lists {
		lists[1] << 2
	}
	map_value := rlock slots {
		slots[0]['k']
	}
	array_value := rlock lists {
		lists[1][0]
	}
	default_value := rlock configs {
		configs[0].value
	}
	println(int_str(map_value) + ':' + int_str(array_value) + ':' + int_str(default_value))
}
")
	assert out == '1:2:7'
}

fn test_global_array_initializers_fill_runtime_defaults() {
	v3_bin := global_decl_build_v3()
	out := global_decl_run_good(v3_bin, 'global_array_runtime_defaults',
		"struct Config {\nmut:\n\tretries int = 7\n\tnames []string\n\tscores map[string]int\n}\n\n__global configs = []Config{len: 2}\n__global nested = [][]int{len: 2}\n__global lookups = []map[string]int{len: 2}\n\nfn main() {\n\tconfigs[0].names << 'ok'\n\tconfigs[0].scores['x'] = 5\n\tnested[0] << 9\n\tlookups[0]['x'] = 11\n\tprintln(int_str(configs[0].retries))\n\tprintln(configs[0].names[0])\n\tprintln(int_str(configs[0].scores['x']))\n\tprintln(int_str(nested[0][0]))\n\tprintln(int_str(lookups[0]['x']))\n\tprintln(int_str(configs[1].names.len) + ':' + int_str(configs[1].scores.len) + ':' + int_str(nested[1].len) + ':' + int_str(lookups[1].len))\n}\n")
	assert out == '7\nok\n5\n9\n11\n0:0:0:0'
}

fn test_global_arrays_fill_nested_fixed_array_defaults() {
	v3_bin := global_decl_build_v3()
	out := global_decl_run_good(v3_bin, 'global_nested_fixed_array_defaults',
		"struct Config {\nmut:\n\tretries int = 7\n\tnames []string\n\tscores map[string]int\n}\n\n__global rows = [][2]map[string]int{len: 1}\n__global config_rows = [][2]Config{len: 1}\n__global grids = [][2][2]map[string]int{len: 1}\n\nfn main() {\n\trows[0][0]['x'] = 13\n\tconfig_rows[0][0].names << 'fixed'\n\tconfig_rows[0][0].scores['x'] = 17\n\tgrids[0][1][1]['x'] = 19\n\tprintln(int_str(rows[0][0]['x']))\n\tprintln(int_str(config_rows[0][0].retries) + ':' + config_rows[0][0].names[0] + ':' + int_str(config_rows[0][0].scores['x']))\n\tprintln(int_str(grids[0][1][1]['x']))\n\tprintln(int_str(rows[0][1].len) + ':' + int_str(config_rows[0][1].retries) + ':' + int_str(grids[0][0][0].len))\n}\n")
	assert out == '13\n7:fixed:17\n19\n0:7:0'
}

fn test_global_array_initializer_call_preserves_fixed_array_elements() {
	v3_bin := global_decl_build_v3()
	out := global_decl_run_good(v3_bin, 'global_fixed_array_elements_from_call',
		"fn make_rows() [][2]int {\n\treturn [[1, 2]!, [3, 4]!]\n}\n\n__global rows = make_rows()\n\nfn main() {\n\tprintln(int_str(rows[0][0]) + ':' + int_str(rows[0][1]))\n\tprintln(int_str(rows[1][0]) + ':' + int_str(rows[1][1]))\n}\n")
	assert out == '1:2\n3:4'
}

fn test_global_channel_containers_are_initialized() {
	v3_bin := global_decl_build_v3()
	out := global_decl_run_good(v3_bin, 'global_channel_containers', '__global channels = []chan int{len: 1}
__global events shared chan int

fn send_value_to(channel chan int, value int) {
	channel <- value
}

fn main() {
	array_channel := channels[0]
	array_thread := spawn send_value_to(array_channel, 11)
	println(int_str(<-array_channel))
	array_thread.wait()

	shared_channel := rlock events {
		events
	}
	shared_thread := spawn send_value_to(shared_channel, 13)
	println(int_str(<-shared_channel))
	shared_thread.wait()
}
')
	assert out == '11\n13'
}

fn test_global_enum_and_sum_values_use_v_defaults() {
	v3_bin := global_decl_build_v3()
	out := global_decl_run_good(v3_bin, 'global_enum_and_sum_defaults', "enum Mode {
	ready = 7
	waiting
}

type Payload = string | int

__global modes = []Mode{len: 2}
__global shared_mode shared Mode
__global payloads = []Payload{len: 1}
__global payload shared Payload

fn describe(value Payload) string {
	return match value {
		string { 'string:' + value }
		int { 'int:' + int_str(value) }
	}
}

fn main() {
	println(if modes[0] == .ready { 'ready' } else { 'wrong' })
	shared_mode_description := rlock shared_mode {
		if shared_mode == .ready { 'shared-ready' } else { 'shared-wrong' }
	}
	println(shared_mode_description)
	println(describe(payloads[0]))
	shared_description := rlock payload {
		describe(payload)
	}
	println(shared_description)
}
")
	assert out == 'ready\nshared-ready\nstring:\nstring:'
}

// Observation only: report absent annotations instead of resolving new types
// or failing before the native V1 and V3 captures have both been collected.
fn global_decl_padding_nodes(a &flat.FlatAst, tc &types.TypeChecker, id flat.NodeId, stage string, owner string) string {
	node := a.node(id)
	mut report := ''
	if node.kind in [.ident, .selector, .if_expr, .decl_assign] {
		cached := if typ := tc.expr_type(id) { typ.name() } else { '<none>' }
		annotation := if node.typ.len > 0 { node.typ } else { '<none>' }
		report += '${stage}: fn=${owner} node=${int(id)} kind=${node.kind} value=${node.value} annotation=${annotation} cached=${cached}\n'
	}
	for child in a.children_of(node) {
		report += global_decl_padding_nodes(a, tc, child, stage, owner)
	}
	return report
}

fn global_decl_padding_metadata(a &flat.FlatAst, tc &types.TypeChecker, stage string) (string, bool) {
	mut report := ''
	mut present := true
	for name in ['panel.inferred_theme', 'panel.typed_theme'] {
		if typ := tc.file_scope.lookup(name) {
			report += '${stage}: global=${name} type=${typ.name()}\n'
		} else {
			report += '${stage}: global=${name} type=<missing>\n'
			present = false
		}
	}
	if typ := tc.const_types['panel.theme_defaults'] {
		report += '${stage}: const=panel.theme_defaults type=${typ.name()}\n'
	} else {
		report += '${stage}: const=panel.theme_defaults type=<missing>\n'
		present = false
	}
	if fields := tc.structs['panel.Theme'] {
		for field in fields {
			report += '${stage}: struct=panel.Theme field=${field.name} type=${field.typ.name()}\n'
		}
	} else {
		report += '${stage}: struct=panel.Theme fields=<missing>\n'
		present = false
	}
	// Visit only current top-level file children, not detached old fn nodes
	// remaining in the arena after lowering. This is not driver parse order.
	for name in ['inferred_row', 'inferred_column', 'typed_row'] {
		mut matches := 0
		for file_node in a.nodes {
			if file_node.kind != .file {
				continue
			}
			for child in a.children_of(&file_node) {
				node := a.node(child)
				if node.kind == .fn_decl && node.value.all_after_last('.') == name {
					matches++
					report += '${stage}: fn=${name} source=${file_node.value}\n'
					report += global_decl_padding_nodes(a, tc, child, stage, name)
				}
			}
		}
		report += '${stage}: fn=${name} roots=${matches}\n'
		present = present && matches == 1
	}
	return report, present
}

// Evidence bounds apply after capture. The existing CI job supplies process
// deadlines; these helpers do not introduce a process-output limiter.
fn global_decl_capture_text(root string, name string, text string) bool {
	if text.len > 8 * 1024 * 1024 {
		eprintln('Padding evidence exceeds 8 MiB: ${name}')
		return false
	}
	os.write_file(os.join_path(root, name), text) or {
		eprintln('cannot write Padding evidence ${name}: ${err}')
		return false
	}
	return true
}

fn global_decl_capture_c(root string, name string, source string) bool {
	if !os.is_file(source) || os.is_link(source) || os.file_size(source) > 8 * 1024 * 1024 {
		eprintln('missing, unsafe, or oversized Padding C evidence: ${source}')
		return false
	}
	content := os.read_file(source) or { return false }
	return global_decl_capture_text(root, name, content)
}

fn test_inferred_global_if_padding_preserves_nominal_type() {
	root := os.join_path(os.vtmp_dir(), 'v3_global_padding_${os.getpid()}')
	os.mkdir_all(root) or { panic(err) }
	module_text := "Module { name: 'global_padding' }\n"
	os.write_file(os.join_path(root, 'v.mod'), module_text) or { panic(err) }
	files := {
		'panel/_globals.v': '@[has_globals]
module panel

__global inferred_theme = theme_defaults
__global typed_theme = Theme{medium: theme_defaults.medium, large: theme_defaults.large}
'
		'panel/theme.v': 'module panel

pub struct Padding {
pub:
	top f32
	right f32
	bottom f32
	left f32
}

struct Theme {
	medium Padding
	large Padding
}

struct ThemeCfg {
	medium Padding = Padding{top: 1, right: 2, bottom: 3, left: 4}
	large Padding = Padding{top: 5, right: 6, bottom: 7, left: 8}
}

fn make_theme(cfg &ThemeCfg) Theme {
	return Theme{medium: cfg.medium, large: cfg.large}
}

const theme_defaults = make_theme(ThemeCfg{})
const padding_none = Padding{}
'
		'panel/views.v': 'module panel

pub struct Config {
pub:
	title string
	padding ?Padding
}

pub struct Container {
pub:
	padding Padding
}

pub fn inferred_row(cfg Config) Container {
	default_padding := if cfg.title.len == 0 {
		inferred_theme.medium
	} else {
		inferred_theme.large
	}
	return Container{padding: cfg.padding or { default_padding }}
}

pub fn inferred_column(cfg Config) Container {
	default_padding := if cfg.title.len == 0 {
		padding_none
	} else {
		inferred_theme.large
	}
	return Container{padding: cfg.padding or { default_padding }}
}

pub fn typed_row(cfg Config) Container {
	default_padding := if cfg.title.len == 0 {
		typed_theme.medium
	} else {
		typed_theme.large
	}
	return Container{padding: cfg.padding or { default_padding }}
}
'
		'main.v': 'module main

import panel

fn check_padding(value panel.Padding, top f32, right f32, bottom f32, left f32) {
	if value.top != top || value.right != right || value.bottom != bottom || value.left != left {
		panic(\'padding fields changed\')
	}
}

fn main() {
	check_padding(panel.inferred_row(panel.Config{}).padding, 1, 2, 3, 4)
	check_padding(panel.inferred_row(panel.Config{title: \'title\'}).padding, 5, 6, 7, 8)
	check_padding(panel.inferred_column(panel.Config{}).padding, 0, 0, 0, 0)
	check_padding(panel.inferred_column(panel.Config{title: \'title\'}).padding, 5, 6, 7, 8)
	check_padding(panel.typed_row(panel.Config{}).padding, 1, 2, 3, 4)
	check_padding(panel.typed_row(panel.Config{title: \'title\'}).padding, 5, 6, 7, 8)
	override := panel.Config{padding: panel.Padding{top: 9, right: 10, bottom: 11, left: 12}}
	check_padding(panel.inferred_row(override).padding, 9, 10, 11, 12)
	check_padding(panel.inferred_column(override).padding, 9, 10, 11, 12)
	check_padding(panel.typed_row(override).padding, 9, 10, 11, 12)
	println(\'padding-global-if-ok\')
}
'
	}
	source_order := ['panel/_globals.v', 'panel/theme.v', 'panel/views.v', 'main.v']
	mut source_paths := []string{}
	mut fixture := '// v.mod\n' + module_text
	fixture += '// Metadata probe source order (not a native driver order trace): ${source_order}\n'
	for rel in source_order {
		path := os.join_path(root, rel)
		os.mkdir_all(os.dir(path)) or { panic(err) }
		os.write_file(path, files[rel]) or { panic(err) }
		source_paths << path
		fixture += '\n// ${rel}\n${files[rel]}'
	}
	runner_temp := os.getenv('RUNNER_TEMP')
	evidence_base := if runner_temp.len > 0 { runner_temp } else { os.vtmp_dir() }
	evidence := os.join_path(evidence_base, 'issue74-padding-evidence')
	assert !os.is_link(evidence), evidence
	os.mkdir_all(evidence) or { panic(err) }
	mut capture_ok := global_decl_capture_text(evidence, 'fixture.txt', fixture)
	mut prefs := pref.new_preferences()
	prefs.enable_globals = true
	mut p := parser.Parser.new(prefs)
	mut a := p.parse_files(source_paths)
	mut tc := types.TypeChecker.new(a)
	tc.enable_globals = true
	tc.collect(a)
	tc.annotate_types()
	before_report, before_ok := global_decl_padding_metadata(a, &tc, 'before_transform')
	transform.transform(mut a, &tc)
	tc.annotate_types()
	after_report, after_ok := global_decl_padding_metadata(a, &tc, 'after_transform')
	mut report := before_report + after_report
	v3_bin := global_decl_build_v3()
	cc_args := global_decl_c_compiler_args()
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
		bin := global_decl_executable(os.join_path(generation_dir, 'global_padding'))
		compiler := if generation == 'v1' { global_decl_vexe } else { v3_bin }
		mut args := if generation == 'v1' { ['-old-compiler'] } else { []string{} }
		args << ['-enable-globals', '-gc', 'none', '-prod', '-showcc', '-keepc',
			'-no-retry-compilation', '-b', 'c']
		args << cc_args
		args << link_args
		args << ['-path', '${root}|${global_decl_vlib_dir}|@vlib|@vmodules', '-o', bin,
			os.join_path(root, 'main.v')]
		command := cmdexec.display(compiler, args)
		compile := cmdexec.run(compiler, args)
		compile_log := '${command}\ncompile_rc=${compile.exit_code}\n${compile.output}'
		if !global_decl_capture_text(evidence, '${generation}-compile.log', compile_log) {
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
		if !global_decl_capture_c(evidence, '${generation}.c', c_path) {
			capture_ok = false
		}
		mut run_code := -1
		mut run_output := 'not executed: compilation failed or executable missing\n'
		if compile.exit_code == 0 && os.is_file(bin) {
			run := cmdexec.run(bin, [])
			run_code = run.exit_code
			run_output = run.output
		}
		if !global_decl_capture_text(evidence, '${generation}-run.log', 'run_rc=${run_code}\n${run_output}') {
			capture_ok = false
		}
		ok := compile.exit_code == 0 && run_code == 0
			&& run_output.replace('\r\n', '\n') == 'padding-global-if-ok\n'
		passed = passed && ok
		report += '${generation}: compile_rc=${compile.exit_code} run_rc=${run_code} passed=${ok} c=${c_path}\n'
	}
	// Eight texts, <=8 MiB each and <=64 MiB total, all before the verdict.
	report += 'metadata_before_present=${before_ok} metadata_after_present=${after_ok}\n'
	report += 'capture_complete=${capture_ok}\n'
	if !global_decl_capture_text(evidence, 'results.txt', report) {
		capture_ok = false
	}
	eprintln(report)
	assert capture_ok, 'Padding evidence capture failed; ${report}'
	assert before_ok && after_ok && passed, report
}
