module cleanc

import v2.ast

struct AutofreeStatementCleanupEmitContextTestHookPreviewFields {
mut:
	fn_key               string
	fn_name              string
	name                 string
	hook_status          AutofreeCleanCStatementCleanupHookPreviewStatus
	hook_kind            AutofreeCleanCStatementCleanupHookPreviewKind
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
	reason               string
}

fn autofree_statement_cleanup_emit_context_test_hook_preview_fields() AutofreeStatementCleanupEmitContextTestHookPreviewFields {
	return AutofreeStatementCleanupEmitContextTestHookPreviewFields{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		hook_status:          .inert
		hook_kind:            .after_body_before_scheduled_drops
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
		reason:               'statement cleanup hook preview accepted'
	}
}

fn autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields AutofreeStatementCleanupEmitContextTestHookPreviewFields) AutofreeCleanCStatementCleanupHookPreviewFact {
	return AutofreeCleanCStatementCleanupHookPreviewFact{
		fn_key:               fields.fn_key
		fn_name:              fields.fn_name
		name:                 fields.name
		hook_status:          fields.hook_status
		hook_kind:            fields.hook_kind
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
		reason:               fields.reason
	}
}

fn autofree_statement_cleanup_emit_context_test_hook_preview() AutofreeCleanCStatementCleanupHookPreviewFact {
	return autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(autofree_statement_cleanup_emit_context_test_hook_preview_fields())
}

fn autofree_statement_cleanup_emit_context_test_assert_no_context(previews []AutofreeCleanCStatementCleanupHookPreviewFact) {
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews(previews)
	assert contexts.len == 0
}

fn test_autofree_statement_cleanup_emit_context_accepts_single_hook_preview() {
	preview := autofree_statement_cleanup_emit_context_test_hook_preview()
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews([
		preview,
	])
	assert contexts.len == 1
	context := contexts[0]
	assert context.fn_key == preview.fn_key
	assert context.fn_name == preview.fn_name
	assert context.name == preview.name
	assert context.context_status == .inert
	assert context.context_kind == .after_body_before_scheduled_drops
	assert context.fn_node_id == preview.fn_node_id
	assert context.fn_pos_id == preview.fn_pos_id
	assert context.target_node_id == preview.target_node_id
	assert context.target_pos_id == preview.target_pos_id
	assert context.stmt_node_id == preview.stmt_node_id
	assert context.stmt_pos_id == preview.stmt_pos_id
	assert context.insert_after_node_id == preview.insert_after_node_id
	assert context.insert_after_pos_id == preview.insert_after_pos_id
	assert context.stmt_index == preview.stmt_index
	assert context.lhs_index == preview.lhs_index
	assert context.target_c_name == preview.target_c_name
	assert context.cleanup_symbol == preview.cleanup_symbol
	assert context.cleanup_text == preview.cleanup_text
	assert context.context_key.len > 0
}

fn test_autofree_statement_cleanup_emit_context_accepts_last_statement_items_context() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.target_node_id = ast.FlatNodeId(40)
	fields.target_pos_id = 220
	fields.stmt_node_id = ast.FlatNodeId(50)
	fields.stmt_pos_id = 310
	fields.insert_after_node_id = ast.FlatNodeId(50)
	fields.insert_after_pos_id = 310
	fields.stmt_index = 1
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	contexts := autofree_statement_cleanup_emit_context_facts_from_hook_previews([
		preview,
	])
	assert contexts.len == 1
	context := contexts[0]
	assert context.name == 'items'
	assert context.name != 'copy'
	assert context.name != 'source'
	assert context.target_c_name == 'items'
	assert context.stmt_index == 1
	assert context.target_node_id == ast.FlatNodeId(40)
	assert context.target_pos_id == 220
	assert context.insert_after_node_id == ast.FlatNodeId(50)
	assert context.insert_after_pos_id == 310
	assert context.cleanup_symbol == 'array__free'
	assert context.cleanup_text == 'array__free(&items);'
	assert context.context_key == 'make_items:10:100:40:220:50:310:items'
	assert !context.cleanup_text.contains('copy')
	assert !context.cleanup_text.contains('source')
	assert !context.cleanup_text.contains('string__free')
}

fn test_autofree_statement_cleanup_emit_context_key_is_stable() {
	preview := autofree_statement_cleanup_emit_context_test_hook_preview()
	first := autofree_statement_cleanup_emit_context_facts_from_hook_previews([
		preview,
	])
	second := autofree_statement_cleanup_emit_context_facts_from_hook_previews([
		preview,
	])
	assert first.len == 1
	assert second.len == 1
	assert first[0].context_key == second[0].context_key
	assert first[0].context_key.len > 0
}

fn test_autofree_statement_cleanup_emit_context_rejects_empty_input() {
	autofree_statement_cleanup_emit_context_test_assert_no_context([])
}

fn test_autofree_statement_cleanup_emit_context_rejects_two_previews() {
	preview := autofree_statement_cleanup_emit_context_test_hook_preview()
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview, preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_unknown_status() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.hook_status = .unknown
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_unknown_kind() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.hook_kind = .unknown
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_bad_symbol() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.cleanup_symbol = 'string__free'
	fields.cleanup_text = 'string__free(&items);'
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_bad_text() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.cleanup_text = 'array__free(items);'
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_empty_fn_key() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.fn_key = ''
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_empty_fn_name() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.fn_name = ''
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_empty_name() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.name = ''
	fields.target_c_name = ''
	fields.cleanup_text = 'array__free(&);'
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_bad_target_name() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.name = 'array'
	fields.target_c_name = 'array'
	fields.cleanup_text = 'array__free(&array);'
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_invalid_fn_ids() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.fn_node_id = ast.FlatNodeId(-1)
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_invalid_fn_pos() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.fn_pos_id = 0
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_invalid_target_ids() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.target_node_id = ast.FlatNodeId(-1)
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_invalid_target_pos() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.target_pos_id = 0
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_invalid_stmt_ids() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.stmt_node_id = ast.FlatNodeId(-1)
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_invalid_stmt_pos() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.stmt_pos_id = 0
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_invalid_insert_ids() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.insert_after_node_id = ast.FlatNodeId(-1)
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_invalid_insert_pos() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.insert_after_pos_id = 0
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_stmt_node_mismatch() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.stmt_node_id = ast.FlatNodeId(31)
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_stmt_pos_mismatch() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.stmt_pos_id = 211
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_target_equal_insert() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.target_node_id = fields.insert_after_node_id
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_negative_stmt_index() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.stmt_index = -1
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}

fn test_autofree_statement_cleanup_emit_context_rejects_nonzero_lhs_index() {
	mut fields := autofree_statement_cleanup_emit_context_test_hook_preview_fields()
	fields.lhs_index = 1
	preview := autofree_statement_cleanup_emit_context_test_hook_preview_from_fields(fields)
	autofree_statement_cleanup_emit_context_test_assert_no_context([preview])
}
