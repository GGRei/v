module cleanc

import v2.ast

fn autofree_statement_adapter_test_bridge_fact() AutofreeCleanCBridgeFact {
	return AutofreeCleanCBridgeFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'items'
		bridge_status:        .inert
		target_node_id:       5
		target_pos_id:        120
		insert_after_node_id: 7
		insert_after_pos_id:  210
		reason:               'bridge accepted'
	}
}

fn autofree_statement_adapter_test_other_bridge_fact() AutofreeCleanCBridgeFact {
	return AutofreeCleanCBridgeFact{
		fn_key:               'make_more_items'
		fn_name:              'make_more_items'
		name:                 'items'
		bridge_status:        .inert
		target_node_id:       5
		target_pos_id:        120
		insert_after_node_id: 7
		insert_after_pos_id:  210
		reason:               'bridge accepted'
	}
}

fn autofree_statement_adapter_test_bridge_fact_same_fn_other_slot() AutofreeCleanCBridgeFact {
	return AutofreeCleanCBridgeFact{
		fn_key:               'make_items'
		fn_name:              'make_items'
		name:                 'more_items'
		bridge_status:        .inert
		target_node_id:       8
		target_pos_id:        121
		insert_after_node_id: 9
		insert_after_pos_id:  220
		reason:               'bridge accepted'
	}
}

fn autofree_statement_adapter_test_assert_no_anchor(facts []AutofreeCleanCBridgeFact) {
	anchors := autofree_statement_anchor_facts_from_bridge_facts(facts)
	assert anchors.len == 0
}

fn test_autofree_statement_adapter_accepts_valid_bridge_fact() {
	bridge_fact := autofree_statement_adapter_test_bridge_fact()
	anchors := autofree_statement_anchor_facts_from_bridge_facts([bridge_fact])
	assert anchors.len == 1
	anchor := anchors[0]
	assert anchor.fn_key == bridge_fact.fn_key
	assert anchor.fn_name == bridge_fact.fn_name
	assert anchor.name == bridge_fact.name
	assert anchor.anchor_status == .inert
	assert anchor.target_node_id == bridge_fact.target_node_id
	assert anchor.target_pos_id == bridge_fact.target_pos_id
	assert anchor.insert_after_node_id == bridge_fact.insert_after_node_id
	assert anchor.insert_after_pos_id == bridge_fact.insert_after_pos_id
	assert anchor.reason.len > 0
}

fn test_autofree_statement_adapter_skips_empty_bridge_facts() {
	autofree_statement_adapter_test_assert_no_anchor([]AutofreeCleanCBridgeFact{})
}

fn test_autofree_statement_adapter_rejects_bad_bridge_status() {
	bridge_fact := AutofreeCleanCBridgeFact{
		...autofree_statement_adapter_test_bridge_fact()
		bridge_status: .unknown
	}
	autofree_statement_adapter_test_assert_no_anchor([bridge_fact])
}

fn test_autofree_statement_adapter_rejects_empty_fn_key() {
	bridge_fact := AutofreeCleanCBridgeFact{
		...autofree_statement_adapter_test_bridge_fact()
		fn_key: ''
	}
	autofree_statement_adapter_test_assert_no_anchor([bridge_fact])
}

fn test_autofree_statement_adapter_rejects_empty_name() {
	bridge_fact := AutofreeCleanCBridgeFact{
		...autofree_statement_adapter_test_bridge_fact()
		name: ''
	}
	autofree_statement_adapter_test_assert_no_anchor([bridge_fact])
}

fn test_autofree_statement_adapter_rejects_invalid_target_ids() {
	bridge_fact := AutofreeCleanCBridgeFact{
		...autofree_statement_adapter_test_bridge_fact()
		target_node_id: ast.FlatNodeId(-1)
		target_pos_id:  0
	}
	autofree_statement_adapter_test_assert_no_anchor([bridge_fact])
}

fn test_autofree_statement_adapter_rejects_invalid_insert_after_ids() {
	bridge_fact := AutofreeCleanCBridgeFact{
		...autofree_statement_adapter_test_bridge_fact()
		insert_after_node_id: ast.FlatNodeId(-1)
		insert_after_pos_id:  0
	}
	autofree_statement_adapter_test_assert_no_anchor([bridge_fact])
}

fn test_autofree_statement_adapter_rejects_target_equal_insert_after() {
	bridge_fact := AutofreeCleanCBridgeFact{
		...autofree_statement_adapter_test_bridge_fact()
		insert_after_node_id: 5
		insert_after_pos_id:  120
	}
	autofree_statement_adapter_test_assert_no_anchor([bridge_fact])
}

fn test_autofree_statement_adapter_rejects_target_node_equal_insert_after_node() {
	bridge_fact := AutofreeCleanCBridgeFact{
		...autofree_statement_adapter_test_bridge_fact()
		insert_after_node_id: 5
		insert_after_pos_id:  121
	}
	autofree_statement_adapter_test_assert_no_anchor([bridge_fact])
}

fn test_autofree_statement_adapter_rejects_duplicate_name() {
	bridge_fact := autofree_statement_adapter_test_bridge_fact()
	duplicate := AutofreeCleanCBridgeFact{
		...autofree_statement_adapter_test_bridge_fact()
		target_node_id:       8
		target_pos_id:        121
		insert_after_node_id: 9
		insert_after_pos_id:  220
	}
	autofree_statement_adapter_test_assert_no_anchor([bridge_fact, duplicate])
}

fn test_autofree_statement_adapter_rejects_duplicate_target() {
	bridge_fact := autofree_statement_adapter_test_bridge_fact()
	duplicate := AutofreeCleanCBridgeFact{
		...autofree_statement_adapter_test_bridge_fact()
		name:                 'more_items'
		insert_after_node_id: 9
		insert_after_pos_id:  220
	}
	autofree_statement_adapter_test_assert_no_anchor([bridge_fact, duplicate])
}

fn test_autofree_statement_adapter_rejects_duplicate_slot() {
	bridge_fact := autofree_statement_adapter_test_bridge_fact()
	duplicate := AutofreeCleanCBridgeFact{
		...autofree_statement_adapter_test_bridge_fact()
		name:           'more_items'
		target_node_id: 8
		target_pos_id:  121
	}
	autofree_statement_adapter_test_assert_no_anchor([bridge_fact, duplicate])
}
