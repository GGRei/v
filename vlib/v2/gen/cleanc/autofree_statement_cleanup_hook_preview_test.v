module cleanc

import v2.ast
import v2.token

struct AutofreeStatementCleanupHookPreviewTestFlat {
	flat         ast.FlatAst
	fn_id        ast.FlatNodeId
	stmt_id      ast.FlatNodeId
	lhs_id       ast.FlatNodeId
	rhs_id       ast.FlatNodeId
	next_stmt_id ast.FlatNodeId
	next_lhs_id  ast.FlatNodeId
	next_rhs_id  ast.FlatNodeId
}

fn autofree_statement_cleanup_hook_preview_test_pos(id int) token.Pos {
	return token.Pos{
		offset: id
		id:     id
	}
}

fn autofree_statement_cleanup_hook_preview_test_array_init(mut b ast.FlatBuilder, pos_id int) ast.FlatNodeId {
	return b.emit_array_init_expr_by_ids(ast.invalid_flat_node_id, ast.invalid_flat_node_id,
		ast.invalid_flat_node_id, ast.invalid_flat_node_id, ast.invalid_flat_node_id,
		[]ast.FlatNodeId{}, autofree_statement_cleanup_hook_preview_test_pos(pos_id))
}

fn autofree_statement_cleanup_hook_preview_test_fn_cursor(fixture &AutofreeStatementCleanupHookPreviewTestFlat) ast.Cursor {
	return ast.Cursor{
		flat: &fixture.flat
		id:   fixture.fn_id
	}
}

fn autofree_statement_cleanup_hook_preview_test_flat_with_assigns(names []string, ops []token.Token) AutofreeStatementCleanupHookPreviewTestFlat {
	mut b := ast.new_flat_builder()
	mut stmt_ids := []ast.FlatNodeId{}
	mut lhs_ids := []ast.FlatNodeId{}
	mut rhs_ids := []ast.FlatNodeId{}
	for i, name in names {
		stmt_pos := 210 + i * 100
		lhs_pos := 120 + i * 100
		rhs_pos := 130 + i * 100
		lhs_id := b.emit_ident_by_name(name,
			autofree_statement_cleanup_hook_preview_test_pos(lhs_pos))
		rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, rhs_pos)
		op := if i < ops.len { ops[i] } else { token.Token.decl_assign }
		stmt_id := b.emit_assign_stmt_by_ids(op, [lhs_id], [rhs_id],
			autofree_statement_cleanup_hook_preview_test_pos(stmt_pos))
		lhs_ids << lhs_id
		rhs_ids << rhs_id
		stmt_ids << stmt_id
	}
	body_id := b.emit_aux_list_from_ids(stmt_ids)
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(100), ast.invalid_flat_node_id,
		fn_type_id, attrs_id, body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementCleanupHookPreviewTestFlat{
		flat:         b.take_flat()
		fn_id:        fn_id
		stmt_id:      stmt_ids[0]
		lhs_id:       lhs_ids[0]
		rhs_id:       rhs_ids[0]
		next_stmt_id: if stmt_ids.len > 1 { stmt_ids[1] } else { ast.invalid_flat_node_id }
		next_lhs_id:  if lhs_ids.len > 1 { lhs_ids[1] } else { ast.invalid_flat_node_id }
		next_rhs_id:  if rhs_ids.len > 1 { rhs_ids[1] } else { ast.invalid_flat_node_id }
	}
}

