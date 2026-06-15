module cleanc

import v2.ast
import v2.token

struct AutofreeStatementPreviewTestFlat {
	flat         ast.FlatAst
	fn_id        ast.FlatNodeId
	stmt_id      ast.FlatNodeId
	lhs_id       ast.FlatNodeId
	rhs_id       ast.FlatNodeId
	next_stmt_id ast.FlatNodeId
	next_lhs_id  ast.FlatNodeId
	next_rhs_id  ast.FlatNodeId
}

fn autofree_statement_preview_test_pos(id int) token.Pos {
	return token.Pos{
		offset: id
		id:     id
	}
}

fn autofree_statement_preview_test_array_init(mut b ast.FlatBuilder, pos_id int) ast.FlatNodeId {
	return b.emit_array_init_expr_by_ids(ast.invalid_flat_node_id, ast.invalid_flat_node_id,
		ast.invalid_flat_node_id, ast.invalid_flat_node_id, ast.invalid_flat_node_id,
		[]ast.FlatNodeId{}, autofree_statement_preview_test_pos(pos_id))
}

fn autofree_statement_preview_test_fn_cursor(fixture &AutofreeStatementPreviewTestFlat) ast.Cursor {
	return ast.Cursor{
		flat: &fixture.flat
		id:   fixture.fn_id
	}
}

