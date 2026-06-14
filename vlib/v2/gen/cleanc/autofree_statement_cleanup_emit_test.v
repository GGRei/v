module cleanc

import strings
import v2.ast
import v2.pref as vpref
import v2.token

struct AutofreeStatementCleanupEmitTestContextFields {
mut:
	fn_key               string
	fn_name              string
	name                 string
	context_status       AutofreeCleanCStatementCleanupEmitContextStatus
	context_kind         AutofreeCleanCStatementCleanupEmitContextKind
	fn_node_id           ast.FlatNodeId
	fn_pos_id            int
	target_node_id       ast.FlatNodeId
	target_pos_id        int
	stmt_node_id         ast.FlatNodeId
	stmt_pos_id          int
	insert_after_node_id ast.FlatNodeId
	insert_after_pos_id  int
	stmt_index           int
	lhs_index            int
	target_c_name        string
	cleanup_symbol       string
	cleanup_text         string
	context_key          string
	reason               string
}

fn autofree_statement_cleanup_emit_test_context_fields() AutofreeStatementCleanupEmitTestContextFields {
	return AutofreeStatementCleanupEmitTestContextFields{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		context_status:       .inert
		context_kind:         .after_body_before_scheduled_drops
		fn_node_id:           ast.FlatNodeId(10)
		fn_pos_id:            100
		target_node_id:       ast.FlatNodeId(20)
		target_pos_id:        120
		stmt_node_id:         ast.FlatNodeId(30)
		stmt_pos_id:          210
		insert_after_node_id: ast.FlatNodeId(30)
		insert_after_pos_id:  210
		stmt_index:           0
		lhs_index:            0
		target_c_name:        'items'
		cleanup_symbol:       'array__free'
		cleanup_text:         'array__free(&items);'
		context_key:          'make_items:10:100:20:120:30:210:items'
		reason:               'statement cleanup emit context accepted'
	}
}

fn autofree_statement_cleanup_emit_test_context_from_fields(fields AutofreeStatementCleanupEmitTestContextFields) AutofreeCleanCStatementCleanupEmitContextFact {
	return AutofreeCleanCStatementCleanupEmitContextFact{
		fn_key:               fields.fn_key
		fn_name:              fields.fn_name
		name:                 fields.name
		context_status:       fields.context_status
		context_kind:         fields.context_kind
		fn_node_id:           fields.fn_node_id
		fn_pos_id:            fields.fn_pos_id
		target_node_id:       fields.target_node_id
		target_pos_id:        fields.target_pos_id
		stmt_node_id:         fields.stmt_node_id
		stmt_pos_id:          fields.stmt_pos_id
		insert_after_node_id: fields.insert_after_node_id
		insert_after_pos_id:  fields.insert_after_pos_id
		stmt_index:           fields.stmt_index
		lhs_index:            fields.lhs_index
		target_c_name:        fields.target_c_name
		cleanup_symbol:       fields.cleanup_symbol
		cleanup_text:         fields.cleanup_text
		context_key:          fields.context_key
		reason:               fields.reason
	}
}

fn autofree_statement_cleanup_emit_test_context() AutofreeCleanCStatementCleanupEmitContextFact {
	return autofree_statement_cleanup_emit_test_context_from_fields(autofree_statement_cleanup_emit_test_context_fields())
}

fn autofree_statement_cleanup_emit_test_fn_decl() ast.FnDecl {
	return ast.FnDecl{
		name: 'make_items'
		pos:  token.Pos{
			id: 100
		}
	}
}

fn autofree_statement_cleanup_emit_test_gen(autofree bool) Gen {
	prefs := &vpref.Preferences{
		autofree: autofree
	}
	return Gen{
		pref: prefs
		sb:   strings.new_builder(64)
	}
}

fn autofree_statement_cleanup_emit_test_freestanding_gen(hooks []string) Gen {
	prefs := &vpref.Preferences{
		autofree:           true
		freestanding:       true
		freestanding_hooks: hooks
	}
	return Gen{
		pref: prefs
		sb:   strings.new_builder(64)
	}
}

fn autofree_statement_cleanup_emit_test_cross_gen() Gen {
	prefs := &vpref.Preferences{
		autofree:       true
		target_os:      'cross'
		output_cross_c: true
	}
	return Gen{
		pref: prefs
		sb:   strings.new_builder(64)
	}
}

fn autofree_statement_cleanup_emit_test_install_context(mut g Gen, context AutofreeCleanCStatementCleanupEmitContextFact,
	prepared bool) {
	g.autofree_cleanup_emit_context = context
	g.has_autofree_cleanup_emit_context = true
	g.autofree_cleanup_emit_context_consumed = false
	g.autofree_cleanup_emit_context_prepared = prepared
	if prepared {
		g.autofree_cleanup_emit_fn_key = context.fn_key
		g.autofree_cleanup_emit_fn_node_id = context.fn_node_id
		g.autofree_cleanup_emit_fn_pos_id = context.fn_pos_id
	}
}

