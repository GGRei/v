// Copyright (c) 2026 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module cleanc

import v2.ast

enum AutofreeCleanCStatementAnchorStatus {
	unknown
	inert
}

struct AutofreeCleanCStatementAnchorFact {
	fn_key               string
	fn_name              string
	name                 string
	anchor_status        AutofreeCleanCStatementAnchorStatus
	target_node_id       ast.FlatNodeId
	target_pos_id        int
	insert_after_node_id ast.FlatNodeId
	insert_after_pos_id  int
	reason               string
}

fn autofree_statement_anchor_facts_from_bridge_facts(facts []AutofreeCleanCBridgeFact) []AutofreeCleanCStatementAnchorFact {
	duplicate_names := autofree_statement_anchor_duplicate_names(facts)
	duplicate_targets := autofree_statement_anchor_duplicate_target_positions(facts)
	duplicate_positions := autofree_statement_anchor_duplicate_positions(facts)
	mut anchors := []AutofreeCleanCStatementAnchorFact{}
	for fact in facts {
		name_key := autofree_statement_anchor_name_key(fact)
		target_key := autofree_statement_anchor_target_position_key(fact)
		position_key := autofree_statement_anchor_position_key(fact)
		if name_key.len == 0 || name_key in duplicate_names || target_key.len == 0
			|| target_key in duplicate_targets || position_key.len == 0
			|| position_key in duplicate_positions {
			continue
		}
		anchor := autofree_statement_anchor_fact_from_bridge_fact(fact) or { continue }
		anchors << anchor
	}
	return anchors
}

fn autofree_statement_anchor_fact_from_bridge_fact(fact AutofreeCleanCBridgeFact) ?AutofreeCleanCStatementAnchorFact {
	if fact.bridge_status != .inert || fact.fn_key.len == 0 || fact.name.len == 0 {
		return none
	}
	if fact.target_node_id < 0 || fact.target_pos_id <= 0 || fact.insert_after_node_id < 0
		|| fact.insert_after_pos_id <= 0 {
		return none
	}
	if fact.target_node_id == fact.insert_after_node_id {
		return none
	}
	return AutofreeCleanCStatementAnchorFact{
		fn_key:               fact.fn_key
		fn_name:              fact.fn_name
		name:                 fact.name
		anchor_status:        .inert
		target_node_id:       fact.target_node_id
		target_pos_id:        fact.target_pos_id
		insert_after_node_id: fact.insert_after_node_id
		insert_after_pos_id:  fact.insert_after_pos_id
		reason:               'inert statement anchor accepted'
	}
}

fn autofree_statement_anchor_duplicate_names(facts []AutofreeCleanCBridgeFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for fact in facts {
		name_key := autofree_statement_anchor_name_key(fact)
		if name_key.len == 0 {
			continue
		}
		if name_key in seen {
			duplicates[name_key] = true
			continue
		}
		seen[name_key] = true
	}
	return duplicates
}

fn autofree_statement_anchor_duplicate_target_positions(facts []AutofreeCleanCBridgeFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for fact in facts {
		target_key := autofree_statement_anchor_target_position_key(fact)
		if target_key.len == 0 {
			continue
		}
		if target_key in seen {
			duplicates[target_key] = true
			continue
		}
		seen[target_key] = true
	}
	return duplicates
}

fn autofree_statement_anchor_duplicate_positions(facts []AutofreeCleanCBridgeFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for fact in facts {
		position_key := autofree_statement_anchor_position_key(fact)
		if position_key.len == 0 {
			continue
		}
		if position_key in seen {
			duplicates[position_key] = true
			continue
		}
		seen[position_key] = true
	}
	return duplicates
}

fn autofree_statement_anchor_name_key(fact AutofreeCleanCBridgeFact) string {
	if fact.fn_key.len == 0 || fact.name.len == 0 {
		return ''
	}
	return '${fact.fn_key.len}:${fact.fn_key}:${fact.name.len}:${fact.name}'
}

fn autofree_statement_anchor_target_position_key(fact AutofreeCleanCBridgeFact) string {
	if fact.fn_key.len == 0 || fact.target_node_id < 0 || fact.target_pos_id <= 0 {
		return ''
	}
	return '${fact.fn_key.len}:${fact.fn_key}:${fact.target_node_id}:${fact.target_pos_id}'
}

fn autofree_statement_anchor_position_key(fact AutofreeCleanCBridgeFact) string {
	if fact.fn_key.len == 0 || fact.insert_after_node_id < 0 || fact.insert_after_pos_id <= 0 {
		return ''
	}
	return '${fact.fn_key.len}:${fact.fn_key}:${fact.insert_after_node_id}:${fact.insert_after_pos_id}'
}
