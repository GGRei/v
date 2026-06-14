module cleanc

import v2.ast

fn autofree_statement_emission_slot_test_intent() AutofreeCleanCStatementIntentFact {
	return AutofreeCleanCStatementIntentFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		intent_status:        .inert
		intent_kind:          .after_statement
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
		reason:               'statement intent accepted'
	}
}

fn autofree_statement_emission_slot_test_assert_no_slot(intents []AutofreeCleanCStatementIntentFact) {
	slots := autofree_statement_emission_slot_facts_from_intents(intents)
	assert slots.len == 0
}

fn autofree_statement_emission_slot_test_assert_no_named_slot(case_name string, intents []AutofreeCleanCStatementIntentFact) {
	assert case_name.len > 0
	autofree_statement_emission_slot_test_assert_no_slot(intents)
}

fn test_autofree_statement_emission_slot_accepts_single_intent() {
	intent := autofree_statement_emission_slot_test_intent()
	slots := autofree_statement_emission_slot_facts_from_intents([intent])
	assert slots.len == 1
	slot := slots[0]
	assert slot.fn_key == intent.fn_key
	assert slot.fn_name == intent.fn_name
	assert slot.name == intent.name
	assert slot.slot_status == .inert
	assert slot.slot_kind == .after_statement
	assert slot.fn_node_id == intent.fn_node_id
	assert slot.fn_pos_id == intent.fn_pos_id
	assert slot.target_node_id == intent.target_node_id
	assert slot.target_pos_id == intent.target_pos_id
	assert slot.stmt_node_id == intent.stmt_node_id
	assert slot.stmt_pos_id == intent.stmt_pos_id
	assert slot.insert_after_node_id == intent.insert_after_node_id
	assert slot.insert_after_pos_id == intent.insert_after_pos_id
	assert slot.stmt_index == intent.stmt_index
	assert slot.lhs_index == intent.lhs_index
	assert slot.reason.len > 0
}

fn test_autofree_statement_emission_slot_rejects_empty_intent_list() {
	autofree_statement_emission_slot_test_assert_no_slot([]AutofreeCleanCStatementIntentFact{})
}

fn test_autofree_statement_emission_slot_rejects_two_intents() {
	intent := autofree_statement_emission_slot_test_intent()
	autofree_statement_emission_slot_test_assert_no_slot([intent, intent])
}

fn test_autofree_statement_emission_slot_rejects_target_equal_insert_after() {
	intent := AutofreeCleanCStatementIntentFact{
		...autofree_statement_emission_slot_test_intent()
		target_node_id: ast.FlatNodeId(30)
	}
	autofree_statement_emission_slot_test_assert_no_slot([intent])
}

fn test_autofree_statement_emission_slot_rejects_invalid_intent_fields() {
	base := autofree_statement_emission_slot_test_intent()
	cases := [
		'unknown_status',
		'unknown_kind',
		'empty_fn_key',
		'empty_fn_name',
		'empty_name',
		'invalid_fn_ids',
		'invalid_target_ids',
		'invalid_stmt_ids',
		'invalid_insert_after_ids',
		'negative_stmt_index',
		'nonzero_lhs_index',
	]
	intents := [
		AutofreeCleanCStatementIntentFact{
			...base
			intent_status: .unknown
		},
		AutofreeCleanCStatementIntentFact{
			...base
			intent_kind: .unknown
		},
		AutofreeCleanCStatementIntentFact{
			...base
			fn_key: ''
		},
		AutofreeCleanCStatementIntentFact{
			...base
			fn_name: ''
		},
		AutofreeCleanCStatementIntentFact{
			...base
			name: ''
		},
		AutofreeCleanCStatementIntentFact{
			...base
			fn_node_id: ast.FlatNodeId(-1)
			fn_pos_id:  0
		},
		AutofreeCleanCStatementIntentFact{
			...base
			target_node_id: ast.FlatNodeId(-1)
			target_pos_id:  0
		},
		AutofreeCleanCStatementIntentFact{
			...base
			stmt_node_id: ast.FlatNodeId(-1)
			stmt_pos_id:  0
		},
		AutofreeCleanCStatementIntentFact{
			...base
			insert_after_node_id: ast.FlatNodeId(-1)
			insert_after_pos_id:  0
		},
		AutofreeCleanCStatementIntentFact{
			...base
			stmt_index: -1
		},
		AutofreeCleanCStatementIntentFact{
			...base
			lhs_index: 1
		},
	]
	assert cases.len == intents.len
	for index, invalid_case in cases {
		intent := intents[index]
		autofree_statement_emission_slot_test_assert_no_named_slot(invalid_case, [
			intent,
		])
	}
}

fn test_autofree_statement_emission_slot_rejects_cursor_slot_mismatch() {
	base := autofree_statement_emission_slot_test_intent()
	cases := [
		'stmt_node_mismatch',
		'stmt_pos_mismatch',
	]
	intents := [
		AutofreeCleanCStatementIntentFact{
			...base
			insert_after_node_id: ast.FlatNodeId(31)
		},
		AutofreeCleanCStatementIntentFact{
			...base
			insert_after_pos_id: 211
		},
	]
	assert cases.len == intents.len
	for index, invalid_case in cases {
		intent := intents[index]
		autofree_statement_emission_slot_test_assert_no_named_slot(invalid_case, [
			intent,
		])
	}
}
