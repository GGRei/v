module transform

import os
import v3.flat
import v3.parser
import v3.pref
import v3.types

fn test_comptime_loop_type_metadata_survives_generic_specialization() {
	mut a := flat.FlatAst.new()
	mut tc := types.TypeChecker.new(&a)
	mut t := new_transformer(mut a, &tc, map[string]bool{})
	t.cloning_comptime_for_depth = 1
	t.cloning_comptime_for_vars = ['field']

	assert t.subst_comptime_type_operand('field.typ', ['Address']) == 'field.typ'
	assert t.subst_comptime_type_operand('field.unaliased_typ', ['Address']) == 'field.unaliased_typ'
	assert t.subst_comptime_type_operand('field.unaliased_typ.payload_type', [
		'Address',
	]) == 'field.unaliased_typ.payload_type'
	t.cur_module = 'veb'
	assert t.subst_comptime_type_operand("'Middleware'", ['App']) == "'Middleware'"
	assert t.subst_comptime_type_condition("field.name == 'Middleware'", [
		'App',
	]) == "field.name == 'Middleware'"
}

fn test_generic_unresolved_type_detects_multi_return_placeholders() {
	mut a := flat.FlatAst.new()
	mut tc := types.TypeChecker.new(&a)
	t := new_transformer(mut a, &tc, map[string]bool{})

	assert t.generic_arg_is_unresolved('(T, T)')
	assert t.generic_arg_is_unresolved('([]T, map[string]T)')
	assert !t.generic_arg_is_unresolved('(f64, f64)')
}

fn test_zero_value_normalizes_generic_alias_but_preserves_generic_struct() {
	mut a := flat.FlatAst.new()
	mut tc := types.TypeChecker.new(&a)
	tc.type_aliases['Values'] = '[]T'
	tc.type_alias_generic_params['Values'] = ['T']
	tc.structs['Box'] = []types.StructField{}
	mut t := new_transformer(mut a, &tc, map[string]bool{})

	alias_zero_id := t.zero_value_for_type('Values[int]')
	alias_zero := t.a.nodes[int(alias_zero_id)]
	assert alias_zero.kind == .array_init
	assert alias_zero.value == 'int'
	assert alias_zero.typ == '[]int'

	struct_zero_id := t.zero_value_for_type('Box[int]')
	struct_zero := t.a.nodes[int(struct_zero_id)]
	assert struct_zero.kind == .struct_init
	assert struct_zero.value == 'Box[int]'
	assert struct_zero.typ == 'Box[int]'
}

fn test_explicit_generic_fn_value_candidates_resolve_selective_import() {
	mut a := flat.FlatAst.new()
	base_id := a.add_node(flat.Node{
		kind:  .ident
		value: 'id'
	})
	index_id := a.add_node(flat.Node{
		kind: .index
	})
	mut tc := types.TypeChecker.new(&a)
	file_name := '/tmp/main.v'
	tc.file_selective_imports[file_import_key(file_name, 'id')] = ['lib.id']
	mut t := new_transformer(mut a, &tc, map[string]bool{})
	t.node_file_map_cache = []string{len: a.nodes.len}
	t.node_file_map_cache[int(index_id)] = file_name

	candidates := t.explicit_generic_fn_value_decl_candidates(index_id, base_id,
		a.nodes[int(base_id)], 'main')
	assert candidates[0] == 'lib.id'
	assert 'id' in candidates
}