fn autofree_statement_preview_test_flat_with_assigns(names []string, ops []token.Token) AutofreeStatementPreviewTestFlat {
	mut b := ast.new_flat_builder()
	mut stmt_ids := []ast.FlatNodeId{}
	mut lhs_ids := []ast.FlatNodeId{}
	mut rhs_ids := []ast.FlatNodeId{}
	for i, name in names {
		stmt_pos := 210 + i * 100
		lhs_pos := 120 + i * 100
		rhs_pos := 130 + i * 100
		lhs_id := b.emit_ident_by_name(name, autofree_statement_preview_test_pos(lhs_pos))
		rhs_id := autofree_statement_preview_test_array_init(mut b, rhs_pos)
		op := if i < ops.len { ops[i] } else { token.Token.decl_assign }
		stmt_id := b.emit_assign_stmt_by_ids(op, [lhs_id], [rhs_id],
			autofree_statement_preview_test_pos(stmt_pos))
		lhs_ids << lhs_id
		rhs_ids << rhs_id
		stmt_ids << stmt_id
	}
	body_id := b.emit_aux_list_from_ids(stmt_ids)
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_preview_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_preview_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementPreviewTestFlat{
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

fn autofree_statement_preview_test_flat_with_source_prefix_then_items() AutofreeStatementPreviewTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('copy', autofree_statement_preview_test_pos(120))
	first_rhs_id := b.emit_ident_by_name('source', autofree_statement_preview_test_pos(130))
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_preview_test_pos(210))
	next_lhs_id := b.emit_ident_by_name('items', autofree_statement_preview_test_pos(220))
	next_rhs_id := autofree_statement_preview_test_array_init(mut b, 230)
	next_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [next_lhs_id], [
		next_rhs_id,
	], autofree_statement_preview_test_pos(310))
	body_id := b.emit_aux_list_from_ids([first_stmt_id, next_stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_preview_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_preview_prefix_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementPreviewTestFlat{
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

fn autofree_statement_preview_test_flat_with_later_insert_assignment() AutofreeStatementPreviewTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('arr', autofree_statement_preview_test_pos(120))
	first_rhs_id := autofree_statement_preview_test_array_init(mut b, 130)
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_preview_test_pos(210))
	block_id := b.emit_block_stmt_by_ids([])
	next_lhs_id := b.emit_ident_by_name('gen', autofree_statement_preview_test_pos(320))
	next_rhs_id := b.emit_ident_by_name('arr', autofree_statement_preview_test_pos(330))
	next_stmt_id := b.emit_assign_stmt_by_ids(.assign, [next_lhs_id], [
		next_rhs_id,
	], autofree_statement_preview_test_pos(410))
	body_id := b.emit_aux_list_from_ids([first_stmt_id, block_id, next_stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('next_generation', false, false, false, .v,
		autofree_statement_preview_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_preview_later_insert_test.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementPreviewTestFlat{
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

fn autofree_statement_preview_test_flat_with_return() AutofreeStatementPreviewTestFlat {
	mut b := ast.new_flat_builder()
	rhs_id := autofree_statement_preview_test_array_init(mut b, 130)
	stmt_id := b.emit_return_stmt_by_ids([rhs_id])
	body_id := b.emit_aux_list_from_ids([stmt_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_preview_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_preview_return.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementPreviewTestFlat{
		flat:    b.take_flat()
		fn_id:   fn_id
		stmt_id: stmt_id
		lhs_id:  rhs_id
		rhs_id:  rhs_id
	}
}

fn autofree_statement_preview_test_flat_with_nested_assign() AutofreeStatementPreviewTestFlat {
	mut b := ast.new_flat_builder()
	lhs_id := b.emit_ident_by_name('items', autofree_statement_preview_test_pos(120))
	rhs_id := autofree_statement_preview_test_array_init(mut b, 130)
	stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [lhs_id], [rhs_id],
		autofree_statement_preview_test_pos(210))
	block_id := b.emit_block_stmt_by_ids([stmt_id])
	body_id := b.emit_aux_list_from_ids([block_id])
	fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	attrs_id := b.emit_attribute_list([])
	fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_preview_test_pos(100), ast.invalid_flat_node_id, fn_type_id, attrs_id,
		body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_preview_nested.v'
		mod:  'main'
	}, [fn_id])
	return AutofreeStatementPreviewTestFlat{
		flat:    b.take_flat()
		fn_id:   fn_id
		stmt_id: stmt_id
		lhs_id:  lhs_id
		rhs_id:  rhs_id
	}
}

fn autofree_statement_preview_test_flat_with_two_files() AutofreeStatementPreviewTestFlat {
	mut b := ast.new_flat_builder()
	first_lhs_id := b.emit_ident_by_name('items', autofree_statement_preview_test_pos(120))
	first_rhs_id := autofree_statement_preview_test_array_init(mut b, 130)
	first_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [first_lhs_id], [
		first_rhs_id,
	], autofree_statement_preview_test_pos(210))
	first_body_id := b.emit_aux_list_from_ids([first_stmt_id])
	first_fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	first_attrs_id := b.emit_attribute_list([])
	first_fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_preview_test_pos(100), ast.invalid_flat_node_id, first_fn_type_id,
		first_attrs_id, first_body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_preview_first.v'
		mod:  'main'
	}, [first_fn_id])
	second_lhs_id := b.emit_ident_by_name('items', autofree_statement_preview_test_pos(320))
	second_rhs_id := autofree_statement_preview_test_array_init(mut b, 330)
	second_stmt_id := b.emit_assign_stmt_by_ids(.decl_assign, [second_lhs_id], [
		second_rhs_id,
	], autofree_statement_preview_test_pos(410))
	second_body_id := b.emit_aux_list_from_ids([second_stmt_id])
	second_fn_type_id := b.emit_type(ast.Type(ast.FnType{}))
	second_attrs_id := b.emit_attribute_list([])
	second_fn_id := b.emit_fn_decl_by_ids('make_items', false, false, false, .v,
		autofree_statement_preview_test_pos(300), ast.invalid_flat_node_id, second_fn_type_id,
		second_attrs_id, second_body_id)
	b.append_file_with_stmt_ids(ast.File{
		name: 'autofree_statement_preview_second.v'
		mod:  'main'
	}, [second_fn_id])
	return AutofreeStatementPreviewTestFlat{
		flat:    b.take_flat()
		fn_id:   second_fn_id
		stmt_id: second_stmt_id
		lhs_id:  second_lhs_id
		rhs_id:  second_rhs_id
	}
}

fn autofree_statement_preview_test_location(fixture AutofreeStatementPreviewTestFlat) AutofreeCleanCStatementLocationFact {
	return AutofreeCleanCStatementLocationFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		location_status:      .inert
		fn_node_id:           fixture.fn_id
		fn_pos_id:            100
		stmt_node_id:         fixture.stmt_id
		stmt_pos_id:          210
		stmt_index:           0
		lhs_index:            0
		target_node_id:       fixture.lhs_id
		target_pos_id:        120
		insert_after_node_id: fixture.stmt_id
		insert_after_pos_id:  210
		reason:               'statement location accepted'
	}
}

fn autofree_statement_preview_test_next_location(fixture AutofreeStatementPreviewTestFlat) AutofreeCleanCStatementLocationFact {
	return AutofreeCleanCStatementLocationFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'more_items'
		location_status:      .inert
		fn_node_id:           fixture.fn_id
		fn_pos_id:            100
		stmt_node_id:         fixture.next_stmt_id
		stmt_pos_id:          310
		stmt_index:           1
		lhs_index:            0
		target_node_id:       fixture.next_lhs_id
		target_pos_id:        220
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  310
		reason:               'statement location accepted'
	}
}