fn autofree_statement_cleanup_hook_preview_test_flat_with_source_prefix_then_items() AutofreeStatementCleanupHookPreviewTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('copy',
		autofree_statement_cleanup_hook_preview_test_pos(120))
	first_rhs_id := b.emit_ident_by_name('source',
		autofree_statement_cleanup_hook_preview_test_pos(130))
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_cleanup_hook_preview_test_pos(210))
	next_lhs_id := b.emit_ident_by_name('items',
		autofree_statement_cleanup_hook_preview_test_pos(220))
	next_rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 230)
	next_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [next_lhs_id], [
		next_rhs_id,
	], autofree_statement_cleanup_hook_preview_test_pos(310))
	body_id := b.emit_aux_list_from_ids([first_stmt_id, next_stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(100), ast.invalid_flat_node_id,
		fn_type_id, attrs_id, body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_prefix_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementCleanupHookPreviewTestFlat{
		flat:         b.take_flat()
		fn_id:        fn_id
		stmt_id:      first_stmt_id
		lhs_id:       first_lhs_id
		rhs_id:       first_rhs_id
		next_stmt_id: next_stmt_id
		next_lhs_id:  next_lhs_id
		next_rhs_id:  next_rhs_id
	}
}

fn autofree_statement_cleanup_hook_preview_test_flat_with_later_insert_assignment() AutofreeStatementCleanupHookPreviewTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('arr',
		autofree_statement_cleanup_hook_preview_test_pos(120))
	first_rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 130)
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_cleanup_hook_preview_test_pos(210))
	block_id := b.emit_block_stmt_by_ids([])
	next_lhs_id := b.emit_ident_by_name('gen',
		autofree_statement_cleanup_hook_preview_test_pos(320))
	next_rhs_id := b.emit_ident_by_name('arr',
		autofree_statement_cleanup_hook_preview_test_pos(330))
	next_stmt_id := b.emit_assign_stmt_by_ids(.assign, [next_lhs_id], [
		next_rhs_id,
	], autofree_statement_cleanup_hook_preview_test_pos(410))
	body_id := b.emit_aux_list_from_ids([first_stmt_id, block_id, next_stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('next_generation', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(100), ast.invalid_flat_node_id,
		fn_type_id, attrs_id, body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_later_insert_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementCleanupHookPreviewTestFlat{
		flat:         b.take_flat()
		fn_id:        fn_id
		stmt_id:      first_stmt_id
		lhs_id:       first_lhs_id
		rhs_id:       first_rhs_id
		next_stmt_id: next_stmt_id
		next_lhs_id:  next_lhs_id
		next_rhs_id:  next_rhs_id
	}
}

fn autofree_statement_cleanup_hook_preview_test_flat_with_modifier_assign(kind token.Token, extra_child bool) AutofreeStatementCleanupHookPreviewTestFlat {
	mut b := ast.new_flat_builder()
	lhs_id := b.emit_ident_by_name('items', autofree_statement_cleanup_hook_preview_test_pos(120))
	extra_lhs_id := b.emit_ident_by_name('extra_items',
		autofree_statement_cleanup_hook_preview_test_pos(121))
	modifier_id := b.emit_modifier_expr_by_id(kind, lhs_id,
		autofree_statement_cleanup_hook_preview_test_pos(119))
	rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 130)
	stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [modifier_id], [rhs_id],
		autofree_statement_cleanup_hook_preview_test_pos(210))
	body_id := b.emit_aux_list_from_ids([stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(100), ast.invalid_flat_node_id,
		fn_type_id, attrs_id, body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_modifier.v'
		mod:  'main'
	}, [fn_id])
	mut flat := b.take_flat()
	if extra_child {
		flat.nodes[modifier_id].first_edge = flat.edges.len
		flat.nodes[modifier_id].edge_count = 2
		flat.edges << ast.FlatEdge{
			child_id: lhs_id
		}
		flat.edges << ast.FlatEdge{
			child_id: extra_lhs_id
		}
	}
	return AutofreeStatementCleanupHookPreviewTestFlat{
		flat:    flat
		fn_id:   fn_id
		stmt_id: stmt_id
		lhs_id:  lhs_id
		rhs_id:  rhs_id
	}
}