fn test_materialized_generic_struct_fields_preserve_plain_alias_arguments() {
	mut a := flat.FlatAst.new()
	mut values_alias := flat.Node{
		kind:  .type_decl
		value: 'Values'
		typ:   '[]T'
	}
	values_alias.set_generic_params(['T'])
	a.add_node(values_alias)

	value_field := a.add_node(flat.Node{
		kind:  .field_decl
		value: 'value'
		typ:   'T'
	})
	values_field := a.add_node(flat.Node{
		kind:  .field_decl
		value: 'values'
		typ:   'Values[T]'
	})
	children_start := a.children.len
	a.children << value_field
	a.children << values_field
	mut box_decl := flat.Node{
		kind:           .struct_decl
		value:          'Box'
		children_start: children_start
		children_count: 2
	}
	box_decl.set_generic_params(['T'])
	box_id := a.add_node(box_decl)

	mut tc := types.TypeChecker.new(&a)
	tc.cur_module = 'main'
	tc.type_aliases['UserId'] = 'int'
	tc.type_aliases['Values'] = '[]T'
	tc.type_alias_generic_params['Values'] = ['T']
	mut t := new_transformer(mut a, &tc, map[string]bool{})
	t.cur_module = 'main'
	t.materialize_generic_struct_spec('Box[UserId]', GenericStructDecl{
		id:     box_id
		node:   box_decl
		module: 'main'
		key:    'Box'
	})

	fields := tc.structs['Box[UserId]'] or {
		assert false, 'missing materialized Box[UserId] fields'
		return
	}
	assert fields.len == 2
	assert fields[0].typ is types.Alias
	assert fields[0].typ.name() == 'UserId'
	assert fields[1].typ is types.Array
	assert fields[1].typ.name() == '[]int'
}

fn test_materialized_imported_generic_struct_preserves_locked_main_generic_argument() {
	mut a := flat.FlatAst.new()
	value_field := a.add_node(flat.Node{
		kind:  .field_decl
		value: 'value'
		typ:   'T'
	})
	children_start := a.children.len
	a.children << value_field
	mut result_decl := flat.Node{
		kind:           .struct_decl
		value:          'StructKeyDecodeResult'
		children_start: children_start
		children_count: 1
	}
	result_decl.set_generic_params(['T'])
	result_id := a.add_node(result_decl)

	mut tc := types.TypeChecker.new(&a)
	tc.struct_generic_params['StructType'] = ['T']
	mut t := new_transformer(mut a, &tc, map[string]bool{})
	t.materialize_generic_struct_spec('json2.StructKeyDecodeResult[main.StructType[main.string]]',
		GenericStructDecl{
			id:     result_id
			node:   result_decl
			module: 'json2'
			key:    'json2.StructKeyDecodeResult'
		})

	fields := tc.structs['json2.StructKeyDecodeResult[main.StructType[main.string]]'] or {
		assert false, 'missing materialized result fields'
		return
	}
	assert fields[0].typ.name() == 'StructType[string]'
}

fn test_flattened_generic_struct_types_materialize_from_recorded_args() {
	mut a := flat.FlatAst.new()
	mut arc_decl := flat.Node{
		kind:  .struct_decl
		value: 'Arc'
	}
	arc_decl.set_generic_params(['T'])
	arc_id := a.add_node(arc_decl)
	mut tc := types.TypeChecker.new(&a)
	tc.sum_types['ResourceSum'] = ['Resource', 'int']
	mut t := new_transformer(mut a, &tc, map[string]bool{})
	t.record_generic_specialization_args_in_module('Arc', 'arc', ['ResourceSum'])
	decls := {
		'arc.Arc': GenericStructDecl{
			id:     arc_id
			node:   arc_decl
			module: 'arc'
			key:    'arc.Arc'
		}
	}
	mut specs := map[string]string{}
	t.collect_generic_struct_spec_from_type('arc.Arc_ResourceSum', 'main', '', decls, mut specs)
	assert specs['arc.Arc[ResourceSum]'] == 'arc.Arc'
}

fn test_flattened_generic_struct_arg_canonicalizes_to_source_application() {
	mut a := flat.FlatAst.new()
	mut tc := types.TypeChecker.new(&a)
	tc.struct_generic_params['StructType'] = ['T']
	mut t := new_transformer(mut a, &tc, map[string]bool{})
	t.record_generic_specialization_args_in_module('StructType', 'main', ['int'])

	assert t.tc.struct_generic_params['StructType'] == ['T']
	assert t.recorded_generic_specialization_args('StructType_int') or { []string{} } == [
		'int',
	]
	assert generic_specialized_type_matches_flat_name('StructType_int', 'StructType', [
		'int',
	])
	assert t.generic_specialized_source_type_name('StructType_int') or { '' } == 'StructType[int]'
	assert t.canonical_generic_specialization_arg('StructType_int') == 'StructType[int]'
	assert t.generic_specialized_source_type_name('&StructType_int') or { '' } == '&StructType[int]'
	assert t.canonical_generic_specialization_arg('&StructType[int]') == '&StructType[int]'

	t.record_generic_specialization_args_in_module('StructType', 'main', ['time.Time'])
	assert c_name('StructType[time.Time]') == 'StructType_time__Time'
	assert t.recorded_generic_specialization_args('StructType_time.Time') or { []string{} } == [
		'time.Time',
	]
	assert t.generic_specialized_source_type_name('StructType_time.Time') or { '' } == 'StructType[time.Time]'
	assert t.canonical_generic_specialization_arg('StructType_time.Time') == 'StructType[time.Time]'
}

