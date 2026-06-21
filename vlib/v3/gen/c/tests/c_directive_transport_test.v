import os
import time
import v3.gen.c as cgen
import v3.parser
import v3.pref
import v3.types

fn c_directive_source_path(name string) string {
	return os.join_path(os.vtmp_dir(),
		'v3_c_directives_${name}_${os.getpid()}_${time.now().unix_micro()}.v')
}

fn c_directive_ast_from_source(name string, source string) (&parser.Parser, string) {
	src := c_directive_source_path(name)
	os.write_file(src, source) or { panic(err) }
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	p.parse_file(src)
	return p, src
}

fn test_c_define_and_include_directives_are_reemitted_before_declarations() {
	mut p, src := c_directive_ast_from_source('source_directives', '
#define FIRST_VALUE 1
#include "@VEXEROOT/include/sample.h"

fn main() {}
')
	defer {
		os.rm(src) or {}
	}
	fake_vroot := os.join_path(os.vtmp_dir(), 'v3 directive root')
	mut tc := types.TypeChecker.new(p.a)
	tc.collect(p.a)
	mut g := cgen.FlatGen.new()
	g.set_vroot(fake_vroot)
	lines := cgen.collect_c_source_directive_lines(p.a, fake_vroot)
	assert lines.len == 2, lines.str()
	code := g.gen_with_used(p.a, map[string]bool{}, &tc)

	define_idx := code.index('#define FIRST_VALUE 1') or { -1 }
	include_idx := code.index('#include "${fake_vroot}/include/sample.h"') or { -1 }
	typedef_idx := code.index('typedef signed char i8;') or { -1 }
	assert define_idx >= 0
	assert include_idx > define_idx
	assert typedef_idx > include_idx
}

fn test_c_flags_are_filtered_expanded_deduplicated_and_split() {
	mut p, src := c_directive_ast_from_source('flags', '
#flag -I @VEXEROOT/include
#flag -I@VEXEROOT/alt_include
#flag linux -DKEEP_LINUX
#flag linux -DKEEP_LINUX
#flag windows -DSKIP_WINDOWS
#flag linux -lkeep
#flag linux -L @VEXEROOT/lib

fn main() {}
')
	defer {
		os.rm(src) or {}
	}
	fake_vroot := os.join_path(os.vtmp_dir(), 'v3 flag root')
	mut prefs := pref.new_preferences()
	prefs.target_os = 'linux'
	prefs.vroot = fake_vroot
	compile_flags := cgen.collect_c_compile_flags(p.a, prefs)
	link_flags := cgen.collect_c_link_flags(p.a, prefs)

	include_dir := os.quoted_path(os.join_path(fake_vroot, 'include'))
	alt_include_dir := os.quoted_path(os.join_path(fake_vroot, 'alt_include'))
	lib_dir := os.quoted_path(os.join_path(fake_vroot, 'lib'))
	assert '-I ${include_dir}' in compile_flags
	assert '-I${alt_include_dir}' in compile_flags
	assert '-DKEEP_LINUX' in compile_flags
	assert compile_flags.filter(it == '-DKEEP_LINUX').len == 1
	assert '-DSKIP_WINDOWS' !in compile_flags
	assert '-lkeep' in link_flags
	assert '-L ${lib_dir}' in link_flags
}

fn test_mixed_c_flag_directive_is_split_into_compile_and_link_groups() {
	mut p, src := c_directive_ast_from_source('mixed_flags', '
#flag linux -I/usr/X11R6/include -L/usr/X11R6/lib -lX11 -DKEEP -isystem @VEXEROOT/sysroot/include -include @VEXEROOT/config.h -Xlinker -rpath -framework Cocoa -Wl,--as-needed

fn main() {}
')
	defer {
		os.rm(src) or {}
	}
	fake_vroot := os.join_path(os.vtmp_dir(), 'v3 mixed flag root')
	mut prefs := pref.new_preferences()
	prefs.target_os = 'linux'
	prefs.vroot = fake_vroot
	compile_flags := cgen.collect_c_compile_flags(p.a, prefs)
	link_flags := cgen.collect_c_link_flags(p.a, prefs)

	sysroot_include := os.quoted_path(os.join_path(fake_vroot, 'sysroot/include'))
	config_h := os.quoted_path(os.join_path(fake_vroot, 'config.h'))
	assert compile_flags == [
		'-I/usr/X11R6/include',
		'-DKEEP',
		'-isystem ${sysroot_include}',
		'-include ${config_h}',
	]
	assert link_flags == [
		'-L/usr/X11R6/lib',
		'-lX11',
		'-Xlinker -rpath',
		'-framework Cocoa',
		'-Wl,--as-needed',
	]
}

fn test_quoted_vroot_object_archive_and_shared_library_paths_are_link_flags() {
	mut p, src := c_directive_ast_from_source('link_paths', '
#flag linux "@VEXEROOT/obj/main.o" "@VEXEROOT/lib/libsample.a" "@VEXEROOT/lib/libshared.so" "@VEXEROOT/lib/libportable.dylib" -Xlinker "@VEXEROOT/lib with spaces" -I @VEXEROOT/inc

fn main() {}
')
	defer {
		os.rm(src) or {}
	}
	fake_vroot := os.join_path(os.vtmp_dir(), 'v3 quoted link root')
	mut prefs := pref.new_preferences()
	prefs.target_os = 'linux'
	prefs.vroot = fake_vroot
	compile_flags := cgen.collect_c_compile_flags(p.a, prefs)
	link_flags := cgen.collect_c_link_flags(p.a, prefs)

	obj_path := os.quoted_path(os.join_path(fake_vroot, 'obj/main.o'))
	archive_path := os.quoted_path(os.join_path(fake_vroot, 'lib/libsample.a'))
	shared_path := os.quoted_path(os.join_path(fake_vroot, 'lib/libshared.so'))
	dylib_path := os.quoted_path(os.join_path(fake_vroot, 'lib/libportable.dylib'))
	linker_arg := os.quoted_path(os.join_path(fake_vroot, 'lib with spaces'))
	include_dir := os.quoted_path(os.join_path(fake_vroot, 'inc'))
	assert compile_flags == ['-I ${include_dir}']
	assert link_flags == [
		obj_path,
		archive_path,
		shared_path,
		dylib_path,
		'-Xlinker ${linker_arg}',
	]
	assert link_flags.filter(it == dylib_path).len == 1
}
