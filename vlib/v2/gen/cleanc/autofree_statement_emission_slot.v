// Copyright (c) 2026 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module cleanc

import v2.ast

enum AutofreeCleanCStatementEmissionSlotStatus {
	unknown
	inert
}

enum AutofreeCleanCStatementEmissionSlotKind {
	unknown
	after_statement
}

struct AutofreeCleanCStatementEmissionSlotFact {
	fn_key               string
	fn_name              string
	name                 string
	slot_status          AutofreeCleanCStatementEmissionSlotStatus
	slot_kind            AutofreeCleanCStatementEmissionSlotKind
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
	reason               string
}

fn autofree_statement_emission_slot_facts_from_intents(intents []AutofreeCleanCStatementIntentFact) []AutofreeCleanCStatementEmissionSlotFact {
	if intents.len != 1 {
		return []AutofreeCleanCStatementEmissionSlotFact{}
	}
	slot := autofree_statement_emission_slot_fact_from_intent(intents[0]) or {
		return []AutofreeCleanCStatementEmissionSlotFact{}
	}
	return [slot]
}

fn autofree_statement_emission_slot_fact_from_intent(intent AutofreeCleanCStatementIntentFact) ?AutofreeCleanCStatementEmissionSlotFact {
	if intent.intent_status != .inert || intent.intent_kind != .after_statement
		|| intent.fn_key.len == 0 || intent.fn_name.len == 0 || intent.name.len == 0 {
		return none
	}
	if intent.fn_node_id < 0 || intent.fn_pos_id <= 0 || intent.target_node_id < 0
		|| intent.target_pos_id <= 0 || intent.stmt_node_id < 0 || intent.stmt_pos_id <= 0
		|| intent.insert_after_node_id < 0 || intent.insert_after_pos_id <= 0 {
		return none
	}
	if intent.stmt_node_id != intent.insert_after_node_id
		|| intent.stmt_pos_id != intent.insert_after_pos_id {
		return none
	}
	if intent.target_node_id == intent.insert_after_node_id {
		return none
	}
	if intent.stmt_index < 0 || intent.lhs_index != 0 {
		return none
	}
	return AutofreeCleanCStatementEmissionSlotFact{
		fn_key:               intent.fn_key
		fn_name:              intent.fn_name
		name:                 intent.name
		slot_status:          .inert
		slot_kind:            .after_statement
		fn_node_id:           intent.fn_node_id
		fn_pos_id:            intent.fn_pos_id
		target_node_id:       intent.target_node_id
		target_pos_id:        intent.target_pos_id
		stmt_node_id:         intent.stmt_node_id
		stmt_pos_id:          intent.stmt_pos_id
		insert_after_node_id: intent.insert_after_node_id
		insert_after_pos_id:  intent.insert_after_pos_id
		stmt_index:           intent.stmt_index
		lhs_index:            intent.lhs_index
		reason:               'inert statement emission slot accepted'
	}
}