fn test_short_fixed_array_generic_arg_canonicalizes_to_source_type() {
	mut a := flat.FlatAst.new()
	mut tc := types.TypeChecker.new(&a)
	t := new_transformer(mut a, &tc, map[string]bool{})

	assert t.canonical_generic_specialization_arg('int_2') == '[2]int'
	assert t.canonical_generic_specialization_arg('int_3_2') == '[2][3]int'
	tc.type_aliases['int_2'] = 'int'
	assert t.canonical_generic_specialization_arg('int_2') == 'int_2'
}

fn test_composite_generic_inference_preserves_nested_alias() {
	mut a := flat.FlatAst.new()
	mut tc := types.TypeChecker.new(&a)
	tc.type_aliases['Distance'] = 'int'
	mut t := new_transformer(mut a, &tc, map[string]bool{})
	t.build_generic_alias_name_index()

	assert t.generic_composite_inference_alias_type('datatypes.LinkedList[Distance]', 'datatypes') == 'datatypes.LinkedList[Distance]'
}

fn test_composite_generic_inference_still_expands_direct_alias() {
	mut a := flat.FlatAst.new()
	mut tc := types.TypeChecker.new(&a)
	tc.type_aliases['Distances'] = '[]int'
	mut t := new_transformer(mut a, &tc, map[string]bool{})
	t.build_generic_alias_name_index()

	assert t.generic_composite_inference_alias_type('Distances', 'main') == '[]int'
}

fn test_concrete_generic_fn_alias_call_expands_multi_return_signature() {
	mut a := flat.FlatAst.new()
	callee_id := a.add_node(flat.Node{
		kind:  .ident
		value: 'make_splitter'
	})
	children_start := a.children.len
	a.children << callee_id
	call_id := a.add_node(flat.Node{
		kind:           .call
		typ:            'fn(I) (O, R)[string, string, string]'
		children_start: children_start
		children_count: 1
	})
	mut tc := types.TypeChecker.new(&a)
	tc.type_aliases['FnMultiReturn'] = 'fn (I) (O, R)'
	tc.type_alias_generic_params['FnMultiReturn'] = ['I', 'O', 'R']
	tc.fn_ret_types['make_splitter'] = types.Type(types.Alias{
		name:      'FnMultiReturn[string, string, string]'
		base_type: types.Type(types.void_)
	})
	mut t := new_transformer(mut a, &tc, map[string]bool{})
	t.cur_module = 'main'

	concrete := t.concrete_fn_alias_call_return_type(int(call_id), a.nodes[int(call_id)]) or {
		assert false, 'generic function type alias was not expanded'
		return
	}
	assert concrete == 'fn(string) (string, string)'
}

fn test_concrete_generic_fn_alias_call_expands_result_signature() {
	mut a := flat.FlatAst.new()
	callee_id := a.add_node(flat.Node{
		kind:  .ident
		value: 'literal'
	})
	children_start := a.children.len
	a.children << callee_id
	call_id := a.add_node(flat.Node{
		kind:           .call
		typ:            'fn(string) !ParseResult[T][string]'
		children_start: children_start
		children_count: 1
	})
	mut tc := types.TypeChecker.new(&a)
	tc.type_aliases['ParseFunction'] = 'fn (string) !ParseResult[T]'
	tc.type_alias_generic_params['ParseFunction'] = ['T']
	tc.fn_ret_types['literal'] = types.Type(types.Alias{
		name:      'ParseFunction[string]'
		base_type: types.Type(types.void_)
	})
	mut t := new_transformer(mut a, &tc, map[string]bool{})
	t.cur_module = 'main'

	concrete := t.concrete_fn_alias_call_return_type(int(call_id), a.nodes[int(call_id)]) or {
		assert false, 'generic result function type alias was not expanded'
		return
	}
	assert concrete == 'fn(string) !ParseResult[string]'
}

