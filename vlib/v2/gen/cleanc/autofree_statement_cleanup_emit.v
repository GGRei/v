// Copyright (c) 2026 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module cleanc

import v2.ast

fn (mut g Gen) autofree_clear_statement_cleanup_emit_context() {
	g.autofree_cleanup_emit_context = AutofreeCleanCStatementCleanupEmitContextFact{}
	g.has_autofree_cleanup_emit_context = false
	g.autofree_cleanup_emit_context_consumed = false
	g.autofree_cleanup_emit_context_prepared = false
	g.autofree_cleanup_emit_fn_key = ''
	g.autofree_cleanup_emit_fn_node_id = ast.invalid_flat_node_id
	g.autofree_cleanup_emit_fn_pos_id = 0
}

fn (mut g Gen) gen_fn_decl_ptr_with_autofree_cleanup_context(file_cursor ast.FileCursor, fn_cursor ast.Cursor) {
	g.autofree_prepare_statement_cleanup_emit_context(file_cursor, fn_cursor)
	defer {
		g.autofree_clear_statement_cleanup_emit_context()
	}
	fn_decl := fn_cursor.fn_decl()
	g.gen_fn_decl_ptr(&fn_decl)
}

fn (mut g Gen) autofree_prepare_statement_cleanup_emit_context(file_cursor ast.FileCursor, fn_cursor ast.Cursor) {
	g.autofree_clear_statement_cleanup_emit_context()
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(file_cursor, fn_cursor) or {
		return
	}
	contexts := g.autofree_statement_cleanup_emit_contexts_from_file_cursor(file_cursor, fn_cursor)
	if contexts.len != 1 {
		return
	}
	context := contexts[0]
	if !autofree_statement_cleanup_emit_context_is_valid(context) || context.fn_key != fn_key {
		return
	}
	g.autofree_cleanup_emit_context = context
	g.has_autofree_cleanup_emit_context = true
	g.autofree_cleanup_emit_context_prepared = true
	g.autofree_cleanup_emit_fn_key = fn_key
	g.autofree_cleanup_emit_fn_node_id = fn_cursor.id
	g.autofree_cleanup_emit_fn_pos_id = fn_cursor.pos().id
}

fn (g &Gen) autofree_statement_cleanup_emit_contexts_from_file_cursor(file_cursor ast.FileCursor, fn_cursor ast.Cursor) []AutofreeCleanCStatementCleanupEmitContextFact {
	if g.pref == unsafe { nil } || !g.pref.autofree || g.pref.is_freestanding()
		|| g.env == unsafe { nil } {
		return []AutofreeCleanCStatementCleanupEmitContextFact{}
	}
	if g.flat == unsafe { nil } || file_cursor.flat == unsafe { nil } || file_cursor.flat != g.flat
		|| fn_cursor.flat != file_cursor.flat {
		return []AutofreeCleanCStatementCleanupEmitContextFact{}
	}
	fn_key := g.autofree_statement_cleanup_emit_fn_key_from_cursor(file_cursor, fn_cursor) or {
		return []AutofreeCleanCStatementCleanupEmitContextFact{}
	}
	points := g.env.autofree_release_insertion_points_by_fn_key[fn_key] or {
		return []AutofreeCleanCStatementCleanupEmitContextFact{}
	}
	bridge_facts := autofree_bridge_facts_from_insertion_points(points)
	anchors := autofree_statement_anchor_facts_from_bridge_facts(bridge_facts)
	locations := autofree_statement_location_facts_from_file_cursor(file_cursor, fn_cursor, anchors)
	previews := autofree_statement_preview_facts_from_file_cursor(file_cursor, fn_cursor, locations)
	intents := autofree_statement_intent_facts_from_previews(previews)
	slots := autofree_statement_emission_slot_facts_from_intents(intents)
	cleanup_previews := autofree_statement_cleanup_preview_facts_from_slots(slots)
	hook_previews := autofree_statement_cleanup_hook_preview_facts_from_file_cursor(file_cursor,
		fn_cursor, cleanup_previews)
	return autofree_statement_cleanup_emit_context_facts_from_hook_previews(hook_previews)
}

fn (g &Gen) autofree_statement_cleanup_emit_fn_key_from_cursor(file_cursor ast.FileCursor, fn_cursor ast.Cursor) ?string {
	if g.flat == unsafe { nil } || file_cursor.flat == unsafe { nil } || file_cursor.flat != g.flat
		|| fn_cursor.flat != file_cursor.flat {
		return none
	}
	return autofree_statement_location_fn_key_from_file_cursor(file_cursor, fn_cursor)
}

fn (mut g Gen) autofree_emit_statement_cleanup_context(fn_name string, node &ast.FnDecl) {
	if g.pref == unsafe { nil } || !g.pref.autofree || g.pref.is_freestanding()
		|| !g.has_autofree_cleanup_emit_context || g.autofree_cleanup_emit_context_consumed
		|| !g.autofree_cleanup_emit_context_prepared {
		return
	}
	context := g.autofree_cleanup_emit_context
	if !g.autofree_statement_cleanup_emit_context_matches_current_fn(context, fn_name, node) {
		return
	}
	g.autofree_cleanup_emit_context_consumed = true
	g.write_indent()
	g.sb.writeln(context.cleanup_text)
}

fn (g &Gen) autofree_statement_cleanup_emit_context_matches_current_fn(context AutofreeCleanCStatementCleanupEmitContextFact, fn_name string, node &ast.FnDecl) bool {
	return autofree_statement_cleanup_emit_context_is_valid(context) && fn_name.len > 0
		&& context.fn_key == g.autofree_cleanup_emit_fn_key && context.fn_key == fn_name
		&& context.fn_name == node.name && context.fn_node_id == g.autofree_cleanup_emit_fn_node_id
		&& context.fn_pos_id == g.autofree_cleanup_emit_fn_pos_id
		&& context.fn_pos_id == node.pos.id
}

fn autofree_statement_cleanup_emit_context_is_valid(context AutofreeCleanCStatementCleanupEmitContextFact) bool {
	if context.context_status != .inert
		|| context.context_kind != .after_body_before_scheduled_drops || context.fn_key.len == 0
		|| context.fn_name.len == 0 || context.name.len == 0 || context.context_key.len == 0 {
		return false
	}
	if context.fn_node_id < 0 || context.fn_pos_id <= 0 || context.target_node_id < 0
		|| context.target_pos_id <= 0 || context.stmt_node_id < 0 || context.stmt_pos_id <= 0
		|| context.insert_after_node_id < 0 || context.insert_after_pos_id <= 0 {
		return false
	}
	if context.stmt_node_id != context.insert_after_node_id
		|| context.stmt_pos_id != context.insert_after_pos_id {
		return false
	}
	if context.target_node_id == context.insert_after_node_id {
		return false
	}
	if context.stmt_index < 0 || context.lhs_index != 0 {
		return false
	}
	target_c_name := c_local_name(context.name)
	expected_key := '${context.fn_key}:${context.fn_node_id}:${context.fn_pos_id}:${context.target_node_id}:${context.target_pos_id}:${context.insert_after_node_id}:${context.insert_after_pos_id}:${context.name}'
	return target_c_name.len > 0 && context.target_c_name == target_c_name
		&& context.cleanup_symbol == 'array__free'
		&& context.cleanup_text == '${context.cleanup_symbol}(&${target_c_name});'
		&& context.context_key == expected_key
}
