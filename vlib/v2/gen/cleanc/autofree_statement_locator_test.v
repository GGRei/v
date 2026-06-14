module cleanc

import v2.ast
import v2.token

struct AutofreeStatementLocatorTestFlat {
	flat          ast.FlatAst
	fn_id         ast.FlatNodeId
	first_stmt_id ast.FlatNodeId
	first_lhs_id  ast.FlatNodeId
	first_rhs_id  ast.FlatNodeId
	next_stmt_id  ast.FlatNodeId
	next_lhs_id   ast.FlatNodeId
	next_rhs_id   ast.FlatNodeId
}

fn autofree_statement_locator_test_pos(id int) token.Pos {
	return token.Pos{
		offset: id
		id:     id
	}
}

fn autofree_statement_locator_test_array_init(mut b ast.FlatBuilder, pos_id int) ast.FlatNodeId {
	return b.emit_array_init_expr_by_ids(ast.invalid_flat_node_id, ast.invalid_flat_node_id,
		ast.invalid_flat_node_id, ast.invalid_flat_node_id, ast.invalid_flat_node_id,
		[]ast.FlatNodeId{}, autofree_statement_locator_test_pos(pos_id))
}

fn autofree_statement_locator_test_flat_with_assign(fn_name string, module_name string, is_method bool, is_static bool, language ast.Language, lhs_count int) AutofreeStatementLocatorTestFlat {
	mut b := ast.new_flat_builder()
	lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(120))
	rhs_id := autofree_statement_locator_test_array_init(mut b, 130)
	mut lhs_ids := [lhs_id]
	mut rhs_ids := [rhs_id]
	if lhs_count > 1 {
		lhs_ids << b.emit_ident_by_name('other_items', autofree_statement_locator_test_pos(121))
		rhs_ids << autofree_statement_locator_test_array_init(mut b, 131)
	}
	stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, lhs_ids, rhs_ids,
		autofree_statement_locator_test_pos(210))
	body_id := b.emit_aux_list_from_ids([stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids(fn_name, false, is_method, is_static, language,
		autofree_statement_locator_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_test.v'
		mod:  module_name
	}, [fn_id])
	return AutofreeStatementLocatorTestFlat{
		flat:          b.take_flat()
		fn_id:         fn_id
		first_stmt_id: stmt_id
		first_lhs_id:  lhs_id
		first_rhs_id:  rhs_id
	}
}