fn test_lock_colliding_main_generic_type_text_locks_args_behind_qualified_base() {
	mut a := flat.FlatAst.new()
	mut tc := types.TypeChecker.new(&a)
	mut t := new_transformer(mut a, &tc, map[string]bool{})
	// The program (main) declares `Context` (bare-keyed); the `callee` module declares a
	// colliding `Context` of its own.
	t.structs['Context'] = StructInfo{}
	t.structs['callee.Context'] = StructInfo{}
	t.structs['MiddlewareOptions'] = StructInfo{}
	t.structs['callee.MiddlewareOptions'] = StructInfo{}
	tc.struct_generic_params['MiddlewareOptions'] = ['T']
	tc.struct_generic_params['callee.MiddlewareOptions'] = ['T']

	// A bare program type substituted into a specialization is locked to `main.`.
	assert t.lock_colliding_main_generic_type_text('Context', 'callee') == 'main.Context'
	// A qualified generic base with a bare program argument (`other.Box[Context]`) must
	// still lock the nested `Context`, not return early on the qualified spelling.
	assert t.lock_colliding_main_generic_type_text('other.Box[Context]', 'callee') == 'other.Box[main.Context]'
	// The same nested program type behind a map / fixed array is locked too.
	assert t.lock_colliding_main_generic_type_text('map[string]Context', 'callee') == 'map[string]main.Context'
	assert t.lock_colliding_main_generic_type_text('[3]Context', 'callee') == '[3]main.Context'
	assert t.lock_colliding_main_generic_type_text('(Context, []Context)', 'callee') == '(main.Context, []main.Context)'
	// A simple qualified type has no lockable bare component and is returned verbatim.
	assert t.lock_colliding_main_generic_type_text('veb.Context', 'callee') == 'veb.Context'
	// An already-qualified argument keeps its exact spelling (no rewrite / name desync).
	assert t.lock_colliding_main_generic_type_text('other.Box[user.LocalWriter]', 'callee') == 'other.Box[user.LocalWriter]'
	// No lock target: the callee module does not declare `Other`, so nothing changes.
	assert t.lock_colliding_main_generic_type_text('other.Box[Other]', 'callee') == 'other.Box[Other]'
	// A module-local generic base must stay local even when one of its concrete arguments
	// is a colliding main type. `callee.MiddlewareOptions` is not `main.MiddlewareOptions`.
	assert t.lock_colliding_main_generic_type_text('MiddlewareOptions[Context]', 'callee') == 'MiddlewareOptions[main.Context]'
	// When the generic base itself is an active caller type, caller provenance wins over the
	// otherwise ambiguous pair of main/callee generic declarations.
	t.structs['Box'] = StructInfo{}
	t.structs['callee.Box'] = StructInfo{}
	tc.struct_generic_params['Box'] = ['T']
	tc.struct_generic_params['callee.Box'] = ['T']
	t.active_specialization_main_types['Box'] = true
	assert t.lock_colliding_main_generic_type_text('Box[string]', 'callee') == 'main.Box[string]'
	// A main type that is active in the specialization is locked even without a
	// callee homonym, since a different imported module can own the same short name.
	t.structs['Event'] = StructInfo{}
	t.structs['other.Event'] = StructInfo{}
	t.structs['string'] = StructInfo{
		module: 'builtin'
	}
	t.active_specialization_main_types['Event'] = true
	assert t.lock_colliding_main_generic_type_text('Event', 'callee') == 'main.Event'
	t.active_specialization_main_types['Context'] = true
	assert t.lock_colliding_main_substitution_type_text('fn (mut T) bool', 'fn (mut Context) bool',
		'callee', ['T']) == 'fn (mut main.Context) bool'
	t.structs['Unique'] = StructInfo{}
	assert t.lock_colliding_main_generic_type_text('Unique', 'callee') == 'Unique'
	assert t.canonical_generic_specialization_arg('[]main.Event') == '[]Event'
	assert t.canonical_generic_specialization_arg('main.Box[main.Event]') == 'Box[Event]'
	assert t.canonical_generic_specialization_arg('[main.string]Box') == 'Box[string]'
	assert t.canonical_generic_specialization_arg('u8_3') == '[3]u8'
	assert strip_main_type_locks('domain.Type[main.Event]') == 'domain.Type[Event]'
	assert t.specialization_main_type_closure(['map[string]Event']) == {
		'Event': true
	}
	tc.type_aliases['AliasContext'] = 'Context'
	assert t.specialization_main_type_closure(['AliasContext']) == {
		'AliasContext': true
		'Context':      true
	}
	t.active_specialization_main_types['AliasContext'] = true
	assert t.lock_colliding_main_generic_type_text('AliasContext', 'callee') == 'main.AliasContext'
}