fn autofree_statement_preview_test_next_items_location(fixture AutofreeStatementPreviewTestFlat) AutofreeCleanCStatementLocationFact {
	return AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_next_location(fixture)
		name: 'items'
	}
}

fn autofree_statement_preview_test_later_insert_location(fixture AutofreeStatementPreviewTestFlat) AutofreeCleanCStatementLocationFact {
	return AutofreeCleanCStatementLocationFact{
		fn_key:               'next_generation'
		fn_name:              'next_generation'
		name:                 'arr'
		location_status:      .inert
		fn_node_id:           fixture.fn_id
		fn_pos_id:            100
		stmt_node_id:         fixture.next_stmt_id
		stmt_pos_id:          410
		stmt_index:           2
		lhs_index:            0
		target_node_id:       fixture.lhs_id
		target_pos_id:        120
		insert_after_node_id: fixture.next_stmt_id
		insert_after_pos_id:  410
		reason:               'statement location accepted'
	}
}

fn autofree_statement_preview_test_second_file_location(fixture AutofreeStatementPreviewTestFlat) AutofreeCleanCStatementLocationFact {
	return AutofreeCleanCStatementLocationFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		location_status:      .inert
		fn_node_id:           fixture.fn_id
		fn_pos_id:            300
		stmt_node_id:         fixture.stmt_id
		stmt_pos_id:          410
		stmt_index:           0
		lhs_index:            0
		target_node_id:       fixture.lhs_id
		target_pos_id:        320
		insert_after_node_id: fixture.stmt_id
		insert_after_pos_id:  410
		reason:               'statement location accepted'
	}
}

fn autofree_statement_preview_test_previews(fixture &AutofreeStatementPreviewTestFlat,
	locations []AutofreeCleanCStatementLocationFact) []AutofreeCleanCStatementPreviewFact {
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_preview_test_fn_cursor(fixture)
	return autofree_statement_preview_facts_from_file_cursor(file_cursor, fn_cursor, locations)
}

fn autofree_statement_preview_test_assert_no_preview(fixture &AutofreeStatementPreviewTestFlat,
	locations []AutofreeCleanCStatementLocationFact) {
	previews := autofree_statement_preview_test_previews(fixture, locations)
	assert previews.len == 0
}

fn test_autofree_statement_preview_accepts_valid_location() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := autofree_statement_preview_test_location(fixture)
	previews := autofree_statement_preview_test_previews(&fixture, [location])
	assert previews.len == 1
	preview := previews[0]
	assert preview.fn_key == location.fn_key
	assert preview.fn_name == location.fn_name
	assert preview.name == location.name
	assert preview.preview_status == .inert
	assert preview.fn_node_id == location.fn_node_id
	assert preview.fn_pos_id == location.fn_pos_id
	assert preview.stmt_node_id == location.stmt_node_id
	assert preview.stmt_pos_id == location.stmt_pos_id
	assert preview.stmt_index == location.stmt_index
	assert preview.lhs_index == location.lhs_index
	assert preview.target_node_id == location.target_node_id
	assert preview.target_pos_id == location.target_pos_id
	assert preview.insert_after_node_id == location.insert_after_node_id
	assert preview.insert_after_pos_id == location.insert_after_pos_id
	assert preview.reason.len > 0
}

fn test_autofree_statement_preview_accepts_last_statement_after_prefix() {
	fixture := autofree_statement_preview_test_flat_with_source_prefix_then_items()
	location := autofree_statement_preview_test_next_items_location(fixture)
	previews := autofree_statement_preview_test_previews(&fixture, [location])
	assert previews.len == 1
	preview := previews[0]
	assert preview.name == 'items'
	assert preview.name != 'copy'
	assert preview.name != 'source'
	assert preview.stmt_index == 1
	assert preview.target_node_id == fixture.next_lhs_id
	assert preview.target_pos_id == 220
	assert preview.insert_after_node_id == fixture.next_stmt_id
	assert preview.insert_after_pos_id == 310
}

fn test_autofree_statement_preview_accepts_later_final_assignment_after_target_decl() {
	fixture := autofree_statement_preview_test_flat_with_later_insert_assignment()
	location := autofree_statement_preview_test_later_insert_location(fixture)
	previews := autofree_statement_preview_test_previews(&fixture, [location])
	assert previews.len == 1
	preview := previews[0]
	assert preview.fn_key == 'next_generation'
	assert preview.fn_name == 'next_generation'
	assert preview.name == 'arr'
	assert preview.stmt_index == 2
	assert preview.target_node_id == fixture.lhs_id
	assert preview.target_pos_id == 120
	assert preview.stmt_node_id == fixture.next_stmt_id
	assert preview.stmt_pos_id == 410
	assert preview.insert_after_node_id == fixture.next_stmt_id
	assert preview.insert_after_pos_id == 410
	assert preview.lhs_index == 0
}