fn autofree_statement_cleanup_hook_preview_test_flat_with_multi_lhs() AutofreeStatementCleanupHookPreviewTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('items',
		autofree_statement_cleanup_hook_preview_test_pos(120))
	second_lhs_id := b.emit_ident_by_name('other',
		autofree_statement_cleanup_hook_preview_test_pos(125))
	rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 130)
	stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id, second_lhs_id], [
		rhs_id,
	], autofree_statement_cleanup_hook_preview_test_pos(210))
	body_id := b.emit_aux_list_from_ids([stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(100), ast.invalid_flat_node_id,
		fn_type_id, attrs_id, body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_multi.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementCleanupHookPreviewTestFlat{
		flat:    b.take_flat()
		fn_id:   fn_id
		stmt_id: stmt_id
		lhs_id:  first_lhs_id
		rhs_id:  rhs_id
	}
}

fn autofree_statement_cleanup_hook_preview_test_flat_with_return() AutofreeStatementCleanupHookPreviewTestFlat {
	mut b := ast.new_flat_builder()
	rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 130)
	stmt_id := b.emit_return_stmt_by_ids([rhs_id])
	body_id := b.emit_aux_list_from_ids([stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(100), ast.invalid_flat_node_id,
		fn_type_id, attrs_id, body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_return.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementCleanupHookPreviewTestFlat{
		flat:    b.take_flat()
		fn_id:   fn_id
		stmt_id: stmt_id
		lhs_id:  rhs_id
		rhs_id:  rhs_id
	}
}

fn autofree_statement_cleanup_hook_preview_test_flat_with_nested_assign() AutofreeStatementCleanupHookPreviewTestFlat {
	mut b := ast.new_flat_builder()
	lhs_id := b.emit_ident_by_name('items', autofree_statement_cleanup_hook_preview_test_pos(120))
	rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 130)
	stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [lhs_id], [rhs_id],
		autofree_statement_cleanup_hook_preview_test_pos(210))
	block_id := b.emit_block_stmt_by_ids([stmt_id])
	body_id := b.emit_aux_list_from_ids([block_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(100), ast.invalid_flat_node_id,
		fn_type_id, attrs_id, body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_nested.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementCleanupHookPreviewTestFlat{
		flat:    b.take_flat()
		fn_id:   fn_id
		stmt_id: stmt_id
		lhs_id:  lhs_id
		rhs_id:  rhs_id
	}
}

fn autofree_statement_cleanup_hook_preview_test_flat_with_two_files() AutofreeStatementCleanupHookPreviewTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('items',
		autofree_statement_cleanup_hook_preview_test_pos(120))
	first_rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 130)
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_cleanup_hook_preview_test_pos(210))
	first_body_id := b.emit_aux_list_from_ids([first_stmt_id])
	first_fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	first_attrs_id := b.emit_attribute_list([])
	first_fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(100), ast.invalid_flat_node_id,
		first_fn_type_id, first_attrs_id, first_body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_first.v'
		mod:  'main'
	}, [first_fn_id])
	second_lhs_id := b.emit_ident_by_name('items',
		autofree_statement_cleanup_hook_preview_test_pos(320))
	second_rhs_id := autofree_statement_cleanup_hook_preview_test_array_init(mut b, 330)
	second_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [second_lhs_id], [
		second_rhs_id,
	], autofree_statement_cleanup_hook_preview_test_pos(410))
	second_body_id := b.emit_aux_list_from_ids([second_stmt_id])
	second_fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	second_attrs_id := b.emit_attribute_list([])
	second_fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_cleanup_hook_preview_test_pos(300), ast.invalid_flat_node_id,
		second_fn_type_id, second_attrs_id, second_body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_cleanup_hook_preview_second.v'
		mod:  'main'
	}, [second_fn_id])
	return AutofreeStatementCleanupHookPreviewTestFlat{
		flat:    b.take_flat()
		fn_id:   second_fn_id
		stmt_id: second_stmt_id
		lhs_id:  second_lhs_id
		rhs_id:  second_rhs_id
	}
}

fn autofree_statement_cleanup_hook_preview_test_preview(fixture AutofreeStatementCleanupHookPreviewTestFlat) AutofreeCleanCStatementCleanupPreviewFact {
	return autofree_statement_cleanup_hook_preview_test_preview_with_name(fixture, 'items',
		c_local_name('items'))
}

fn autofree_statement_cleanup_hook_preview_test_preview_with_name(fixture AutofreeStatementCleanupHookPreviewTestFlat, name string, target_c_name string) AutofreeCleanCStatementCleanupPreviewFact {
	return AutofreeCleanCStatementCleanupPreviewFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 name
		cleanup_status:       .inert
		cleanup_kind:         .array_after_statement
		fn_node_id:           fixture.fn_id
		fn_pos_id:            100
		target_node_id:       fixture.lhs_id
		target_pos_id:        120
		stmt_node_id:         fixture.stmt_id
		stmt_pos_id:          210
		insert_after_node_id: fixture.stmt_id
		insert_after_pos_id:  210
		stmt_index:           0
		lhs_index:            0
		target_c_name:        target_c_name
		cleanup_symbol:       'array__free'
		cleanup_text:         'array__free(&${target_c_name});'
		reason:               'statement cleanup preview accepted'
	}
}