fn test_lock_colliding_main_substitution_keeps_decl_module_generic_base() {
	mut a := flat.FlatAst.new()
	mut tc := types.TypeChecker.new(&a)
	mut t := new_transformer(mut a, &tc, map[string]bool{})
	t.structs['Arc'] = StructInfo{
		name:   'Arc'
		module: 'arc'
	}
	t.structs['arc.Arc'] = StructInfo{
		name:   'Arc'
		module: 'arc'
	}
	assert t.lock_colliding_main_substitution_type_text('Arc[T]', 'Arc[Resource]', 'arc', [
		'T',
	]) == 'Arc[Resource]'
	assert t.lock_colliding_main_substitution_type_text('([]T, []T)', '([]int, []int)', 'arrays', [
		'T',
	]) == '([]int, []int)'
	t.structs['Context'] = StructInfo{}
	t.structs['arc.Context'] = StructInfo{}
	t.active_specialization_main_types['Context'] = true
	assert t.lock_colliding_main_substitution_type_text('other.Box[map[other.Key]T]',
		'other.Box[map[other.Key]Context]', 'arc', ['T']) == 'other.Box[map[other.Key]main.Context]'
}

fn test_generic_fn_type_param_mode_payload_preserves_mutability() {
	assert generic_fn_type_param_mode_payload('mut Item') == 'mut Item'
	assert generic_fn_type_param_mode_payload('mut item Item') == 'mut Item'
	assert generic_fn_type_param_mode_payload('item Item') == 'Item'
}

fn test_resolve_substituted_type_text_qualifies_local_generic_base() {
	mut a := flat.FlatAst.new()
	mut tc := types.TypeChecker.new(&a)
	tc.struct_generic_params['Node'] = ['T']
	tc.struct_generic_params['json2.Node'] = ['T']
	mut t := new_transformer(mut a, &tc, map[string]bool{})
	t.cur_module = 'json2'
	t.structs['Node'] = StructInfo{
		name:   'Node'
		module: 'main'
	}
	t.structs['json2.Node'] = StructInfo{
		name:   'Node'
		module: 'json2'
	}

	assert t.resolve_substituted_type_text('Node[json2.ValueInfo]') == 'json2.Node[json2.ValueInfo]'
	assert t.resolve_substituted_type_text('&Node[json2.ValueInfo]') == '&json2.Node[json2.ValueInfo]'
	t.active_specialization_main_types['Node'] = true
	assert t.resolve_substituted_type_text('Node[int]') == 'Node[int]'
	assert t.resolve_substituted_type_text('main.Node') == 'main.Node'
}