fn test_autofree_statement_preview_rejects_return_statement() {
	fixture := autofree_statement_preview_test_flat_with_return()
	location := autofree_statement_preview_test_location(fixture)
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_nested_assign() {
	fixture := autofree_statement_preview_test_flat_with_nested_assign()
	location := autofree_statement_preview_test_location(fixture)
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_cross_file_context() {
	fixture := autofree_statement_preview_test_flat_with_two_files()
	location := autofree_statement_preview_test_second_file_location(fixture)
	file_cursor := fixture.flat.file_cursor(0)
	fn_cursor := autofree_statement_preview_test_fn_cursor(&fixture)
	previews := autofree_statement_preview_facts_from_file_cursor(file_cursor, fn_cursor, [
		location,
	])
	assert previews.len == 0
}

fn test_autofree_statement_preview_rejects_later_assign_to_same_name() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items', 'items'], [
		.decl_assign,
		.assign,
	])
	location := autofree_statement_preview_test_location(fixture)
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_non_last_statement() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items', 'more_items'], [
		.decl_assign,
		.decl_assign,
	])
	location := autofree_statement_preview_test_location(fixture)
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_prefix_target_as_non_last_statement() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['copy', 'items'], [
		.decl_assign,
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		name: 'copy'
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_bad_status() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		location_status: .unknown
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_empty_fn_key() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		fn_key: ''
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_empty_fn_name() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		fn_name: ''
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_empty_name() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		name: ''
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_invalid_fn_ids() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		fn_node_id: ast.FlatNodeId(-1)
		fn_pos_id:  0
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_invalid_stmt_ids() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		stmt_node_id: ast.FlatNodeId(-1)
		stmt_pos_id:  0
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_invalid_target_ids() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		target_node_id: ast.FlatNodeId(-1)
		target_pos_id:  0
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_invalid_insert_after_ids() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		insert_after_node_id: ast.FlatNodeId(-1)
		insert_after_pos_id:  0
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_target_equal_insert_after() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		insert_after_node_id: fixture.lhs_id
		insert_after_pos_id:  120
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_stmt_mismatch() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		stmt_node_id: ast.FlatNodeId(int(fixture.stmt_id) + 1)
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_stmt_pos_mismatch() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		stmt_pos_id: 211
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_negative_stmt_index() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		stmt_index: -1
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_nonzero_lhs_index() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		lhs_index: 1
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location])
}

fn test_autofree_statement_preview_rejects_duplicate_name() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items', 'more_items'], [
		.decl_assign,
		.decl_assign,
	])
	location := autofree_statement_preview_test_location(fixture)
	duplicate := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_next_location(fixture)
		name: 'items'
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location, duplicate])
}

fn test_autofree_statement_preview_rejects_duplicate_target_position() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items', 'more_items'], [
		.decl_assign,
		.decl_assign,
	])
	location := autofree_statement_preview_test_location(fixture)
	duplicate := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_next_location(fixture)
		target_node_id: fixture.lhs_id
		target_pos_id:  120
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location, duplicate])
}

fn test_autofree_statement_preview_rejects_duplicate_insertion_slot() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := autofree_statement_preview_test_location(fixture)
	duplicate := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		name:                 'more_items'
		target_node_id:       fixture.rhs_id
		target_pos_id:        130
		stmt_node_id:         fixture.rhs_id
		stmt_pos_id:          130
		insert_after_node_id: fixture.stmt_id
		insert_after_pos_id:  210
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location, duplicate])
}

fn test_autofree_statement_preview_rejects_duplicate_statement_position() {
	fixture := autofree_statement_preview_test_flat_with_assigns(['items'], [
		.decl_assign,
	])
	location := autofree_statement_preview_test_location(fixture)
	duplicate := AutofreeCleanCStatementLocationFact{
		...autofree_statement_preview_test_location(fixture)
		name:                 'more_items'
		target_node_id:       fixture.fn_id
		target_pos_id:        100
		insert_after_node_id: fixture.rhs_id
		insert_after_pos_id:  130
		stmt_node_id:         fixture.stmt_id
		stmt_pos_id:          210
	}
	autofree_statement_preview_test_assert_no_preview(&fixture, [location, duplicate])
}