fn autofree_statement_locator_test_flat_with_modifier_assign(kind token.Token, extra_child bool) AutofreeStatementLocatorTestFlat {
	mut b := ast.new_flat_builder()
	lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(120))
	extra_lhs_id := b.emit_ident_by_name('extra_items', autofree_statement_locator_test_pos(121))
	modifier_id := b.emit_modifier_expr_by_id(kind, lhs_id,
		autofree_statement_locator_test_pos(119))
	rhs_id := autofree_statement_locator_test_array_init(mut b, 130)
	stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [modifier_id], [rhs_id],
		autofree_statement_locator_test_pos(210))
	body_id := b.emit_aux_list_from_ids([stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_locator_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_modifier_test.v'
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
	return AutofreeStatementLocatorTestFlat{
		flat:          flat
		fn_id:         fn_id
		first_stmt_id: stmt_id
		first_lhs_id:  lhs_id
		first_rhs_id:  rhs_id
	}
}

fn autofree_statement_locator_test_flat_with_two_assigns() AutofreeStatementLocatorTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(120))
	first_rhs_id := autofree_statement_locator_test_array_init(mut b, 130)
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_locator_test_pos(210))
	next_lhs_id := b.emit_ident_by_name('more_items', autofree_statement_locator_test_pos(220))
	next_rhs_id := autofree_statement_locator_test_array_init(mut b, 230)
	next_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [next_lhs_id], [
		next_rhs_id,
	], autofree_statement_locator_test_pos(310))
	body_id := b.emit_aux_list_from_ids([first_stmt_id, next_stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_locator_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementLocatorTestFlat{
		flat:          b.take_flat()
		fn_id:         fn_id
		first_stmt_id: first_stmt_id
		first_lhs_id:  first_lhs_id
		first_rhs_id:  first_rhs_id
		next_stmt_id:  next_stmt_id
		next_lhs_id:   next_lhs_id
		next_rhs_id:   next_rhs_id
	}
}

fn autofree_statement_locator_test_flat_with_prefix_then_items() AutofreeStatementLocatorTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('copy', autofree_statement_locator_test_pos(120))
	first_rhs_id := b.emit_ident_by_name('source', autofree_statement_locator_test_pos(130))
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_locator_test_pos(210))
	next_lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(220))
	next_rhs_id := autofree_statement_locator_test_array_init(mut b, 230)
	next_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [next_lhs_id], [
		next_rhs_id,
	], autofree_statement_locator_test_pos(310))
	body_id := b.emit_aux_list_from_ids([first_stmt_id, next_stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_locator_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_prefix_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementLocatorTestFlat{
		flat:          b.take_flat()
		fn_id:         fn_id
		first_stmt_id: first_stmt_id
		first_lhs_id:  first_lhs_id
		first_rhs_id:  first_rhs_id
		next_stmt_id:  next_stmt_id
		next_lhs_id:   next_lhs_id
		next_rhs_id:   next_rhs_id
	}
}

fn autofree_statement_locator_test_flat_with_two_files() AutofreeStatementLocatorTestFlat {
	mut b := ast.new_flat_builder()
	first_file_lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(120))
	first_file_rhs_id := autofree_statement_locator_test_array_init(mut b, 130)
	first_file_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_file_lhs_id], [
		first_file_rhs_id,
	], autofree_statement_locator_test_pos(210))
	first_file_body_id := b.emit_aux_list_from_ids([first_file_stmt_id])
	first_file_fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	first_file_attrs_id := b.emit_attribute_list([])
	first_file_fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_locator_test_pos(100), ast.invalid_flat_node_id, first_file_fn_type_id,
		first_file_attrs_id, first_file_body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_first.v'
		mod:  'main'
	}, [first_file_fn_id])
	second_file_lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(320))
	second_file_rhs_id := autofree_statement_locator_test_array_init(mut b, 330)
	second_file_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [
		second_file_lhs_id,
	], [second_file_rhs_id], autofree_statement_locator_test_pos(410))
	second_file_body_id := b.emit_aux_list_from_ids([second_file_stmt_id])
	second_file_fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	second_file_attrs_id := b.emit_attribute_list([])
	second_file_fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_locator_test_pos(300), ast.invalid_flat_node_id, second_file_fn_type_id,
		second_file_attrs_id, second_file_body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_second.v'
		mod:  'main'
	}, [second_file_fn_id])
	return AutofreeStatementLocatorTestFlat{
		flat:          b.take_flat()
		fn_id:         second_file_fn_id
		first_stmt_id: second_file_stmt_id
		first_lhs_id:  second_file_lhs_id
		first_rhs_id:  second_file_rhs_id
	}
}

fn autofree_statement_locator_test_flat_with_nested_assign() AutofreeStatementLocatorTestFlat {
	mut b := ast.new_flat_builder()
	lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(120))
	rhs_id := autofree_statement_locator_test_array_init(mut b, 130)
	stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [lhs_id], [rhs_id],
		autofree_statement_locator_test_pos(210))
	block_id := b.emit_block_stmt_by_ids([stmt_id])
	body_id := b.emit_aux_list_from_ids([block_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_locator_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_nested.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementLocatorTestFlat{
		flat:          b.take_flat()
		fn_id:         fn_id
		first_stmt_id: stmt_id
		first_lhs_id:  lhs_id
		first_rhs_id:  rhs_id
	}
}

fn autofree_statement_locator_test_flat_with_invalid_body_edge() AutofreeStatementLocatorTestFlat {
	mut b := ast.new_flat_builder()
	lhs_id := b.emit_ident_by_name('items', autofree_statement_locator_test_pos(120))
	rhs_id := autofree_statement_locator_test_array_init(mut b, 130)
	stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [lhs_id], [rhs_id],
		autofree_statement_locator_test_pos(210))
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_locator_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		stmt_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_locator_invalid_body.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementLocatorTestFlat{
		flat:          b.take_flat()
		fn_id:         fn_id
		first_stmt_id: stmt_id
		first_lhs_id:  lhs_id
		first_rhs_id:  rhs_id
	}
}

fn autofree_statement_locator_test_anchor(fixture &AutofreeStatementLocatorTestFlat) AutofreeCleanCStatementAnchorFact {
	return AutofreeCleanCStatementAnchorFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		anchor_status:        .inert
		target_node_id:       fixture.first_lhs_id
		target_pos_id:        120
		insert_after_node_id: fixture.first_stmt_id
		insert_after_pos_id:  210
		reason:               'anchor accepted'
	}
}