fn test_imported_generic_alias_target_uses_declaration_module() {
	mut a := flat.FlatAst.new()
	mut inner_decl := flat.Node{
		kind:  .struct_decl
		value: 'Inner'
	}
	inner_decl.set_generic_params(['T'])
	inner_id := a.add_node(inner_decl)
	mut tc := types.TypeChecker.new(&a)
	tc.type_aliases['a.Box'] = 'Inner[T]'
	tc.type_alias_generic_params['a.Box'] = ['T']
	mut t := new_transformer(mut a, &tc, map[string]bool{})
	t.cur_module = 'main'
	t.structs['Inner'] = StructInfo{
		name:   'Inner'
		module: 'main'
	}
	t.structs['a.Inner'] = StructInfo{
		name:   'Inner'
		module: 'a'
	}

	assert t.normalize_type_alias('a.Box[int]') == 'a.Inner[int]'
	decls := {
		'a.Inner': GenericStructDecl{
			id:     inner_id
			node:   inner_decl
			module: 'a'
			key:    'a.Inner'
		}
	}
	mut specs := map[string]string{}
	t.collect_generic_struct_spec_from_type('a.Box[int]', 'main', '', decls, mut specs)
	assert specs['a.Inner[int]'] == 'a.Inner'
}

fn test_generic_method_decl_matches_embedded_receiver() {
	mut a := flat.FlatAst.new()
	mut tc := types.TypeChecker.new(&a)
	mut t := new_transformer(mut a, &tc, map[string]bool{})
	t.embedded_fields['Outer'] = [
		FieldInfo{
			name:        'Middle'
			typ:         'Middle'
			raw_typ:     'Middle'
			is_embedded: true
		},
	]
	t.embedded_fields['Middle'] = [
		FieldInfo{
			name:        'Collector'
			typ:         'Collector[int]'
			raw_typ:     'Collector[int]'
			is_embedded: true
		},
	]
	decl := GenericFnDecl{
		node:   flat.Node{
			kind:  .fn_decl
			value: 'Collector[T].use'
		}
		module: 'main'
		key:    'Collector[T].use'
	}
	mut seen := map[string]bool{}
	assert t.generic_decl_matches_embedded_receiver('Outer', decl, 'main', mut seen)
}

fn test_escaped_generic_method_indexes_unescaped_call_spelling() {
	mut a := flat.FlatAst.new()
	receiver_id := a.add_node(flat.Node{
		kind: .param
		typ:  '&Box[T]'
	})
	children_start := a.children.len
	a.children << receiver_id
	mut fn_decl := flat.Node{
		kind:           .fn_decl
		value:          'Box[T].@union'
		children_start: children_start
		children_count: 1
	}
	fn_decl.set_generic_params(['T'])
	mut tc := types.TypeChecker.new(&a)
	mut t := new_transformer(mut a, &tc, map[string]bool{})
	t.generic_fn_decls_cache['Box.@union'] = GenericFnDecl{
		node: fn_decl
		key:  'Box.@union'
	}
	t.build_generic_receiver_method_index()

	assert t.generic_fn_call_names['union']
	assert t.generic_receiver_methods_by_name['union'] == ['Box.@union']
	assert t.generic_receiver_decl_key('Box', 'union', t.generic_fn_decls_cache) == 'Box.@union'
	assert t.generic_plain_call_candidates('type', 'main') == ['type', '@type']
}

fn test_synthetic_generic_call_with_exact_identity_is_scannable() {
	mut a := flat.FlatAst.new()
	callee_id := a.add_node(flat.Node{
		kind:  .ident
		value: 'datatypes.LinkedList[map[string]int].str'
	})
	children_start := a.children.len
	a.children << callee_id
	call := flat.Node{
		kind:           .call
		children_start: children_start
		children_count: 1
	}
	mut tc := types.TypeChecker.new(&a)
	t := new_transformer(mut a, &tc, map[string]bool{})

	assert t.synthetic_generic_call_has_exact_identity(call)
	a.nodes[int(callee_id)].value = 'orm.v_sql_create_table_T_Demo'
	assert t.synthetic_generic_call_has_exact_identity(call)
}

fn test_specialized_plain_generic_call_args_decode_top_level_array_suffix() {
	mut a := flat.FlatAst.new()
	callee_id := a.add_node(flat.Node{
		kind:  .ident
		value: 'json2__decode_T_Array_net__jsonrpc__Response'
	})
	children_start := a.children.len
	a.children << callee_id
	call := flat.Node{
		kind:           .call
		children_start: children_start
		children_count: 1
	}
	mut fn_decl := flat.Node{
		kind:  .fn_decl
		value: 'decode'
	}
	fn_decl.set_generic_params(['T'])
	mut tc := types.TypeChecker.new(&a)
	mut t := new_transformer(mut a, &tc, map[string]bool{})
	args := t.specialized_plain_generic_call_args(call, GenericFnDecl{
		node:   fn_decl
		module: 'json2'
		key:    'json2.decode'
	}, 'net.jsonrpc') or {
		assert false, 'failed to decode specialized generic call arguments'
		return
	}
	assert args == ['[]net.jsonrpc.Response']
}