fn autofree_statement_cleanup_hook_preview_test_next_items_preview(fixture AutofreeStatementCleanupHookPreviewTestFlat) AutofreeCleanCStatementCleanupPreviewFact {
	return AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview_with_name(fixture, 'items',
			c_local_name('items'))
		target_node_id:       fixture.next_lhs_id
		target_pos_id:        220
		stmt_node_id:         fixture.next_stmt_id
		stmt_pos_id:          310
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  310
		stmt_index:           1
	}
}

fn autofree_statement_cleanup_hook_preview_test_later_insert_preview(fixture AutofreeStatementCleanupHookPreviewTestFlat) AutofreeCleanCStatementCleanupPreviewFact {
	return AutofreeCleanCStatementCleanupPreviewFact{
		fn_key:               'next_generation'
		fn_name:              'next_generation'
		name:                 'arr'
		cleanup_status:       .inert
		cleanup_kind:         .array_after_statement
		fn_node_id:           fixture.fn_id
		fn_pos_id:            100
		target_node_id:       fixture.lhs_id
		target_pos_id:        120
		stmt_node_id:         fixture.next_stmt_id
		stmt_pos_id:          410
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  410
		stmt_index:           2
		lhs_index:            0
		target_c_name:        c_local_name('arr')
		cleanup_symbol:       'array__free'
		cleanup_text:         'array__free(&arr);'
		reason:               'statement cleanup preview accepted'
	}
}

fn autofree_statement_cleanup_hook_preview_test_previews(fixture &AutofreeStatementCleanupHookPreviewTestFlat,
	previews []AutofreeCleanCStatementCleanupPreviewFact) []AutofreeCleanCStatementCleanupHookPreviewFact {
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_cleanup_hook_preview_test_fn_cursor(fixture)
	return autofree_statement_cleanup_hook_preview_facts_from_file_cursor(file_cursor, fn_cursor,
		previews)
}

fn autofree_statement_cleanup_hook_preview_test_assert_no_hook(fixture &AutofreeStatementCleanupHookPreviewTestFlat,
	previews []AutofreeCleanCStatementCleanupPreviewFact) {
	hook_previews := autofree_statement_cleanup_hook_preview_test_previews(fixture, previews)
	assert hook_previews.len == 0
}

fn test_autofree_statement_cleanup_hook_preview_accepts_valid_preview() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	preview := autofree_statement_cleanup_hook_preview_test_preview(fixture)
	hook_previews := autofree_statement_cleanup_hook_preview_test_previews(&fixture, [
		preview,
	])
	assert hook_previews.len == 1
	hook_preview := hook_previews[0]
	assert hook_preview.fn_key == preview.fn_key
	assert hook_preview.fn_name == preview.fn_name
	assert hook_preview.name == preview.name
	assert hook_preview.hook_status == .inert
	assert hook_preview.hook_kind == .after_body_before_scheduled_drops
	assert hook_preview.fn_node_id == preview.fn_node_id
	assert hook_preview.fn_pos_id == preview.fn_pos_id
	assert hook_preview.target_node_id == preview.target_node_id
	assert hook_preview.target_pos_id == preview.target_pos_id
	assert hook_preview.stmt_node_id == preview.stmt_node_id
	assert hook_preview.stmt_pos_id == preview.stmt_pos_id
	assert hook_preview.insert_after_node_id == preview.insert_after_node_id
	assert hook_preview.insert_after_pos_id == preview.insert_after_pos_id
	assert hook_preview.stmt_index == preview.stmt_index
	assert hook_preview.lhs_index == preview.lhs_index
	assert hook_preview.target_c_name == preview.target_c_name
	assert hook_preview.cleanup_symbol == preview.cleanup_symbol
	assert hook_preview.cleanup_text == preview.cleanup_text
	assert hook_preview.reason.len > 0
}

fn test_autofree_statement_cleanup_hook_preview_accepts_last_statement_after_prefix() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_source_prefix_then_items()
	preview := autofree_statement_cleanup_hook_preview_test_next_items_preview(fixture)
	hook_previews := autofree_statement_cleanup_hook_preview_test_previews(&fixture, [
		preview,
	])
	assert hook_previews.len == 1
	hook_preview := hook_previews[0]
	assert hook_preview.name == 'items'
	assert hook_preview.name != 'copy'
	assert hook_preview.name != 'source'
	assert hook_preview.stmt_index == 1
	assert hook_preview.target_node_id == fixture.next_lhs_id
	assert hook_preview.target_pos_id == 220
	assert hook_preview.insert_after_node_id == fixture.next_stmt_id
	assert hook_preview.insert_after_pos_id == 310
	assert hook_preview.cleanup_symbol == 'array__free'
	assert hook_preview.cleanup_text == 'array__free(&items);'
	assert !hook_preview.cleanup_text.contains('copy')
	assert !hook_preview.cleanup_text.contains('source')
	assert !hook_preview.cleanup_text.contains('string__free')
}

