import os

struct CVHeaderOwnedMode {
	name      string
	prealloc  bool
	extra_args []string
}

fn build_c_v_header_owned_v3(root string, mode CVHeaderOwnedMode, environment map[string]string) string {
	v3_binary := os.join_path(root, 'v3_${mode.name}')
	vlib_dir := os.join_path(@VEXEROOT, 'vlib')
	v3_source := os.join_path(vlib_dir, 'v3', 'v3.v')
	mut args := ['-gc', 'none']
	if mode.prealloc {
		args << '-prealloc'
	}
	args << ['-path', '${vlib_dir}|@vlib|@vmodules', '-o', v3_binary, v3_source]
	mut compiler := os.new_process(@VEXE)
	compiler.set_args(args)
	compiler.set_environment(environment)
	compiler.set_redirect_stdio()
	compiler.run()
	compiler.wait()
	compiler_output := compiler.stdout_slurp() + compiler.stderr_slurp()
	compiler_exit_code := compiler.code
	compiler.close()
	assert compiler_exit_code == 0, '${mode.name}: ${compiler_output}'
	return v3_binary
}

fn test_c_v_ordinary_header_owns_externs_in_serial_and_scoped_codegen() {
	$if macos || linux {
		root := os.join_path(os.vtmp_dir(), 'v3_c_v_header_owned_extern_${os.getpid()}')
		os.rmdir_all(root) or {}
		os.mkdir_all(root) or { panic(err) }
		defer {
			os.rmdir_all(root) or {}
		}
		header := os.join_path(root, 'api.h')
		implementation := os.join_path(root, 'api.c')
		source := os.join_path(root, 'main.c.v')
		os.write_file(header, '#ifndef ISSUE74_V37_API_H\n#define ISSUE74_V37_API_H\n#define ISSUE74_V37_HEADER_ACTIVE 1\n#define ISSUE74_V37_DECLARE(name) int name(const char *value)\n#if ISSUE74_V37_HEADER_ACTIVE\nISSUE74_V37_DECLARE(issue74_v37_header_api);\n#endif\n#endif\n') or {
			panic(err)
		}
		os.write_file(implementation,
			'#include "api.h"\nint issue74_v37_header_api(const char *value) { return value != 0 && value[0] == \'v\'; }\n') or {
			panic(err)
		}
		os.write_file(source, 'module main

#include "${header}"
#flag "${implementation}"

fn C.issue74_v37_header_api(&char) int

fn main() {
	assert C.issue74_v37_header_api(c\'v37\') == 1
}
') or {
			panic(err)
		}

		mut environment := os.environ()
		environment['VFLAGS'] = ''
		environment['VOSARGS'] = ''
		environment['VJOBS'] = '4'
		for mode in [
			CVHeaderOwnedMode{
				name:       'serial'
				extra_args: ['-no-parallel']
			},
			CVHeaderOwnedMode{
				name:     'scoped'
				prealloc: true
			},
		] {
			v3_binary := build_c_v_header_owned_v3(root, mode, environment)
			output := os.join_path(root, 'main_${mode.name}')
			mut args := ['-gc', 'none', '-nocache']
			args << mode.extra_args
			args << ['-o', output, source]
			mut compiler := os.new_process(v3_binary)
			compiler.set_args(args)
			compiler.set_environment(environment)
			compiler.set_redirect_stdio()
			compiler.run()
			compiler.wait()
			compiler_output := compiler.stdout_slurp() + compiler.stderr_slurp()
			compiler_exit_code := compiler.code
			compiler.close()
			assert compiler_exit_code == 0, '${mode.name}: ${compiler_output}'
			run := os.execute(os.quoted_path(output))
			assert run.exit_code == 0, '${mode.name}: ${run.output}'
		}
	}
}
