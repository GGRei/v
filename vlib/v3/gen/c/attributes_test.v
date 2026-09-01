module c

import os
import v3.flat
import v3.token
import v3.types

fn cgen_attribute_test_gen() &FlatGen {
	mut ast := &flat.FlatAst{}
	mut tc := types.TypeChecker.new(ast)
	mut g := FlatGen.new()
	g.a = ast
	g.tc = &tc
	return &g
}

fn test_noinline_attribute_is_preserved_for_generic_specialization() {
	mut g := cgen_attribute_test_gen()
	g.ccompiler = 'clang'
	source_pos := token.new_span(1, 20, 40)
	template_id := g.a.add_node(flat.Node{
		kind: .fn_decl
		value: 'helper'
		pos: source_pos
	})
	specialization_id := g.a.add_node(flat.Node{
		kind: .fn_decl
		value: 'helper_T_int'
		pos: source_pos
	})
	g.a.specialized_fn_nodes[int(specialization_id)] = true
	g.decl_attrs[int(template_id)] = ['noinline']
	g.decl_attrs_by_source_position[flat_fn_source_position_key(g.a.nodes[int(template_id)])] = [
		'noinline',
	]

	assert g.fn_decl_gnu_attribute_prefix(template_id) == '__attribute__((noinline)) '
	assert g.fn_decl_gnu_attribute_prefix(specialization_id) == '__attribute__((noinline)) '

	g.ccompiler = 'msvc'
	assert g.fn_decl_gnu_attribute_prefix(specialization_id) == ''
	assert g.fn_decl_msvc_noinline_prefix(specialization_id) == '__declspec(noinline) '
}

fn test_function_definition_attributes_are_composed_as_prefixes() {
	mut g := cgen_attribute_test_gen()
	g.ccompiler = 'clang'
	fn_id := g.a.add_node(flat.Node{
		kind: .fn_decl
		value: 'helper'
	})
	g.decl_attrs[int(fn_id)] = ['_constructor', '_destructor', 'noinline']

	gnu_prefix := g.fn_decl_gnu_attribute_prefix(fn_id)
	assert gnu_prefix == '__attribute__((constructor, destructor, noinline)) '
	definition := '${gnu_prefix}__attribute__((visibility("default"))) VNORETURN int helper(void) {'
	assert definition == '__attribute__((constructor, destructor, noinline)) __attribute__((visibility("default"))) VNORETURN int helper(void) {'
	ordinary_definition := '${gnu_prefix}int helper(void) {'
	assert !ordinary_definition.contains(') __attribute__')
	assert !definition.contains('helper(void) __attribute__')

	source := os.read_file(os.join_path(os.dir(@FILE), 'fn.v'))!
	start := source.index('g.write(g.fn_decl_gnu_attribute_prefix(node_id))') or {
		panic('ordinary function definition does not emit the GNU attribute prefix')
	}
	end_offset := source[start..].index("g.writeln(') {')") or {
		panic('ordinary function definition terminator is missing')
	}
	callsite := source[start..start + end_offset + "g.writeln(') {')".len]
	gnu_pos := callsite.index('g.write(g.fn_decl_gnu_attribute_prefix(node_id))') or { -1 }
	msvc_pos := callsite.index('g.write(g.fn_decl_msvc_noinline_prefix(node_id))') or { -1 }
	export_pos := callsite.index('g.write(g.exported_symbol_attribute())') or { -1 }
	noreturn_pos := callsite.index('g.write(g.fn_decl_noreturn_prefix(node_id))') or { -1 }
	type_pos := callsite.index('g.write(g.fn_return_type_name(ret_type))') or { -1 }
	assert gnu_pos >= 0
	assert gnu_pos < msvc_pos
	assert msvc_pos < export_pos
	assert export_pos < noreturn_pos
	assert noreturn_pos < type_pos
	assert callsite.count('fn_decl_gnu_attribute_prefix') == 1
	assert !callsite.contains('fn_decl_c_attribute')
}