fn test_autofree_statement_cleanup_hook_preview_accepts_later_final_assignment_after_target_decl() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_later_insert_assignment()
	preview := autofree_statement_cleanup_hook_preview_test_later_insert_preview(fixture)
	hook_previews := autofree_statement_cleanup_hook_preview_test_previews(&fixture, [
		preview,
	])
	assert hook_previews.len == 1
	hook_preview := hook_previews[0]
	assert hook_preview.fn_key == 'next_generation'
	assert hook_preview.fn_name == 'next_generation'
	assert hook_preview.name == 'arr'
	assert hook_preview.stmt_index == 2
	assert hook_preview.target_node_id == fixture.lhs_id
	assert hook_preview.target_pos_id == 120
	assert hook_preview.stmt_node_id == fixture.next_stmt_id
	assert hook_preview.stmt_pos_id == 410
	assert hook_preview.insert_after_node_id == fixture.next_stmt_id
	assert hook_preview.insert_after_pos_id == 410
	assert hook_preview.cleanup_symbol == 'array__free'
	assert hook_preview.cleanup_text == 'array__free(&arr);'
	assert !hook_preview.cleanup_text.contains('gen')
}

fn test_autofree_statement_cleanup_hook_preview_rejects_later_insert_without_target_decl() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_later_insert_assignment()
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_later_insert_preview(fixture)
		target_node_id: fixture.rhs_id
		target_pos_id:  130
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_accepts_mut_ident_lhs() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_modifier_assign(.key_mut,
		false)
	preview := autofree_statement_cleanup_hook_preview_test_preview(fixture)
	hook_previews := autofree_statement_cleanup_hook_preview_test_previews(&fixture, [
		preview,
	])
	assert hook_previews.len == 1
	assert hook_previews[0].target_node_id == preview.target_node_id
	assert hook_previews[0].target_pos_id == preview.target_pos_id
	assert hook_previews[0].cleanup_text == 'array__free(&items);'
}

fn test_autofree_statement_cleanup_hook_preview_accepts_c_keyword_name() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'@return',
	], [
		.decl_assign,
	])
	preview := autofree_statement_cleanup_hook_preview_test_preview_with_name(fixture, '@return',
		'_return')
	hook_previews := autofree_statement_cleanup_hook_preview_test_previews(&fixture, [
		preview,
	])
	assert hook_previews.len == 1
	assert hook_previews[0].target_c_name == '_return'
	assert hook_previews[0].cleanup_text == 'array__free(&_return);'
}

fn test_autofree_statement_cleanup_hook_preview_accepts_array_name() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'array',
	], [
		.decl_assign,
	])
	preview := autofree_statement_cleanup_hook_preview_test_preview_with_name(fixture, 'array',
		'_v_array')
	hook_previews := autofree_statement_cleanup_hook_preview_test_previews(&fixture, [
		preview,
	])
	assert hook_previews.len == 1
	assert hook_previews[0].target_c_name == '_v_array'
	assert hook_previews[0].cleanup_text == 'array__free(&_v_array);'
}

fn test_autofree_statement_cleanup_hook_preview_rejects_empty_preview_list() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture,
		[]AutofreeCleanCStatementCleanupPreviewFact{})
}

fn test_autofree_statement_cleanup_hook_preview_rejects_two_previews() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	preview := autofree_statement_cleanup_hook_preview_test_preview(fixture)
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview, preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_wrong_status() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview(fixture)
		cleanup_status: .unknown
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_wrong_kind() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview(fixture)
		cleanup_kind: .unknown
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_wrong_symbol() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview(fixture)
		cleanup_symbol: 'array__clear'
		cleanup_text:   'array__clear(&items);'
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_wrong_text() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview(fixture)
		cleanup_text: 'array__free(items);'
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_empty_identity() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	for preview in [
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			fn_key: ''
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			fn_name: ''
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			name: ''
		},
	] {
		autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [
			preview,
		])
	}
}