fn test_autofree_statement_cleanup_emit_writes_valid_context_once() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == 'array__free(&items);\n'
	assert g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_writes_last_statement_items_context_once() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	mut fields := autofree_statement_cleanup_emit_test_context_fields()
	fields.target_node_id = ast.FlatNodeId(40)
	fields.target_pos_id = 220
	fields.stmt_node_id = ast.FlatNodeId(50)
	fields.stmt_pos_id = 310
	fields.insert_after_node_id = ast.FlatNodeId(50)
	fields.insert_after_pos_id = 310
	fields.stmt_index = 1
	fields.context_key = 'make_items:10:100:40:220:50:310:items'
	context := autofree_statement_cleanup_emit_test_context_from_fields(fields)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	output := g.sb.str()
	assert output == 'array__free(&items);\n'
	assert !output.contains('copy')
	assert !output.contains('source')
	assert !output.contains('string__free')
	assert g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_skips_disabled_context() {
	mut g := autofree_statement_cleanup_emit_test_gen(false)
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
}

fn test_autofree_statement_cleanup_emit_keeps_cross_context() {
	mut g := autofree_statement_cleanup_emit_test_cross_gen()
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == 'array__free(&items);\n'
	assert g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_skips_freestanding_context() {
	mut g := autofree_statement_cleanup_emit_test_freestanding_gen([]string{})
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
	assert !g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_skips_freestanding_alloc_hook_context() {
	mut g := autofree_statement_cleanup_emit_test_freestanding_gen(['alloc'])
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
	assert !g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_skips_missing_context() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
}

fn test_autofree_statement_cleanup_emit_skips_consumed_context() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_cleanup_emit_context_consumed = true
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
}

fn test_autofree_statement_cleanup_emit_skips_bad_status() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	mut fields := autofree_statement_cleanup_emit_test_context_fields()
	fields.context_status = .unknown
	context := autofree_statement_cleanup_emit_test_context_from_fields(fields)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
}

fn test_autofree_statement_cleanup_emit_skips_bad_kind() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	mut fields := autofree_statement_cleanup_emit_test_context_fields()
	fields.context_kind = .unknown
	context := autofree_statement_cleanup_emit_test_context_from_fields(fields)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
}

fn test_autofree_statement_cleanup_emit_skips_bad_symbol() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	mut fields := autofree_statement_cleanup_emit_test_context_fields()
	fields.cleanup_symbol = 'string__free'
	fields.cleanup_text = 'string__free(&items);'
	context := autofree_statement_cleanup_emit_test_context_from_fields(fields)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
}

fn test_autofree_statement_cleanup_emit_skips_bad_text() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	mut fields := autofree_statement_cleanup_emit_test_context_fields()
	fields.cleanup_text = 'array__free(items);'
	context := autofree_statement_cleanup_emit_test_context_from_fields(fields)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
}

fn test_autofree_statement_cleanup_emit_skips_bad_ids() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	mut fields := autofree_statement_cleanup_emit_test_context_fields()
	fields.target_node_id = ast.FlatNodeId(-1)
	context := autofree_statement_cleanup_emit_test_context_from_fields(fields)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
}

fn test_autofree_statement_cleanup_emit_skips_fn_mismatch() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('other_fn', &node)
	assert g.sb.str() == ''
}

fn test_autofree_statement_cleanup_emit_wrong_fn_does_not_consume_context() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('other_fn', &node)
	assert g.sb.str() == ''
	assert !g.autofree_cleanup_emit_context_consumed
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == 'array__free(&items);\n'
	assert g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_skips_unprepared_context() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, false)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
	assert !g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_skips_wrong_prepared_fn_node_id() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	mut fields := autofree_statement_cleanup_emit_test_context_fields()
	fields.fn_node_id = ast.FlatNodeId(11)
	fields.context_key = 'make_items:11:100:20:120:30:210:items'
	context := autofree_statement_cleanup_emit_test_context_from_fields(fields)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_cleanup_emit_fn_node_id = ast.FlatNodeId(10)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
	assert !g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_skips_wrong_prepared_fn_key() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	context := autofree_statement_cleanup_emit_test_context()
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_cleanup_emit_fn_key = 'other_key'
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
	assert !g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_skips_clean_c_name_mismatch() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	mut fields := autofree_statement_cleanup_emit_test_context_fields()
	fields.fn_key = 'main__make_items'
	fields.context_key = 'main__make_items:10:100:20:120:30:210:items'
	context := autofree_statement_cleanup_emit_test_context_from_fields(fields)
	node := autofree_statement_cleanup_emit_test_fn_decl()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_emit_statement_cleanup_context('make_items', &node)
	assert g.sb.str() == ''
	assert !g.autofree_cleanup_emit_context_consumed
}

fn test_autofree_statement_cleanup_emit_clear_resets_cursor_state() {
	mut g := autofree_statement_cleanup_emit_test_gen(true)
	context := autofree_statement_cleanup_emit_test_context()
	autofree_statement_cleanup_emit_test_install_context(mut g, context, true)
	g.autofree_cleanup_emit_context_consumed = true
	g.autofree_clear_statement_cleanup_emit_context()
	assert !g.has_autofree_cleanup_emit_context
	assert !g.autofree_cleanup_emit_context_consumed
	assert !g.autofree_cleanup_emit_context_prepared
	assert g.autofree_cleanup_emit_fn_key == ''
	assert g.autofree_cleanup_emit_fn_node_id == ast.invalid_flat_node_id
	assert g.autofree_cleanup_emit_fn_pos_id == 0
}