fn test_free_generic_map_suffix_preserves_qualified_value_type() {
	suffix := generic_type_full_suffixes(['map[string]binary.St'])
	assert suffix == 'Map_string_binary__St'
	decoded := generic_type_arg_from_suffix_with_containers(suffix)
	assert decoded == 'map[string]binary.St'
}

fn iterator_boundary_nodes(a &flat.FlatAst, id flat.NodeId, kind flat.NodeKind, mut found []flat.NodeId) {
	node := a.node(id)
	if node.kind == kind {
		found << id
	}
	for child in a.children_of(node) {
		iterator_boundary_nodes(a, child, kind, mut found)
	}
}

// Observe actual generated nodes. No inferred type or spec is inserted into
// the AST, checker maps, or inference state by this diagnostic.
fn iterator_boundary_observe(source_path string, reverse_source string, name string) (string, bool) {
	mut report := 'function=${name}\n'
	if !os.is_file(source_path) || !os.is_file(reverse_source) {
		return report + 'source=<missing>\n', false
	}
	mut p := parser.Parser.new(pref.new_preferences())
	mut a := p.parse_files([reverse_source, source_path])
	mut tc := types.TypeChecker.new(a)
	tc.collect(a)
	tc.annotate_types()
	mut t := new_transformer(mut a, &tc, map[string]bool{})
	t.prepare_with_pre_scans()
	t.cur_file = source_path
	t.cur_module = tc.file_modules[source_path] or { '' }
	mut roots := []int{}
	for i, node in a.nodes {
		if node.kind == .fn_decl && node.value == name {
			roots << i
		}
	}
	report += 'module=${t.cur_module} roots=${roots.len} skip_generics=${t.skip_generics}\n'
	if roots.len != 1 {
		return report + 'function_root=<missing-or-ambiguous>\n', false
	}
	fn_id := flat.NodeId(roots[0])
	mut loops := []flat.NodeId{}
	iterator_boundary_nodes(a, fn_id, .for_in_stmt, mut loops)
	report += 'original_loops=${loops.len}\n'
	for loop_id in loops {
		loop := a.node(loop_id)
		if loop.children_count < 3 {
			report += 'container=<missing>\n'
			continue
		}
		container_id := a.child(loop, 2)
		container := a.node(container_id)
		checked := if typ := tc.expr_type(container_id) { typ.name() } else { '' }
		report += 'before: for.typ=${loop.typ} container.typ=${container.typ} checked=${checked}\n'
		if info := tc.iterator_for_in_next_call_info_text(checked) {
			report += 'before: checked_info.name=${info.name} checked_info.return=${info.return_type.name()}\n'
		} else {
			report += 'before: checked_info=<absent>\n'
		}
	}
	// Use the real function entry to establish parameter/local scope. Each
	// function gets a fresh parse/check/transform instance, not forged maps.
	t.transform_fn_body(roots[0])
	mut declarations := []flat.NodeId{}
	iterator_boundary_nodes(a, fn_id, .decl_assign, mut declarations)
	mut receivers := 0
	mut next_calls := []flat.NodeId{}
	mut slots := 0
	for decl_id in declarations {
		decl := a.node(decl_id)
		if decl.children_count != 2 {
			continue
		}
		lhs := a.child_node(decl, 0)
		rhs_id := a.child(decl, 1)
		rhs := a.node(rhs_id)
		if lhs.value.starts_with('__iter_') && !lhs.value.starts_with('__iter_next_') {
			receivers++
			report += 'after: receiver=${lhs.value} decl.typ=${decl.typ} lhs.typ=${lhs.typ} factory.kind=${rhs.kind} factory.typ=${rhs.typ}\n'
		} else if lhs.value.starts_with('__iter_next_') {
			next_calls << rhs_id
			report += 'after: next=${lhs.value} decl.typ=${decl.typ} lhs.typ=${lhs.typ} call.kind=${rhs.kind} call.typ=${rhs.typ}\n'
			for child in a.children_of(rhs) {
				arg := a.node(child)
				report += 'after: next_child kind=${arg.kind} value=${arg.value} typ=${arg.typ}\n'
				if arg.kind == .prefix && arg.children_count == 1 {
					value := a.child_node(arg, 0)
					report += 'after: receiver_ident=${value.value} typ=${value.typ}\n'
				}
			}
		} else if lhs.value in ['item', 'child'] {
			slots++
			report += 'after: slot=${lhs.value} decl.typ=${decl.typ} lhs.typ=${lhs.typ} rhs.kind=${rhs.kind} rhs.value=${rhs.value} rhs.typ=${rhs.typ}\n'
		}
	}
	// Derive text only AFTER observing the generated tree. A cached spec is
	// not a trace of B5's returned value; absence does not prove an empty return.
	for next_id in next_calls {
		if spec := t.generic_call_spec_cache[int(next_id)] {
			report += 'spec: present=true key=${spec.decl_key} args=${spec.args}\n'
			if decl := t.generic_fn_decls_cache[spec.decl_key] {
				derived := t.specialized_fn_return_type_text(decl, spec.args)
				report += 'spec: derived_return_from_spec=${derived}\n'
			} else {
				report += 'spec: declaration=<absent> derived_return_from_spec=<unavailable>\n'
			}
		} else {
			report += 'spec: present=false derived_return_from_spec=<unavailable>\n'
		}
	}
	report += 'b5_return_value_observed=false receivers=${receivers} next_calls=${next_calls.len} slots=${slots}\n'
	return report, t.cur_module == 'main' && loops.len == 1 && receivers == 1
		&& next_calls.len == 1 && slots == 1
}

