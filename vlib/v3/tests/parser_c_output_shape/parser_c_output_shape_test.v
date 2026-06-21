import os
import time
import v3.flat
import v3.gen.c as cgen
import v3.parser
import v3.pref
import v3.types

fn v3_shape_source_path(name string) string {
	return os.join_path(os.vtmp_dir(), 'v3_${name}_${os.getpid()}_${time.now().unix_micro()}.v')
}

fn parse_v3_shape_source(name string, source string) &flat.FlatAst {
	src := v3_shape_source_path(name)
	os.write_file(src, source) or { panic(err) }
	defer {
		os.rm(src) or {}
	}
	prefs := pref.new_preferences()
	mut p := parser.Parser.new(prefs)
	return p.parse_file(src)
}

fn find_shape_fn(a &flat.FlatAst, name string) flat.Node {
	for node in a.nodes {
		if node.kind == .fn_decl && node.value == name {
			return node
		}
	}
	assert false
	return flat.Node{}
}

fn first_param_type(a &flat.FlatAst, fn_name string) string {
	f := find_shape_fn(a, fn_name)
	for i in 0 .. f.children_count {
		p := a.child_node(&f, i)
		if p.kind == .param {
			return p.typ
		}
	}
	assert false
	return ''
}

fn gen_c_from_v3_shape_source(name string, source string) string {
	a := parse_v3_shape_source(name, source)
	mut tc := types.TypeChecker.new(a)
	tc.collect(a)
	tc.annotate_types()
	mut g := cgen.FlatGen.new()
	return g.gen_with_used(a, map[string]bool{}, &tc)
}

fn test_mut_pointer_type_shape_does_not_add_extra_pointer_level() {
	a := parse_v3_shape_source('mut_pointer_shape', '
struct Receiver {}

fn takes_mut(mut x int) {}
fn takes_mut_ptr(mut x &int) {}
fn takes_mut_ptr_ptr(mut x & &int) {}

fn (mut r Receiver) receiver_mut() {}
fn (mut r &Receiver) receiver_mut_ptr() {}
fn (mut r & &Receiver) receiver_mut_ptr_ptr() {}
')

	assert first_param_type(a, 'takes_mut') == '&int'
	assert first_param_type(a, 'takes_mut_ptr') == '&int'
	assert first_param_type(a, 'takes_mut_ptr_ptr') == '&&int'

	assert first_param_type(a, 'Receiver.receiver_mut') == '&Receiver'
	assert first_param_type(a, 'Receiver.receiver_mut_ptr') == '&Receiver'
	assert first_param_type(a, 'Receiver.receiver_mut_ptr_ptr') == '&&Receiver'
}

fn test_linux_gettid_preamble_is_strict_enough_for_generated_c() {
	code := gen_c_from_v3_shape_source('gettid_preamble_probe', '
module builtin

pub struct string {
	str &u8
	len int
	is_lit int
}

fn C.gettid() u32

pub fn v_gettid() u64 {
	return u64(C.gettid())
}
')

	define_idx := code.index('#define _GNU_SOURCE') or { -1 }
	include_idx := code.index('#include <stdio.h>') or { -1 }
	assert define_idx >= 0
	assert include_idx >= 0
	assert define_idx < include_idx
	assert code.contains('#include <sys/syscall.h>')
	assert code.contains('static inline unsigned int v3_gettid(void) { return (unsigned int)syscall(SYS_gettid); }')
	assert code.contains('#define gettid() v3_gettid()')
	assert code.contains('return (u64)(gettid());')
}
