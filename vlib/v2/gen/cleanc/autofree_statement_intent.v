// Copyright (c) 2026 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module cleanc

import v2.ast

enum AutofreeCleanCStatementIntentStatus {
	unknown
	inert
}

enum AutofreeCleanCStatementIntentKind {
	unknown
	after_statement
}

struct AutofreeCleanCStatementIntentFact {
	fn_key               string
	fn_name              string
	name                 string
	intent_status        AutofreeCleanCStatementIntentStatus
	intent_kind          AutofreeCleanCStatementIntentKind
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

fn autofree_statement_intent_facts_from_previews(previews []AutofreeCleanCStatementPreviewFact) []AutofreeCleanCStatementIntentFact {
	if previews.len != 1 {
		return []AutofreeCleanCStatementIntentFact{}
	}
	intent := autofree_statement_intent_fact_from_preview(previews[0]) or {
		return []AutofreeCleanCStatementIntentFact{}
	}
	return [intent]
}

fn autofree_statement_intent_fact_from_preview(preview AutofreeCleanCStatementPreviewFact) ?AutofreeCleanCStatementIntentFact {
	if preview.preview_status != .inert || preview.fn_key.len == 0 || preview.fn_name.len == 0
		|| preview.name.len == 0 {
		return none
	}
	if preview.fn_node_id < 0 || preview.fn_pos_id <= 0 || preview.target_node_id < 0
		|| preview.target_pos_id <= 0 || preview.stmt_node_id < 0 || preview.stmt_pos_id <= 0
		|| preview.insert_after_node_id < 0 || preview.insert_after_pos_id <= 0 {
		return none
	}
	if preview.stmt_node_id != preview.insert_after_node_id
		|| preview.stmt_pos_id != preview.insert_after_pos_id {
		return none
	}
	if preview.target_node_id == preview.insert_after_node_id {
		return none
	}
	if preview.stmt_index < 0 || preview.lhs_index != 0 {
		return none
	}
	return AutofreeCleanCStatementIntentFact{
		fn_key:               preview.fn_key
		fn_name:              preview.fn_name
		name:                 preview.name
		intent_status:        .inert
		intent_kind:          .after_statement
		fn_node_id:           preview.fn_node_id
		fn_pos_id:            preview.fn_pos_id
		target_node_id:       preview.target_node_id
		target_pos_id:        preview.target_pos_id
		stmt_node_id:         preview.stmt_node_id
		stmt_pos_id:          preview.stmt_pos_id
		insert_after_node_id: preview.insert_after_node_id
		insert_after_pos_id:  preview.insert_after_pos_id
		stmt_index:           preview.stmt_index
		lhs_index:            preview.lhs_index
		reason:               'inert statement intent accepted'
	}
}
