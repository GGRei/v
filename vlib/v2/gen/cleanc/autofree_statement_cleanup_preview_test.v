module cleanc

import v2.ast

fn autofree_statement_cleanup_preview_test_slot() AutofreeCleanCStatementEmissionSlotFact {
	return AutofreeCleanCStatementEmissionSlotFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		slot_status:          .inert
		slot_kind:            .after_statement
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
		reason:               'statement emission slot accepted'
	}
}

fn autofree_statement_cleanup_preview_test_assert_no_preview(slots []AutofreeCleanCStatementEmissionSlotFact) {
	previews := autofree_statement_cleanup_preview_facts_from_slots(slots)
	assert previews.len == 0
}

fn test_autofree_statement_cleanup_preview_accepts_normal_name() {
	slot := autofree_statement_cleanup_preview_test_slot()
	previews := autofree_statement_cleanup_preview_facts_from_slots([slot])
	assert previews.len == 1
	preview := previews[0]
	assert preview.fn_key == slot.fn_key
	assert preview.fn_name == slot.fn_name
	assert preview.name == slot.name
	assert preview.cleanup_status == .inert
	assert preview.cleanup_kind == .array_after_statement
	assert preview.fn_node_id == slot.fn_node_id
	assert preview.fn_pos_id == slot.fn_pos_id
	assert preview.target_node_id == slot.target_node_id
	assert preview.target_pos_id == slot.target_pos_id
	assert preview.stmt_node_id == slot.stmt_node_id
	assert preview.stmt_pos_id == slot.stmt_pos_id
	assert preview.insert_after_node_id == slot.insert_after_node_id
	assert preview.insert_after_pos_id == slot.insert_after_pos_id
	assert preview.stmt_index == slot.stmt_index
	assert preview.lhs_index == slot.lhs_index
	assert preview.target_c_name == 'items'
	assert preview.cleanup_symbol == 'array__free'
	assert preview.cleanup_text == 'array__free(&items);'
	assert preview.reason.len > 0
}

fn test_autofree_statement_cleanup_preview_escapes_c_keyword_name() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		name: '@return'
	}
	previews := autofree_statement_cleanup_preview_facts_from_slots([slot])
	assert previews.len == 1
	assert previews[0].target_c_name == '_return'
	assert previews[0].cleanup_text == 'array__free(&_return);'
}

fn test_autofree_statement_cleanup_preview_escapes_array_name() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		name: 'array'
	}
	previews := autofree_statement_cleanup_preview_facts_from_slots([slot])
	assert previews.len == 1
	assert previews[0].target_c_name == '_v_array'
	assert previews[0].cleanup_text == 'array__free(&_v_array);'
}

fn test_autofree_statement_cleanup_preview_rejects_empty_slot_list() {
	autofree_statement_cleanup_preview_test_assert_no_preview([]AutofreeCleanCStatementEmissionSlotFact{})
}

fn test_autofree_statement_cleanup_preview_rejects_two_slots() {
	slot := autofree_statement_cleanup_preview_test_slot()
	autofree_statement_cleanup_preview_test_assert_no_preview([slot, slot])
}

fn test_autofree_statement_cleanup_preview_rejects_unknown_status() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		slot_status: .unknown
	}
	autofree_statement_cleanup_preview_test_assert_no_preview([slot])
}

fn test_autofree_statement_cleanup_preview_rejects_unknown_kind() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		slot_kind: .unknown
	}
	autofree_statement_cleanup_preview_test_assert_no_preview([slot])
}

fn test_autofree_statement_cleanup_preview_rejects_empty_fn_key() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		fn_key: ''
	}
	autofree_statement_cleanup_preview_test_assert_no_preview([slot])
}

fn test_autofree_statement_cleanup_preview_rejects_empty_fn_name() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		fn_name: ''
	}
	autofree_statement_cleanup_preview_test_assert_no_preview([slot])
}

fn test_autofree_statement_cleanup_preview_rejects_empty_name() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		name: ''
	}
	autofree_statement_cleanup_preview_test_assert_no_preview([slot])
}

fn test_autofree_statement_cleanup_preview_rejects_invalid_fn_ids() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		fn_node_id: ast.FlatNodeId(-1)
		fn_pos_id:  0
	}
	autofree_statement_cleanup_preview_test_assert_no_preview([slot])
}

fn test_autofree_statement_cleanup_preview_rejects_invalid_target_ids() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		target_node_id: ast.FlatNodeId(-1)
		target_pos_id:  0
	}
	autofree_statement_cleanup_preview_test_assert_no_preview([slot])
}

fn test_autofree_statement_cleanup_preview_rejects_invalid_stmt_ids() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		stmt_node_id: ast.FlatNodeId(-1)
		stmt_pos_id:  0
	}
	autofree_statement_cleanup_preview_test_assert_no_preview([slot])
}

fn test_autofree_statement_cleanup_preview_rejects_invalid_insert_after_ids() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		insert_after_node_id: ast.FlatNodeId(-1)
		insert_after_pos_id:  0
	}
	autofree_statement_cleanup_preview_test_assert_no_preview([slot])
}

fn test_autofree_statement_cleanup_preview_rejects_stmt_node_mismatch() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		insert_after_node_id: ast.FlatNodeId(31)
	}
	autofree_statement_cleanup_preview_test_assert_no_preview([slot])
}

fn test_autofree_statement_cleanup_preview_rejects_stmt_pos_mismatch() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		insert_after_pos_id: 211
	}
	autofree_statement_cleanup_preview_test_assert_no_preview([slot])
}

fn test_autofree_statement_cleanup_preview_rejects_target_equal_insert_after() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		target_node_id: ast.FlatNodeId(30)
	}
	autofree_statement_cleanup_preview_test_assert_no_preview([slot])
}

fn test_autofree_statement_cleanup_preview_rejects_negative_stmt_index() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		stmt_index: -1
	}
	autofree_statement_cleanup_preview_test_assert_no_preview([slot])
}

fn test_autofree_statement_cleanup_preview_rejects_nonzero_lhs_index() {
	slot := AutofreeCleanCStatementEmissionSlotFact{
		...autofree_statement_cleanup_preview_test_slot()
		lhs_index: 1
	}
	autofree_statement_cleanup_preview_test_assert_no_preview([slot])
}