fn test_reverse_iterator_lowering_records_concrete_payload_boundary() {
	vlib_dir := os.dir(os.dir(os.dir(@FILE)))
	reverse_source := os.join_path(vlib_dir, 'arrays', 'reverse_iterator.v')
	root := os.join_path(os.vtmp_dir(), 'iterator_boundary_${os.getpid()}')
	os.mkdir_all(root) or { panic(err) }
	source_path := os.join_path(root, 'main.v')
	source := 'module main
import arrays

struct Item {
	id int
}
struct Node {
	id int
	children []Node
}
fn parameter_order(items []Item) int {
	mut order := 0
	for item in arrays.reverse_iterator(items) {
		order = order * 10 + item.id
	}
	return order
}
fn field_order(node &Node) int {
	mut order := 0
	for child in arrays.reverse_iterator(node.children) {
		order = order * 10 + child.id
	}
	return order
}
fn main() {}
'
	os.write_file(source_path, source) or { panic(err) }
	mut report := 'Reduced parser input, not the native 80-file import graph.\n'
	report += 'source_order=[${reverse_source}, ${source_path}]\n'
	mut observed := true
	for name in ['parameter_order', 'field_order'] {
		detail, present := iterator_boundary_observe(source_path, reverse_source, name)
		report += detail
		observed = observed && present
	}
	report += 'observation_complete=${observed}\n'
	runner_temp := os.getenv('RUNNER_TEMP')
	report_base := if runner_temp.len > 0 { runner_temp } else { os.vtmp_dir() }
	report_path := os.join_path(report_base, 'issue74-iterator-boundary.txt')
	mut captured := false
	if !os.is_link(report_path) {
		bounded := if report.len <= 16 * 1024 {
			report
		} else {
			report[..16 * 1024 - 64] + '\nREPORT EXCEEDS 16 KiB; observation incomplete\n'
		}
		os.write_file(report_path, bounded) or {
			eprintln('cannot retain iterator observation: ${err}')
		}
		captured = os.is_file(report_path) && report.len <= 16 * 1024
			&& (os.read_file(report_path) or { '' }) == report
		eprintln(bounded)
	}
	// Only completeness is asserted. Concrete slots here would mean this
	// observation did not reproduce the native boundary, not a product fix.
	assert captured, 'iterator observation capture failed'
	assert observed, report
}
