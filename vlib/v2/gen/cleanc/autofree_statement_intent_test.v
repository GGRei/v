module cleanc

import v2.ast

fn autofree_statement_intent_test_preview() AutofreeCleanCStatementPreviewFact {
	return AutofreeCleanCStatementPreviewFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		preview_status:       .inert
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
		reason:               'statement preview accepted'
	}
}

fn autofree_statement_intent_test_assert_no_intent(previews []AutofreeCleanCStatementPreviewFact) {
	intents := autofree_statement_intent_facts_from_previews(previews)
	assert intents.len == 0
}

fn test_autofree_statement_intent_accepts_single_preview() {
	preview := autofree_statement_intent_test_preview()
	intents := autofree_statement_intent_facts_from_previews([preview])
	assert intents.len == 1
	intent := intents[0]
	assert intent.fn_key == preview.fn_key
	assert intent.fn_name == preview.fn_name
	assert intent.name == preview.name
	assert intent.intent_status == .inert
	assert intent.intent_kind == .after_statement
	assert intent.fn_node_id == preview.fn_node_id
	assert intent.fn_pos_id == preview.fn_pos_id
	assert intent.target_node_id == preview.target_node_id
	assert intent.target_pos_id == preview.target_pos_id
	assert intent.stmt_node_id == preview.stmt_node_id
	assert intent.stmt_pos_id == preview.stmt_pos_id
	assert intent.insert_after_node_id == preview.insert_after_node_id
	assert intent.insert_after_pos_id == preview.insert_after_pos_id
	assert intent.stmt_index == preview.stmt_index
	assert intent.lhs_index == preview.lhs_index
	assert intent.reason.len > 0
}

fn test_autofree_statement_intent_rejects_empty_preview_list() {
	autofree_statement_intent_test_assert_no_intent([]AutofreeCleanCStatementPreviewFact{})
}

fn test_autofree_statement_intent_rejects_two_previews() {
	preview := autofree_statement_intent_test_preview()
	autofree_statement_intent_test_assert_no_intent([preview, preview])
}

fn test_autofree_statement_intent_rejects_unknown_status() {
	preview := AutofreeCleanCStatementPreviewFact{
		...autofree_statement_intent_test_preview()
		preview_status: .unknown
	}
	autofree_statement_intent_test_assert_no_intent([preview])
}

fn test_autofree_statement_intent_rejects_empty_fn_key() {
	preview := AutofreeCleanCStatementPreviewFact{
		...autofree_statement_intent_test_preview()
		fn_key: ''
	}
	autofree_statement_intent_test_assert_no_intent([preview])
}

fn test_autofree_statement_intent_rejects_empty_fn_name() {
	preview := AutofreeCleanCStatementPreviewFact{
		...autofree_statement_intent_test_preview()
		fn_name: ''
	}
	autofree_statement_intent_test_assert_no_intent([preview])
}

fn test_autofree_statement_intent_rejects_empty_name() {
	preview := AutofreeCleanCStatementPreviewFact{
		...autofree_statement_intent_test_preview()
		name: ''
	}
	autofree_statement_intent_test_assert_no_intent([preview])
}

fn test_autofree_statement_intent_rejects_invalid_fn_ids() {
	preview := AutofreeCleanCStatementPreviewFact{
		...autofree_statement_intent_test_preview()
		fn_node_id: ast.FlatNodeId(-1)
		fn_pos_id:  0
	}
	autofree_statement_intent_test_assert_no_intent([preview])
}

fn test_autofree_statement_intent_rejects_invalid_target_ids() {
	preview := AutofreeCleanCStatementPreviewFact{
		...autofree_statement_intent_test_preview()
		target_node_id: ast.FlatNodeId(-1)
		target_pos_id:  0
	}
	autofree_statement_intent_test_assert_no_intent([preview])
}

fn test_autofree_statement_intent_rejects_invalid_stmt_ids() {
	preview := AutofreeCleanCStatementPreviewFact{
		...autofree_statement_intent_test_preview()
		stmt_node_id: ast.FlatNodeId(-1)
		stmt_pos_id:  0
	}
	autofree_statement_intent_test_assert_no_intent([preview])
}

fn test_autofree_statement_intent_rejects_invalid_insert_after_ids() {
	preview := AutofreeCleanCStatementPreviewFact{
		...autofree_statement_intent_test_preview()
		insert_after_node_id: ast.FlatNodeId(-1)
		insert_after_pos_id:  0
	}
	autofree_statement_intent_test_assert_no_intent([preview])
}

fn test_autofree_statement_intent_rejects_stmt_node_mismatch() {
	preview := AutofreeCleanCStatementPreviewFact{
		...autofree_statement_intent_test_preview()
		insert_after_node_id: ast.FlatNodeId(31)
	}
	autofree_statement_intent_test_assert_no_intent([preview])
}

fn test_autofree_statement_intent_rejects_stmt_pos_mismatch() {
	preview := AutofreeCleanCStatementPreviewFact{
		...autofree_statement_intent_test_preview()
		insert_after_pos_id: 211
	}
	autofree_statement_intent_test_assert_no_intent([preview])
}

fn test_autofree_statement_intent_rejects_target_equal_insert_after() {
	preview := AutofreeCleanCStatementPreviewFact{
		...autofree_statement_intent_test_preview()
		target_node_id: ast.FlatNodeId(30)
	}
	autofree_statement_intent_test_assert_no_intent([preview])
}

fn test_autofree_statement_intent_rejects_negative_stmt_index() {
	preview := AutofreeCleanCStatementPreviewFact{
		...autofree_statement_intent_test_preview()
		stmt_index: -1
	}
	autofree_statement_intent_test_assert_no_intent([preview])
}

fn test_autofree_statement_intent_rejects_nonzero_lhs_index() {
	preview := AutofreeCleanCStatementPreviewFact{
		...autofree_statement_intent_test_preview()
		lhs_index: 1
	}
	autofree_statement_intent_test_assert_no_intent([preview])
}