fn autofree_statement_locator_test_second_file_anchor(fixture &AutofreeStatementLocatorTestFlat) AutofreeCleanCStatementAnchorFact {
	return AutofreeCleanCStatementAnchorFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		anchor_status:        .inert
		target_node_id:       fixture.first_lhs_id
		target_pos_id:        320
		insert_after_node_id: fixture.first_stmt_id
		insert_after_pos_id:  410
		reason:               'anchor accepted'
	}
}

fn autofree_statement_locator_test_next_anchor(fixture &AutofreeStatementLocatorTestFlat) AutofreeCleanCStatementAnchorFact {
	return AutofreeCleanCStatementAnchorFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'more_items'
		anchor_status:        .inert
		target_node_id:       fixture.next_lhs_id
		target_pos_id:        220
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  310
		reason:               'anchor accepted'
	}
}

fn autofree_statement_locator_test_fn_cursor(fixture &AutofreeStatementLocatorTestFlat) ast.Cursor {
	return ast.Cursor{
		flat: &fixture.flat
		id:   fixture.fn_id
	}
}

fn autofree_statement_locator_test_locations(fixture &AutofreeStatementLocatorTestFlat, anchors []AutofreeCleanCStatementAnchorFact) []AutofreeCleanCStatementLocationFact {
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_locator_test_fn_cursor(fixture)
	return autofree_statement_location_facts_from_file_cursor(file_cursor, fn_cursor, anchors)
}

fn autofree_statement_locator_test_assert_no_location(fixture &AutofreeStatementLocatorTestFlat, anchors []AutofreeCleanCStatementAnchorFact) {
	locations := autofree_statement_locator_test_locations(fixture, anchors)
	assert locations.len == 0
}

fn autofree_statement_locator_test_assert_location(location AutofreeCleanCStatementLocationFact, fixture &AutofreeStatementLocatorTestFlat, anchor AutofreeCleanCStatementAnchorFact) {
	assert location.fn_key == anchor.fn_key
	assert location.fn_name == anchor.fn_name
	assert location.name == anchor.name
	assert location.location_status == .inert
	assert location.fn_node_id == fixture.fn_id
	assert location.fn_pos_id == 100
	assert location.stmt_node_id == fixture.first_stmt_id
	assert location.stmt_pos_id == 210
	assert location.stmt_index == 0
	assert location.lhs_index == 0
	assert location.target_node_id == fixture.first_lhs_id
	assert location.target_pos_id == 120
	assert location.insert_after_node_id == fixture.first_stmt_id
	assert location.insert_after_pos_id == 210
	assert location.reason.len > 0
}

fn test_autofree_statement_locator_file_cursor_accepts_direct_array_decl() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, false,
		.v, 1)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_locator_test_fn_cursor(&fixture)
	locations := autofree_statement_location_facts_from_file_cursor(file_cursor, fn_cursor, [
		anchor,
	])
	assert locations.len == 1
	autofree_statement_locator_test_assert_location(locations[0], &fixture, anchor)
}

fn test_autofree_statement_locator_file_cursor_accepts_mut_array_decl() {
	fixture := autofree_statement_locator_test_flat_with_modifier_assign(.key_mut, false)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_locator_test_fn_cursor(&fixture)
	locations := autofree_statement_location_facts_from_file_cursor(file_cursor, fn_cursor, [
		anchor,
	])
	assert locations.len == 1
	autofree_statement_locator_test_assert_location(locations[0], &fixture, anchor)
}

fn test_autofree_statement_locator_accepts_last_statement_after_prefix() {
	fixture := autofree_statement_locator_test_flat_with_prefix_then_items()
	anchor := AutofreeCleanCStatementAnchorFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		anchor_status:        .inert
		target_node_id:       fixture.next_lhs_id
		target_pos_id:        220
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  310
		reason:               'anchor accepted'
	}
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_locator_test_fn_cursor(&fixture)
	locations := autofree_statement_location_facts_from_file_cursor(file_cursor, fn_cursor, [
		anchor,
	])
	assert locations.len == 1
	location := locations[0]
	assert location.name == 'items'
	assert location.name != 'copy'
	assert location.name != 'source'
	assert location.stmt_index == 1
	assert location.target_node_id == fixture.next_lhs_id
	assert location.target_pos_id == 220
	assert location.insert_after_node_id == fixture.next_stmt_id
	assert location.insert_after_pos_id == 310
}