fn test_autofree_statement_cleanup_hook_preview_rejects_invalid_ids() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	for preview in [
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			fn_node_id: ast.FlatNodeId(-1)
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			fn_pos_id: 0
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			target_node_id: ast.FlatNodeId(-1)
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			target_pos_id: 0
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			stmt_node_id: ast.FlatNodeId(-1)
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			stmt_pos_id: 0
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			insert_after_node_id: ast.FlatNodeId(-1)
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			insert_after_pos_id: 0
		},
	] {
		autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [
			preview,
		])
	}
}

fn test_autofree_statement_cleanup_hook_preview_rejects_wrong_file() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_two_files()
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview(fixture)
		fn_pos_id:           300
		target_pos_id:       320
		stmt_pos_id:         410
		insert_after_pos_id: 410
		cleanup_text:        'array__free(&items);'
	}
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_cleanup_hook_preview_test_fn_cursor(&fixture)
	hook_previews := autofree_statement_cleanup_hook_preview_facts_from_file_cursor(file_cursor,
		fn_cursor, [preview])
	assert hook_previews.len == 0
}

fn test_autofree_statement_cleanup_hook_preview_rejects_wrong_function_identity() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	for preview in [
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			fn_key: 'other'
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			fn_name: 'other'
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			fn_node_id: ast.FlatNodeId(999)
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			fn_pos_id: 999
		},
	] {
		autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [
			preview,
		])
	}
}

fn test_autofree_statement_cleanup_hook_preview_rejects_wrong_statement_identity() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	for preview in [
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			stmt_node_id: ast.FlatNodeId(999)
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			stmt_pos_id: 999
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			insert_after_node_id: ast.FlatNodeId(999)
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			insert_after_pos_id: 999
		},
	] {
		autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [
			preview,
		])
	}
}

fn test_autofree_statement_cleanup_hook_preview_rejects_wrong_statement_index() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview(fixture)
		stmt_index: 1
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_non_last_statement() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
		'more_items',
	], [
		.decl_assign,
		.decl_assign,
	])
	preview := autofree_statement_cleanup_hook_preview_test_preview(fixture)
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_prefix_target() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_source_prefix_then_items()
	preview := autofree_statement_cleanup_hook_preview_test_preview_with_name(fixture, 'copy',
		c_local_name('copy'))
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_source_target() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_source_prefix_then_items()
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_next_items_preview(fixture)
		name:          'source'
		target_c_name: 'source'
		cleanup_text:  'array__free(&source);'
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_return_body() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_return()
	preview := autofree_statement_cleanup_hook_preview_test_preview(fixture)
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_nested_body() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_nested_assign()
	preview := autofree_statement_cleanup_hook_preview_test_preview(fixture)
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_non_mut_modifier_lhs() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_modifier_assign(.key_shared,
		false)
	preview := autofree_statement_cleanup_hook_preview_test_preview(fixture)
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_modifier_lhs_with_extra_child() {
	fixture :=
		autofree_statement_cleanup_hook_preview_test_flat_with_modifier_assign(.key_mut, true)
	preview := autofree_statement_cleanup_hook_preview_test_preview(fixture)
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_multi_lhs() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_multi_lhs()
	preview := autofree_statement_cleanup_hook_preview_test_preview(fixture)
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_nonzero_lhs_index() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview(fixture)
		lhs_index: 1
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}

fn test_autofree_statement_cleanup_hook_preview_rejects_target_mismatch() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	for preview in [
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			target_node_id: ast.FlatNodeId(999)
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			target_pos_id: 999
		},
		AutofreeCleanCStatementCleanupPreviewFact{
			...autofree_statement_cleanup_hook_preview_test_preview(fixture)
			name:          'other'
			target_c_name: 'other'
			cleanup_text:  'array__free(&other);'
		},
	] {
		autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [
			preview,
		])
	}
}

fn test_autofree_statement_cleanup_hook_preview_rejects_target_equal_insert() {
	fixture := autofree_statement_cleanup_hook_preview_test_flat_with_assigns([
		'items',
	], [
		.decl_assign,
	])
	preview := AutofreeCleanCStatementCleanupPreviewFact{
		...autofree_statement_cleanup_hook_preview_test_preview(fixture)
		target_node_id: fixture.stmt_id
	}
	autofree_statement_cleanup_hook_preview_test_assert_no_hook(&fixture, [preview])
}