fn test_autofree_statement_locator_rejects_rhs_target() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, false,
		.v, 1)
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_anchor(&fixture)
		target_node_id: fixture.first_rhs_id
		target_pos_id:  130
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_multi_lhs_assign() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, false,
		.v, 2)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_non_mut_modifier_lhs() {
	fixture := autofree_statement_locator_test_flat_with_modifier_assign(.key_shared, false)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_modifier_lhs_with_extra_child() {
	fixture := autofree_statement_locator_test_flat_with_modifier_assign(.key_mut, true)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_nested_assign() {
	fixture := autofree_statement_locator_test_flat_with_nested_assign()
	anchor := autofree_statement_locator_test_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_invalid_body_edge() {
	fixture := autofree_statement_locator_test_flat_with_invalid_body_edge()
	anchor := autofree_statement_locator_test_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_duplicate_target_position() {
	fixture := autofree_statement_locator_test_flat_with_two_assigns()
	anchor := autofree_statement_locator_test_anchor(&fixture)
	duplicate := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_next_anchor(&fixture)
		target_node_id: fixture.first_lhs_id
		target_pos_id:  120
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor, duplicate])
}

fn test_autofree_statement_locator_rejects_duplicate_insert_slot() {
	fixture := autofree_statement_locator_test_flat_with_two_assigns()
	anchor := autofree_statement_locator_test_anchor(&fixture)
	duplicate := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_next_anchor(&fixture)
		insert_after_node_id: fixture.first_stmt_id
		insert_after_pos_id:  210
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor, duplicate])
}

fn test_autofree_statement_locator_rejects_method_function() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', true, false,
		.v, 1)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_static_function() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, true,
		.v, 1)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_fn_cursor_rejects_bad_kind() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, false,
		.v, 1)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	stmt_cursor := ast.Cursor{
		flat: &fixture.flat
		id:   fixture.first_stmt_id
	}
	file_cursor := fixture.flat.file_cursor(0)
	locations := autofree_statement_location_facts_from_file_cursor(file_cursor, stmt_cursor, [
		anchor,
	])
	assert locations.len == 0
}

fn test_autofree_statement_locator_file_cursor_rejects_different_flat_cursor_context() {
	file_fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false,
		false, .v, 1)
	fn_fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false,
		false, .v, 1)
	anchor := autofree_statement_locator_test_anchor(&fn_fixture)
	file_cursor := file_fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_locator_test_fn_cursor(&fn_fixture)
	locations := autofree_statement_location_facts_from_file_cursor(file_cursor, fn_cursor, [
		anchor,
	])
	assert locations.len == 0
}

fn test_autofree_statement_locator_file_cursor_rejects_same_flat_different_file_context() {
	fixture := autofree_statement_locator_test_flat_with_two_files()
	anchor := autofree_statement_locator_test_second_file_anchor(&fixture)
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_locator_test_fn_cursor(&fixture)
	locations := autofree_statement_location_facts_from_file_cursor(file_cursor, fn_cursor, [
		anchor,
	])
	assert locations.len == 0
}

fn test_autofree_statement_locator_rejects_duplicate_fn_key_across_files() {
	fixture := autofree_statement_locator_test_flat_with_two_files()
	anchor := autofree_statement_locator_test_second_file_anchor(&fixture)
	file_cursor := fixture.flat.file_cursor(1)
	fn_cursor := autofree_statement_locator_test_fn_cursor(&fixture)
	file_locations := autofree_statement_location_facts_from_file_cursor(file_cursor, fn_cursor, [
		anchor,
	])
	assert file_locations.len == 0
}

fn test_autofree_statement_locator_rejects_non_v_function() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, false,
		.c, 1)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_empty_fn_key() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, false,
		.v, 1)
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_anchor(&fixture)
		fn_key: ''
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_fn_key_mismatch() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, false,
		.v, 1)
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_anchor(&fixture)
		fn_key: 'other_make_items'
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_rejects_fn_name_mismatch() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, false,
		.v, 1)
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_anchor(&fixture)
		fn_name: 'other_make_items'
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_flat_rejects_module_fn_key_mismatch() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'math', false, false,
		.v, 1)
	anchor := autofree_statement_locator_test_anchor(&fixture)
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}

fn test_autofree_statement_locator_flat_rejects_qualified_key_for_root_module() {
	fixture := autofree_statement_locator_test_flat_with_assign('make_items', 'main', false, false,
		.v, 1)
	anchor := AutofreeCleanCStatementAnchorFact{
		...autofree_statement_locator_test_anchor(&fixture)
		fn_key: 'math__make_items'
	}
	autofree_statement_locator_test_assert_no_location(&fixture, [anchor])
}
