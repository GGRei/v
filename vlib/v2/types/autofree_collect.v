// Copyright (c) 2026 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module types

import v2.ast
import v2.token

// collect_autofree_facts_from_flat records pipeline coverage and clears facts.
pub fn (mut e Environment) collect_autofree_facts_from_flat(flat &ast.FlatAst) {
	counts := autofree_validate_flat_traversal(flat)
	e.autofree_pipeline = AutofreePipelineFact{
		enabled:              true
		flat_nodes:           flat.nodes.len
		flat_edges:           flat.edges.len
		flat_strings:         flat.strings.len
		valid_files:          counts.valid_files
		valid_stmt_lists:     counts.valid_stmt_lists
		fn_decls_seen:        counts.fn_decls_seen
		free_fns_seen:        counts.free_fns_seen
		methods_skipped:      counts.methods_skipped
		valid_param_lists:    counts.valid_param_lists
		params_seen:          counts.params_seen
		named_params:         counts.named_params
		valid_body_lists:     counts.valid_body_lists
		body_stmts_seen:      counts.body_stmts_seen
		assign_stmts_seen:    counts.assign_stmts_seen
		return_stmts_seen:    counts.return_stmts_seen
		decl_assigns_seen:    counts.decl_assigns_seen
		malformed_body_items: counts.malformed_body_items
		malformed_items:      counts.malformed_items
	}
	e.autofree_bindings_by_fn_key = map[string][]AutofreeBindingFact{}
	e.autofree_fresh_locals_by_fn_key = map[string][]AutofreeFreshLocalFact{}
	e.autofree_move_proofs_by_fn_key = map[string][]AutofreeMoveProofFact{}
	e.autofree_natural_release_candidates_by_fn_key = map[string][]AutofreeNaturalReleaseCandidateFact{}
	e.autofree_release_plans_by_fn_key = map[string][]AutofreeReleasePlanFact{}
	e.autofree_release_preflights_by_fn_key = map[string][]AutofreeReleasePreflightFact{}
	e.autofree_release_insertion_points_by_fn_key = map[string][]AutofreeReleaseInsertionPointFact{}
	e.autofree_transfers_by_fn_key = map[string][]AutofreeTransferFact{}
	e.autofree_release_eligibility_by_fn_key = map[string][]AutofreeReleaseEligibilityFact{}
	e.autofree_releases_by_fn_key = map[string][]AutofreeReleaseFact{}
	e.autofree_helper_roots = []AutofreeHelperRootFact{}
	e.collect_autofree_fresh_locals_from_flat(flat)
	e.collect_autofree_move_proofs_from_fresh_locals()
	e.collect_autofree_local_array_clone_move_proofs_from_flat(flat)
	e.collect_autofree_fresh_array_final_clone_move_proofs_from_flat(flat)
	e.collect_autofree_natural_release_candidates_from_move_proofs()
	e.collect_autofree_release_plans_from_candidates()
	e.collect_autofree_release_preflights_from_plans()
	e.collect_autofree_release_insertion_points_from_preflights()
	e.collect_autofree_parameter_bindings_from_flat(flat)
	e.collect_autofree_decl_transfers_from_flat(flat)
	e.collect_autofree_return_transfers_from_flat(flat)
	e.collect_autofree_global_store_transfers_from_flat(flat)
	e.collect_autofree_field_store_transfers_from_flat(flat)
	e.collect_autofree_map_value_store_transfers_from_flat(flat)
	e.collect_autofree_array_element_store_transfers_from_flat(flat)
	e.collect_autofree_array_push_transfers_from_flat(flat)
	e.collect_autofree_field_array_push_transfers_from_flat(flat)
	e.collect_autofree_parameter_array_push_transfers_from_flat(flat)
	e.collect_autofree_parameter_field_array_push_transfers_from_flat(flat)
	e.collect_autofree_prior_local_field_array_push_transfers_from_flat(flat)
	e.collect_autofree_prior_local_array_push_transfers_from_flat(flat)
	e.collect_autofree_for_in_field_array_push_transfers_from_flat(flat)
	e.collect_autofree_for_in_array_push_transfers_from_flat(flat)
	e.collect_autofree_borrowed_pointer_loop_cursor_transfers_from_flat(flat)
	e.collect_autofree_borrowed_pointer_field_read_transfers_from_flat(flat)
	e.collect_autofree_borrowed_pointer_field_store_transfers_from_flat(flat)
	e.collect_autofree_prior_local_borrowed_pointer_field_store_transfers_from_flat(flat)
	e.collect_autofree_struct_init_borrowed_pointer_field_transfers_from_flat(flat)
	e.collect_autofree_return_struct_init_borrowed_pointer_field_transfers_from_flat(flat)
	e.collect_autofree_prior_local_return_struct_init_borrowed_pointer_field_transfers_from_flat(flat)
	e.collect_autofree_direct_sumtype_wrap_payload_transfers_from_flat(flat)
	e.collect_autofree_prior_local_sumtype_wrap_payload_transfers_from_flat(flat)
	e.collect_autofree_struct_init_field_sumtype_wrap_payload_transfers_from_flat(flat)
	e.collect_autofree_local_holder_return_interop_transfers_from_flat(flat)
	e.collect_autofree_prior_local_holder_return_interop_transfers_from_flat(flat)
	e.collect_autofree_prior_local_struct_init_field_sumtype_wrap_payload_transfers_from_flat(flat)
	e.collect_autofree_return_struct_init_field_sumtype_wrap_payload_transfers_from_flat(flat)
	e.collect_autofree_prior_local_return_struct_init_field_sumtype_wrap_payload_transfers_from_flat(flat)
	e.collect_autofree_release_eligibility_from_transfers()
}

fn (mut e Environment) collect_autofree_fresh_locals_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_fresh_locals_from_fn(flat, module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_fresh_locals_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count <= 0 {
		return
	}
	body_node := flat.nodes[body_id]
	fn_key := autofree_fn_key(module_name, fn_name, '')
	if body_count == 2 {
		first_stmt_id := flat.edges[body_node.first_edge].child_id
		if autofree_collect_fresh_array_decl_lhs_rhs_schema_is_exact(flat, first_stmt_id) {
			second_stmt_id := flat.edges[body_node.first_edge + 1].child_id
			if e.collect_autofree_single_fresh_final_len_from_stmts(flat, fn_key, fn_name,
				first_stmt_id, second_stmt_id, param_names)
			{
				return
			}
		}
	}
	if body_count == 2 || body_count == 3 {
		first_stmt_id := flat.edges[body_node.first_edge].child_id
		if autofree_collect_fresh_array_decl_lhs_rhs_schema_is_exact(flat, first_stmt_id) {
			second_stmt_id := flat.edges[body_node.first_edge + 1].child_id
			mut shared_stmt_id := second_stmt_id
			if body_count == 3 {
				shared_stmt_id = flat.edges[body_node.first_edge + 2].child_id
			}
			facts := e.collect_autofree_two_fresh_locals_from_stmts(flat, fn_key, fn_name,
				first_stmt_id, second_stmt_id, shared_stmt_id, param_names) or { return }
			e.autofree_fresh_locals_by_fn_key[fn_key] = facts
			if !e.collect_autofree_two_fresh_shared_release_candidates(flat, facts, shared_stmt_id) {
				e.autofree_fresh_locals_by_fn_key.delete(fn_key)
			}
			return
		}
	}
	last_stmt_index := body_count - 1
	stmt_id := flat.edges[body_node.first_edge + last_stmt_index].child_id
	fact := e.collect_autofree_fresh_local_from_stmt(flat, fn_key, fn_name, stmt_id, param_names) or {
		return
	}
	if !e.autofree_collect_fresh_body_prefix_is_safe(flat, body_id, body_count, fact.name,
		param_names) {
		return
	}
	mut facts := e.autofree_fresh_locals_by_fn_key[fn_key] or { []AutofreeFreshLocalFact{} }
	facts << fact
	e.autofree_fresh_locals_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_single_fresh_final_len_from_stmts(flat &ast.FlatAst, fn_key string, fn_name string, fresh_stmt_id ast.FlatNodeId, final_stmt_id ast.FlatNodeId, param_names map[string]bool) bool {
	fresh := e.collect_autofree_fresh_local_from_stmt(flat, fn_key, fn_name, fresh_stmt_id,
		param_names) or { return false }
	if !autofree_collect_single_fresh_final_len_source_is_supported(fresh) {
		return false
	}
	if !e.autofree_collect_single_fresh_final_len_stmt_is_safe(flat, final_stmt_id, fresh.name,
		param_names) {
		return false
	}
	e.autofree_fresh_locals_by_fn_key[fn_key] = [fresh]
	if !e.collect_autofree_single_fresh_final_len_release_candidate(flat, fresh, final_stmt_id) {
		e.autofree_fresh_locals_by_fn_key.delete(fn_key)
		return false
	}
	return true
}

fn (mut e Environment) collect_autofree_single_fresh_final_len_release_candidate(flat &ast.FlatAst, fresh AutofreeFreshLocalFact, final_stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is_valid(flat, final_stmt_id) {
		return false
	}
	final_stmt_pos_id := flat.nodes[final_stmt_id].pos.id
	if final_stmt_pos_id <= 0 || final_stmt_pos_id < fresh.stmt_pos_id {
		return false
	}
	proof := autofree_collect_move_proof_from_fresh_local(fresh) or { return false }
	candidate := autofree_collect_natural_release_candidate_from_move_proof_at_release(proof,
		final_stmt_id, final_stmt_pos_id) or { return false }
	e.autofree_move_proofs_by_fn_key[fresh.fn_key] = [proof]
	e.autofree_natural_release_candidates_by_fn_key[fresh.fn_key] = [candidate]
	return true
}

fn autofree_collect_single_fresh_final_len_source_is_supported(fresh AutofreeFreshLocalFact) bool {
	return autofree_collect_name_is_usable(fresh.name) && fresh.state == .owned_unique
		&& fresh.resource == .array_value && fresh.shape.kind == .array
		&& fresh.shape.target_kind == .no_resource
		&& autofree_collect_two_fresh_local_reason_is_supported(fresh.reason)
}

fn (mut e Environment) autofree_collect_single_fresh_final_len_stmt_is_safe(flat &ast.FlatAst, stmt_id ast.FlatNodeId, fresh_name string, param_names map[string]bool) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_assign)
		|| !autofree_collect_name_is_usable(fresh_name) {
		return false
	}
	stmt_node := flat.nodes[stmt_id]
	op := unsafe { token.Token(int(stmt_node.aux)) }
	if op != .decl_assign {
		return false
	}
	if stmt_node.extra != 1 || autofree_collect_exact_edge_count(flat, stmt_id) != 2 {
		return false
	}
	raw_lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	lhs_id := autofree_collect_two_fresh_final_scalar_lhs_id(flat, raw_lhs_id)
	if !autofree_collect_node_is(flat, lhs_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, lhs_id) != 0 {
		return false
	}
	lhs_name := flat.string_at(flat.nodes[lhs_id].name_id)
	if !autofree_collect_name_is_usable(lhs_name) || lhs_name == fresh_name
		|| lhs_name in param_names {
		return false
	}
	return e.autofree_collect_single_fresh_final_len_rhs_is_safe(flat, rhs_id, fresh_name)
}

fn (mut e Environment) autofree_collect_single_fresh_final_len_rhs_is_safe(flat &ast.FlatAst, expr_id ast.FlatNodeId, fresh_name string) bool {
	if !e.autofree_collect_two_fresh_final_len_scalar_expr_is_safe(flat, expr_id)
		|| !autofree_collect_node_is(flat, expr_id, .expr_selector)
		|| autofree_collect_exact_edge_count(flat, expr_id) != 2 {
		return false
	}
	expr_node := flat.nodes[expr_id]
	root_id := flat.edges[expr_node.first_edge].child_id
	field_id := flat.edges[expr_node.first_edge + 1].child_id
	if !autofree_collect_node_is(flat, root_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, root_id) != 0
		|| !autofree_collect_node_is(flat, field_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, field_id) != 0 {
		return false
	}
	root_name := flat.string_at(flat.nodes[root_id].name_id)
	field_name := flat.string_at(flat.nodes[field_id].name_id)
	return root_name == fresh_name && field_name == 'len'
}

fn (mut e Environment) collect_autofree_two_fresh_locals_from_stmts(flat &ast.FlatAst, fn_key string, fn_name string, first_stmt_id ast.FlatNodeId, second_stmt_id ast.FlatNodeId, shared_stmt_id ast.FlatNodeId, param_names map[string]bool) ?[]AutofreeFreshLocalFact {
	first := e.collect_autofree_fresh_local_from_stmt(flat, fn_key, fn_name, first_stmt_id,
		param_names) or { return none }
	second := e.collect_autofree_fresh_local_from_stmt(flat, fn_key, fn_name, second_stmt_id,
		param_names) or { return none }
	if !autofree_collect_two_fresh_locals_are_supported(first, second) {
		return none
	}
	if shared_stmt_id != second_stmt_id
		&& !e.autofree_collect_two_fresh_final_inert_stmt_is_safe(flat, shared_stmt_id, first.name, second.name, param_names) {
		return none
	}
	return [first, second]
}

fn (mut e Environment) collect_autofree_two_fresh_shared_release_candidates(flat &ast.FlatAst, fresh_locals []AutofreeFreshLocalFact, shared_stmt_id ast.FlatNodeId) bool {
	if fresh_locals.len != 2 || !autofree_collect_node_is_valid(flat, shared_stmt_id) {
		return false
	}
	first := fresh_locals[0]
	second := fresh_locals[1]
	if !autofree_collect_two_fresh_locals_are_supported(first, second) {
		return false
	}
	shared_stmt_pos_id := flat.nodes[shared_stmt_id].pos.id
	if shared_stmt_pos_id <= 0 || shared_stmt_pos_id < second.stmt_pos_id {
		return false
	}
	mut proofs := []AutofreeMoveProofFact{cap: 2}
	mut candidates := []AutofreeNaturalReleaseCandidateFact{cap: 2}
	for fresh in fresh_locals {
		proof := autofree_collect_move_proof_from_fresh_local(fresh) or { return false }
		candidate := autofree_collect_natural_release_candidate_from_move_proof_at_release(proof,
			shared_stmt_id, shared_stmt_pos_id) or { return false }
		proofs << proof
		candidates << candidate
	}
	e.autofree_move_proofs_by_fn_key[first.fn_key] = proofs
	e.autofree_natural_release_candidates_by_fn_key[first.fn_key] = candidates
	return true
}

fn autofree_collect_natural_release_candidate_from_move_proof_at_release(proof AutofreeMoveProofFact, release_after_node_id ast.FlatNodeId, release_after_pos_id int) ?AutofreeNaturalReleaseCandidateFact {
	candidate := autofree_collect_natural_release_candidate_from_move_proof(proof) or {
		return none
	}
	if release_after_node_id < 0 || release_after_pos_id <= 0
		|| release_after_pos_id < proof.stmt_pos_id {
		return none
	}
	return AutofreeNaturalReleaseCandidateFact{
		fn_key:                candidate.fn_key
		fn_name:               candidate.fn_name
		name:                  candidate.name
		move_kind:             candidate.move_kind
		source_endpoint:       candidate.source_endpoint
		endpoint:              candidate.endpoint
		state:                 candidate.state
		resource:              candidate.resource
		shape:                 candidate.shape
		typ:                   candidate.typ
		type_name:             candidate.type_name
		node_id:               candidate.node_id
		pos_id:                candidate.pos_id
		proof_node_id:         candidate.proof_node_id
		proof_pos_id:          candidate.proof_pos_id
		release_after_node_id: release_after_node_id
		release_after_pos_id:  release_after_pos_id
		reason:                'shared natural local cleanup candidate'
	}
}

fn (mut e Environment) autofree_collect_two_fresh_final_inert_stmt_is_safe(flat &ast.FlatAst, stmt_id ast.FlatNodeId, first_name string, second_name string, param_names map[string]bool) bool {
	return
		e.autofree_collect_two_fresh_scalar_inert_stmt_is_safe(flat, stmt_id, first_name, second_name, param_names)
		|| e.autofree_collect_two_fresh_final_len_stmt_is_safe(flat, stmt_id, first_name, second_name, param_names)
}

fn (mut e Environment) autofree_collect_two_fresh_scalar_inert_stmt_is_safe(flat &ast.FlatAst, stmt_id ast.FlatNodeId, first_name string, second_name string, param_names map[string]bool) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_assign)
		|| !autofree_collect_name_is_usable(first_name)
		|| !autofree_collect_name_is_usable(second_name) || first_name == second_name {
		return false
	}
	stmt_node := flat.nodes[stmt_id]
	op := unsafe { token.Token(int(stmt_node.aux)) }
	if op != .decl_assign && op != .assign {
		return false
	}
	if stmt_node.extra != 1 || autofree_collect_exact_edge_count(flat, stmt_id) != 2 {
		return false
	}
	raw_lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	lhs_id := autofree_collect_two_fresh_final_scalar_lhs_id(flat, raw_lhs_id)
	if !autofree_collect_node_is(flat, lhs_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, lhs_id) != 0 {
		return false
	}
	lhs_name := flat.string_at(flat.nodes[lhs_id].name_id)
	if !autofree_collect_name_is_usable(lhs_name) || lhs_name == first_name
		|| lhs_name == second_name || lhs_name in param_names {
		return false
	}
	if !e.autofree_collect_two_fresh_final_inert_expr_is_safe(flat, lhs_id, first_name, second_name) {
		return false
	}
	return e.autofree_collect_two_fresh_final_inert_expr_is_safe(flat, rhs_id, first_name,
		second_name)
}

fn (mut e Environment) autofree_collect_two_fresh_final_len_stmt_is_safe(flat &ast.FlatAst, stmt_id ast.FlatNodeId, first_name string, second_name string, param_names map[string]bool) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_assign)
		|| !autofree_collect_name_is_usable(first_name)
		|| !autofree_collect_name_is_usable(second_name) || first_name == second_name {
		return false
	}
	stmt_node := flat.nodes[stmt_id]
	op := unsafe { token.Token(int(stmt_node.aux)) }
	if op != .decl_assign && op != .assign {
		return false
	}
	if stmt_node.extra != 1 || autofree_collect_exact_edge_count(flat, stmt_id) != 2 {
		return false
	}
	raw_lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	lhs_id := autofree_collect_two_fresh_final_scalar_lhs_id(flat, raw_lhs_id)
	if !autofree_collect_node_is(flat, lhs_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, lhs_id) != 0 {
		return false
	}
	lhs_name := flat.string_at(flat.nodes[lhs_id].name_id)
	if !autofree_collect_name_is_usable(lhs_name) || lhs_name == first_name
		|| lhs_name == second_name || lhs_name in param_names {
		return false
	}
	mut term_counts := AutofreeFinalLenTermCounts{}
	if !e.autofree_collect_two_fresh_final_len_expr_is_safe(flat, rhs_id, first_name, second_name,
		param_names, mut term_counts) {
		return false
	}
	return term_counts.first_len_count == 1 && term_counts.second_len_count == 1
		&& term_counts.param_terms.len <= 1
}

fn autofree_collect_two_fresh_final_scalar_lhs_id(flat &ast.FlatAst, lhs_id ast.FlatNodeId) ast.FlatNodeId {
	if !autofree_collect_node_is(flat, lhs_id, .expr_modifier) {
		return lhs_id
	}
	lhs_node := flat.nodes[lhs_id]
	if unsafe { token.Token(int(lhs_node.aux)) } != .key_mut
		|| autofree_collect_exact_edge_count(flat, lhs_id) != 1 {
		return ast.invalid_flat_node_id
	}
	return flat.edges[lhs_node.first_edge].child_id
}

fn (mut e Environment) autofree_collect_two_fresh_final_inert_expr_is_safe(flat &ast.FlatAst, expr_id ast.FlatNodeId, first_name string, second_name string) bool {
	if !autofree_collect_node_is_valid(flat, expr_id)
		|| autofree_collect_exact_edge_count(flat, expr_id) != 0 {
		return false
	}
	expr_node := flat.nodes[expr_id]
	match expr_node.kind {
		.expr_basic_literal {}
		.expr_ident {
			expr_name := flat.string_at(expr_node.name_id)
			if !autofree_collect_name_is_usable(expr_name) || expr_name == first_name
				|| expr_name == second_name {
				return false
			}
		}
		else {
			return false
		}
	}

	expr_pos_id := expr_node.pos.id
	if expr_pos_id <= 0 {
		return false
	}
	expr_typ := e.get_expr_type(expr_pos_id) or { return false }
	if !type_has_valid_payload(expr_typ) {
		return false
	}
	shape := e.autofree_resource_shape(expr_typ)
	return !shape.fail_closed && shape.kind == .no_resource
}

struct AutofreeFinalLenTermCounts {
mut:
	first_len_count  int
	second_len_count int
	param_terms      []string
}

fn (mut e Environment) autofree_collect_two_fresh_final_len_expr_is_safe(flat &ast.FlatAst, expr_id ast.FlatNodeId, first_name string, second_name string, param_names map[string]bool, mut term_counts AutofreeFinalLenTermCounts) bool {
	if !autofree_collect_node_is_valid(flat, expr_id) {
		return false
	}
	expr_node := flat.nodes[expr_id]
	if !e.autofree_collect_two_fresh_final_len_scalar_expr_is_safe(flat, expr_id) {
		return false
	}
	match expr_node.kind {
		.expr_basic_literal {
			return false
		}
		.expr_ident {
			expr_name := flat.string_at(expr_node.name_id)
			if !autofree_collect_name_is_usable(expr_name) || expr_name !in param_names
				|| expr_name == first_name || expr_name == second_name
				|| term_counts.param_terms.len >= 1 {
				return false
			}
			term_counts.param_terms << expr_name
			return true
		}
		.expr_selector {
			return autofree_collect_two_fresh_final_len_selector_is_safe(flat, expr_id, first_name,
				second_name, mut term_counts)
		}
		.expr_infix {
			if autofree_collect_exact_edge_count(flat, expr_id) != 2 || !autofree_collect_two_fresh_final_len_infix_op_is_safe(unsafe {
				token.Token(int(expr_node.aux))
			}) {
				return false
			}
			lhs_id := flat.edges[expr_node.first_edge].child_id
			rhs_id := flat.edges[expr_node.first_edge + 1].child_id
			return
				e.autofree_collect_two_fresh_final_len_expr_is_safe(flat, lhs_id, first_name, second_name, param_names, mut term_counts)
				&& e.autofree_collect_two_fresh_final_len_expr_is_safe(flat, rhs_id, first_name, second_name, param_names, mut term_counts)
		}
		else {
			return false
		}
	}
}

fn autofree_collect_two_fresh_final_len_infix_op_is_safe(op token.Token) bool {
	return op == .plus
}

fn (mut e Environment) autofree_collect_two_fresh_final_len_scalar_expr_is_safe(flat &ast.FlatAst, expr_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is_valid(flat, expr_id) {
		return false
	}
	expr_pos_id := flat.nodes[expr_id].pos.id
	if expr_pos_id <= 0 {
		return false
	}
	expr_typ := e.get_expr_type(expr_pos_id) or { return false }
	if !type_has_valid_payload(expr_typ) {
		return false
	}
	shape := e.autofree_resource_shape(expr_typ)
	return !shape.fail_closed && shape.kind == .no_resource
}

fn autofree_collect_two_fresh_final_len_selector_is_safe(flat &ast.FlatAst, expr_id ast.FlatNodeId, first_name string, second_name string, mut term_counts AutofreeFinalLenTermCounts) bool {
	if !autofree_collect_node_is(flat, expr_id, .expr_selector)
		|| autofree_collect_exact_edge_count(flat, expr_id) != 2 {
		return false
	}
	expr_node := flat.nodes[expr_id]
	root_id := flat.edges[expr_node.first_edge].child_id
	field_id := flat.edges[expr_node.first_edge + 1].child_id
	if !autofree_collect_node_is(flat, root_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, root_id) != 0
		|| !autofree_collect_node_is(flat, field_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, field_id) != 0 {
		return false
	}
	root_name := flat.string_at(flat.nodes[root_id].name_id)
	field_name := flat.string_at(flat.nodes[field_id].name_id)
	if field_name != 'len' || (root_name != first_name && root_name != second_name) {
		return false
	}
	if root_name == first_name {
		term_counts.first_len_count++
		return term_counts.first_len_count <= 1
	}
	term_counts.second_len_count++
	return term_counts.second_len_count <= 1
}

fn autofree_collect_two_fresh_locals_are_supported(first AutofreeFreshLocalFact, second AutofreeFreshLocalFact) bool {
	if first.fn_key.len == 0 || first.fn_key != second.fn_key || first.fn_name != second.fn_name {
		return false
	}
	if !autofree_collect_name_is_usable(first.name) || !autofree_collect_name_is_usable(second.name)
		|| first.name == second.name {
		return false
	}
	if !autofree_collect_two_fresh_local_reason_is_supported(first.reason)
		|| !autofree_collect_two_fresh_local_reason_is_supported(second.reason) {
		return false
	}
	if first.stmt_pos_id <= 0 || second.stmt_pos_id <= 0 || first.stmt_pos_id >= second.stmt_pos_id {
		return false
	}
	if first.shape.kind != .array || second.shape.kind != .array {
		return false
	}
	if first.shape.target_kind != .no_resource || second.shape.target_kind != .no_resource {
		return false
	}
	if first.state != .owned_unique || second.state != .owned_unique {
		return false
	}
	return first.resource == .array_value && second.resource == .array_value
}

fn autofree_collect_two_fresh_local_reason_is_supported(reason string) bool {
	return reason == 'empty dynamic array literal' || reason == 'cap-only scalar array literal'
		|| reason == 'len-only scalar array literal'
}

fn (mut e Environment) collect_autofree_fresh_local_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, param_names map[string]bool) ?AutofreeFreshLocalFact {
	if !autofree_collect_fresh_array_decl_lhs_rhs_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	stmt_pos_id := stmt_node.pos.id
	if stmt_pos_id <= 0 {
		return none
	}
	lhs_expr_id := flat.edges[stmt_node.first_edge].child_id
	lhs_id := autofree_collect_fresh_array_lhs_ident_id(flat, lhs_expr_id)
	if lhs_id == ast.invalid_flat_node_id {
		return none
	}
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	lhs_name := flat.string_at(flat.nodes[lhs_id].name_id)
	if !autofree_collect_name_is_usable(lhs_name) || lhs_name in param_names {
		return none
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	rhs_pos_id := flat.nodes[rhs_id].pos.id
	if lhs_pos_id <= 0 || rhs_pos_id <= 0 {
		return none
	}
	lhs_typ := e.get_expr_type(lhs_pos_id) or {
		lhs_expr_pos_id := flat.nodes[lhs_expr_id].pos.id
		if lhs_expr_id == lhs_id || lhs_expr_pos_id <= 0 {
			return none
		}
		e.get_expr_type(lhs_expr_pos_id) or { return none }
	}
	rhs_typ := e.get_expr_type(rhs_pos_id) or { return none }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(rhs_typ) {
		return none
	}
	mut matched_typ := lhs_typ
	if !same_type_name(lhs_typ, rhs_typ) {
		matched_typ = autofree_collect_canonical_empty_string_array_type(lhs_typ, rhs_typ) or {
			return none
		}
	}
	fact_typ := matched_typ
	mut rhs_is_supported_fresh_array_source := false
	mut source_reason := ''
	match fact_typ {
		Array {
			if autofree_collect_empty_dynamic_array_init_is_exact(flat, rhs_id, fact_typ.elem_type) {
				rhs_is_supported_fresh_array_source = true
				source_reason = 'empty dynamic array literal'
			} else if e.autofree_collect_cap_only_array_init_is_exact(flat, rhs_id,
				fact_typ.elem_type, param_names)
			{
				if !autofree_collect_fresh_array_lhs_is_mut(flat, lhs_expr_id) {
					return none
				}
				rhs_is_supported_fresh_array_source = true
				source_reason = 'cap-only scalar array literal'
			} else if e.autofree_collect_len_only_array_init_is_exact(flat, rhs_id,
				fact_typ.elem_type, param_names)
			{
				if !autofree_collect_fresh_array_lhs_is_mut(flat, lhs_expr_id) {
					return none
				}
				rhs_is_supported_fresh_array_source = true
				source_reason = 'len-only scalar array literal'
			} else {
				return none
			}
		}
		else {
			return none
		}
	}

	shape := e.autofree_resource_shape(fact_typ)
	endpoint := autofree_collect_fresh_local_endpoint(flat, lhs_id, lhs_name, fact_typ, shape)
	source_endpoint := autofree_collect_fresh_literal_endpoint_with_reason(flat, rhs_id, fact_typ,
		shape, source_reason)
	if !autofree_collect_array_container_cleanup_allowed(shape, source_endpoint,
		rhs_is_supported_fresh_array_source) {
		return none
	}
	return AutofreeFreshLocalFact{
		fn_key:          fn_key
		fn_name:         fn_name
		name:            lhs_name
		endpoint:        endpoint
		source_endpoint: source_endpoint
		state:           .owned_unique
		resource:        endpoint.resource
		shape:           shape
		typ:             fact_typ
		type_name:       fact_typ.name()
		node_id:         lhs_id
		pos_id:          lhs_pos_id
		stmt_node_id:    stmt_id
		stmt_pos_id:     stmt_pos_id
		reason:          source_reason
	}
}

fn (mut e Environment) collect_autofree_move_proofs_from_fresh_locals() {
	for fn_key, fresh_locals in e.autofree_fresh_locals_by_fn_key {
		if fn_key in e.autofree_move_proofs_by_fn_key {
			continue
		}
		duplicates := autofree_collect_duplicate_fresh_local_names(fresh_locals)
		for fresh in fresh_locals {
			if fresh.fn_key != fn_key || fresh.name in duplicates {
				continue
			}
			proof := autofree_collect_move_proof_from_fresh_local(fresh) or { continue }
			mut proofs := e.autofree_move_proofs_by_fn_key[fresh.fn_key] or {
				[]AutofreeMoveProofFact{}
			}
			proofs << proof
			e.autofree_move_proofs_by_fn_key[fresh.fn_key] = proofs
		}
	}
}

fn autofree_collect_duplicate_fresh_local_names(fresh_locals []AutofreeFreshLocalFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for fresh in fresh_locals {
		if fresh.name.len == 0 {
			continue
		}
		if fresh.name in seen {
			duplicates[fresh.name] = true
			continue
		}
		seen[fresh.name] = true
	}
	return duplicates
}

fn autofree_collect_fresh_local_is_empty_dynamic_array(fresh AutofreeFreshLocalFact) bool {
	return fresh.reason == 'empty dynamic array literal'
		&& fresh.source_endpoint.reason == 'empty dynamic array literal'
}

fn autofree_collect_fresh_local_is_final_clone_array_source(fresh AutofreeFreshLocalFact) bool {
	if autofree_collect_fresh_local_is_empty_dynamic_array(fresh) {
		return true
	}
	if fresh.reason == 'cap-only scalar array literal'
		&& fresh.source_endpoint.reason == 'cap-only scalar array literal' {
		return true
	}
	return fresh.reason == 'len-only scalar array literal'
		&& fresh.source_endpoint.reason == 'len-only scalar array literal'
}

fn autofree_collect_move_proof_from_fresh_local(fresh AutofreeFreshLocalFact) ?AutofreeMoveProofFact {
	source := fresh.source_endpoint
	target := fresh.endpoint
	if fresh.fn_key.len == 0 || fresh.name.len == 0 {
		return none
	}
	if fresh.stmt_node_id < 0 || fresh.stmt_pos_id <= 0 {
		return none
	}
	if source.storage != .literal || source.root_storage != .literal || source.path.len != 0 {
		return none
	}
	if target.storage != .local || target.root_storage != .local || target.path.len != 0 {
		return none
	}
	if source.root_node_id != source.node_id || source.root_pos_id != source.pos_id
		|| source.node_id != fresh.source_endpoint.node_id
		|| source.pos_id != fresh.source_endpoint.pos_id || source.node_id < 0 || source.pos_id <= 0 {
		return none
	}
	if source.root_name != source.name {
		return none
	}
	if target.name != fresh.name || target.root_name != fresh.name
		|| target.root_node_id != target.node_id || target.root_pos_id != target.pos_id
		|| target.node_id != fresh.node_id || target.pos_id != fresh.pos_id || target.node_id < 0
		|| target.pos_id <= 0 {
		return none
	}
	if !source.has_type || !target.has_type {
		return none
	}
	if !type_has_valid_payload(source.typ) || !type_has_valid_payload(target.typ)
		|| !type_has_valid_payload(fresh.typ) {
		return none
	}
	if !same_type_name(source.typ, target.typ) || !same_type_name(target.typ, fresh.typ) {
		return none
	}
	canonical_type_name := fresh.typ.name()
	if canonical_type_name.len == 0 || fresh.type_name.len == 0 || source.type_name.len == 0
		|| target.type_name.len == 0 || fresh.type_name != canonical_type_name
		|| source.type_name != canonical_type_name || target.type_name != canonical_type_name {
		return none
	}
	if fresh.state != .owned_unique || target.state != .owned_unique
		|| source.state != .owned_unique {
		return none
	}
	if fresh.resource != .array_value || target.resource != .array_value
		|| source.resource != .array_value {
		return none
	}
	shape := fresh.shape
	if shape.kind != .array || shape.fail_closed || !shape.needs_autofree() {
		return none
	}
	if !autofree_collect_shapes_match_for_move_proof(shape, source.shape)
		|| !autofree_collect_shapes_match_for_move_proof(shape, target.shape) {
		return none
	}
	return AutofreeMoveProofFact{
		fn_key:          fresh.fn_key
		fn_name:         fresh.fn_name
		name:            fresh.name
		kind:            .fresh_local_binding
		source_endpoint: source
		target_endpoint: target
		state:           .owned_unique
		resource:        .array_value
		shape:           shape
		typ:             fresh.typ
		type_name:       canonical_type_name
		node_id:         fresh.node_id
		pos_id:          fresh.pos_id
		stmt_node_id:    fresh.stmt_node_id
		stmt_pos_id:     fresh.stmt_pos_id
		reason:          'fresh local binding'
	}
}

fn autofree_collect_shapes_match_for_move_proof(a AutofreeResourceShape, b AutofreeResourceShape) bool {
	return a.kind == b.kind && a.identity == b.identity && a.target_kind == b.target_kind
		&& a.target_identity == b.target_identity && a.has_owned_resource == b.has_owned_resource
		&& a.may_need_free == b.may_need_free && a.fail_closed == b.fail_closed
		&& a.needs_autofree() == b.needs_autofree()
}

struct AutofreeLocalArrayCloneRhs {
	receiver_name   string
	receiver_id     ast.FlatNodeId
	receiver_pos_id int
	call_id         ast.FlatNodeId
	call_pos_id     int
}

fn (mut e Environment) collect_autofree_local_array_clone_move_proofs_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			fn_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_local_array_clone_move_proof_from_fn(flat, module_name, fn_id)
		}
	}
}

fn (mut e Environment) collect_autofree_local_array_clone_move_proof_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count < 2 {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	param_ids_by_name := autofree_collect_param_ids_by_name(flat, param_ids)
	body_node := flat.nodes[body_id]
	first_stmt_id := flat.edges[body_node.first_edge].child_id
	last_stmt_id := flat.edges[body_node.first_edge + body_count - 1].child_id
	fn_key := autofree_fn_key(module_name, fn_name, '')
	proof := e.collect_autofree_local_array_clone_move_proof_from_stmts(flat, fn_key, fn_name,
		first_stmt_id, last_stmt_id, param_names, param_ids_by_name) or { return }
	if !autofree_collect_local_array_clone_middle_is_safe(flat, body_id, body_count, proof.name,
		proof.source_endpoint.name) {
		return
	}
	mut proofs := e.autofree_move_proofs_by_fn_key[proof.fn_key] or { []AutofreeMoveProofFact{} }
	proofs << proof
	e.autofree_move_proofs_by_fn_key[proof.fn_key] = proofs
}

fn (mut e Environment) collect_autofree_local_array_clone_move_proof_from_stmts(flat &ast.FlatAst, fn_key string, fn_name string, first_stmt_id ast.FlatNodeId, last_stmt_id ast.FlatNodeId, param_names map[string]bool, param_ids_by_name map[string]ast.FlatNodeId) ?AutofreeMoveProofFact {
	if !autofree_collect_node_is(flat, first_stmt_id, .stmt_assign)
		|| !autofree_collect_node_is(flat, last_stmt_id, .stmt_assign) {
		return none
	}
	first_node := flat.nodes[first_stmt_id]
	last_node := flat.nodes[last_stmt_id]
	if unsafe { token.Token(int(first_node.aux)) } != .decl_assign
		|| unsafe { token.Token(int(last_node.aux)) } != .assign {
		return none
	}
	if first_node.extra != 1 || last_node.extra != 1
		|| autofree_collect_exact_edge_count(flat, first_stmt_id) != 2
		|| autofree_collect_exact_edge_count(flat, last_stmt_id) != 2 {
		return none
	}
	arr_lhs_expr_id := flat.edges[first_node.first_edge].child_id
	arr_lhs_id := autofree_collect_fresh_array_lhs_ident_id(flat, arr_lhs_expr_id)
	if arr_lhs_id == ast.invalid_flat_node_id {
		return none
	}
	arr_name := flat.string_at(flat.nodes[arr_lhs_id].name_id)
	if !autofree_collect_name_is_usable(arr_name) || arr_name in param_names {
		return none
	}
	source_clone := autofree_collect_direct_clone_rhs(flat,
		flat.edges[first_node.first_edge + 1].child_id) or { return none }
	if !autofree_collect_name_is_usable(source_clone.receiver_name)
		|| source_clone.receiver_name == arr_name || source_clone.receiver_name !in param_names {
		return none
	}
	final_lhs_id := flat.edges[last_node.first_edge].child_id
	if !autofree_collect_node_is(flat, final_lhs_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, final_lhs_id) != 0 {
		return none
	}
	final_lhs_name := flat.string_at(flat.nodes[final_lhs_id].name_id)
	if final_lhs_name != source_clone.receiver_name {
		return none
	}
	final_clone := autofree_collect_direct_clone_rhs(flat,
		flat.edges[last_node.first_edge + 1].child_id) or { return none }
	if final_clone.receiver_name != arr_name {
		return none
	}
	arr_pos_id := flat.nodes[arr_lhs_id].pos.id
	source_pos_id := flat.nodes[source_clone.receiver_id].pos.id
	final_lhs_pos_id := flat.nodes[final_lhs_id].pos.id
	final_clone_pos_id := flat.nodes[final_clone.call_id].pos.id
	if arr_pos_id <= 0 || source_pos_id <= 0 || final_lhs_pos_id <= 0 || final_clone_pos_id <= 0
		|| first_node.pos.id <= 0 || last_node.pos.id <= 0 {
		return none
	}
	arr_typ := e.get_expr_type(arr_pos_id) or { return none }
	source_typ := e.get_expr_type(source_pos_id) or { return none }
	final_lhs_typ := e.get_expr_type(final_lhs_pos_id) or { return none }
	final_clone_typ := e.get_expr_type(final_clone_pos_id) or { return none }
	if !type_has_valid_payload(arr_typ) || !type_has_valid_payload(source_typ)
		|| !type_has_valid_payload(final_lhs_typ) || !type_has_valid_payload(final_clone_typ) {
		return none
	}
	source_transfer_typ := autofree_collect_local_array_clone_endpoint_type(source_typ,
		source_clone.receiver_name, param_names)
	final_lhs_transfer_typ := autofree_collect_local_array_clone_endpoint_type(final_lhs_typ,
		final_lhs_name, param_names)
	transfer_typ := autofree_collect_canonical_decl_transfer_type(arr_typ, source_transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(final_lhs_transfer_typ, transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(final_clone_typ, transfer_typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if !autofree_collect_scalar_array_clone_cleanup_allowed(transfer_typ, shape) {
		return none
	}
	source_root_id := param_ids_by_name[source_clone.receiver_name] or { return none }
	source_root_pos_id := flat.nodes[source_root_id].pos.id
	if source_root_id < 0 || source_root_pos_id <= 0 {
		return none
	}
	source_endpoint := AutofreeTransferEndpoint{
		...autofree_collect_endpoint(flat, source_root_id, source_root_pos_id,
			source_clone.receiver_id, source_clone.receiver_name, transfer_typ, shape, .parameter,
			'local scalar array clone source')
		state: .ambiguous_no_free
	}
	target_endpoint := AutofreeTransferEndpoint{
		...autofree_collect_endpoint(flat, arr_lhs_id, arr_pos_id, arr_lhs_id, arr_name,
			transfer_typ, shape, .local, 'local scalar array clone target')
		state: .owned_unique
	}
	return AutofreeMoveProofFact{
		fn_key:          fn_key
		fn_name:         fn_name
		name:            arr_name
		kind:            .local_array_clone_binding
		source_endpoint: source_endpoint
		target_endpoint: target_endpoint
		state:           .owned_unique
		resource:        .array_value
		shape:           shape
		typ:             transfer_typ
		type_name:       transfer_typ.name()
		node_id:         arr_lhs_id
		pos_id:          arr_pos_id
		stmt_node_id:    last_stmt_id
		stmt_pos_id:     last_node.pos.id
		reason:          'local scalar array clone final assignment'
	}
}

fn autofree_collect_local_array_clone_endpoint_type(typ Type, name string, param_names map[string]bool) Type {
	if name in param_names {
		if typ is Pointer {
			return typ.base_type
		}
	}
	return typ
}

fn autofree_collect_direct_clone_rhs(flat &ast.FlatAst, rhs_id ast.FlatNodeId) ?AutofreeLocalArrayCloneRhs {
	if !autofree_collect_node_is(flat, rhs_id, .expr_call) {
		return none
	}
	call_node := flat.nodes[rhs_id]
	if call_node.pos.id <= 0 {
		return none
	}
	edge_count := autofree_collect_exact_edge_count(flat, rhs_id)
	if edge_count != 1 && edge_count != 2 {
		return none
	}
	if edge_count == 2 {
		call_lhs_id := flat.edges[call_node.first_edge].child_id
		receiver_id := flat.edges[call_node.first_edge + 1].child_id
		if !autofree_collect_node_is(flat, call_lhs_id, .expr_ident)
			|| !autofree_collect_node_is(flat, receiver_id, .expr_ident)
			|| autofree_collect_exact_edge_count(flat, call_lhs_id) != 0
			|| autofree_collect_exact_edge_count(flat, receiver_id) != 0 {
			return none
		}
		call_name := flat.string_at(flat.nodes[call_lhs_id].name_id)
		receiver_name := flat.string_at(flat.nodes[receiver_id].name_id)
		if call_name != 'array__clone' || !autofree_collect_name_is_usable(receiver_name) {
			return none
		}
		return AutofreeLocalArrayCloneRhs{
			receiver_name:   receiver_name
			receiver_id:     receiver_id
			receiver_pos_id: flat.nodes[receiver_id].pos.id
			call_id:         rhs_id
			call_pos_id:     call_node.pos.id
		}
	}
	selector_id := flat.edges[call_node.first_edge].child_id
	if !autofree_collect_node_is(flat, selector_id, .expr_selector)
		|| autofree_collect_exact_edge_count(flat, selector_id) != 2 {
		return none
	}
	receiver_id := flat.edges[flat.nodes[selector_id].first_edge].child_id
	method_id := flat.edges[flat.nodes[selector_id].first_edge + 1].child_id
	if !autofree_collect_node_is(flat, receiver_id, .expr_ident)
		|| !autofree_collect_node_is(flat, method_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, receiver_id) != 0
		|| autofree_collect_exact_edge_count(flat, method_id) != 0 {
		return none
	}
	method_name := flat.string_at(flat.nodes[method_id].name_id)
	receiver_name := flat.string_at(flat.nodes[receiver_id].name_id)
	if method_name != 'clone' || !autofree_collect_name_is_usable(receiver_name) {
		return none
	}
	return AutofreeLocalArrayCloneRhs{
		receiver_name:   receiver_name
		receiver_id:     receiver_id
		receiver_pos_id: flat.nodes[receiver_id].pos.id
		call_id:         rhs_id
		call_pos_id:     call_node.pos.id
	}
}

fn autofree_collect_scalar_array_clone_cleanup_allowed(typ Type, shape AutofreeResourceShape) bool {
	if shape.kind != .array || shape.target_kind != .no_resource || shape.fail_closed
		|| !shape.needs_autofree() {
		return false
	}
	match typ {
		Array {
			elem_type := typ.elem_type
			return elem_type is Primitive || elem_type is Char || elem_type is Enum
				|| elem_type is ISize || elem_type is Rune || elem_type is USize
		}
		else {
			return false
		}
	}
}

fn (mut e Environment) collect_autofree_fresh_array_final_clone_move_proofs_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			fn_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_fresh_array_final_clone_move_proof_from_fn(flat, module_name, fn_id)
		}
	}
}

fn (mut e Environment) collect_autofree_fresh_array_final_clone_move_proof_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 2 {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	param_ids_by_name := autofree_collect_param_ids_by_name(flat, param_ids)
	body_node := flat.nodes[body_id]
	fresh_stmt_id := flat.edges[body_node.first_edge].child_id
	final_stmt_id := flat.edges[body_node.first_edge + 1].child_id
	fn_key := autofree_fn_key(module_name, fn_name, '')
	proof := e.collect_autofree_fresh_array_final_clone_move_proof_from_stmts(flat, fn_key,
		fn_name, fresh_stmt_id, final_stmt_id, param_names, param_ids_by_name) or { return }
	mut proofs := e.autofree_move_proofs_by_fn_key[proof.fn_key] or { []AutofreeMoveProofFact{} }
	proofs << proof
	e.autofree_move_proofs_by_fn_key[proof.fn_key] = proofs
}

fn (mut e Environment) collect_autofree_fresh_array_final_clone_move_proof_from_stmts(flat &ast.FlatAst, fn_key string, fn_name string, fresh_stmt_id ast.FlatNodeId, final_stmt_id ast.FlatNodeId, param_names map[string]bool, param_ids_by_name map[string]ast.FlatNodeId) ?AutofreeMoveProofFact {
	fresh := e.collect_autofree_fresh_local_from_stmt(flat, fn_key, fn_name, fresh_stmt_id,
		param_names) or { return none }
	if !autofree_collect_fresh_local_is_final_clone_array_source(fresh) {
		return none
	}
	if !autofree_collect_scalar_array_clone_cleanup_allowed(fresh.typ, fresh.shape) {
		return none
	}
	if !autofree_collect_node_is(flat, final_stmt_id, .stmt_assign) {
		return none
	}
	final_node := flat.nodes[final_stmt_id]
	if unsafe { token.Token(int(final_node.aux)) } != .assign || final_node.extra != 1
		|| autofree_collect_exact_edge_count(flat, final_stmt_id) != 2 {
		return none
	}
	final_lhs_id := flat.edges[final_node.first_edge].child_id
	if !autofree_collect_node_is(flat, final_lhs_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, final_lhs_id) != 0 {
		return none
	}
	final_lhs_name := flat.string_at(flat.nodes[final_lhs_id].name_id)
	if !autofree_collect_name_is_usable(final_lhs_name) || final_lhs_name !in param_names
		|| final_lhs_name == fresh.name {
		return none
	}
	param_id := param_ids_by_name[final_lhs_name] or { return none }
	if param_id < 0 || flat.nodes[param_id].pos.id <= 0
		|| (flat.nodes[param_id].flags & ast.flag_is_mut) == 0 {
		return none
	}
	final_clone := autofree_collect_direct_clone_rhs(flat,
		flat.edges[final_node.first_edge + 1].child_id) or { return none }
	if final_clone.receiver_name != fresh.name || final_clone.receiver_pos_id <= 0
		|| final_clone.call_pos_id <= 0 || final_node.pos.id <= 0 {
		return none
	}
	final_lhs_pos_id := flat.nodes[final_lhs_id].pos.id
	if final_lhs_pos_id <= 0 {
		return none
	}
	final_lhs_typ := e.get_expr_type(final_lhs_pos_id) or { return none }
	final_clone_typ := e.get_expr_type(final_clone.call_pos_id) or { return none }
	if !type_has_valid_payload(final_lhs_typ) || !type_has_valid_payload(final_clone_typ) {
		return none
	}
	final_lhs_transfer_typ := autofree_collect_local_array_clone_endpoint_type(final_lhs_typ,
		final_lhs_name, param_names)
	transfer_typ := autofree_collect_canonical_decl_transfer_type(final_lhs_transfer_typ, fresh.typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(final_clone_typ, transfer_typ) or {
		return none
	}
	if !same_type_name(transfer_typ, fresh.typ) {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if !autofree_collect_scalar_array_clone_cleanup_allowed(transfer_typ, shape)
		|| !autofree_collect_shapes_match_for_move_proof(shape, fresh.shape) {
		return none
	}
	proof := autofree_collect_move_proof_from_fresh_local(fresh) or { return none }
	return AutofreeMoveProofFact{
		...proof
		stmt_node_id: final_stmt_id
		stmt_pos_id:  final_node.pos.id
		reason:       'fresh scalar array final clone assignment'
	}
}

fn autofree_collect_local_array_clone_middle_is_safe(flat &ast.FlatAst, body_id ast.FlatNodeId, body_count int, target_name string, source_name string) bool {
	if body_count < 2 || !autofree_collect_name_is_usable(target_name)
		|| !autofree_collect_name_is_usable(source_name) {
		return false
	}
	body_node := flat.nodes[body_id]
	if body_node.first_edge < 0 || body_node.first_edge + body_count > flat.edges.len {
		return false
	}
	for i in 1 .. body_count - 1 {
		stmt_id := flat.edges[body_node.first_edge + i].child_id
		if !autofree_collect_local_array_clone_stmt_is_safe(flat, stmt_id, target_name, source_name) {
			return false
		}
	}
	return true
}

fn autofree_collect_local_array_clone_stmt_is_safe(flat &ast.FlatAst, stmt_id ast.FlatNodeId, target_name string, source_name string) bool {
	if !autofree_collect_node_is_valid(flat, stmt_id) {
		return false
	}
	if autofree_collect_local_array_clone_subtree_has_rejected_node(flat, stmt_id, target_name) {
		return false
	}
	if !autofree_collect_local_array_clone_assigns_are_safe(flat, stmt_id, target_name, source_name) {
		return false
	}
	return true
}

fn autofree_collect_local_array_clone_subtree_has_rejected_node(flat &ast.FlatAst, node_id ast.FlatNodeId, target_name string) bool {
	if !autofree_collect_node_is_valid(flat, node_id) {
		return true
	}
	node := flat.nodes[node_id]
	match node.kind {
		.stmt_return, .stmt_flow_control, .expr_fn_literal, .expr_lambda, .expr_call,
		.expr_call_or_cast {
			return true
		}
		.expr_infix {
			if unsafe { token.Token(int(node.aux)) } == .left_shift
				&& autofree_collect_subtree_contains_ident(flat, node_id, target_name) {
				return true
			}
		}
		else {}
	}

	for i in 0 .. node.edge_count {
		if !autofree_collect_child_is_valid(flat, node_id, i) {
			return true
		}
		child_id := flat.edges[node.first_edge + i].child_id
		if autofree_collect_local_array_clone_subtree_has_rejected_node(flat, child_id, target_name) {
			return true
		}
	}
	return false
}

fn autofree_collect_local_array_clone_assigns_are_safe(flat &ast.FlatAst, node_id ast.FlatNodeId, target_name string, source_name string) bool {
	if !autofree_collect_node_is_valid(flat, node_id) {
		return false
	}
	node := flat.nodes[node_id]
	if node.kind == .stmt_assign
		&& !autofree_collect_local_array_clone_assign_is_safe(flat, node_id, target_name, source_name) {
		return false
	}
	for i in 0 .. node.edge_count {
		if !autofree_collect_child_is_valid(flat, node_id, i) {
			return false
		}
		child_id := flat.edges[node.first_edge + i].child_id
		if !autofree_collect_local_array_clone_assigns_are_safe(flat, child_id, target_name,
			source_name) {
			return false
		}
	}
	return true
}

fn autofree_collect_local_array_clone_assign_is_safe(flat &ast.FlatAst, stmt_id ast.FlatNodeId, target_name string, source_name string) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_assign) {
		return false
	}
	stmt_node := flat.nodes[stmt_id]
	op := unsafe { token.Token(int(stmt_node.aux)) }
	edge_count := autofree_collect_exact_edge_count(flat, stmt_id)
	lhs_count := stmt_node.extra
	if lhs_count <= 0 || edge_count < lhs_count {
		return false
	}
	for lhs_i in 0 .. lhs_count {
		lhs_id := flat.edges[stmt_node.first_edge + lhs_i].child_id
		if autofree_collect_lhs_reassigns_direct_name(flat, lhs_id, target_name) {
			return false
		}
		if autofree_collect_node_is(flat, lhs_id, .expr_selector)
			&& autofree_collect_subtree_contains_ident(flat, lhs_id, target_name) {
			return false
		}
		if autofree_collect_node_is(flat, lhs_id, .expr_index)
			&& autofree_collect_subtree_contains_ident(flat, lhs_id, target_name)
			&& (op != .assign || !autofree_collect_index_root_is_ident(flat, lhs_id, target_name)) {
			return false
		}
		if op != .assign && autofree_collect_subtree_contains_ident(flat, lhs_id, target_name) {
			return false
		}
	}
	for rhs_i in lhs_count .. edge_count {
		rhs_id := flat.edges[stmt_node.first_edge + rhs_i].child_id
		if autofree_collect_subtree_contains_ident(flat, rhs_id, target_name) {
			return false
		}
		if autofree_collect_subtree_contains_ident(flat, rhs_id, source_name) && op == .decl_assign {
			return false
		}
	}
	return true
}

fn autofree_collect_lhs_reassigns_direct_name(flat &ast.FlatAst, lhs_id ast.FlatNodeId, name string) bool {
	direct_id := autofree_collect_direct_ident_id(flat, lhs_id)
	if direct_id == ast.invalid_flat_node_id {
		return false
	}
	return flat.string_at(flat.nodes[direct_id].name_id) == name
}

fn autofree_collect_direct_ident_id(flat &ast.FlatAst, node_id ast.FlatNodeId) ast.FlatNodeId {
	if autofree_collect_node_is(flat, node_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, node_id) == 0 {
		return node_id
	}
	return ast.invalid_flat_node_id
}

fn autofree_collect_index_root_is_ident(flat &ast.FlatAst, index_id ast.FlatNodeId, name string) bool {
	if !autofree_collect_node_is(flat, index_id, .expr_index)
		|| autofree_collect_exact_edge_count(flat, index_id) != 2 {
		return false
	}
	root_id := flat.edges[flat.nodes[index_id].first_edge].child_id
	return autofree_collect_lhs_reassigns_direct_name(flat, root_id, name)
}

fn autofree_collect_subtree_contains_ident(flat &ast.FlatAst, node_id ast.FlatNodeId, name string) bool {
	if !autofree_collect_node_is_valid(flat, node_id) || name.len == 0 {
		return false
	}
	node := flat.nodes[node_id]
	if node.kind == .expr_ident && flat.string_at(node.name_id) == name {
		return true
	}
	for i in 0 .. node.edge_count {
		if !autofree_collect_child_is_valid(flat, node_id, i) {
			return false
		}
		child_id := flat.edges[node.first_edge + i].child_id
		if autofree_collect_subtree_contains_ident(flat, child_id, name) {
			return true
		}
	}
	return false
}

fn autofree_collect_array_container_cleanup_allowed(shape AutofreeResourceShape, source AutofreeTransferEndpoint, supported_fresh_array_source bool) bool {
	if shape.kind != .array || shape.fail_closed || !shape.needs_autofree() {
		return false
	}
	if !supported_fresh_array_source || source.storage != .literal
		|| source.root_storage != .literal || source.path.len != 0 {
		return false
	}
	if source.reason == 'empty dynamic array literal' {
		return shape.target_kind == .no_resource || shape.target_kind == .string_
	}
	if source.reason == 'cap-only scalar array literal' {
		return shape.target_kind == .no_resource
	}
	if source.reason == 'len-only scalar array literal' {
		return shape.target_kind == .no_resource
	}
	return false
}

fn autofree_collect_canonical_empty_string_array_type(lhs_typ Type, rhs_typ Type) ?Type {
	if lhs_typ is Array && rhs_typ is Array
		&& autofree_collect_builtin_string_equivalent_type(lhs_typ.elem_type)
		&& autofree_collect_builtin_string_equivalent_type(rhs_typ.elem_type) {
		return Type(Array{
			elem_type: Type(string_)
		})
	}
	return none
}

fn autofree_collect_canonical_decl_transfer_type(lhs_typ Type, rhs_typ Type) ?Type {
	if same_type_name(lhs_typ, rhs_typ) {
		return lhs_typ
	}
	return autofree_collect_canonical_empty_string_array_type(lhs_typ, rhs_typ)
}

fn autofree_collect_builtin_string_equivalent_type(typ Type) bool {
	match typ {
		String {
			return true
		}
		Struct {
			return typ.name == 'string'
		}
		else {
			return false
		}
	}
}

fn (mut e Environment) autofree_collect_fresh_body_prefix_is_safe(flat &ast.FlatAst, body_id ast.FlatNodeId, body_count int, target_name string, param_names map[string]bool) bool {
	if body_count <= 1 {
		return true
	}
	if !autofree_collect_node_is(flat, body_id, .aux_list)
		|| !autofree_collect_name_is_usable(target_name) {
		return false
	}
	body_node := flat.nodes[body_id]
	if body_node.first_edge < 0 || body_node.first_edge + body_count > flat.edges.len {
		return false
	}
	if body_count == 2 {
		stmt_id := flat.edges[body_node.first_edge].child_id
		if e.autofree_collect_fresh_inert_transfer_prefix_stmt_is_safe(flat, stmt_id, target_name,
			param_names)
		{
			return true
		}
	}
	last_stmt_index := body_count - 1
	for i in 0 .. last_stmt_index {
		stmt_id := flat.edges[body_node.first_edge + i].child_id
		if !autofree_collect_fresh_literal_prefix_stmt_is_safe(flat, stmt_id, target_name) {
			return false
		}
	}
	return true
}

fn autofree_collect_fresh_literal_prefix_stmt_is_safe(flat &ast.FlatAst, stmt_id ast.FlatNodeId, target_name string) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_assign) {
		return false
	}
	stmt_node := flat.nodes[stmt_id]
	if unsafe { token.Token(int(stmt_node.aux)) } != .decl_assign {
		return false
	}
	if stmt_node.extra != 1 || autofree_collect_exact_edge_count(flat, stmt_id) != 2 {
		return false
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	if !autofree_collect_node_is(flat, lhs_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, lhs_id) != 0 {
		return false
	}
	lhs_name := flat.string_at(flat.nodes[lhs_id].name_id)
	if !autofree_collect_name_is_usable(lhs_name) || lhs_name == target_name {
		return false
	}
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	return autofree_collect_node_is(flat, rhs_id, .expr_basic_literal)
		&& autofree_collect_exact_edge_count(flat, rhs_id) == 0
}

fn (mut e Environment) autofree_collect_fresh_inert_transfer_prefix_stmt_is_safe(flat &ast.FlatAst, stmt_id ast.FlatNodeId, target_name string, param_names map[string]bool) bool {
	if !autofree_collect_decl_assign_schema_is_exact(flat, stmt_id) {
		return false
	}
	stmt_node := flat.nodes[stmt_id]
	if stmt_node.pos.id <= 0 {
		return false
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	lhs_name := flat.string_at(flat.nodes[lhs_id].name_id)
	rhs_name := flat.string_at(flat.nodes[rhs_id].name_id)
	if !autofree_collect_name_is_usable(lhs_name) || lhs_name == target_name
		|| lhs_name in param_names {
		return false
	}
	if !autofree_collect_name_is_usable(rhs_name) || rhs_name !in param_names {
		return false
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	rhs_pos_id := flat.nodes[rhs_id].pos.id
	if lhs_pos_id <= 0 || rhs_pos_id <= 0 {
		return false
	}
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return false }
	rhs_typ := e.get_expr_type(rhs_pos_id) or { return false }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(rhs_typ) {
		return false
	}
	transfer_typ := autofree_collect_canonical_decl_transfer_type(lhs_typ, rhs_typ) or {
		return false
	}
	lhs_shape := e.autofree_resource_shape(transfer_typ)
	rhs_shape := e.autofree_resource_shape(transfer_typ)
	if lhs_shape.fail_closed || rhs_shape.fail_closed {
		return false
	}
	return autofree_collect_transfer_action_from_shape(lhs_shape) != .move
}

fn (mut e Environment) collect_autofree_natural_release_candidates_from_move_proofs() {
	for fn_key, proofs in e.autofree_move_proofs_by_fn_key {
		if fn_key in e.autofree_natural_release_candidates_by_fn_key {
			continue
		}
		duplicates := autofree_collect_duplicate_move_proof_names(proofs)
		for proof in proofs {
			if proof.fn_key != fn_key || proof.name in duplicates {
				continue
			}
			candidate := autofree_collect_natural_release_candidate_from_move_proof(proof) or {
				continue
			}
			mut facts := e.autofree_natural_release_candidates_by_fn_key[proof.fn_key] or {
				[]AutofreeNaturalReleaseCandidateFact{}
			}
			facts << candidate
			e.autofree_natural_release_candidates_by_fn_key[proof.fn_key] = facts
		}
	}
}

fn autofree_collect_duplicate_move_proof_names(proofs []AutofreeMoveProofFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for proof in proofs {
		if proof.name.len == 0 {
			continue
		}
		if proof.name in seen {
			duplicates[proof.name] = true
			continue
		}
		seen[proof.name] = true
	}
	return duplicates
}

fn autofree_collect_natural_release_candidate_from_move_proof(proof AutofreeMoveProofFact) ?AutofreeNaturalReleaseCandidateFact {
	source := proof.source_endpoint
	target := proof.target_endpoint
	if proof.fn_key.len == 0 || proof.name.len == 0
		|| !autofree_collect_natural_release_move_kind_is_supported(proof.kind) {
		return none
	}
	if proof.node_id < 0 || proof.pos_id <= 0 || proof.stmt_node_id < 0 || proof.stmt_pos_id <= 0 {
		return none
	}
	if !autofree_collect_source_endpoint_matches_natural_release_kind(proof.kind, source) {
		return none
	}
	if target.storage != .local || target.root_storage != .local || target.path.len != 0 {
		return none
	}
	if !autofree_collect_source_endpoint_ids_match_natural_release_kind(proof.kind, source) {
		return none
	}
	if target.name != proof.name || target.root_name != proof.name
		|| target.root_node_id != target.node_id || target.root_pos_id != target.pos_id
		|| target.node_id != proof.node_id || target.pos_id != proof.pos_id || target.node_id < 0
		|| target.pos_id <= 0 {
		return none
	}
	if !source.has_type || !target.has_type || !type_has_valid_payload(source.typ)
		|| !type_has_valid_payload(target.typ) || !type_has_valid_payload(proof.typ) {
		return none
	}
	if !same_type_name(source.typ, target.typ) || !same_type_name(target.typ, proof.typ) {
		return none
	}
	canonical_type_name := proof.typ.name()
	if canonical_type_name.len == 0 || proof.type_name.len == 0 || source.type_name.len == 0
		|| target.type_name.len == 0 || proof.type_name != canonical_type_name
		|| source.type_name != canonical_type_name || target.type_name != canonical_type_name {
		return none
	}
	if proof.state != .owned_unique || target.state != .owned_unique
		|| !autofree_collect_source_state_matches_natural_release_kind(proof.kind, source.state) {
		return none
	}
	if proof.resource != .array_value || target.resource != .array_value
		|| source.resource != .array_value {
		return none
	}
	shape := proof.shape
	if !autofree_collect_natural_release_shape_allowed(proof.kind, shape, source, proof.typ) {
		return none
	}
	if !autofree_collect_shapes_match_for_move_proof(shape, source.shape)
		|| !autofree_collect_shapes_match_for_move_proof(shape, target.shape) {
		return none
	}
	return AutofreeNaturalReleaseCandidateFact{
		fn_key:                proof.fn_key
		fn_name:               proof.fn_name
		name:                  proof.name
		move_kind:             proof.kind
		source_endpoint:       source
		endpoint:              target
		state:                 .owned_unique
		resource:              .array_value
		shape:                 shape
		typ:                   proof.typ
		type_name:             canonical_type_name
		node_id:               proof.node_id
		pos_id:                proof.pos_id
		proof_node_id:         proof.node_id
		proof_pos_id:          proof.pos_id
		release_after_node_id: proof.stmt_node_id
		release_after_pos_id:  proof.stmt_pos_id
		reason:                'natural local cleanup candidate'
	}
}

fn autofree_collect_natural_release_move_kind_is_supported(kind AutofreeMoveProofKind) bool {
	return kind == .fresh_local_binding || kind == .local_array_clone_binding
}

fn autofree_collect_source_endpoint_matches_natural_release_kind(kind AutofreeMoveProofKind, source AutofreeTransferEndpoint) bool {
	match kind {
		.fresh_local_binding {
			return source.storage == .literal && source.root_storage == .literal
				&& source.path.len == 0 && source.root_node_id == source.node_id
				&& source.root_pos_id == source.pos_id
		}
		.local_array_clone_binding {
			return source.storage == .parameter && source.root_storage == .parameter
				&& source.path.len == 0
		}
		else {
			return false
		}
	}
}

fn autofree_collect_source_endpoint_ids_match_natural_release_kind(kind AutofreeMoveProofKind, source AutofreeTransferEndpoint) bool {
	if source.root_node_id < 0 || source.root_pos_id <= 0 || source.node_id < 0
		|| source.pos_id <= 0 || source.name.len == 0 || source.root_name != source.name {
		return false
	}
	match kind {
		.fresh_local_binding {
			return source.root_node_id == source.node_id && source.root_pos_id == source.pos_id
		}
		.local_array_clone_binding {
			return true
		}
		else {
			return false
		}
	}
}

fn autofree_collect_source_state_matches_natural_release_kind(kind AutofreeMoveProofKind, state AutofreeOwnershipState) bool {
	match kind {
		.fresh_local_binding {
			return state == .owned_unique
		}
		.local_array_clone_binding {
			return state == .ambiguous_no_free
		}
		else {
			return false
		}
	}
}

fn autofree_collect_natural_release_shape_allowed(kind AutofreeMoveProofKind, shape AutofreeResourceShape, source AutofreeTransferEndpoint, typ Type) bool {
	match kind {
		.fresh_local_binding {
			return autofree_collect_array_container_cleanup_allowed(shape, source, true)
		}
		.local_array_clone_binding {
			return autofree_collect_scalar_array_clone_cleanup_allowed(typ, shape)
		}
		else {
			return false
		}
	}
}

fn (mut e Environment) collect_autofree_release_plans_from_candidates() {
	for fn_key, candidates in e.autofree_natural_release_candidates_by_fn_key {
		duplicates := autofree_collect_duplicate_release_candidate_names(candidates)
		proofs := e.autofree_move_proofs_by_fn_key[fn_key] or { []AutofreeMoveProofFact{} }
		for candidate in candidates {
			if candidate.fn_key != fn_key || candidate.name in duplicates {
				continue
			}
			proof := autofree_collect_matching_move_proof_for_release_plan(candidate, proofs) or {
				continue
			}
			plan := autofree_collect_release_plan_from_candidate(candidate, proof) or { continue }
			mut plans := e.autofree_release_plans_by_fn_key[candidate.fn_key] or {
				[]AutofreeReleasePlanFact{}
			}
			plans << plan
			e.autofree_release_plans_by_fn_key[candidate.fn_key] = plans
		}
	}
}

fn autofree_collect_duplicate_release_candidate_names(candidates []AutofreeNaturalReleaseCandidateFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for candidate in candidates {
		if candidate.name.len == 0 {
			continue
		}
		if candidate.name in seen {
			duplicates[candidate.name] = true
			continue
		}
		seen[candidate.name] = true
	}
	return duplicates
}

fn autofree_collect_matching_move_proof_for_release_plan(candidate AutofreeNaturalReleaseCandidateFact, proofs []AutofreeMoveProofFact) ?AutofreeMoveProofFact {
	mut match_count := 0
	mut matched := AutofreeMoveProofFact{}
	for proof in proofs {
		if !autofree_collect_move_proof_matches_release_candidate(proof, candidate) {
			continue
		}
		match_count++
		matched = proof
	}
	if match_count != 1 {
		return none
	}
	return matched
}

fn autofree_collect_move_proof_matches_release_candidate(proof AutofreeMoveProofFact, candidate AutofreeNaturalReleaseCandidateFact) bool {
	return proof.fn_key == candidate.fn_key && proof.name == candidate.name
		&& proof.kind == candidate.move_kind && proof.node_id == candidate.proof_node_id
		&& proof.pos_id == candidate.proof_pos_id
		&& autofree_collect_release_candidate_slot_matches_proof(proof, candidate)
		&& autofree_collect_endpoints_match_for_release_plan(proof.source_endpoint, candidate.source_endpoint)
		&& autofree_collect_endpoints_match_for_release_plan(proof.target_endpoint, candidate.endpoint)
}

fn autofree_collect_release_candidate_slot_matches_proof(proof AutofreeMoveProofFact, candidate AutofreeNaturalReleaseCandidateFact) bool {
	if proof.stmt_node_id == candidate.release_after_node_id
		&& proof.stmt_pos_id == candidate.release_after_pos_id {
		return true
	}
	if candidate.reason != 'shared natural local cleanup candidate'
		|| proof.kind != .fresh_local_binding || candidate.move_kind != .fresh_local_binding {
		return false
	}
	return candidate.release_after_node_id >= 0
		&& candidate.release_after_pos_id >= proof.stmt_pos_id
		&& proof.stmt_node_id != candidate.release_after_node_id && proof.stmt_pos_id > 0
		&& proof.stmt_pos_id < candidate.release_after_pos_id
}

fn autofree_collect_endpoints_match_for_release_plan(a AutofreeTransferEndpoint, b AutofreeTransferEndpoint) bool {
	if a.storage != b.storage || a.root_storage != b.root_storage || a.root_name != b.root_name
		|| a.name != b.name || a.root_node_id != b.root_node_id || a.root_pos_id != b.root_pos_id
		|| a.node_id != b.node_id || a.pos_id != b.pos_id || a.path.len != 0 || b.path.len != 0
		|| a.has_type != b.has_type || !a.has_type {
		return false
	}
	if !type_has_valid_payload(a.typ) || !type_has_valid_payload(b.typ)
		|| !same_type_name(a.typ, b.typ) || a.type_name.len == 0 || a.type_name != b.type_name {
		return false
	}
	return a.resource == b.resource && a.state == b.state
		&& autofree_collect_shapes_match_for_move_proof(a.shape, b.shape)
}

fn autofree_collect_release_plan_from_candidate(candidate AutofreeNaturalReleaseCandidateFact, proof AutofreeMoveProofFact) ?AutofreeReleasePlanFact {
	source := candidate.source_endpoint
	target := candidate.endpoint
	if candidate.fn_key.len == 0 || candidate.name.len == 0
		|| !autofree_collect_natural_release_move_kind_is_supported(candidate.move_kind) {
		return none
	}
	if proof.fn_key != candidate.fn_key || proof.name != candidate.name
		|| proof.kind != candidate.move_kind {
		return none
	}
	if candidate.proof_node_id < 0 || candidate.proof_pos_id <= 0
		|| candidate.release_after_node_id < 0 || candidate.release_after_pos_id <= 0 {
		return none
	}
	if proof.node_id != candidate.proof_node_id || proof.pos_id != candidate.proof_pos_id
		|| !autofree_collect_release_candidate_slot_matches_proof(proof, candidate) {
		return none
	}
	if candidate.node_id < 0 || candidate.pos_id <= 0
		|| candidate.node_id != candidate.proof_node_id
		|| candidate.pos_id != candidate.proof_pos_id || candidate.node_id != target.node_id
		|| candidate.pos_id != target.pos_id {
		return none
	}
	if candidate.release_after_node_id == target.node_id {
		return none
	}
	if !autofree_collect_source_endpoint_matches_natural_release_kind(candidate.move_kind, source) {
		return none
	}
	if target.storage != .local || target.root_storage != .local || target.path.len != 0 {
		return none
	}
	if !autofree_collect_endpoints_match_for_release_plan(source, proof.source_endpoint)
		|| !autofree_collect_endpoints_match_for_release_plan(target, proof.target_endpoint) {
		return none
	}
	if !source.has_type || !target.has_type || !type_has_valid_payload(source.typ)
		|| !type_has_valid_payload(target.typ) || !type_has_valid_payload(candidate.typ)
		|| !type_has_valid_payload(proof.typ) {
		return none
	}
	if !same_type_name(source.typ, target.typ) || !same_type_name(target.typ, candidate.typ)
		|| !same_type_name(candidate.typ, proof.typ) {
		return none
	}
	canonical_type_name := candidate.typ.name()
	if canonical_type_name.len == 0 || candidate.type_name.len == 0 || proof.type_name.len == 0
		|| source.type_name.len == 0 || target.type_name.len == 0
		|| candidate.type_name != canonical_type_name || proof.type_name != canonical_type_name
		|| source.type_name != canonical_type_name || target.type_name != canonical_type_name {
		return none
	}
	if candidate.state != .owned_unique || proof.state != .owned_unique
		|| target.state != .owned_unique
		|| !autofree_collect_source_state_matches_natural_release_kind(candidate.move_kind, source.state) {
		return none
	}
	if candidate.resource != .array_value || proof.resource != .array_value
		|| source.resource != .array_value || target.resource != .array_value {
		return none
	}
	shape := candidate.shape
	if !autofree_collect_natural_release_shape_allowed(candidate.move_kind, shape, source,
		candidate.typ) {
		return none
	}
	if !autofree_collect_shapes_match_for_move_proof(shape, proof.shape)
		|| !autofree_collect_shapes_match_for_move_proof(shape, source.shape)
		|| !autofree_collect_shapes_match_for_move_proof(shape, target.shape) {
		return none
	}
	return AutofreeReleasePlanFact{
		fn_key:                candidate.fn_key
		fn_name:               candidate.fn_name
		name:                  candidate.name
		move_kind:             candidate.move_kind
		plan_kind:             .natural_exit
		plan_action:           .array_container_cleanup
		helper_requirement:    .none
		source_endpoint:       source
		endpoint:              target
		state:                 .owned_unique
		resource:              .array_value
		shape:                 shape
		typ:                   candidate.typ
		type_name:             canonical_type_name
		node_id:               candidate.node_id
		pos_id:                candidate.pos_id
		proof_node_id:         candidate.proof_node_id
		proof_pos_id:          candidate.proof_pos_id
		release_after_node_id: candidate.release_after_node_id
		release_after_pos_id:  candidate.release_after_pos_id
		reason:                'natural release plan'
	}
}

fn (mut e Environment) collect_autofree_release_preflights_from_plans() {
	for fn_key, plans in e.autofree_release_plans_by_fn_key {
		duplicates := autofree_collect_duplicate_release_plan_identities(plans)
		for plan in plans {
			identity := autofree_collect_release_plan_identity(plan)
			if plan.fn_key != fn_key || identity in duplicates {
				continue
			}
			preflight := autofree_collect_release_preflight_from_plan(plan) or { continue }
			mut facts := e.autofree_release_preflights_by_fn_key[plan.fn_key] or {
				[]AutofreeReleasePreflightFact{}
			}
			facts << preflight
			e.autofree_release_preflights_by_fn_key[plan.fn_key] = facts
		}
	}
}

fn autofree_collect_duplicate_release_plan_identities(plans []AutofreeReleasePlanFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for plan in plans {
		identity := autofree_collect_release_plan_identity(plan)
		if identity.len == 0 {
			continue
		}
		if identity in seen {
			duplicates[identity] = true
			continue
		}
		seen[identity] = true
	}
	return duplicates
}

fn autofree_collect_release_plan_identity(plan AutofreeReleasePlanFact) string {
	return plan.name
}

fn autofree_collect_release_preflight_from_plan(plan AutofreeReleasePlanFact) ?AutofreeReleasePreflightFact {
	source := plan.source_endpoint
	target := plan.endpoint
	if plan.fn_key.len == 0 || plan.name.len == 0
		|| !autofree_collect_natural_release_move_kind_is_supported(plan.move_kind) {
		return none
	}
	if plan.plan_kind != .natural_exit || plan.plan_action != .array_container_cleanup
		|| plan.helper_requirement != .none {
		return none
	}
	if plan.node_id < 0 || plan.pos_id <= 0 || plan.proof_node_id < 0 || plan.proof_pos_id <= 0
		|| plan.release_after_node_id < 0 || plan.release_after_pos_id <= 0 {
		return none
	}
	if plan.node_id != plan.proof_node_id || plan.pos_id != plan.proof_pos_id
		|| plan.node_id != target.node_id || plan.pos_id != target.pos_id {
		return none
	}
	if plan.release_after_node_id == target.node_id {
		return none
	}
	if !autofree_collect_source_endpoint_matches_natural_release_kind(plan.move_kind, source) {
		return none
	}
	if target.storage != .local || target.root_storage != .local || target.path.len != 0 {
		return none
	}
	if !autofree_collect_source_endpoint_ids_match_natural_release_kind(plan.move_kind, source) {
		return none
	}
	if target.name != plan.name || target.root_name != plan.name
		|| target.root_node_id != target.node_id || target.root_pos_id != target.pos_id {
		return none
	}
	if !source.has_type || !target.has_type || !type_has_valid_payload(source.typ)
		|| !type_has_valid_payload(target.typ) || !type_has_valid_payload(plan.typ) {
		return none
	}
	if !same_type_name(source.typ, target.typ) || !same_type_name(target.typ, plan.typ) {
		return none
	}
	canonical_type_name := plan.typ.name()
	if canonical_type_name.len == 0 || plan.type_name.len == 0 || source.type_name.len == 0
		|| target.type_name.len == 0 || plan.type_name != canonical_type_name
		|| source.type_name != canonical_type_name || target.type_name != canonical_type_name {
		return none
	}
	if plan.state != .owned_unique || target.state != .owned_unique
		|| !autofree_collect_source_state_matches_natural_release_kind(plan.move_kind, source.state) {
		return none
	}
	if plan.resource != .array_value || source.resource != .array_value
		|| target.resource != .array_value {
		return none
	}
	shape := plan.shape
	if !autofree_collect_natural_release_shape_allowed(plan.move_kind, shape, source, plan.typ) {
		return none
	}
	if !autofree_collect_shapes_match_for_move_proof(shape, source.shape)
		|| !autofree_collect_shapes_match_for_move_proof(shape, target.shape) {
		return none
	}
	return AutofreeReleasePreflightFact{
		fn_key:                plan.fn_key
		fn_name:               plan.fn_name
		name:                  plan.name
		move_kind:             plan.move_kind
		plan_kind:             plan.plan_kind
		plan_action:           plan.plan_action
		helper_requirement:    plan.helper_requirement
		preflight_status:      .inert
		source_endpoint:       source
		endpoint:              target
		state:                 .owned_unique
		resource:              .array_value
		shape:                 shape
		typ:                   plan.typ
		type_name:             canonical_type_name
		node_id:               plan.node_id
		pos_id:                plan.pos_id
		proof_node_id:         plan.proof_node_id
		proof_pos_id:          plan.proof_pos_id
		release_after_node_id: plan.release_after_node_id
		release_after_pos_id:  plan.release_after_pos_id
		reason:                'release preflight accepted'
	}
}

fn (mut e Environment) collect_autofree_release_insertion_points_from_preflights() {
	for fn_key, preflights in e.autofree_release_preflights_by_fn_key {
		duplicates := autofree_collect_duplicate_release_preflight_names(preflights)
		for preflight in preflights {
			if preflight.fn_key != fn_key || preflight.name in duplicates {
				continue
			}
			point := autofree_collect_release_insertion_point_from_preflight(preflight) or {
				continue
			}
			mut facts := e.autofree_release_insertion_points_by_fn_key[preflight.fn_key] or {
				[]AutofreeReleaseInsertionPointFact{}
			}
			facts << point
			e.autofree_release_insertion_points_by_fn_key[preflight.fn_key] = facts
		}
	}
}

fn autofree_collect_duplicate_release_preflight_names(preflights []AutofreeReleasePreflightFact) map[string]bool {
	mut seen := map[string]bool{}
	mut duplicates := map[string]bool{}
	for preflight in preflights {
		if preflight.name.len == 0 {
			continue
		}
		if preflight.name in seen {
			duplicates[preflight.name] = true
			continue
		}
		seen[preflight.name] = true
	}
	return duplicates
}

fn autofree_collect_release_insertion_point_from_preflight(preflight AutofreeReleasePreflightFact) ?AutofreeReleaseInsertionPointFact {
	source := preflight.source_endpoint
	target := preflight.endpoint
	if preflight.fn_key.len == 0 || preflight.name.len == 0 || preflight.preflight_status != .inert {
		return none
	}
	if !autofree_collect_natural_release_move_kind_is_supported(preflight.move_kind)
		|| preflight.plan_kind != .natural_exit || preflight.plan_action != .array_container_cleanup
		|| preflight.helper_requirement != .none {
		return none
	}
	if preflight.node_id < 0 || preflight.pos_id <= 0 || preflight.proof_node_id < 0
		|| preflight.proof_pos_id <= 0 || preflight.release_after_node_id < 0
		|| preflight.release_after_pos_id <= 0 {
		return none
	}
	if preflight.node_id != preflight.proof_node_id || preflight.pos_id != preflight.proof_pos_id
		|| preflight.node_id != target.node_id || preflight.pos_id != target.pos_id {
		return none
	}
	if preflight.release_after_node_id == target.node_id {
		return none
	}
	if !autofree_collect_source_endpoint_matches_natural_release_kind(preflight.move_kind, source) {
		return none
	}
	if target.storage != .local || target.root_storage != .local || target.path.len != 0 {
		return none
	}
	if !autofree_collect_source_endpoint_ids_match_natural_release_kind(preflight.move_kind, source) {
		return none
	}
	if target.name != preflight.name || target.root_name != preflight.name
		|| target.root_node_id != target.node_id || target.root_pos_id != target.pos_id {
		return none
	}
	if !source.has_type || !target.has_type || !type_has_valid_payload(source.typ)
		|| !type_has_valid_payload(target.typ) || !type_has_valid_payload(preflight.typ) {
		return none
	}
	if !same_type_name(source.typ, target.typ) || !same_type_name(target.typ, preflight.typ) {
		return none
	}
	canonical_type_name := preflight.typ.name()
	if canonical_type_name.len == 0 || preflight.type_name.len == 0 || source.type_name.len == 0
		|| target.type_name.len == 0 || preflight.type_name != canonical_type_name
		|| source.type_name != canonical_type_name || target.type_name != canonical_type_name {
		return none
	}
	if preflight.state != .owned_unique || target.state != .owned_unique
		|| !autofree_collect_source_state_matches_natural_release_kind(preflight.move_kind, source.state) {
		return none
	}
	if preflight.resource != .array_value || source.resource != .array_value
		|| target.resource != .array_value {
		return none
	}
	shape := preflight.shape
	if !autofree_collect_natural_release_shape_allowed(preflight.move_kind, shape, source,
		preflight.typ) {
		return none
	}
	if !autofree_collect_shapes_match_for_move_proof(shape, source.shape)
		|| !autofree_collect_shapes_match_for_move_proof(shape, target.shape) {
		return none
	}
	return AutofreeReleaseInsertionPointFact{
		fn_key:                preflight.fn_key
		fn_name:               preflight.fn_name
		name:                  preflight.name
		move_kind:             preflight.move_kind
		plan_kind:             preflight.plan_kind
		plan_action:           preflight.plan_action
		helper_requirement:    preflight.helper_requirement
		preflight_status:      preflight.preflight_status
		insertion_kind:        .after_statement
		insertion_status:      .inert
		source_endpoint:       source
		endpoint:              target
		state:                 .owned_unique
		resource:              .array_value
		shape:                 shape
		typ:                   preflight.typ
		type_name:             canonical_type_name
		node_id:               preflight.node_id
		pos_id:                preflight.pos_id
		proof_node_id:         preflight.proof_node_id
		proof_pos_id:          preflight.proof_pos_id
		release_after_node_id: preflight.release_after_node_id
		release_after_pos_id:  preflight.release_after_pos_id
		insert_after_node_id:  preflight.release_after_node_id
		insert_after_pos_id:   preflight.release_after_pos_id
		reason:                'release insertion point accepted'
	}
}

fn (mut e Environment) collect_autofree_parameter_bindings_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_parameter_bindings_from_fn(flat, module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_parameter_bindings_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 {
		return
	}
	if !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	if param_ids.len == 0 {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	for param_id in param_ids {
		param_name := flat.string_at(flat.nodes[param_id].name_id)
		if param_name.len == 0 {
			continue
		}
		obj := fn_scope.lookup(param_name) or { continue }
		typ := obj.typ()
		if !type_has_valid_payload(typ) {
			continue
		}
		shape := e.autofree_resource_shape(typ)
		if shape.fail_closed {
			continue
		}
		binding := AutofreeBindingFact{
			fn_key:   fn_key
			fn_name:  fn_name
			name:     param_name
			typ:      typ
			node_id:  param_id
			pos_id:   flat.nodes[param_id].pos.id
			storage:  .parameter
			resource: autofree_collect_resource_kind_from_shape(shape)
			shape:    shape
			state:    autofree_collect_binding_state_from_shape(shape)
			reason:   'parameter'
		}
		mut facts := e.autofree_bindings_by_fn_key[fn_key] or { []AutofreeBindingFact{} }
		facts << binding
		e.autofree_bindings_by_fn_key[fn_key] = facts
	}
}

fn (mut e Environment) collect_autofree_decl_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_decl_transfers_from_fn(flat, module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_decl_transfers_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count < 0 {
		return
	}
	body_node := flat.nodes[body_id]
	mut local_decls := map[string]bool{}
	mut proven_locals := map[string]AutofreeTransferEndpoint{}
	for i in 0 .. body_count {
		stmt_id := flat.edges[body_node.first_edge + i].child_id
		if accepted_endpoint := e.collect_autofree_decl_transfer_from_stmt(flat, fn_key, fn_name,
			stmt_id, param_names, param_bindings_by_name, local_decls, proven_locals)
		{
			autofree_collect_record_assignment_lhs_names(flat, stmt_id, mut local_decls, mut
				proven_locals)
			proven_locals[accepted_endpoint.name] = accepted_endpoint
		} else {
			autofree_collect_record_assignment_lhs_names(flat, stmt_id, mut local_decls, mut
				proven_locals)
		}
	}
}

fn (mut e Environment) collect_autofree_decl_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact, local_decls map[string]bool, proven_locals map[string]AutofreeTransferEndpoint) ?AutofreeTransferEndpoint {
	if !autofree_collect_decl_assign_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	if stmt_node.pos.id <= 0 {
		return none
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	lhs_name := flat.string_at(flat.nodes[lhs_id].name_id)
	rhs_name := flat.string_at(flat.nodes[rhs_id].name_id)
	if !autofree_collect_name_is_usable(lhs_name) {
		return none
	}
	if lhs_name in param_names || lhs_name in local_decls {
		return none
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	rhs_pos_id := flat.nodes[rhs_id].pos.id
	if lhs_pos_id <= 0 || rhs_pos_id <= 0 {
		return none
	}
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return none }
	rhs_typ := e.get_expr_type(rhs_pos_id) or { return none }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(rhs_typ) {
		return none
	}
	transfer_typ := autofree_collect_canonical_decl_transfer_type(lhs_typ, rhs_typ) or {
		return none
	}
	lhs_shape := e.autofree_resource_shape(transfer_typ)
	rhs_shape := e.autofree_resource_shape(transfer_typ)
	if lhs_shape.fail_closed || rhs_shape.fail_closed {
		return none
	}
	from_endpoint := autofree_collect_source_endpoint(flat, rhs_id, rhs_name, transfer_typ,
		rhs_shape, param_names, param_bindings, local_decls, proven_locals) or { return none }
	to_endpoint := autofree_collect_endpoint(flat, lhs_id, lhs_pos_id, lhs_id, lhs_name,
		transfer_typ, lhs_shape, .local, 'declaration target')
	transfer := AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .decl
		action:        autofree_collect_transfer_action_from_shape(lhs_shape)
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     rhs_name
		to_name:       lhs_name
		typ:           transfer_typ
		shape:         lhs_shape
		node_id:       stmt_id
		pos_id:        stmt_node.pos.id
		reason:        'direct declaration'
	}
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
	return to_endpoint
}

fn autofree_collect_source_endpoint(flat &ast.FlatAst, rhs_id ast.FlatNodeId, rhs_name string, rhs_typ Type, rhs_shape AutofreeResourceShape, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact, local_decls map[string]bool, proven_locals map[string]AutofreeTransferEndpoint) ?AutofreeTransferEndpoint {
	if !autofree_collect_name_is_usable(rhs_name) {
		return none
	}
	if proven := proven_locals[rhs_name] {
		if proven.storage != .local || proven.root_storage != .local || proven.path.len != 0
			|| !proven.has_type || !type_has_valid_payload(proven.typ) {
			return none
		}
		_ = autofree_collect_canonical_decl_transfer_type(rhs_typ, proven.typ) or { return none }
		return autofree_collect_endpoint(flat, proven.root_node_id, proven.root_pos_id, rhs_id,
			rhs_name, rhs_typ, rhs_shape, .local, 'declaration source')
	}
	if rhs_name in local_decls || rhs_name !in param_names {
		return none
	}
	rhs_binding := param_bindings[rhs_name] or { return none }
	if rhs_binding.storage != .parameter || !type_has_valid_payload(rhs_binding.typ) {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(rhs_typ, rhs_binding.typ) or { return none }
	return autofree_collect_endpoint(flat, rhs_binding.node_id, rhs_binding.pos_id, rhs_id,
		rhs_name, rhs_typ, rhs_shape, .parameter, 'declaration source')
}

fn (mut e Environment) collect_autofree_return_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_return_transfer_from_fn(flat, module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_return_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 2 {
		return
	}
	body_node := flat.nodes[body_id]
	fresh_stmt_id := flat.edges[body_node.first_edge].child_id
	return_stmt_id := flat.edges[body_node.first_edge + 1].child_id
	fn_key := autofree_fn_key(module_name, fn_name, '')
	fresh := e.collect_autofree_fresh_local_from_stmt(flat, fn_key, fn_name, fresh_stmt_id,
		param_names) or { return }
	if !autofree_collect_fresh_local_is_empty_dynamic_array(fresh) {
		return
	}
	transfer := e.collect_autofree_return_transfer_from_stmt(flat, fn_key, fn_name, return_stmt_id,
		fresh) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_return_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, fresh AutofreeFreshLocalFact) ?AutofreeTransferFact {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_return) {
		return none
	}
	if autofree_collect_exact_edge_count(flat, stmt_id) != 1 {
		return none
	}
	return_id := flat.edges[flat.nodes[stmt_id].first_edge].child_id
	if !autofree_collect_node_is(flat, return_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, return_id) != 0 {
		return none
	}
	return_name := flat.string_at(flat.nodes[return_id].name_id)
	if return_name != fresh.name || !autofree_collect_name_is_usable(return_name) {
		return none
	}
	return_pos_id := flat.nodes[return_id].pos.id
	if return_pos_id <= 0 {
		return none
	}
	return_typ := e.get_expr_type(return_pos_id) or { return none }
	if !type_has_valid_payload(return_typ) || !type_has_valid_payload(fresh.typ) {
		return none
	}
	transfer_typ := autofree_collect_canonical_decl_transfer_type(return_typ, fresh.typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		...autofree_collect_endpoint(flat, fresh.endpoint.root_node_id, fresh.endpoint.root_pos_id,
			return_id, return_name, transfer_typ, shape, .local, 'return source')
		state: .owned_unique
	}
	to_endpoint := AutofreeTransferEndpoint{
		...autofree_collect_endpoint(flat, return_id, return_pos_id, return_id, return_name,
			transfer_typ, shape, .return_value, 'return value')
		state: .owned_unique
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .return_expr
		action:        autofree_collect_transfer_action_from_shape(shape)
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     return_name
		to_name:       return_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       return_id
		pos_id:        return_pos_id
		reason:        'direct return'
	}
}

fn (mut e Environment) collect_autofree_global_store_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_global_store_transfer_from_fn(flat, module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_global_store_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 2 {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	body_node := flat.nodes[body_id]
	fresh_stmt_id := flat.edges[body_node.first_edge].child_id
	store_stmt_id := flat.edges[body_node.first_edge + 1].child_id
	fn_key := autofree_fn_key(module_name, fn_name, '')
	fresh := e.collect_autofree_fresh_local_from_stmt(flat, fn_key, fn_name, fresh_stmt_id,
		param_names) or { return }
	if !autofree_collect_fresh_local_is_empty_dynamic_array(fresh) {
		return
	}
	transfer := e.collect_autofree_global_store_transfer_from_stmt(flat, fn_key, fn_name,
		store_stmt_id, fresh, fn_scope, param_names) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_global_store_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, fresh AutofreeFreshLocalFact, fn_scope &Scope, param_names map[string]bool) ?AutofreeTransferFact {
	if !autofree_collect_global_store_assign_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	if stmt_node.pos.id <= 0 {
		return none
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	lhs_name := flat.string_at(flat.nodes[lhs_id].name_id)
	rhs_name := flat.string_at(flat.nodes[rhs_id].name_id)
	if !autofree_collect_name_is_usable(lhs_name) || !autofree_collect_name_is_usable(rhs_name)
		|| rhs_name != fresh.name || lhs_name == fresh.name {
		return none
	}
	if lhs_name in param_names {
		return none
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	rhs_pos_id := flat.nodes[rhs_id].pos.id
	if lhs_pos_id <= 0 || rhs_pos_id <= 0 {
		return none
	}
	global_obj := fn_scope.lookup_parent(lhs_name, lhs_pos_id) or { return none }
	if global_obj !is Global {
		return none
	}
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return none }
	rhs_typ := e.get_expr_type(rhs_pos_id) or { return none }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(rhs_typ)
		|| !type_has_valid_payload(fresh.typ) {
		return none
	}
	transfer_typ := autofree_collect_canonical_decl_transfer_type(lhs_typ, fresh.typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(rhs_typ, transfer_typ) or { return none }
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action == .move || action == .clone_value {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		...autofree_collect_endpoint(flat, fresh.endpoint.root_node_id, fresh.endpoint.root_pos_id,
			rhs_id, rhs_name, transfer_typ, shape, .local, 'global store source')
		state: .owned_unique
	}
	to_endpoint := AutofreeTransferEndpoint{
		...autofree_collect_endpoint(flat, lhs_id, lhs_pos_id, lhs_id, lhs_name, transfer_typ,
			shape, .global, 'global store target')
		state: .owned_unique
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .global_set
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     rhs_name
		to_name:       lhs_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       stmt_id
		pos_id:        stmt_node.pos.id
		reason:        'direct global store'
	}
}

fn (mut e Environment) collect_autofree_field_store_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_field_store_transfer_from_fn(flat, module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_field_store_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 2 {
		return
	}
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	fresh_stmt_id := flat.edges[body_node.first_edge].child_id
	store_stmt_id := flat.edges[body_node.first_edge + 1].child_id
	fresh := e.collect_autofree_fresh_local_from_stmt(flat, fn_key, fn_name, fresh_stmt_id,
		param_names) or { return }
	if !autofree_collect_fresh_local_is_empty_dynamic_array(fresh) {
		return
	}
	transfer := e.collect_autofree_field_store_transfer_from_stmt(flat, fn_key, fn_name,
		store_stmt_id, fresh, param_names, param_bindings_by_name) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_field_store_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, fresh AutofreeFreshLocalFact, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_field_store_assign_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	if stmt_node.pos.id <= 0 {
		return none
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	root_id := flat.edges[flat.nodes[lhs_id].first_edge].child_id
	field_id := flat.edges[flat.nodes[lhs_id].first_edge + 1].child_id
	root_name := flat.string_at(flat.nodes[root_id].name_id)
	field_name := flat.string_at(flat.nodes[field_id].name_id)
	rhs_name := flat.string_at(flat.nodes[rhs_id].name_id)
	if !autofree_collect_name_is_usable(root_name) || !autofree_collect_name_is_usable(field_name)
		|| !autofree_collect_name_is_usable(rhs_name) || root_name !in param_names
		|| rhs_name != fresh.name || root_name == fresh.name || field_name == fresh.name {
		return none
	}
	root_binding := param_bindings[root_name] or { return none }
	if root_binding.storage != .parameter || !type_has_valid_payload(root_binding.typ) {
		return none
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	root_pos_id := flat.nodes[root_id].pos.id
	field_pos_id := flat.nodes[field_id].pos.id
	rhs_pos_id := flat.nodes[rhs_id].pos.id
	if lhs_pos_id <= 0 || root_pos_id <= 0 || field_pos_id <= 0 || rhs_pos_id <= 0 {
		return none
	}
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return none }
	root_typ := e.get_expr_type(root_pos_id) or { return none }
	rhs_typ := e.get_expr_type(rhs_pos_id) or { return none }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(root_typ)
		|| !type_has_valid_payload(rhs_typ) || !type_has_valid_payload(fresh.typ) {
		return none
	}
	if !same_type_name(root_typ, root_binding.typ) {
		return none
	}
	transfer_typ := autofree_collect_canonical_decl_transfer_type(lhs_typ, fresh.typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(rhs_typ, transfer_typ) or { return none }
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action == .move || action == .clone_value {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		...autofree_collect_endpoint(flat, fresh.endpoint.root_node_id, fresh.endpoint.root_pos_id,
			rhs_id, rhs_name, transfer_typ, shape, .local, 'field store source')
		state: .owned_unique
	}
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .struct_field
		root_storage: .parameter
		root_name:    root_name
		name:         field_name
		root_node_id: root_id
		root_pos_id:  root_pos_id
		node_id:      lhs_id
		pos_id:       lhs_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage: .struct_field
				name:    field_name
				node_id: field_id
				pos_id:  field_pos_id
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .owned_unique
		reason:       'field store target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .field_set
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     rhs_name
		to_name:       field_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       stmt_id
		pos_id:        stmt_node.pos.id
		reason:        'direct field store'
	}
}

fn (mut e Environment) collect_autofree_map_value_store_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_map_value_store_transfer_from_fn(flat, module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_map_value_store_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 2 {
		return
	}
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	fresh_stmt_id := flat.edges[body_node.first_edge].child_id
	store_stmt_id := flat.edges[body_node.first_edge + 1].child_id
	fresh := e.collect_autofree_fresh_local_from_stmt(flat, fn_key, fn_name, fresh_stmt_id,
		param_names) or { return }
	if !autofree_collect_fresh_local_is_empty_dynamic_array(fresh) {
		return
	}
	transfer := e.collect_autofree_map_value_store_transfer_from_stmt(flat, fn_key, fn_name,
		store_stmt_id, fresh, param_names, param_bindings_by_name) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_map_value_store_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, fresh AutofreeFreshLocalFact, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_map_value_store_assign_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	if stmt_node.pos.id <= 0 {
		return none
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	root_id := flat.edges[flat.nodes[lhs_id].first_edge].child_id
	key_id := flat.edges[flat.nodes[lhs_id].first_edge + 1].child_id
	root_name := flat.string_at(flat.nodes[root_id].name_id)
	key_name := flat.string_at(flat.nodes[key_id].name_id)
	rhs_name := flat.string_at(flat.nodes[rhs_id].name_id)
	if !autofree_collect_name_is_usable(root_name) || key_name.len == 0
		|| !autofree_collect_name_is_usable(rhs_name) || root_name !in param_names
		|| rhs_name != fresh.name || root_name == fresh.name {
		return none
	}
	root_binding := param_bindings[root_name] or { return none }
	if root_binding.storage != .parameter || !type_has_valid_payload(root_binding.typ) {
		return none
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	root_pos_id := flat.nodes[root_id].pos.id
	key_pos_id := flat.nodes[key_id].pos.id
	rhs_pos_id := flat.nodes[rhs_id].pos.id
	if lhs_pos_id <= 0 || root_pos_id <= 0 || key_pos_id <= 0 || rhs_pos_id <= 0 {
		return none
	}
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return none }
	root_typ := e.get_expr_type(root_pos_id) or { return none }
	key_typ := e.get_expr_type(key_pos_id) or { return none }
	rhs_typ := e.get_expr_type(rhs_pos_id) or { return none }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(root_typ)
		|| !type_has_valid_payload(key_typ) || !type_has_valid_payload(rhs_typ)
		|| !type_has_valid_payload(fresh.typ) {
		return none
	}
	if !same_type_name(root_typ, root_binding.typ) {
		return none
	}
	map_key_typ := match root_typ {
		Map {
			root_typ.key_type
		}
		else {
			return none
		}
	}

	map_value_typ := match root_typ {
		Map {
			root_typ.value_type
		}
		else {
			return none
		}
	}

	key_shape := e.autofree_resource_shape(key_typ)
	if key_shape.fail_closed || key_shape.kind != .no_resource
		|| !autofree_collect_map_value_store_key_type_matches(map_key_typ, key_typ) {
		return none
	}
	transfer_typ := autofree_collect_canonical_decl_transfer_type(lhs_typ, fresh.typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(rhs_typ, transfer_typ) or { return none }
	_ = autofree_collect_canonical_decl_transfer_type(map_value_typ, transfer_typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action == .move || action == .clone_value {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		...autofree_collect_endpoint(flat, fresh.endpoint.root_node_id, fresh.endpoint.root_pos_id,
			rhs_id, rhs_name, transfer_typ, shape, .local, 'map value store source')
		state: .owned_unique
	}
	to_name := '${root_name}[${key_name}]'
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .map_value
		root_storage: .parameter
		root_name:    root_name
		name:         to_name
		root_node_id: root_id
		root_pos_id:  root_pos_id
		node_id:      lhs_id
		pos_id:       lhs_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage:       .map_value
				name:          key_name
				node_id:       lhs_id
				pos_id:        lhs_pos_id
				index_node_id: key_id
				index_pos_id:  key_pos_id
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .owned_unique
		reason:       'map value store target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .map_set
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     rhs_name
		to_name:       to_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       stmt_id
		pos_id:        stmt_node.pos.id
		reason:        'direct map value store'
	}
}

fn (mut e Environment) collect_autofree_array_element_store_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_array_element_store_transfer_from_fn(flat, module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_array_element_store_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 2 {
		return
	}
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	fresh_stmt_id := flat.edges[body_node.first_edge].child_id
	store_stmt_id := flat.edges[body_node.first_edge + 1].child_id
	fresh := e.collect_autofree_fresh_local_from_stmt(flat, fn_key, fn_name, fresh_stmt_id,
		param_names) or { return }
	if !autofree_collect_fresh_local_is_empty_dynamic_array(fresh) {
		return
	}
	transfer := e.collect_autofree_array_element_store_transfer_from_stmt(flat, fn_key, fn_name,
		store_stmt_id, fresh, param_names, param_bindings_by_name) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_array_element_store_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, fresh AutofreeFreshLocalFact, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_array_element_store_assign_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	if stmt_node.pos.id <= 0 {
		return none
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	root_id := flat.edges[flat.nodes[lhs_id].first_edge].child_id
	index_id := flat.edges[flat.nodes[lhs_id].first_edge + 1].child_id
	root_name := flat.string_at(flat.nodes[root_id].name_id)
	index_name := flat.string_at(flat.nodes[index_id].name_id)
	rhs_name := flat.string_at(flat.nodes[rhs_id].name_id)
	if !autofree_collect_name_is_usable(root_name) || index_name.len == 0
		|| !autofree_collect_name_is_usable(rhs_name) || root_name !in param_names
		|| rhs_name != fresh.name || root_name == fresh.name {
		return none
	}
	root_binding := param_bindings[root_name] or { return none }
	if root_binding.storage != .parameter || !type_has_valid_payload(root_binding.typ) {
		return none
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	root_pos_id := flat.nodes[root_id].pos.id
	index_pos_id := flat.nodes[index_id].pos.id
	rhs_pos_id := flat.nodes[rhs_id].pos.id
	if lhs_pos_id <= 0 || root_pos_id <= 0 || index_pos_id <= 0 || rhs_pos_id <= 0 {
		return none
	}
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return none }
	root_typ := e.get_expr_type(root_pos_id) or { return none }
	index_typ := e.get_expr_type(index_pos_id) or { return none }
	rhs_typ := e.get_expr_type(rhs_pos_id) or { return none }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(root_typ)
		|| !type_has_valid_payload(index_typ) || !type_has_valid_payload(rhs_typ)
		|| !type_has_valid_payload(fresh.typ) {
		return none
	}
	if !same_type_name(root_typ, root_binding.typ) {
		return none
	}
	array_elem_typ := match root_typ {
		Array {
			root_typ.elem_type
		}
		else {
			return none
		}
	}

	index_shape := e.autofree_resource_shape(index_typ)
	if index_shape.fail_closed || index_shape.kind != .no_resource
		|| !autofree_collect_array_element_store_index_type_matches(index_typ) {
		return none
	}
	transfer_typ := autofree_collect_canonical_decl_transfer_type(lhs_typ, fresh.typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(rhs_typ, transfer_typ) or { return none }
	_ = autofree_collect_canonical_decl_transfer_type(array_elem_typ, transfer_typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action == .move || action == .clone_value {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		...autofree_collect_endpoint(flat, fresh.endpoint.root_node_id, fresh.endpoint.root_pos_id,
			rhs_id, rhs_name, transfer_typ, shape, .local, 'array element store source')
		state: .owned_unique
	}
	to_name := '${root_name}[${index_name}]'
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .array_element
		root_storage: .parameter
		root_name:    root_name
		name:         to_name
		root_node_id: root_id
		root_pos_id:  root_pos_id
		node_id:      lhs_id
		pos_id:       lhs_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage:       .array_element
				name:          index_name
				node_id:       lhs_id
				pos_id:        lhs_pos_id
				index_node_id: index_id
				index_pos_id:  index_pos_id
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .owned_unique
		reason:       'array element store target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .assign
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     rhs_name
		to_name:       to_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       stmt_id
		pos_id:        stmt_node.pos.id
		reason:        'direct array element store'
	}
}

fn (mut e Environment) collect_autofree_array_push_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_array_push_transfer_from_fn(flat, module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_array_push_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 2 {
		return
	}
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	fresh_stmt_id := flat.edges[body_node.first_edge].child_id
	push_stmt_id := flat.edges[body_node.first_edge + 1].child_id
	fresh := e.collect_autofree_fresh_local_from_stmt(flat, fn_key, fn_name, fresh_stmt_id,
		param_names) or { return }
	if !autofree_collect_fresh_local_is_empty_dynamic_array(fresh) {
		return
	}
	transfer := e.collect_autofree_array_push_transfer_from_stmt(flat, fn_key, fn_name,
		push_stmt_id, fresh, param_names, param_bindings_by_name) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_array_push_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, fresh AutofreeFreshLocalFact, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_array_push_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	push_id := flat.edges[stmt_node.first_edge].child_id
	push_node := flat.nodes[push_id]
	push_pos_id := push_node.pos.id
	if push_pos_id <= 0 {
		return none
	}
	root_id := flat.edges[push_node.first_edge].child_id
	rhs_id := flat.edges[push_node.first_edge + 1].child_id
	root_name := flat.string_at(flat.nodes[root_id].name_id)
	rhs_name := flat.string_at(flat.nodes[rhs_id].name_id)
	if !autofree_collect_name_is_usable(root_name) || !autofree_collect_name_is_usable(rhs_name)
		|| root_name !in param_names || rhs_name != fresh.name || root_name == fresh.name {
		return none
	}
	root_binding := param_bindings[root_name] or { return none }
	if root_binding.storage != .parameter || !type_has_valid_payload(root_binding.typ) {
		return none
	}
	root_pos_id := flat.nodes[root_id].pos.id
	rhs_pos_id := flat.nodes[rhs_id].pos.id
	if root_pos_id <= 0 || rhs_pos_id <= 0 {
		return none
	}
	root_typ := e.get_expr_type(root_pos_id) or { return none }
	rhs_typ := e.get_expr_type(rhs_pos_id) or { return none }
	if !type_has_valid_payload(root_typ) || !type_has_valid_payload(rhs_typ)
		|| !type_has_valid_payload(fresh.typ) {
		return none
	}
	if !same_type_name(root_typ, root_binding.typ) {
		return none
	}
	array_elem_typ := match root_typ {
		Array {
			root_typ.elem_type
		}
		else {
			return none
		}
	}

	transfer_typ := autofree_collect_canonical_decl_transfer_type(rhs_typ, fresh.typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(array_elem_typ, transfer_typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action == .move || action == .clone_value {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		...autofree_collect_endpoint(flat, fresh.endpoint.root_node_id, fresh.endpoint.root_pos_id,
			rhs_id, rhs_name, transfer_typ, shape, .local, 'array push source')
		state: .owned_unique
	}
	to_name := '${root_name}[]'
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .array_element
		root_storage: .parameter
		root_name:    root_name
		name:         to_name
		root_node_id: root_id
		root_pos_id:  root_pos_id
		node_id:      push_id
		pos_id:       push_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage:       .array_element
				name:          '[]'
				node_id:       push_id
				pos_id:        push_pos_id
				index_node_id: ast.invalid_flat_node_id
				index_pos_id:  0
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .owned_unique
		reason:       'array push target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .array_push
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     rhs_name
		to_name:       to_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       push_id
		pos_id:        push_pos_id
		reason:        'direct array push'
	}
}

fn (mut e Environment) collect_autofree_field_array_push_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_field_array_push_transfer_from_fn(flat, module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_field_array_push_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 2 {
		return
	}
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	fresh_stmt_id := flat.edges[body_node.first_edge].child_id
	push_stmt_id := flat.edges[body_node.first_edge + 1].child_id
	fresh := e.collect_autofree_fresh_local_from_stmt(flat, fn_key, fn_name, fresh_stmt_id,
		param_names) or { return }
	if !autofree_collect_fresh_local_is_empty_dynamic_array(fresh) {
		return
	}
	transfer := e.collect_autofree_field_array_push_transfer_from_stmt(flat, fn_key, fn_name,
		push_stmt_id, fresh, param_names, param_bindings_by_name) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_field_array_push_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, fresh AutofreeFreshLocalFact, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_field_array_push_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	push_id := flat.edges[stmt_node.first_edge].child_id
	push_node := flat.nodes[push_id]
	push_pos_id := push_node.pos.id
	if push_pos_id <= 0 {
		return none
	}
	lhs_id := flat.edges[push_node.first_edge].child_id
	rhs_id := flat.edges[push_node.first_edge + 1].child_id
	root_id := flat.edges[flat.nodes[lhs_id].first_edge].child_id
	field_id := flat.edges[flat.nodes[lhs_id].first_edge + 1].child_id
	root_name := flat.string_at(flat.nodes[root_id].name_id)
	field_name := flat.string_at(flat.nodes[field_id].name_id)
	rhs_name := flat.string_at(flat.nodes[rhs_id].name_id)
	if !autofree_collect_name_is_usable(root_name) || !autofree_collect_name_is_usable(field_name)
		|| !autofree_collect_name_is_usable(rhs_name) || root_name !in param_names
		|| rhs_name != fresh.name || root_name == fresh.name || field_name == fresh.name {
		return none
	}
	root_binding := param_bindings[root_name] or { return none }
	if root_binding.storage != .parameter || !type_has_valid_payload(root_binding.typ) {
		return none
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	root_pos_id := flat.nodes[root_id].pos.id
	field_pos_id := flat.nodes[field_id].pos.id
	rhs_pos_id := flat.nodes[rhs_id].pos.id
	if lhs_pos_id <= 0 || root_pos_id <= 0 || field_pos_id <= 0 || rhs_pos_id <= 0 {
		return none
	}
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return none }
	root_typ := e.get_expr_type(root_pos_id) or { return none }
	rhs_typ := e.get_expr_type(rhs_pos_id) or { return none }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(root_typ)
		|| !type_has_valid_payload(rhs_typ) || !type_has_valid_payload(fresh.typ) {
		return none
	}
	if !same_type_name(root_typ, root_binding.typ) {
		return none
	}
	array_elem_typ := match lhs_typ {
		Array {
			lhs_typ.elem_type
		}
		else {
			return none
		}
	}

	transfer_typ := autofree_collect_canonical_decl_transfer_type(rhs_typ, fresh.typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(array_elem_typ, transfer_typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action == .move || action == .clone_value {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		...autofree_collect_endpoint(flat, fresh.endpoint.root_node_id, fresh.endpoint.root_pos_id,
			rhs_id, rhs_name, transfer_typ, shape, .local, 'field array push source')
		state: .owned_unique
	}
	to_name := '${root_name}.${field_name}[]'
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .array_element
		root_storage: .parameter
		root_name:    root_name
		name:         to_name
		root_node_id: root_id
		root_pos_id:  root_pos_id
		node_id:      push_id
		pos_id:       push_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage: .struct_field
				name:    field_name
				node_id: field_id
				pos_id:  field_pos_id
			},
			AutofreeEndpointPathSegment{
				storage:       .array_element
				name:          '[]'
				node_id:       push_id
				pos_id:        push_pos_id
				index_node_id: ast.invalid_flat_node_id
				index_pos_id:  0
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .owned_unique
		reason:       'field array push target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .array_push
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     rhs_name
		to_name:       to_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       push_id
		pos_id:        push_pos_id
		reason:        'direct field array push'
	}
}

fn (mut e Environment) collect_autofree_parameter_array_push_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_parameter_array_push_transfer_from_fn(flat, module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_parameter_array_push_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len < 2 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 1 {
		return
	}
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len < 2 {
		return
	}
	body_node := flat.nodes[body_id]
	push_stmt_id := flat.edges[body_node.first_edge].child_id
	transfer := e.collect_autofree_parameter_array_push_transfer_from_stmt(flat, fn_key, fn_name,
		push_stmt_id, param_names, param_bindings_by_name) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_parameter_array_push_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_array_push_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	push_id := flat.edges[stmt_node.first_edge].child_id
	push_node := flat.nodes[push_id]
	push_pos_id := push_node.pos.id
	if push_pos_id <= 0 {
		return none
	}
	root_id := flat.edges[push_node.first_edge].child_id
	rhs_id := flat.edges[push_node.first_edge + 1].child_id
	root_name := flat.string_at(flat.nodes[root_id].name_id)
	rhs_name := flat.string_at(flat.nodes[rhs_id].name_id)
	if !autofree_collect_name_is_usable(root_name) || !autofree_collect_name_is_usable(rhs_name)
		|| root_name !in param_names || rhs_name !in param_names || root_name == rhs_name {
		return none
	}
	root_binding := param_bindings[root_name] or { return none }
	source_binding := param_bindings[rhs_name] or { return none }
	if root_binding.storage != .parameter || source_binding.storage != .parameter
		|| !type_has_valid_payload(root_binding.typ) || !type_has_valid_payload(source_binding.typ) {
		return none
	}
	root_pos_id := flat.nodes[root_id].pos.id
	rhs_pos_id := flat.nodes[rhs_id].pos.id
	if root_pos_id <= 0 || rhs_pos_id <= 0 {
		return none
	}
	root_typ := e.get_expr_type(root_pos_id) or { return none }
	rhs_typ := e.get_expr_type(rhs_pos_id) or { return none }
	if !type_has_valid_payload(root_typ) || !type_has_valid_payload(rhs_typ) {
		return none
	}
	if !same_type_name(root_typ, root_binding.typ) {
		return none
	}
	array_elem_typ := match root_typ {
		Array {
			root_typ.elem_type
		}
		else {
			return none
		}
	}

	transfer_typ := autofree_collect_canonical_decl_transfer_type(rhs_typ, source_binding.typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(array_elem_typ, transfer_typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action == .move || action == .clone_value {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .parameter
		root_storage: .parameter
		root_name:    rhs_name
		name:         rhs_name
		root_node_id: source_binding.node_id
		root_pos_id:  source_binding.pos_id
		node_id:      rhs_id
		pos_id:       rhs_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        source_binding.state
		reason:       'parameter array push source'
	}
	to_name := '${root_name}[]'
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .array_element
		root_storage: .parameter
		root_name:    root_name
		name:         to_name
		root_node_id: root_id
		root_pos_id:  root_pos_id
		node_id:      push_id
		pos_id:       push_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage:       .array_element
				name:          '[]'
				node_id:       push_id
				pos_id:        push_pos_id
				index_node_id: ast.invalid_flat_node_id
				index_pos_id:  0
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .owned_unique
		reason:       'parameter array push target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .array_push
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     rhs_name
		to_name:       to_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       push_id
		pos_id:        push_pos_id
		reason:        'direct parameter array push'
	}
}

fn (mut e Environment) collect_autofree_parameter_field_array_push_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_parameter_field_array_push_transfer_from_fn(flat, module_name,
				stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_parameter_field_array_push_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len < 2 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 1 {
		return
	}
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len < 2 {
		return
	}
	body_node := flat.nodes[body_id]
	push_stmt_id := flat.edges[body_node.first_edge].child_id
	transfer := e.collect_autofree_parameter_field_array_push_transfer_from_stmt(flat, fn_key,
		fn_name, push_stmt_id, param_names, param_bindings_by_name) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_parameter_field_array_push_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_field_array_push_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	push_id := flat.edges[stmt_node.first_edge].child_id
	push_node := flat.nodes[push_id]
	push_pos_id := push_node.pos.id
	if push_pos_id <= 0 {
		return none
	}
	lhs_id := flat.edges[push_node.first_edge].child_id
	rhs_id := flat.edges[push_node.first_edge + 1].child_id
	root_id := flat.edges[flat.nodes[lhs_id].first_edge].child_id
	field_id := flat.edges[flat.nodes[lhs_id].first_edge + 1].child_id
	root_name := flat.string_at(flat.nodes[root_id].name_id)
	field_name := flat.string_at(flat.nodes[field_id].name_id)
	rhs_name := flat.string_at(flat.nodes[rhs_id].name_id)
	if !autofree_collect_name_is_usable(root_name) || !autofree_collect_name_is_usable(field_name)
		|| !autofree_collect_name_is_usable(rhs_name) || root_name !in param_names
		|| rhs_name !in param_names || root_name == rhs_name {
		return none
	}
	root_binding := param_bindings[root_name] or { return none }
	source_binding := param_bindings[rhs_name] or { return none }
	if root_binding.storage != .parameter || source_binding.storage != .parameter
		|| !type_has_valid_payload(root_binding.typ) || !type_has_valid_payload(source_binding.typ) {
		return none
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	root_pos_id := flat.nodes[root_id].pos.id
	field_pos_id := flat.nodes[field_id].pos.id
	rhs_pos_id := flat.nodes[rhs_id].pos.id
	if lhs_pos_id <= 0 || root_pos_id <= 0 || field_pos_id <= 0 || rhs_pos_id <= 0 {
		return none
	}
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return none }
	root_typ := e.get_expr_type(root_pos_id) or { return none }
	rhs_typ := e.get_expr_type(rhs_pos_id) or { return none }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(root_typ)
		|| !type_has_valid_payload(rhs_typ) {
		return none
	}
	if !same_type_name(root_typ, root_binding.typ) {
		return none
	}
	array_elem_typ := match lhs_typ {
		Array {
			lhs_typ.elem_type
		}
		else {
			return none
		}
	}

	transfer_typ := autofree_collect_canonical_decl_transfer_type(rhs_typ, source_binding.typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(array_elem_typ, transfer_typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action == .move || action == .clone_value {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .parameter
		root_storage: .parameter
		root_name:    rhs_name
		name:         rhs_name
		root_node_id: source_binding.node_id
		root_pos_id:  source_binding.pos_id
		node_id:      rhs_id
		pos_id:       rhs_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        source_binding.state
		reason:       'parameter field array push source'
	}
	to_name := '${root_name}.${field_name}[]'
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .array_element
		root_storage: .parameter
		root_name:    root_name
		name:         to_name
		root_node_id: root_id
		root_pos_id:  root_pos_id
		node_id:      push_id
		pos_id:       push_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage: .struct_field
				name:    field_name
				node_id: field_id
				pos_id:  field_pos_id
			},
			AutofreeEndpointPathSegment{
				storage:       .array_element
				name:          '[]'
				node_id:       push_id
				pos_id:        push_pos_id
				index_node_id: ast.invalid_flat_node_id
				index_pos_id:  0
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .owned_unique
		reason:       'parameter field array push target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .array_push
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     rhs_name
		to_name:       to_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       push_id
		pos_id:        push_pos_id
		reason:        'direct parameter field array push'
	}
}

struct AutofreePriorLocalAliasProof {
	alias_name     string
	source_name    string
	alias_endpoint AutofreeTransferEndpoint
	source_binding AutofreeBindingFact
	typ            Type
}

struct AutofreeDirectSumtypeVariantProof {
	typ   Type
	shape AutofreeResourceShape
}

fn (mut e Environment) collect_autofree_prior_local_field_array_push_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_prior_local_field_array_push_transfer_from_fn(flat, module_name,
				stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_prior_local_field_array_push_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len < 2 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 2 {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len < 2 {
		return
	}
	body_node := flat.nodes[body_id]
	alias_stmt_id := flat.edges[body_node.first_edge].child_id
	push_stmt_id := flat.edges[body_node.first_edge + 1].child_id
	alias := e.collect_autofree_prior_local_alias_from_stmt(flat, alias_stmt_id, fn_scope,
		param_names, param_bindings_by_name) or { return }
	transfer := e.collect_autofree_prior_local_field_array_push_transfer_from_stmt(flat, fn_key,
		fn_name, push_stmt_id, alias, param_names, param_bindings_by_name) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_prior_local_alias_from_stmt(flat &ast.FlatAst, stmt_id ast.FlatNodeId, fn_scope &Scope, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact) ?AutofreePriorLocalAliasProof {
	if !autofree_collect_decl_assign_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	if stmt_node.pos.id <= 0 {
		return none
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	lhs_name := flat.string_at(flat.nodes[lhs_id].name_id)
	rhs_name := flat.string_at(flat.nodes[rhs_id].name_id)
	if !autofree_collect_name_is_usable(lhs_name) || !autofree_collect_name_is_usable(rhs_name)
		|| lhs_name in param_names || rhs_name !in param_names || lhs_name == rhs_name {
		return none
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	rhs_pos_id := flat.nodes[rhs_id].pos.id
	if lhs_pos_id <= 0 || rhs_pos_id <= 0 {
		return none
	}
	if obj := fn_scope.lookup_parent(lhs_name, lhs_pos_id) {
		if obj is Global {
			return none
		}
	}
	source_obj := fn_scope.lookup_parent(rhs_name, rhs_pos_id) or { return none }
	if source_obj is Global {
		return none
	}
	source_scope_typ := object_as_type(source_obj) or { return none }
	source_binding := param_bindings[rhs_name] or { return none }
	if source_binding.storage != .parameter || !type_has_valid_payload(source_binding.typ) {
		return none
	}
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return none }
	rhs_typ := e.get_expr_type(rhs_pos_id) or { return none }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(rhs_typ)
		|| !type_has_valid_payload(source_scope_typ) {
		return none
	}
	transfer_typ := autofree_collect_canonical_decl_transfer_type(lhs_typ, rhs_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(transfer_typ, source_binding.typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(source_scope_typ, transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(source_scope_typ, source_binding.typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action == .move || action == .clone_value {
		return none
	}
	alias_endpoint := autofree_collect_endpoint(flat, lhs_id, lhs_pos_id, lhs_id, lhs_name,
		transfer_typ, shape, .local, 'prior local alias')
	return AutofreePriorLocalAliasProof{
		alias_name:     lhs_name
		source_name:    rhs_name
		alias_endpoint: alias_endpoint
		source_binding: source_binding
		typ:            transfer_typ
	}
}

fn (mut e Environment) collect_autofree_prior_local_field_array_push_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, alias AutofreePriorLocalAliasProof, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_field_array_push_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	push_id := flat.edges[stmt_node.first_edge].child_id
	push_node := flat.nodes[push_id]
	push_pos_id := push_node.pos.id
	if push_pos_id <= 0 {
		return none
	}
	lhs_id := flat.edges[push_node.first_edge].child_id
	rhs_id := flat.edges[push_node.first_edge + 1].child_id
	root_id := flat.edges[flat.nodes[lhs_id].first_edge].child_id
	field_id := flat.edges[flat.nodes[lhs_id].first_edge + 1].child_id
	root_name := flat.string_at(flat.nodes[root_id].name_id)
	field_name := flat.string_at(flat.nodes[field_id].name_id)
	rhs_name := flat.string_at(flat.nodes[rhs_id].name_id)
	if !autofree_collect_name_is_usable(root_name) || !autofree_collect_name_is_usable(field_name)
		|| !autofree_collect_name_is_usable(rhs_name) || root_name !in param_names
		|| rhs_name != alias.alias_name || alias.source_name == root_name
		|| root_name == alias.alias_name || field_name == alias.alias_name {
		return none
	}
	root_binding := param_bindings[root_name] or { return none }
	if root_binding.storage != .parameter || !type_has_valid_payload(root_binding.typ) {
		return none
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	root_pos_id := flat.nodes[root_id].pos.id
	field_pos_id := flat.nodes[field_id].pos.id
	rhs_pos_id := flat.nodes[rhs_id].pos.id
	if lhs_pos_id <= 0 || root_pos_id <= 0 || field_pos_id <= 0 || rhs_pos_id <= 0 {
		return none
	}
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return none }
	root_typ := e.get_expr_type(root_pos_id) or { return none }
	rhs_typ := e.get_expr_type(rhs_pos_id) or { return none }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(root_typ)
		|| !type_has_valid_payload(rhs_typ) || !type_has_valid_payload(alias.typ)
		|| !type_has_valid_payload(alias.source_binding.typ) {
		return none
	}
	if !same_type_name(root_typ, root_binding.typ) {
		return none
	}
	array_elem_typ := match lhs_typ {
		Array {
			lhs_typ.elem_type
		}
		else {
			return none
		}
	}

	transfer_typ := autofree_collect_canonical_decl_transfer_type(rhs_typ, alias.typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(transfer_typ, alias.source_binding.typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(array_elem_typ, transfer_typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action == .move || action == .clone_value {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    alias.alias_name
		name:         alias.alias_name
		root_node_id: alias.alias_endpoint.root_node_id
		root_pos_id:  alias.alias_endpoint.root_pos_id
		node_id:      rhs_id
		pos_id:       rhs_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        alias.alias_endpoint.state
		reason:       'prior local field array push source'
	}
	to_name := '${root_name}.${field_name}[]'
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .array_element
		root_storage: .parameter
		root_name:    root_name
		name:         to_name
		root_node_id: root_id
		root_pos_id:  root_pos_id
		node_id:      push_id
		pos_id:       push_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage: .struct_field
				name:    field_name
				node_id: field_id
				pos_id:  field_pos_id
			},
			AutofreeEndpointPathSegment{
				storage:       .array_element
				name:          '[]'
				node_id:       push_id
				pos_id:        push_pos_id
				index_node_id: ast.invalid_flat_node_id
				index_pos_id:  0
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .owned_unique
		reason:       'prior local field array push target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .array_push
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     rhs_name
		to_name:       to_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       push_id
		pos_id:        push_pos_id
		reason:        'prior local field array push'
	}
}

fn (mut e Environment) collect_autofree_prior_local_array_push_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_prior_local_array_push_transfer_from_fn(flat, module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_prior_local_array_push_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len < 2 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 2 {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len < 2 {
		return
	}
	body_node := flat.nodes[body_id]
	alias_stmt_id := flat.edges[body_node.first_edge].child_id
	push_stmt_id := flat.edges[body_node.first_edge + 1].child_id
	alias := e.collect_autofree_prior_local_alias_from_stmt(flat, alias_stmt_id, fn_scope,
		param_names, param_bindings_by_name) or { return }
	transfer := e.collect_autofree_prior_local_array_push_transfer_from_stmt(flat, fn_key, fn_name,
		push_stmt_id, alias, param_bindings_by_name) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_prior_local_array_push_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, alias AutofreePriorLocalAliasProof, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_array_push_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	push_id := flat.edges[stmt_node.first_edge].child_id
	push_node := flat.nodes[push_id]
	push_pos_id := push_node.pos.id
	if push_pos_id <= 0 {
		return none
	}
	root_id := flat.edges[push_node.first_edge].child_id
	rhs_id := flat.edges[push_node.first_edge + 1].child_id
	root_name := flat.string_at(flat.nodes[root_id].name_id)
	rhs_name := flat.string_at(flat.nodes[rhs_id].name_id)
	if !autofree_collect_name_is_usable(root_name) || !autofree_collect_name_is_usable(rhs_name)
		|| rhs_name != alias.alias_name || alias.source_name == root_name
		|| root_name == alias.alias_name || alias.source_name == alias.alias_name {
		return none
	}
	root_binding := param_bindings[root_name] or { return none }
	root_binding_typ := root_binding.typ
	if root_binding.storage != .parameter || !type_has_valid_payload(root_binding_typ) {
		return none
	}
	root_pos_id := flat.nodes[root_id].pos.id
	rhs_pos_id := flat.nodes[rhs_id].pos.id
	if root_pos_id <= 0 || rhs_pos_id <= 0 {
		return none
	}
	root_typ := e.get_expr_type(root_pos_id) or { return none }
	rhs_typ := e.get_expr_type(rhs_pos_id) or { return none }
	if !type_has_valid_payload(root_typ) || !type_has_valid_payload(rhs_typ)
		|| !type_has_valid_payload(alias.typ) || !type_has_valid_payload(alias.source_binding.typ) {
		return none
	}
	if !same_type_name(root_typ, root_binding_typ) {
		return none
	}
	array_elem_typ := match root_typ {
		Array {
			root_typ.elem_type
		}
		else {
			return none
		}
	}

	root_binding_elem_typ := match root_binding_typ {
		Array {
			root_binding_typ.elem_type
		}
		else {
			return none
		}
	}

	transfer_typ := autofree_collect_canonical_decl_transfer_type(rhs_typ, alias.typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(transfer_typ, alias.source_binding.typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(array_elem_typ, transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(root_binding_elem_typ, transfer_typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action == .move || action == .clone_value {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    alias.alias_name
		name:         alias.alias_name
		root_node_id: alias.alias_endpoint.root_node_id
		root_pos_id:  alias.alias_endpoint.root_pos_id
		node_id:      rhs_id
		pos_id:       rhs_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        alias.alias_endpoint.state
		reason:       'prior local array push source'
	}
	to_name := '${root_name}[]'
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .array_element
		root_storage: .parameter
		root_name:    root_name
		name:         to_name
		root_node_id: root_id
		root_pos_id:  root_pos_id
		node_id:      push_id
		pos_id:       push_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage:       .array_element
				name:          '[]'
				node_id:       push_id
				pos_id:        push_pos_id
				index_node_id: ast.invalid_flat_node_id
				index_pos_id:  0
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .owned_unique
		reason:       'prior local array push target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .array_push
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     rhs_name
		to_name:       to_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       push_id
		pos_id:        push_pos_id
		reason:        'prior local array push'
	}
}

fn (mut e Environment) collect_autofree_borrowed_pointer_loop_cursor_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_borrowed_pointer_loop_cursor_transfer_from_fn(flat, module_name,
				stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_borrowed_pointer_loop_cursor_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 1 {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	loop_stmt_id := flat.edges[body_node.first_edge].child_id
	transfer := e.collect_autofree_borrowed_pointer_loop_cursor_transfer_from_stmt(flat, fn_key,
		fn_name, loop_stmt_id, fn_scope, param_names, param_bindings_by_name) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_borrowed_pointer_loop_cursor_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, fn_scope &Scope, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_borrowed_pointer_loop_cursor_schema_is_exact(flat, stmt_id) {
		return none
	}
	for_node := flat.nodes[stmt_id]
	init_id := flat.edges[for_node.first_edge].child_id
	post_id := flat.edges[for_node.first_edge + 2].child_id
	init_node := flat.nodes[init_id]
	post_node := flat.nodes[post_id]
	init_pos_id := init_node.pos.id
	if init_pos_id <= 0 {
		return none
	}
	cursor_init_id := flat.edges[init_node.first_edge].child_id
	source_id := flat.edges[init_node.first_edge + 1].child_id
	post_lhs_id := flat.edges[post_node.first_edge].child_id
	post_selector_id := flat.edges[post_node.first_edge + 1].child_id
	post_root_id := flat.edges[flat.nodes[post_selector_id].first_edge].child_id
	post_field_id := flat.edges[flat.nodes[post_selector_id].first_edge + 1].child_id
	cursor_name := flat.string_at(flat.nodes[cursor_init_id].name_id)
	source_name := flat.string_at(flat.nodes[source_id].name_id)
	post_lhs_name := flat.string_at(flat.nodes[post_lhs_id].name_id)
	post_root_name := flat.string_at(flat.nodes[post_root_id].name_id)
	post_field_name := flat.string_at(flat.nodes[post_field_id].name_id)
	if !autofree_collect_name_is_usable(cursor_name)
		|| !autofree_collect_name_is_usable(source_name)
		|| !autofree_collect_name_is_usable(post_field_name) || cursor_name == source_name
		|| cursor_name in param_names || source_name !in param_names || post_lhs_name != cursor_name
		|| post_root_name != cursor_name {
		return none
	}
	source_binding := param_bindings[source_name] or { return none }
	source_binding_typ := source_binding.typ
	if source_binding.storage != .parameter || !type_has_valid_payload(source_binding_typ) {
		return none
	}
	cursor_init_pos_id := flat.nodes[cursor_init_id].pos.id
	source_pos_id := flat.nodes[source_id].pos.id
	post_lhs_pos_id := flat.nodes[post_lhs_id].pos.id
	post_root_pos_id := flat.nodes[post_root_id].pos.id
	post_selector_pos_id := flat.nodes[post_selector_id].pos.id
	if cursor_init_pos_id <= 0 || source_pos_id <= 0 || post_lhs_pos_id <= 0
		|| post_root_pos_id <= 0 || post_selector_pos_id <= 0 {
		return none
	}
	cursor_obj := fn_scope.lookup_parent(cursor_name, cursor_init_pos_id) or { return none }
	if cursor_obj is Global {
		return none
	}
	cursor_scope_typ := object_as_type(cursor_obj) or { return none }
	cursor_init_typ := e.get_expr_type(cursor_init_pos_id) or { return none }
	source_typ := e.get_expr_type(source_pos_id) or { return none }
	post_lhs_typ := e.get_expr_type(post_lhs_pos_id) or { return none }
	post_root_typ := e.get_expr_type(post_root_pos_id) or { return none }
	post_selector_typ := e.get_expr_type(post_selector_pos_id) or { return none }
	if !type_has_valid_payload(cursor_init_typ) || !type_has_valid_payload(source_typ)
		|| !type_has_valid_payload(post_lhs_typ) || !type_has_valid_payload(post_root_typ)
		|| !type_has_valid_payload(post_selector_typ) || !type_has_valid_payload(cursor_scope_typ) {
		return none
	}
	transfer_typ := autofree_collect_canonical_decl_transfer_type(cursor_init_typ, source_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(transfer_typ, source_binding_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(cursor_scope_typ, transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(post_lhs_typ, transfer_typ) or { return none }
	_ = autofree_collect_canonical_decl_transfer_type(post_root_typ, transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(post_selector_typ, transfer_typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed || shape.kind != .borrowed_pointer {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action == .move || action == .clone_value {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .parameter
		root_storage: .parameter
		root_name:    source_name
		name:         source_name
		root_node_id: source_binding.node_id
		root_pos_id:  source_binding.pos_id
		node_id:      source_id
		pos_id:       source_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        source_binding.state
		reason:       'borrowed pointer loop cursor source'
	}
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    cursor_name
		name:         cursor_name
		root_node_id: cursor_init_id
		root_pos_id:  cursor_init_pos_id
		node_id:      cursor_init_id
		pos_id:       cursor_init_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .borrowed_no_free
		reason:       'borrowed pointer loop cursor target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .decl
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     source_name
		to_name:       cursor_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       init_id
		pos_id:        init_pos_id
		reason:        'borrowed pointer loop cursor'
	}
}

fn (mut e Environment) collect_autofree_borrowed_pointer_field_read_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_borrowed_pointer_field_read_transfer_from_fn(flat, module_name,
				stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_borrowed_pointer_field_read_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 1 {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	stmt_id := flat.edges[body_node.first_edge].child_id
	transfer := e.collect_autofree_borrowed_pointer_field_read_transfer_from_stmt(flat, fn_key,
		fn_name, stmt_id, fn_scope, param_names, param_bindings_by_name) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_borrowed_pointer_field_read_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, fn_scope &Scope, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_borrowed_pointer_field_read_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	if stmt_node.pos.id <= 0 {
		return none
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	selector_id := flat.edges[stmt_node.first_edge + 1].child_id
	root_id := flat.edges[flat.nodes[selector_id].first_edge].child_id
	field_id := flat.edges[flat.nodes[selector_id].first_edge + 1].child_id
	lhs_name := flat.string_at(flat.nodes[lhs_id].name_id)
	root_name := flat.string_at(flat.nodes[root_id].name_id)
	field_name := flat.string_at(flat.nodes[field_id].name_id)
	if !autofree_collect_name_is_usable(lhs_name) || !autofree_collect_name_is_usable(root_name)
		|| !autofree_collect_name_is_usable(field_name) || lhs_name == root_name
		|| lhs_name in param_names || root_name !in param_names {
		return none
	}
	root_binding := param_bindings[root_name] or { return none }
	root_binding_typ := root_binding.typ
	if root_binding.storage != .parameter || !type_has_valid_payload(root_binding_typ) {
		return none
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	root_pos_id := flat.nodes[root_id].pos.id
	field_pos_id := flat.nodes[field_id].pos.id
	selector_pos_id := flat.nodes[selector_id].pos.id
	if lhs_pos_id <= 0 || root_pos_id <= 0 || field_pos_id <= 0 || selector_pos_id <= 0 {
		return none
	}
	lhs_obj := fn_scope.lookup_parent(lhs_name, lhs_pos_id) or { return none }
	if lhs_obj is Global {
		return none
	}
	lhs_scope_typ := object_as_type(lhs_obj) or { return none }
	root_obj := fn_scope.lookup_parent(root_name, root_pos_id) or { return none }
	if root_obj is Global {
		return none
	}
	root_scope_typ := object_as_type(root_obj) or { return none }
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return none }
	root_typ := e.get_expr_type(root_pos_id) or { return none }
	selector_typ := e.get_expr_type(selector_pos_id) or { return none }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(root_typ)
		|| !type_has_valid_payload(selector_typ) || !type_has_valid_payload(lhs_scope_typ)
		|| !type_has_valid_payload(root_scope_typ) {
		return none
	}
	if !same_type_name(root_typ, root_binding_typ)
		|| !same_type_name(root_scope_typ, root_binding_typ) {
		return none
	}
	transfer_typ := autofree_collect_canonical_decl_transfer_type(lhs_typ, selector_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(lhs_scope_typ, transfer_typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed || shape.kind != .borrowed_pointer {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action != .borrow_no_free {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .struct_field
		root_storage: .parameter
		root_name:    root_name
		name:         field_name
		root_node_id: root_id
		root_pos_id:  root_pos_id
		node_id:      selector_id
		pos_id:       selector_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage: .struct_field
				name:    field_name
				node_id: field_id
				pos_id:  field_pos_id
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .borrowed_no_free
		reason:       'borrowed pointer field read source'
	}
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    lhs_name
		name:         lhs_name
		root_node_id: lhs_id
		root_pos_id:  lhs_pos_id
		node_id:      lhs_id
		pos_id:       lhs_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .borrowed_no_free
		reason:       'borrowed pointer field read target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .decl
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     '${root_name}.${field_name}'
		to_name:       lhs_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       stmt_id
		pos_id:        stmt_node.pos.id
		reason:        'borrowed pointer field read'
	}
}

fn (mut e Environment) collect_autofree_borrowed_pointer_field_store_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_borrowed_pointer_field_store_transfer_from_fn(flat, module_name,
				stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_borrowed_pointer_field_store_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 1 {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	stmt_id := flat.edges[body_node.first_edge].child_id
	transfer := e.collect_autofree_borrowed_pointer_field_store_transfer_from_stmt(flat, fn_key,
		fn_name, stmt_id, fn_scope, param_names, param_bindings_by_name) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_borrowed_pointer_field_store_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, fn_scope &Scope, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_borrowed_pointer_field_store_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	if stmt_node.pos.id <= 0 {
		return none
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	root_id := flat.edges[flat.nodes[lhs_id].first_edge].child_id
	field_id := flat.edges[flat.nodes[lhs_id].first_edge + 1].child_id
	root_name := flat.string_at(flat.nodes[root_id].name_id)
	field_name := flat.string_at(flat.nodes[field_id].name_id)
	source_name := flat.string_at(flat.nodes[rhs_id].name_id)
	if !autofree_collect_name_is_usable(root_name) || !autofree_collect_name_is_usable(field_name)
		|| !autofree_collect_name_is_usable(source_name) || root_name == source_name
		|| root_name !in param_names || source_name !in param_names {
		return none
	}
	root_binding := param_bindings[root_name] or { return none }
	source_binding := param_bindings[source_name] or { return none }
	root_binding_typ := root_binding.typ
	source_binding_typ := source_binding.typ
	if root_binding.storage != .parameter || source_binding.storage != .parameter
		|| !type_has_valid_payload(root_binding_typ) || !type_has_valid_payload(source_binding_typ) {
		return none
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	root_pos_id := flat.nodes[root_id].pos.id
	field_pos_id := flat.nodes[field_id].pos.id
	rhs_pos_id := flat.nodes[rhs_id].pos.id
	if lhs_pos_id <= 0 || root_pos_id <= 0 || field_pos_id <= 0 || rhs_pos_id <= 0 {
		return none
	}
	root_obj := fn_scope.lookup_parent(root_name, root_pos_id) or { return none }
	if root_obj is Global {
		return none
	}
	root_scope_typ := object_as_type(root_obj) or { return none }
	source_obj := fn_scope.lookup_parent(source_name, rhs_pos_id) or { return none }
	if source_obj is Global {
		return none
	}
	source_scope_typ := object_as_type(source_obj) or { return none }
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return none }
	root_typ := e.get_expr_type(root_pos_id) or { return none }
	rhs_typ := e.get_expr_type(rhs_pos_id) or { return none }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(root_typ)
		|| !type_has_valid_payload(rhs_typ) || !type_has_valid_payload(root_scope_typ)
		|| !type_has_valid_payload(source_scope_typ) {
		return none
	}
	if !same_type_name(root_typ, root_binding_typ)
		|| !same_type_name(root_scope_typ, root_binding_typ) {
		return none
	}
	transfer_typ := autofree_collect_canonical_decl_transfer_type(lhs_typ, rhs_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(source_binding_typ, transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(source_scope_typ, transfer_typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed || shape.kind != .borrowed_pointer {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action != .borrow_no_free {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .parameter
		root_storage: .parameter
		root_name:    source_name
		name:         source_name
		root_node_id: source_binding.node_id
		root_pos_id:  source_binding.pos_id
		node_id:      rhs_id
		pos_id:       rhs_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .borrowed_no_free
		reason:       'borrowed pointer field store source'
	}
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .struct_field
		root_storage: .parameter
		root_name:    root_name
		name:         field_name
		root_node_id: root_id
		root_pos_id:  root_pos_id
		node_id:      lhs_id
		pos_id:       lhs_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage: .struct_field
				name:    field_name
				node_id: field_id
				pos_id:  field_pos_id
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .borrowed_no_free
		reason:       'borrowed pointer field store target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .field_set
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     source_name
		to_name:       field_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       stmt_id
		pos_id:        stmt_node.pos.id
		reason:        'borrowed pointer field store'
	}
}

fn (mut e Environment) collect_autofree_prior_local_borrowed_pointer_field_store_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_prior_local_borrowed_pointer_field_store_transfer_from_fn(flat,
				module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_prior_local_borrowed_pointer_field_store_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len < 2 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 2 {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len < 2 {
		return
	}
	body_node := flat.nodes[body_id]
	alias_stmt_id := flat.edges[body_node.first_edge].child_id
	store_stmt_id := flat.edges[body_node.first_edge + 1].child_id
	alias := e.collect_autofree_prior_local_alias_from_stmt(flat, alias_stmt_id, fn_scope,
		param_names, param_bindings_by_name) or { return }
	transfer := e.collect_autofree_prior_local_borrowed_pointer_field_store_transfer_from_stmt(flat,
		fn_key, fn_name, store_stmt_id, alias, fn_scope, param_names, param_bindings_by_name) or {
		return
	}
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_prior_local_borrowed_pointer_field_store_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, alias AutofreePriorLocalAliasProof, fn_scope &Scope, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_prior_local_borrowed_pointer_field_store_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	if stmt_node.pos.id <= 0 {
		return none
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	root_id := flat.edges[flat.nodes[lhs_id].first_edge].child_id
	field_id := flat.edges[flat.nodes[lhs_id].first_edge + 1].child_id
	root_name := flat.string_at(flat.nodes[root_id].name_id)
	field_name := flat.string_at(flat.nodes[field_id].name_id)
	rhs_name := flat.string_at(flat.nodes[rhs_id].name_id)
	if !autofree_collect_name_is_usable(root_name) || !autofree_collect_name_is_usable(field_name)
		|| !autofree_collect_name_is_usable(rhs_name) || root_name !in param_names
		|| rhs_name != alias.alias_name || root_name == alias.source_name
		|| root_name == alias.alias_name || alias.source_name == alias.alias_name {
		return none
	}
	root_binding := param_bindings[root_name] or { return none }
	root_binding_typ := root_binding.typ
	if root_binding.storage != .parameter || !type_has_valid_payload(root_binding_typ)
		|| !type_has_valid_payload(alias.typ) || !type_has_valid_payload(alias.source_binding.typ) {
		return none
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	root_pos_id := flat.nodes[root_id].pos.id
	field_pos_id := flat.nodes[field_id].pos.id
	rhs_pos_id := flat.nodes[rhs_id].pos.id
	if lhs_pos_id <= 0 || root_pos_id <= 0 || field_pos_id <= 0 || rhs_pos_id <= 0 {
		return none
	}
	root_obj := fn_scope.lookup_parent(root_name, root_pos_id) or { return none }
	if root_obj is Global {
		return none
	}
	root_scope_typ := object_as_type(root_obj) or { return none }
	rhs_obj := fn_scope.lookup_parent(rhs_name, rhs_pos_id) or { return none }
	if rhs_obj is Global {
		return none
	}
	rhs_scope_typ := object_as_type(rhs_obj) or { return none }
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return none }
	root_typ := e.get_expr_type(root_pos_id) or { return none }
	rhs_typ := e.get_expr_type(rhs_pos_id) or { return none }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(root_typ)
		|| !type_has_valid_payload(rhs_typ) || !type_has_valid_payload(root_scope_typ)
		|| !type_has_valid_payload(rhs_scope_typ) {
		return none
	}
	if !same_type_name(root_typ, root_binding_typ)
		|| !same_type_name(root_scope_typ, root_binding_typ) {
		return none
	}
	transfer_typ := autofree_collect_canonical_decl_transfer_type(lhs_typ, rhs_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(transfer_typ, alias.typ) or { return none }
	_ = autofree_collect_canonical_decl_transfer_type(transfer_typ, alias.source_binding.typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(rhs_scope_typ, transfer_typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed || shape.kind != .borrowed_pointer {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action != .borrow_no_free {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    alias.alias_name
		name:         alias.alias_name
		root_node_id: alias.alias_endpoint.root_node_id
		root_pos_id:  alias.alias_endpoint.root_pos_id
		node_id:      rhs_id
		pos_id:       rhs_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .borrowed_no_free
		reason:       'prior local borrowed pointer field store source'
	}
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .struct_field
		root_storage: .parameter
		root_name:    root_name
		name:         field_name
		root_node_id: root_id
		root_pos_id:  root_pos_id
		node_id:      lhs_id
		pos_id:       lhs_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage: .struct_field
				name:    field_name
				node_id: field_id
				pos_id:  field_pos_id
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .borrowed_no_free
		reason:       'prior local borrowed pointer field store target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .field_set
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     alias.alias_name
		to_name:       field_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       stmt_id
		pos_id:        stmt_node.pos.id
		reason:        'prior local borrowed pointer field store'
	}
}

fn (mut e Environment) collect_autofree_struct_init_borrowed_pointer_field_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_struct_init_borrowed_pointer_field_transfer_from_fn(flat,
				module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_struct_init_borrowed_pointer_field_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 1 {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	stmt_id := flat.edges[body_node.first_edge].child_id
	transfer := e.collect_autofree_struct_init_borrowed_pointer_field_transfer_from_stmt(flat,
		fn_key, fn_name, stmt_id, fn_scope, param_names, param_bindings_by_name) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_struct_init_borrowed_pointer_field_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, fn_scope &Scope, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_struct_init_borrowed_pointer_field_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	if stmt_node.pos.id <= 0 {
		return none
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	init_id := flat.edges[stmt_node.first_edge + 1].child_id
	type_id := flat.edges[flat.nodes[init_id].first_edge].child_id
	field_init_id := flat.edges[flat.nodes[init_id].first_edge + 1].child_id
	source_id := flat.edges[flat.nodes[field_init_id].first_edge].child_id
	if !autofree_collect_node_is_valid(flat, type_id) {
		return none
	}
	lhs_name := flat.string_at(flat.nodes[lhs_id].name_id)
	field_name := flat.string_at(flat.nodes[field_init_id].name_id)
	source_name := flat.string_at(flat.nodes[source_id].name_id)
	if !autofree_collect_name_is_usable(lhs_name) || !autofree_collect_name_is_usable(field_name)
		|| !autofree_collect_name_is_usable(source_name) || lhs_name in param_names
		|| source_name !in param_names || lhs_name == source_name {
		return none
	}
	source_binding := param_bindings[source_name] or { return none }
	source_binding_typ := source_binding.typ
	if source_binding.storage != .parameter || !type_has_valid_payload(source_binding_typ) {
		return none
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	init_pos_id := flat.nodes[init_id].pos.id
	source_pos_id := flat.nodes[source_id].pos.id
	if lhs_pos_id <= 0 || init_pos_id <= 0 || source_pos_id <= 0 {
		return none
	}
	lhs_obj := fn_scope.lookup_parent(lhs_name, lhs_pos_id) or { return none }
	if lhs_obj is Global {
		return none
	}
	lhs_scope_typ := object_as_type(lhs_obj) or { return none }
	source_obj := fn_scope.lookup_parent(source_name, source_pos_id) or { return none }
	if source_obj is Global {
		return none
	}
	source_scope_typ := object_as_type(source_obj) or { return none }
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return none }
	init_typ := e.get_expr_type(init_pos_id) or { return none }
	source_typ := e.get_expr_type(source_pos_id) or { return none }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(init_typ)
		|| !type_has_valid_payload(source_typ) || !type_has_valid_payload(lhs_scope_typ)
		|| !type_has_valid_payload(source_scope_typ) {
		return none
	}
	if !same_type_name(lhs_typ, init_typ) || !same_type_name(lhs_scope_typ, lhs_typ) {
		return none
	}
	field_typ := autofree_collect_direct_struct_field_type(lhs_typ, init_typ, field_name) or {
		return none
	}
	transfer_typ := autofree_collect_canonical_decl_transfer_type(field_typ, source_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(transfer_typ, source_binding_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(transfer_typ, source_scope_typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed || shape.kind != .borrowed_pointer {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action != .borrow_no_free {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .parameter
		root_storage: .parameter
		root_name:    source_name
		name:         source_name
		root_node_id: source_binding.node_id
		root_pos_id:  source_binding.pos_id
		node_id:      source_id
		pos_id:       source_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .borrowed_no_free
		reason:       'struct init borrowed pointer field source'
	}
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .struct_field
		root_storage: .local
		root_name:    lhs_name
		name:         field_name
		root_node_id: lhs_id
		root_pos_id:  lhs_pos_id
		node_id:      init_id
		pos_id:       init_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage: .struct_field
				name:    field_name
				node_id: field_init_id
				pos_id:  0
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .borrowed_no_free
		reason:       'struct init borrowed pointer field target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .struct_init
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     source_name
		to_name:       field_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       stmt_id
		pos_id:        stmt_node.pos.id
		reason:        'struct init borrowed pointer field'
	}
}

fn (mut e Environment) collect_autofree_return_struct_init_borrowed_pointer_field_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_return_struct_init_borrowed_pointer_field_transfer_from_fn(flat,
				module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_return_struct_init_borrowed_pointer_field_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 1 {
		return
	}
	return_type_id := autofree_collect_fn_return_type_id(flat, fn_id)
	if return_type_id == ast.invalid_flat_node_id {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	stmt_id := flat.edges[body_node.first_edge].child_id
	transfer := e.collect_autofree_return_struct_init_borrowed_pointer_field_transfer_from_stmt(flat,
		fn_key, fn_name, stmt_id, return_type_id, fn_scope, param_names, param_bindings_by_name) or {
		return
	}
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_return_struct_init_borrowed_pointer_field_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, return_type_id ast.FlatNodeId, fn_scope &Scope, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_return_struct_init_borrowed_pointer_field_schema_is_exact(flat, stmt_id) {
		return none
	}
	if !autofree_collect_node_is(flat, return_type_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, return_type_id) != 0 {
		return none
	}
	return_type_name := flat.string_at(flat.nodes[return_type_id].name_id)
	if !autofree_collect_name_is_usable(return_type_name) {
		return none
	}
	return_type_pos_id := flat.nodes[return_type_id].pos.id
	if return_type_pos_id <= 0 {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	return_expr_id := flat.edges[stmt_node.first_edge].child_id
	type_id := flat.edges[flat.nodes[return_expr_id].first_edge].child_id
	field_init_id := flat.edges[flat.nodes[return_expr_id].first_edge + 1].child_id
	source_id := flat.edges[flat.nodes[field_init_id].first_edge].child_id
	return_struct_type_name := flat.string_at(flat.nodes[type_id].name_id)
	field_name := flat.string_at(flat.nodes[field_init_id].name_id)
	source_name := flat.string_at(flat.nodes[source_id].name_id)
	if !autofree_collect_name_is_usable(return_struct_type_name)
		|| !autofree_collect_name_is_usable(field_name)
		|| !autofree_collect_name_is_usable(source_name) || source_name !in param_names {
		return none
	}
	source_binding := param_bindings[source_name] or { return none }
	source_binding_typ := source_binding.typ
	if source_binding.storage != .parameter || !type_has_valid_payload(source_binding_typ) {
		return none
	}
	return_expr_pos_id := flat.nodes[return_expr_id].pos.id
	type_pos_id := flat.nodes[type_id].pos.id
	source_pos_id := flat.nodes[source_id].pos.id
	if return_expr_pos_id <= 0 || type_pos_id <= 0 || source_pos_id <= 0 {
		return none
	}
	source_obj := fn_scope.lookup_parent(source_name, source_pos_id) or { return none }
	if source_obj is Global {
		return none
	}
	source_scope_typ := object_as_type(source_obj) or { return none }
	return_typ := e.get_expr_type(return_type_pos_id) or { return none }
	init_typ := e.get_expr_type(return_expr_pos_id) or { return none }
	type_typ := e.get_expr_type(type_pos_id) or { return none }
	source_typ := e.get_expr_type(source_pos_id) or { return none }
	if !type_has_valid_payload(return_typ) || !type_has_valid_payload(init_typ)
		|| !type_has_valid_payload(type_typ) || !type_has_valid_payload(source_typ)
		|| !type_has_valid_payload(source_scope_typ) {
		return none
	}
	return_struct := match return_typ {
		Struct {
			return_typ
		}
		else {
			return none
		}
	}

	if !autofree_collect_name_is_usable(return_struct.name)
		|| return_type_name != return_struct.name || return_struct_type_name != return_struct.name {
		return none
	}
	field_typ := autofree_collect_direct_struct_scope_field_type(return_typ, init_typ, type_typ,
		field_name) or { return none }
	transfer_typ := autofree_collect_canonical_decl_transfer_type(field_typ, source_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(transfer_typ, source_binding_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(transfer_typ, source_scope_typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed || shape.kind != .borrowed_pointer {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action != .borrow_no_free {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .parameter
		root_storage: .parameter
		root_name:    source_name
		name:         source_name
		root_node_id: source_binding.node_id
		root_pos_id:  source_binding.pos_id
		node_id:      source_id
		pos_id:       source_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .borrowed_no_free
		reason:       'return struct init borrowed pointer field source'
	}
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .struct_field
		root_storage: .return_value
		root_name:    'return'
		name:         field_name
		root_node_id: return_expr_id
		root_pos_id:  return_expr_pos_id
		node_id:      return_expr_id
		pos_id:       return_expr_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage: .struct_field
				name:    field_name
				node_id: field_init_id
				pos_id:  0
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .borrowed_no_free
		reason:       'return struct init borrowed pointer field target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .struct_init
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     source_name
		to_name:       field_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       stmt_id
		pos_id:        return_expr_pos_id
		reason:        'return struct init borrowed pointer field'
	}
}

fn (mut e Environment) collect_autofree_prior_local_return_struct_init_borrowed_pointer_field_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_prior_local_return_struct_init_borrowed_pointer_field_transfer_from_fn(flat,
				module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_prior_local_return_struct_init_borrowed_pointer_field_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 2 {
		return
	}
	return_type_id := autofree_collect_fn_return_type_id(flat, fn_id)
	if return_type_id == ast.invalid_flat_node_id {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	alias_stmt_id := flat.edges[body_node.first_edge].child_id
	return_stmt_id := flat.edges[body_node.first_edge + 1].child_id
	alias := e.collect_autofree_prior_local_alias_from_stmt(flat, alias_stmt_id, fn_scope,
		param_names, param_bindings_by_name) or { return }
	transfer := e.collect_autofree_prior_local_return_struct_init_borrowed_pointer_field_transfer_from_stmt(flat,
		fn_key, fn_name, return_stmt_id, return_type_id, alias, fn_scope, param_names) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_prior_local_return_struct_init_borrowed_pointer_field_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, return_type_id ast.FlatNodeId, alias AutofreePriorLocalAliasProof, fn_scope &Scope, param_names map[string]bool) ?AutofreeTransferFact {
	if !autofree_collect_return_struct_init_borrowed_pointer_field_schema_is_exact(flat, stmt_id) {
		return none
	}
	if !autofree_collect_node_is(flat, return_type_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, return_type_id) != 0 {
		return none
	}
	return_type_name := flat.string_at(flat.nodes[return_type_id].name_id)
	if !autofree_collect_name_is_usable(return_type_name) {
		return none
	}
	return_type_pos_id := flat.nodes[return_type_id].pos.id
	if return_type_pos_id <= 0 {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	return_expr_id := flat.edges[stmt_node.first_edge].child_id
	type_id := flat.edges[flat.nodes[return_expr_id].first_edge].child_id
	field_init_id := flat.edges[flat.nodes[return_expr_id].first_edge + 1].child_id
	alias_use_id := flat.edges[flat.nodes[field_init_id].first_edge].child_id
	return_struct_type_name := flat.string_at(flat.nodes[type_id].name_id)
	field_name := flat.string_at(flat.nodes[field_init_id].name_id)
	alias_use_name := flat.string_at(flat.nodes[alias_use_id].name_id)
	if !autofree_collect_name_is_usable(return_struct_type_name)
		|| !autofree_collect_name_is_usable(field_name)
		|| !autofree_collect_name_is_usable(alias_use_name) || alias_use_name != alias.alias_name
		|| alias.source_name == alias.alias_name || alias.alias_name in param_names {
		return none
	}
	return_expr_pos_id := flat.nodes[return_expr_id].pos.id
	type_pos_id := flat.nodes[type_id].pos.id
	alias_use_pos_id := flat.nodes[alias_use_id].pos.id
	if return_expr_pos_id <= 0 || type_pos_id <= 0 || alias_use_pos_id <= 0 {
		return none
	}
	alias_obj := fn_scope.lookup_parent(alias_use_name, alias_use_pos_id) or { return none }
	if alias_obj is Global {
		return none
	}
	alias_scope_typ := object_as_type(alias_obj) or { return none }
	return_typ := e.get_expr_type(return_type_pos_id) or { return none }
	init_typ := e.get_expr_type(return_expr_pos_id) or { return none }
	type_typ := e.get_expr_type(type_pos_id) or { return none }
	alias_use_typ := e.get_expr_type(alias_use_pos_id) or { return none }
	if !type_has_valid_payload(return_typ) || !type_has_valid_payload(init_typ)
		|| !type_has_valid_payload(type_typ) || !type_has_valid_payload(alias_use_typ)
		|| !type_has_valid_payload(alias_scope_typ) || !type_has_valid_payload(alias.typ)
		|| !type_has_valid_payload(alias.source_binding.typ) {
		return none
	}
	return_struct := match return_typ {
		Struct {
			return_typ
		}
		else {
			return none
		}
	}

	if !autofree_collect_name_is_usable(return_struct.name)
		|| return_type_name != return_struct.name || return_struct_type_name != return_struct.name {
		return none
	}
	field_typ := autofree_collect_direct_struct_scope_field_type(return_typ, init_typ, type_typ,
		field_name) or { return none }
	transfer_typ := autofree_collect_canonical_decl_transfer_type(field_typ, alias_use_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(transfer_typ, alias.typ) or { return none }
	_ = autofree_collect_canonical_decl_transfer_type(transfer_typ, alias_scope_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(transfer_typ, alias.source_binding.typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed || shape.kind != .borrowed_pointer {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action != .borrow_no_free {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    alias.alias_name
		name:         alias.alias_name
		root_node_id: alias.alias_endpoint.root_node_id
		root_pos_id:  alias.alias_endpoint.root_pos_id
		node_id:      alias_use_id
		pos_id:       alias_use_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .borrowed_no_free
		reason:       'prior local return struct init borrowed pointer field source'
	}
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .struct_field
		root_storage: .return_value
		root_name:    'return'
		name:         field_name
		root_node_id: return_expr_id
		root_pos_id:  return_expr_pos_id
		node_id:      return_expr_id
		pos_id:       return_expr_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage: .struct_field
				name:    field_name
				node_id: field_init_id
				pos_id:  0
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .borrowed_no_free
		reason:       'prior local return struct init borrowed pointer field target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .struct_init
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     alias.alias_name
		to_name:       field_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       stmt_id
		pos_id:        return_expr_pos_id
		reason:        'prior local return struct init borrowed pointer field'
	}
}

fn (mut e Environment) collect_autofree_direct_sumtype_wrap_payload_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_direct_sumtype_wrap_payload_transfer_from_fn(flat, module_name,
				stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_direct_sumtype_wrap_payload_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 1 {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	stmt_id := flat.edges[body_node.first_edge].child_id
	transfer := e.collect_autofree_direct_sumtype_wrap_payload_transfer_from_stmt(flat, fn_key,
		fn_name, stmt_id, fn_scope, param_names, param_bindings_by_name) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_direct_sumtype_wrap_payload_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, fn_scope &Scope, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_direct_sumtype_wrap_payload_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	if stmt_node.pos.id <= 0 {
		return none
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	wrap_id := flat.edges[stmt_node.first_edge + 1].child_id
	target_id := flat.edges[flat.nodes[wrap_id].first_edge].child_id
	source_id := flat.edges[flat.nodes[wrap_id].first_edge + 1].child_id
	lhs_name := flat.string_at(flat.nodes[lhs_id].name_id)
	target_name := flat.string_at(flat.nodes[target_id].name_id)
	source_name := flat.string_at(flat.nodes[source_id].name_id)
	if !autofree_collect_name_is_usable(lhs_name) || !autofree_collect_name_is_usable(target_name)
		|| !autofree_collect_name_is_usable(source_name) || lhs_name in param_names
		|| source_name !in param_names || lhs_name == source_name {
		return none
	}
	source_binding := param_bindings[source_name] or { return none }
	source_binding_typ := source_binding.typ
	if source_binding.storage != .parameter || !type_has_valid_payload(source_binding_typ) {
		return none
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	wrap_pos_id := flat.nodes[wrap_id].pos.id
	source_pos_id := flat.nodes[source_id].pos.id
	if lhs_pos_id <= 0 || wrap_pos_id <= 0 || source_pos_id <= 0 {
		return none
	}
	lhs_obj := fn_scope.lookup_parent(lhs_name, lhs_pos_id) or { return none }
	if lhs_obj is Global {
		return none
	}
	lhs_scope_typ := object_as_type(lhs_obj) or { return none }
	source_obj := fn_scope.lookup_parent(source_name, source_pos_id) or { return none }
	if source_obj is Global {
		return none
	}
	source_scope_typ := object_as_type(source_obj) or { return none }
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return none }
	wrap_typ := e.get_expr_type(wrap_pos_id) or { return none }
	source_typ := e.get_expr_type(source_pos_id) or { return none }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(wrap_typ)
		|| !type_has_valid_payload(source_typ) || !type_has_valid_payload(lhs_scope_typ)
		|| !type_has_valid_payload(source_scope_typ) {
		return none
	}
	target_sumtype := autofree_collect_direct_sumtype_wrap_target(lhs_typ, wrap_typ, lhs_scope_typ) or {
		return none
	}
	if !autofree_collect_name_is_usable(target_sumtype.name) || target_name != target_sumtype.name {
		return none
	}
	source_transfer_typ := autofree_collect_canonical_decl_transfer_type(source_typ,
		source_binding_typ) or { return none }
	_ = autofree_collect_canonical_decl_transfer_type(source_scope_typ, source_transfer_typ) or {
		return none
	}
	variant := autofree_collect_direct_sumtype_variant_for_source(target_sumtype,
		source_transfer_typ) or { return none }
	transfer_typ := variant.typ
	shape := variant.shape
	action := autofree_collect_transfer_action_from_shape(shape)
	if action != .ambiguous_no_free {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .parameter
		root_storage: .parameter
		root_name:    source_name
		name:         source_name
		root_node_id: source_binding.node_id
		root_pos_id:  source_binding.pos_id
		node_id:      source_id
		pos_id:       source_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .ambiguous_no_free
		reason:       'direct sumtype wrap source'
	}
	variant_name := transfer_typ.name()
	to_name := variant_name
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .sumtype_payload
		root_storage: .local
		root_name:    lhs_name
		name:         variant_name
		root_node_id: lhs_id
		root_pos_id:  lhs_pos_id
		node_id:      wrap_id
		pos_id:       wrap_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage: .sumtype_payload
				name:    variant_name
				node_id: source_id
				pos_id:  source_pos_id
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .ambiguous_no_free
		reason:       'direct sumtype wrap target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .sumtype_wrap
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     source_name
		to_name:       to_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       stmt_id
		pos_id:        stmt_node.pos.id
		reason:        'direct sumtype wrap'
	}
}

fn (mut e Environment) collect_autofree_prior_local_sumtype_wrap_payload_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_prior_local_sumtype_wrap_payload_transfer_from_fn(flat, module_name,
				stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_prior_local_sumtype_wrap_payload_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 2 {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	alias_stmt_id := flat.edges[body_node.first_edge].child_id
	wrap_stmt_id := flat.edges[body_node.first_edge + 1].child_id
	alias := e.collect_autofree_prior_local_alias_from_stmt(flat, alias_stmt_id, fn_scope,
		param_names, param_bindings_by_name) or { return }
	transfer := e.collect_autofree_prior_local_sumtype_wrap_payload_transfer_from_stmt(flat,
		fn_key, fn_name, wrap_stmt_id, alias, fn_scope, param_names) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_prior_local_sumtype_wrap_payload_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, alias AutofreePriorLocalAliasProof, fn_scope &Scope, param_names map[string]bool) ?AutofreeTransferFact {
	if !autofree_collect_direct_sumtype_wrap_payload_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	if stmt_node.pos.id <= 0 {
		return none
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	wrap_id := flat.edges[stmt_node.first_edge + 1].child_id
	target_id := flat.edges[flat.nodes[wrap_id].first_edge].child_id
	alias_use_id := flat.edges[flat.nodes[wrap_id].first_edge + 1].child_id
	lhs_name := flat.string_at(flat.nodes[lhs_id].name_id)
	target_name := flat.string_at(flat.nodes[target_id].name_id)
	alias_use_name := flat.string_at(flat.nodes[alias_use_id].name_id)
	if !autofree_collect_name_is_usable(lhs_name) || !autofree_collect_name_is_usable(target_name)
		|| !autofree_collect_name_is_usable(alias_use_name) || lhs_name in param_names
		|| alias_use_name != alias.alias_name || lhs_name == alias.source_name
		|| lhs_name == alias.alias_name || alias.source_name == alias.alias_name {
		return none
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	wrap_pos_id := flat.nodes[wrap_id].pos.id
	alias_use_pos_id := flat.nodes[alias_use_id].pos.id
	if lhs_pos_id <= 0 || wrap_pos_id <= 0 || alias_use_pos_id <= 0 {
		return none
	}
	lhs_obj := fn_scope.lookup_parent(lhs_name, lhs_pos_id) or { return none }
	if lhs_obj is Global {
		return none
	}
	lhs_scope_typ := object_as_type(lhs_obj) or { return none }
	alias_obj := fn_scope.lookup_parent(alias_use_name, alias_use_pos_id) or { return none }
	if alias_obj is Global {
		return none
	}
	alias_scope_typ := object_as_type(alias_obj) or { return none }
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return none }
	wrap_typ := e.get_expr_type(wrap_pos_id) or { return none }
	alias_use_typ := e.get_expr_type(alias_use_pos_id) or { return none }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(wrap_typ)
		|| !type_has_valid_payload(alias_use_typ) || !type_has_valid_payload(lhs_scope_typ)
		|| !type_has_valid_payload(alias_scope_typ) || !type_has_valid_payload(alias.typ)
		|| !type_has_valid_payload(alias.source_binding.typ) {
		return none
	}
	target_sumtype := autofree_collect_direct_sumtype_wrap_target(lhs_typ, wrap_typ, lhs_scope_typ) or {
		return none
	}
	if !autofree_collect_name_is_usable(target_sumtype.name) || target_name != target_sumtype.name {
		return none
	}
	source_transfer_typ := autofree_collect_canonical_decl_transfer_type(alias_use_typ, alias.typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(alias_scope_typ, source_transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(source_transfer_typ, alias.source_binding.typ) or {
		return none
	}
	variant := autofree_collect_direct_sumtype_variant_for_source(target_sumtype,
		source_transfer_typ) or { return none }
	transfer_typ := variant.typ
	shape := variant.shape
	action := autofree_collect_transfer_action_from_shape(shape)
	if action != .ambiguous_no_free {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    alias.alias_name
		name:         alias.alias_name
		root_node_id: alias.alias_endpoint.root_node_id
		root_pos_id:  alias.alias_endpoint.root_pos_id
		node_id:      alias_use_id
		pos_id:       alias_use_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .ambiguous_no_free
		reason:       'prior local sumtype wrap source'
	}
	variant_name := transfer_typ.name()
	to_name := variant_name
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .sumtype_payload
		root_storage: .local
		root_name:    lhs_name
		name:         variant_name
		root_node_id: lhs_id
		root_pos_id:  lhs_pos_id
		node_id:      wrap_id
		pos_id:       wrap_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage: .sumtype_payload
				name:    variant_name
				node_id: alias_use_id
				pos_id:  alias_use_pos_id
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .ambiguous_no_free
		reason:       'prior local sumtype wrap target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .sumtype_wrap
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     alias.alias_name
		to_name:       to_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       stmt_id
		pos_id:        stmt_node.pos.id
		reason:        'prior local sumtype wrap'
	}
}

fn (mut e Environment) collect_autofree_struct_init_field_sumtype_wrap_payload_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_struct_init_field_sumtype_wrap_payload_transfer_from_fn(flat,
				module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_struct_init_field_sumtype_wrap_payload_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 1 {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	stmt_id := flat.edges[body_node.first_edge].child_id
	transfer := e.collect_autofree_struct_init_field_sumtype_wrap_payload_transfer_from_stmt(flat,
		fn_key, fn_name, stmt_id, fn_scope, param_names, param_bindings_by_name) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_struct_init_field_sumtype_wrap_payload_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, fn_scope &Scope, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_struct_init_field_sumtype_wrap_payload_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	if stmt_node.pos.id <= 0 {
		return none
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	init_id := flat.edges[stmt_node.first_edge + 1].child_id
	type_id := flat.edges[flat.nodes[init_id].first_edge].child_id
	field_init_id := flat.edges[flat.nodes[init_id].first_edge + 1].child_id
	wrap_id := flat.edges[flat.nodes[field_init_id].first_edge].child_id
	target_id := flat.edges[flat.nodes[wrap_id].first_edge].child_id
	source_id := flat.edges[flat.nodes[wrap_id].first_edge + 1].child_id
	lhs_name := flat.string_at(flat.nodes[lhs_id].name_id)
	struct_type_name := flat.string_at(flat.nodes[type_id].name_id)
	field_name := flat.string_at(flat.nodes[field_init_id].name_id)
	target_name := flat.string_at(flat.nodes[target_id].name_id)
	source_name := flat.string_at(flat.nodes[source_id].name_id)
	if !autofree_collect_name_is_usable(lhs_name)
		|| !autofree_collect_name_is_usable(struct_type_name)
		|| !autofree_collect_name_is_usable(field_name)
		|| !autofree_collect_name_is_usable(target_name)
		|| !autofree_collect_name_is_usable(source_name) || lhs_name in param_names
		|| source_name !in param_names || lhs_name == source_name {
		return none
	}
	source_binding := param_bindings[source_name] or { return none }
	source_binding_typ := source_binding.typ
	if source_binding.storage != .parameter || !type_has_valid_payload(source_binding_typ) {
		return none
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	init_pos_id := flat.nodes[init_id].pos.id
	target_pos_id := flat.nodes[target_id].pos.id
	wrap_pos_id := flat.nodes[wrap_id].pos.id
	source_pos_id := flat.nodes[source_id].pos.id
	if lhs_pos_id <= 0 || init_pos_id <= 0 || target_pos_id <= 0 || wrap_pos_id <= 0
		|| source_pos_id <= 0 {
		return none
	}
	lhs_obj := fn_scope.lookup_parent(lhs_name, lhs_pos_id) or { return none }
	if lhs_obj is Global {
		return none
	}
	lhs_scope_typ := object_as_type(lhs_obj) or { return none }
	source_obj := fn_scope.lookup_parent(source_name, source_pos_id) or { return none }
	if source_obj is Global {
		return none
	}
	source_scope_typ := object_as_type(source_obj) or { return none }
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return none }
	init_typ := e.get_expr_type(init_pos_id) or { return none }
	target_typ := e.get_expr_type(target_pos_id) or { return none }
	wrap_typ := e.get_expr_type(wrap_pos_id) or { return none }
	source_typ := e.get_expr_type(source_pos_id) or { return none }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(init_typ)
		|| !type_has_valid_payload(target_typ) || !type_has_valid_payload(wrap_typ)
		|| !type_has_valid_payload(source_typ) || !type_has_valid_payload(lhs_scope_typ)
		|| !type_has_valid_payload(source_scope_typ) {
		return none
	}
	lhs_struct := match lhs_typ {
		Struct {
			lhs_typ
		}
		else {
			return none
		}
	}

	if !autofree_collect_name_is_usable(lhs_struct.name) || struct_type_name != lhs_struct.name {
		return none
	}
	field_typ := autofree_collect_direct_struct_scope_field_type(lhs_typ, init_typ, lhs_scope_typ,
		field_name) or { return none }
	target_sumtype := autofree_collect_direct_sumtype_wrap_target(field_typ, wrap_typ, target_typ) or {
		return none
	}
	if !autofree_collect_name_is_usable(target_sumtype.name) || target_name != target_sumtype.name {
		return none
	}
	source_transfer_typ := autofree_collect_canonical_decl_transfer_type(source_typ,
		source_binding_typ) or { return none }
	_ = autofree_collect_canonical_decl_transfer_type(source_scope_typ, source_transfer_typ) or {
		return none
	}
	variant := autofree_collect_direct_sumtype_variant_for_source(target_sumtype,
		source_transfer_typ) or { return none }
	transfer_typ := variant.typ
	shape := variant.shape
	action := autofree_collect_transfer_action_from_shape(shape)
	if action != .ambiguous_no_free {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .parameter
		root_storage: .parameter
		root_name:    source_name
		name:         source_name
		root_node_id: source_binding.node_id
		root_pos_id:  source_binding.pos_id
		node_id:      source_id
		pos_id:       source_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .ambiguous_no_free
		reason:       'struct init field sumtype wrap source'
	}
	variant_name := transfer_typ.name()
	to_name := variant_name
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .sumtype_payload
		root_storage: .local
		root_name:    lhs_name
		name:         variant_name
		root_node_id: lhs_id
		root_pos_id:  lhs_pos_id
		node_id:      wrap_id
		pos_id:       wrap_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage: .struct_field
				name:    field_name
				node_id: field_init_id
				pos_id:  0
			},
			AutofreeEndpointPathSegment{
				storage: .sumtype_payload
				name:    variant_name
				node_id: source_id
				pos_id:  source_pos_id
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .ambiguous_no_free
		reason:       'struct init field sumtype wrap target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .sumtype_wrap
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     source_name
		to_name:       to_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       stmt_id
		pos_id:        stmt_node.pos.id
		reason:        'struct init field sumtype wrap'
	}
}

fn (mut e Environment) collect_autofree_local_holder_return_interop_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_local_holder_return_interop_transfer_from_fn(flat, module_name,
				stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_local_holder_return_interop_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 2 {
		return
	}
	return_type_id := autofree_collect_fn_return_type_id(flat, fn_id)
	if return_type_id == ast.invalid_flat_node_id {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	init_stmt_id := flat.edges[body_node.first_edge].child_id
	return_stmt_id := flat.edges[body_node.first_edge + 1].child_id
	wrap_transfer := e.collect_autofree_struct_init_field_sumtype_wrap_payload_transfer_from_stmt(flat,
		fn_key, fn_name, init_stmt_id, fn_scope, param_names, param_bindings_by_name) or { return }
	return_transfer := e.collect_autofree_local_holder_return_interop_transfer_from_stmt(flat,
		fn_key, fn_name, return_stmt_id, return_type_id, wrap_transfer, fn_scope) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << wrap_transfer
	facts << return_transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_local_holder_return_interop_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, return_type_id ast.FlatNodeId, wrap_transfer AutofreeTransferFact, fn_scope &Scope) ?AutofreeTransferFact {
	if wrap_transfer.kind != .sumtype_wrap || wrap_transfer.action != .ambiguous_no_free
		|| wrap_transfer.to_endpoint.storage != .sumtype_payload
		|| wrap_transfer.to_endpoint.root_storage != .local
		|| wrap_transfer.to_endpoint.path.len != 2 || wrap_transfer.to_endpoint.root_name.len == 0 {
		return none
	}
	if !autofree_collect_node_is(flat, stmt_id, .stmt_return)
		|| autofree_collect_exact_edge_count(flat, stmt_id) != 1 {
		return none
	}
	if !autofree_collect_node_is(flat, return_type_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, return_type_id) != 0 {
		return none
	}
	return_type_name := flat.string_at(flat.nodes[return_type_id].name_id)
	holder_name := wrap_transfer.to_endpoint.root_name
	if !autofree_collect_name_is_usable(return_type_name)
		|| !autofree_collect_name_is_usable(holder_name) {
		return none
	}
	return_type_pos_id := flat.nodes[return_type_id].pos.id
	if return_type_pos_id <= 0 {
		return none
	}
	return_id := flat.edges[flat.nodes[stmt_id].first_edge].child_id
	if !autofree_collect_node_is(flat, return_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, return_id) != 0 {
		return none
	}
	return_name := flat.string_at(flat.nodes[return_id].name_id)
	if return_name != holder_name || !autofree_collect_name_is_usable(return_name) {
		return none
	}
	return_pos_id := flat.nodes[return_id].pos.id
	if return_pos_id <= 0 {
		return none
	}
	holder_obj := fn_scope.lookup_parent(return_name, return_pos_id) or { return none }
	if holder_obj is Global {
		return none
	}
	holder_scope_typ := object_as_type(holder_obj) or { return none }
	return_typ := e.get_expr_type(return_type_pos_id) or { return none }
	holder_typ := e.get_expr_type(wrap_transfer.to_endpoint.root_pos_id) or { return none }
	return_use_typ := e.get_expr_type(return_pos_id) or { return none }
	if !type_has_valid_payload(return_typ) || !type_has_valid_payload(holder_typ)
		|| !type_has_valid_payload(holder_scope_typ) || !type_has_valid_payload(return_use_typ) {
		return none
	}
	return_struct := match return_typ {
		Struct {
			return_typ
		}
		else {
			return none
		}
	}

	holder_struct := match holder_typ {
		Struct {
			holder_typ
		}
		else {
			return none
		}
	}

	holder_scope_struct := match holder_scope_typ {
		Struct {
			holder_scope_typ
		}
		else {
			return none
		}
	}

	return_use_struct := match return_use_typ {
		Struct {
			return_use_typ
		}
		else {
			return none
		}
	}

	if !autofree_collect_name_is_usable(return_struct.name)
		|| return_type_name != return_struct.name
		|| !autofree_collect_same_direct_struct_payload(return_struct, holder_struct)
		|| !autofree_collect_same_direct_struct_payload(return_struct, holder_scope_struct)
		|| !autofree_collect_same_direct_struct_payload(return_struct, return_use_struct) {
		return none
	}
	transfer_typ := return_typ
	shape := e.autofree_resource_shape(transfer_typ)
	action := autofree_collect_transfer_action_from_shape(shape)
	if shape.fail_closed || action != .ambiguous_no_free {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    return_name
		name:         return_name
		root_node_id: wrap_transfer.to_endpoint.root_node_id
		root_pos_id:  wrap_transfer.to_endpoint.root_pos_id
		node_id:      return_id
		pos_id:       return_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .ambiguous_no_free
		reason:       'local holder return interop source'
	}
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .return_value
		root_storage: .return_value
		root_name:    return_name
		name:         return_name
		root_node_id: return_id
		root_pos_id:  return_pos_id
		node_id:      return_id
		pos_id:       return_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .ambiguous_no_free
		reason:       'local holder return interop target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .return_expr
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     return_name
		to_name:       return_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       return_id
		pos_id:        return_pos_id
		reason:        'local holder return interop'
	}
}

fn (mut e Environment) collect_autofree_prior_local_holder_return_interop_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_prior_local_holder_return_interop_transfer_from_fn(flat,
				module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_prior_local_holder_return_interop_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 3 {
		return
	}
	return_type_id := autofree_collect_fn_return_type_id(flat, fn_id)
	if return_type_id == ast.invalid_flat_node_id {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	alias_stmt_id := flat.edges[body_node.first_edge].child_id
	init_stmt_id := flat.edges[body_node.first_edge + 1].child_id
	return_stmt_id := flat.edges[body_node.first_edge + 2].child_id
	alias := e.collect_autofree_prior_local_alias_from_stmt(flat, alias_stmt_id, fn_scope,
		param_names, param_bindings_by_name) or { return }
	wrap_transfer := e.collect_autofree_prior_local_struct_init_field_sumtype_wrap_payload_transfer_from_stmt(flat,
		fn_key, fn_name, init_stmt_id, alias, fn_scope, param_names) or { return }
	return_transfer := e.collect_autofree_local_holder_return_interop_transfer_from_stmt(flat,
		fn_key, fn_name, return_stmt_id, return_type_id, wrap_transfer, fn_scope) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << wrap_transfer
	facts << return_transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_prior_local_struct_init_field_sumtype_wrap_payload_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_prior_local_struct_init_field_sumtype_wrap_payload_transfer_from_fn(flat,
				module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_prior_local_struct_init_field_sumtype_wrap_payload_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 2 {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	alias_stmt_id := flat.edges[body_node.first_edge].child_id
	init_stmt_id := flat.edges[body_node.first_edge + 1].child_id
	alias := e.collect_autofree_prior_local_alias_from_stmt(flat, alias_stmt_id, fn_scope,
		param_names, param_bindings_by_name) or { return }
	transfer := e.collect_autofree_prior_local_struct_init_field_sumtype_wrap_payload_transfer_from_stmt(flat,
		fn_key, fn_name, init_stmt_id, alias, fn_scope, param_names) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_prior_local_struct_init_field_sumtype_wrap_payload_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, alias AutofreePriorLocalAliasProof, fn_scope &Scope, param_names map[string]bool) ?AutofreeTransferFact {
	if !autofree_collect_struct_init_field_sumtype_wrap_payload_schema_is_exact(flat, stmt_id) {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	if stmt_node.pos.id <= 0 {
		return none
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	init_id := flat.edges[stmt_node.first_edge + 1].child_id
	type_id := flat.edges[flat.nodes[init_id].first_edge].child_id
	field_init_id := flat.edges[flat.nodes[init_id].first_edge + 1].child_id
	wrap_id := flat.edges[flat.nodes[field_init_id].first_edge].child_id
	target_id := flat.edges[flat.nodes[wrap_id].first_edge].child_id
	alias_use_id := flat.edges[flat.nodes[wrap_id].first_edge + 1].child_id
	lhs_name := flat.string_at(flat.nodes[lhs_id].name_id)
	struct_type_name := flat.string_at(flat.nodes[type_id].name_id)
	field_name := flat.string_at(flat.nodes[field_init_id].name_id)
	target_name := flat.string_at(flat.nodes[target_id].name_id)
	alias_use_name := flat.string_at(flat.nodes[alias_use_id].name_id)
	if !autofree_collect_name_is_usable(lhs_name)
		|| !autofree_collect_name_is_usable(struct_type_name)
		|| !autofree_collect_name_is_usable(field_name)
		|| !autofree_collect_name_is_usable(target_name)
		|| !autofree_collect_name_is_usable(alias_use_name) || lhs_name in param_names
		|| alias_use_name != alias.alias_name || lhs_name == alias.source_name
		|| lhs_name == alias.alias_name || alias.source_name == alias.alias_name {
		return none
	}
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	init_pos_id := flat.nodes[init_id].pos.id
	target_pos_id := flat.nodes[target_id].pos.id
	wrap_pos_id := flat.nodes[wrap_id].pos.id
	alias_use_pos_id := flat.nodes[alias_use_id].pos.id
	if lhs_pos_id <= 0 || init_pos_id <= 0 || target_pos_id <= 0 || wrap_pos_id <= 0
		|| alias_use_pos_id <= 0 {
		return none
	}
	lhs_obj := fn_scope.lookup_parent(lhs_name, lhs_pos_id) or { return none }
	if lhs_obj is Global {
		return none
	}
	lhs_scope_typ := object_as_type(lhs_obj) or { return none }
	alias_obj := fn_scope.lookup_parent(alias_use_name, alias_use_pos_id) or { return none }
	if alias_obj is Global {
		return none
	}
	alias_scope_typ := object_as_type(alias_obj) or { return none }
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return none }
	init_typ := e.get_expr_type(init_pos_id) or { return none }
	target_typ := e.get_expr_type(target_pos_id) or { return none }
	wrap_typ := e.get_expr_type(wrap_pos_id) or { return none }
	alias_use_typ := e.get_expr_type(alias_use_pos_id) or { return none }
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(init_typ)
		|| !type_has_valid_payload(target_typ) || !type_has_valid_payload(wrap_typ)
		|| !type_has_valid_payload(alias_use_typ) || !type_has_valid_payload(lhs_scope_typ)
		|| !type_has_valid_payload(alias_scope_typ) || !type_has_valid_payload(alias.typ)
		|| !type_has_valid_payload(alias.source_binding.typ) {
		return none
	}
	lhs_struct := match lhs_typ {
		Struct {
			lhs_typ
		}
		else {
			return none
		}
	}

	if !autofree_collect_name_is_usable(lhs_struct.name) || struct_type_name != lhs_struct.name {
		return none
	}
	field_typ := autofree_collect_direct_struct_scope_field_type(lhs_typ, init_typ, lhs_scope_typ,
		field_name) or { return none }
	target_sumtype := autofree_collect_direct_sumtype_wrap_target(field_typ, wrap_typ, target_typ) or {
		return none
	}
	if !autofree_collect_name_is_usable(target_sumtype.name) || target_name != target_sumtype.name {
		return none
	}
	source_transfer_typ := autofree_collect_canonical_decl_transfer_type(alias_use_typ, alias.typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(alias_scope_typ, source_transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(source_transfer_typ, alias.source_binding.typ) or {
		return none
	}
	variant := autofree_collect_direct_sumtype_variant_for_source(target_sumtype,
		source_transfer_typ) or { return none }
	transfer_typ := variant.typ
	shape := variant.shape
	action := autofree_collect_transfer_action_from_shape(shape)
	if action != .ambiguous_no_free {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    alias.alias_name
		name:         alias.alias_name
		root_node_id: alias.alias_endpoint.root_node_id
		root_pos_id:  alias.alias_endpoint.root_pos_id
		node_id:      alias_use_id
		pos_id:       alias_use_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .ambiguous_no_free
		reason:       'prior local struct init field sumtype wrap source'
	}
	variant_name := transfer_typ.name()
	to_name := variant_name
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .sumtype_payload
		root_storage: .local
		root_name:    lhs_name
		name:         variant_name
		root_node_id: lhs_id
		root_pos_id:  lhs_pos_id
		node_id:      wrap_id
		pos_id:       wrap_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage: .struct_field
				name:    field_name
				node_id: field_init_id
				pos_id:  0
			},
			AutofreeEndpointPathSegment{
				storage: .sumtype_payload
				name:    variant_name
				node_id: alias_use_id
				pos_id:  alias_use_pos_id
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .ambiguous_no_free
		reason:       'prior local struct init field sumtype wrap target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .sumtype_wrap
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     alias.alias_name
		to_name:       to_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       stmt_id
		pos_id:        stmt_node.pos.id
		reason:        'prior local struct init field sumtype wrap'
	}
}

fn (mut e Environment) collect_autofree_return_struct_init_field_sumtype_wrap_payload_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_return_struct_init_field_sumtype_wrap_payload_transfer_from_fn(flat,
				module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_return_struct_init_field_sumtype_wrap_payload_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 1 {
		return
	}
	return_type_id := autofree_collect_fn_return_type_id(flat, fn_id)
	if return_type_id == ast.invalid_flat_node_id {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	stmt_id := flat.edges[body_node.first_edge].child_id
	transfer := e.collect_autofree_return_struct_init_field_sumtype_wrap_payload_transfer_from_stmt(flat,
		fn_key, fn_name, stmt_id, return_type_id, fn_scope, param_names, param_bindings_by_name) or {
		return
	}
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_return_struct_init_field_sumtype_wrap_payload_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, return_type_id ast.FlatNodeId, fn_scope &Scope, param_names map[string]bool, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_return_struct_init_field_sumtype_wrap_payload_schema_is_exact(flat,
		stmt_id) {
		return none
	}
	if !autofree_collect_node_is(flat, return_type_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, return_type_id) != 0 {
		return none
	}
	return_type_name := flat.string_at(flat.nodes[return_type_id].name_id)
	if !autofree_collect_name_is_usable(return_type_name) {
		return none
	}
	return_type_pos_id := flat.nodes[return_type_id].pos.id
	if return_type_pos_id <= 0 {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	return_expr_id := flat.edges[stmt_node.first_edge].child_id
	type_id := flat.edges[flat.nodes[return_expr_id].first_edge].child_id
	field_init_id := flat.edges[flat.nodes[return_expr_id].first_edge + 1].child_id
	wrap_id := flat.edges[flat.nodes[field_init_id].first_edge].child_id
	target_id := flat.edges[flat.nodes[wrap_id].first_edge].child_id
	source_id := flat.edges[flat.nodes[wrap_id].first_edge + 1].child_id
	return_struct_type_name := flat.string_at(flat.nodes[type_id].name_id)
	field_name := flat.string_at(flat.nodes[field_init_id].name_id)
	target_name := flat.string_at(flat.nodes[target_id].name_id)
	source_name := flat.string_at(flat.nodes[source_id].name_id)
	if !autofree_collect_name_is_usable(return_struct_type_name)
		|| !autofree_collect_name_is_usable(field_name)
		|| !autofree_collect_name_is_usable(target_name)
		|| !autofree_collect_name_is_usable(source_name) || source_name !in param_names {
		return none
	}
	source_binding := param_bindings[source_name] or { return none }
	source_binding_typ := source_binding.typ
	if source_binding.storage != .parameter || !type_has_valid_payload(source_binding_typ) {
		return none
	}
	return_expr_pos_id := flat.nodes[return_expr_id].pos.id
	type_pos_id := flat.nodes[type_id].pos.id
	target_pos_id := flat.nodes[target_id].pos.id
	wrap_pos_id := flat.nodes[wrap_id].pos.id
	source_pos_id := flat.nodes[source_id].pos.id
	if return_expr_pos_id <= 0 || type_pos_id <= 0 || target_pos_id <= 0 || wrap_pos_id <= 0
		|| source_pos_id <= 0 {
		return none
	}
	source_obj := fn_scope.lookup_parent(source_name, source_pos_id) or { return none }
	if source_obj is Global {
		return none
	}
	source_scope_typ := object_as_type(source_obj) or { return none }
	return_typ := e.get_expr_type(return_type_pos_id) or { return none }
	init_typ := e.get_expr_type(return_expr_pos_id) or { return none }
	type_typ := e.get_expr_type(type_pos_id) or { return none }
	target_typ := e.get_expr_type(target_pos_id) or { return none }
	wrap_typ := e.get_expr_type(wrap_pos_id) or { return none }
	source_typ := e.get_expr_type(source_pos_id) or { return none }
	if !type_has_valid_payload(return_typ) || !type_has_valid_payload(init_typ)
		|| !type_has_valid_payload(type_typ) || !type_has_valid_payload(target_typ)
		|| !type_has_valid_payload(wrap_typ) || !type_has_valid_payload(source_typ)
		|| !type_has_valid_payload(source_scope_typ) {
		return none
	}
	return_struct := match return_typ {
		Struct {
			return_typ
		}
		else {
			return none
		}
	}

	if !autofree_collect_name_is_usable(return_struct.name)
		|| return_type_name != return_struct.name || return_struct_type_name != return_struct.name {
		return none
	}
	field_typ := autofree_collect_direct_struct_scope_field_type(return_typ, init_typ, type_typ,
		field_name) or { return none }
	target_sumtype := autofree_collect_direct_sumtype_wrap_target(field_typ, wrap_typ, target_typ) or {
		return none
	}
	if !autofree_collect_name_is_usable(target_sumtype.name) || target_name != target_sumtype.name {
		return none
	}
	source_transfer_typ := autofree_collect_canonical_decl_transfer_type(source_typ,
		source_binding_typ) or { return none }
	_ = autofree_collect_canonical_decl_transfer_type(source_scope_typ, source_transfer_typ) or {
		return none
	}
	variant := autofree_collect_direct_sumtype_variant_for_source(target_sumtype,
		source_transfer_typ) or { return none }
	transfer_typ := variant.typ
	shape := variant.shape
	action := autofree_collect_transfer_action_from_shape(shape)
	if action != .ambiguous_no_free {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .parameter
		root_storage: .parameter
		root_name:    source_name
		name:         source_name
		root_node_id: source_binding.node_id
		root_pos_id:  source_binding.pos_id
		node_id:      source_id
		pos_id:       source_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .ambiguous_no_free
		reason:       'return struct init field sumtype wrap source'
	}
	variant_name := transfer_typ.name()
	to_name := variant_name
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .sumtype_payload
		root_storage: .return_value
		root_name:    'return'
		name:         variant_name
		root_node_id: return_expr_id
		root_pos_id:  return_expr_pos_id
		node_id:      wrap_id
		pos_id:       wrap_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage: .struct_field
				name:    field_name
				node_id: field_init_id
				pos_id:  0
			},
			AutofreeEndpointPathSegment{
				storage: .sumtype_payload
				name:    variant_name
				node_id: source_id
				pos_id:  source_pos_id
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .ambiguous_no_free
		reason:       'return struct init field sumtype wrap target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .sumtype_wrap
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     source_name
		to_name:       to_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       stmt_id
		pos_id:        return_expr_pos_id
		reason:        'return struct init field sumtype wrap'
	}
}

fn (mut e Environment) collect_autofree_prior_local_return_struct_init_field_sumtype_wrap_payload_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_prior_local_return_struct_init_field_sumtype_wrap_payload_transfer_from_fn(flat,
				module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_prior_local_return_struct_init_field_sumtype_wrap_payload_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	param_ids := autofree_collect_fn_param_ids(flat, fn_id)
	param_names := autofree_collect_param_names(flat, param_ids)
	if param_names.len == 0 {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 2 {
		return
	}
	return_type_id := autofree_collect_fn_return_type_id(flat, fn_id)
	if return_type_id == ast.invalid_flat_node_id {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	alias_stmt_id := flat.edges[body_node.first_edge].child_id
	return_stmt_id := flat.edges[body_node.first_edge + 1].child_id
	alias := e.collect_autofree_prior_local_alias_from_stmt(flat, alias_stmt_id, fn_scope,
		param_names, param_bindings_by_name) or { return }
	transfer := e.collect_autofree_prior_local_return_struct_init_field_sumtype_wrap_payload_transfer_from_stmt(flat,
		fn_key, fn_name, return_stmt_id, return_type_id, alias, fn_scope, param_names) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_prior_local_return_struct_init_field_sumtype_wrap_payload_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, return_type_id ast.FlatNodeId, alias AutofreePriorLocalAliasProof, fn_scope &Scope, param_names map[string]bool) ?AutofreeTransferFact {
	if !autofree_collect_return_struct_init_field_sumtype_wrap_payload_schema_is_exact(flat,
		stmt_id) {
		return none
	}
	if !autofree_collect_node_is(flat, return_type_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, return_type_id) != 0 {
		return none
	}
	return_type_name := flat.string_at(flat.nodes[return_type_id].name_id)
	if !autofree_collect_name_is_usable(return_type_name) {
		return none
	}
	return_type_pos_id := flat.nodes[return_type_id].pos.id
	if return_type_pos_id <= 0 {
		return none
	}
	stmt_node := flat.nodes[stmt_id]
	return_expr_id := flat.edges[stmt_node.first_edge].child_id
	type_id := flat.edges[flat.nodes[return_expr_id].first_edge].child_id
	field_init_id := flat.edges[flat.nodes[return_expr_id].first_edge + 1].child_id
	wrap_id := flat.edges[flat.nodes[field_init_id].first_edge].child_id
	target_id := flat.edges[flat.nodes[wrap_id].first_edge].child_id
	alias_use_id := flat.edges[flat.nodes[wrap_id].first_edge + 1].child_id
	return_struct_type_name := flat.string_at(flat.nodes[type_id].name_id)
	field_name := flat.string_at(flat.nodes[field_init_id].name_id)
	target_name := flat.string_at(flat.nodes[target_id].name_id)
	alias_use_name := flat.string_at(flat.nodes[alias_use_id].name_id)
	if !autofree_collect_name_is_usable(return_struct_type_name)
		|| !autofree_collect_name_is_usable(field_name)
		|| !autofree_collect_name_is_usable(target_name)
		|| !autofree_collect_name_is_usable(alias_use_name) || alias_use_name != alias.alias_name
		|| alias.source_name == alias.alias_name || alias.alias_name in param_names {
		return none
	}
	return_expr_pos_id := flat.nodes[return_expr_id].pos.id
	type_pos_id := flat.nodes[type_id].pos.id
	target_pos_id := flat.nodes[target_id].pos.id
	wrap_pos_id := flat.nodes[wrap_id].pos.id
	alias_use_pos_id := flat.nodes[alias_use_id].pos.id
	if return_expr_pos_id <= 0 || type_pos_id <= 0 || target_pos_id <= 0 || wrap_pos_id <= 0
		|| alias_use_pos_id <= 0 {
		return none
	}
	alias_obj := fn_scope.lookup_parent(alias_use_name, alias_use_pos_id) or { return none }
	if alias_obj is Global {
		return none
	}
	alias_scope_typ := object_as_type(alias_obj) or { return none }
	return_typ := e.get_expr_type(return_type_pos_id) or { return none }
	init_typ := e.get_expr_type(return_expr_pos_id) or { return none }
	type_typ := e.get_expr_type(type_pos_id) or { return none }
	target_typ := e.get_expr_type(target_pos_id) or { return none }
	wrap_typ := e.get_expr_type(wrap_pos_id) or { return none }
	alias_use_typ := e.get_expr_type(alias_use_pos_id) or { return none }
	if !type_has_valid_payload(return_typ) || !type_has_valid_payload(init_typ)
		|| !type_has_valid_payload(type_typ) || !type_has_valid_payload(target_typ)
		|| !type_has_valid_payload(wrap_typ) || !type_has_valid_payload(alias_use_typ)
		|| !type_has_valid_payload(alias_scope_typ) || !type_has_valid_payload(alias.typ)
		|| !type_has_valid_payload(alias.source_binding.typ) {
		return none
	}
	return_struct := match return_typ {
		Struct {
			return_typ
		}
		else {
			return none
		}
	}

	if !autofree_collect_name_is_usable(return_struct.name)
		|| return_type_name != return_struct.name || return_struct_type_name != return_struct.name {
		return none
	}
	field_typ := autofree_collect_direct_struct_scope_field_type(return_typ, init_typ, type_typ,
		field_name) or { return none }
	target_sumtype := autofree_collect_direct_sumtype_wrap_target(field_typ, wrap_typ, target_typ) or {
		return none
	}
	if !autofree_collect_name_is_usable(target_sumtype.name) || target_name != target_sumtype.name {
		return none
	}
	source_transfer_typ := autofree_collect_canonical_decl_transfer_type(alias_use_typ, alias.typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(alias_scope_typ, source_transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(source_transfer_typ, alias.source_binding.typ) or {
		return none
	}
	variant := autofree_collect_direct_sumtype_variant_for_source(target_sumtype,
		source_transfer_typ) or { return none }
	transfer_typ := variant.typ
	shape := variant.shape
	action := autofree_collect_transfer_action_from_shape(shape)
	if action != .ambiguous_no_free {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    alias.alias_name
		name:         alias.alias_name
		root_node_id: alias.alias_endpoint.root_node_id
		root_pos_id:  alias.alias_endpoint.root_pos_id
		node_id:      alias_use_id
		pos_id:       alias_use_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .ambiguous_no_free
		reason:       'prior local return struct init field sumtype wrap source'
	}
	variant_name := transfer_typ.name()
	to_name := variant_name
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .sumtype_payload
		root_storage: .return_value
		root_name:    'return'
		name:         variant_name
		root_node_id: return_expr_id
		root_pos_id:  return_expr_pos_id
		node_id:      wrap_id
		pos_id:       wrap_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage: .struct_field
				name:    field_name
				node_id: field_init_id
				pos_id:  0
			},
			AutofreeEndpointPathSegment{
				storage: .sumtype_payload
				name:    variant_name
				node_id: alias_use_id
				pos_id:  alias_use_pos_id
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .ambiguous_no_free
		reason:       'prior local return struct init field sumtype wrap target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .sumtype_wrap
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     alias.alias_name
		to_name:       to_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       stmt_id
		pos_id:        return_expr_pos_id
		reason:        'prior local return struct init field sumtype wrap'
	}
}

fn (mut e Environment) collect_autofree_for_in_field_array_push_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_for_in_field_array_push_transfer_from_fn(flat, module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_for_in_field_array_push_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 1 {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	loop_stmt_id := flat.edges[body_node.first_edge].child_id
	transfer := e.collect_autofree_for_in_field_array_push_transfer_from_stmt(flat, fn_key,
		fn_name, loop_stmt_id, fn_scope, param_bindings_by_name) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_for_in_field_array_push_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, fn_scope &Scope, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_for_in_field_array_push_schema_is_exact(flat, stmt_id) {
		return none
	}
	for_node := flat.nodes[stmt_id]
	for_in_id := flat.edges[for_node.first_edge].child_id
	body_stmt_id := flat.edges[for_node.first_edge + 3].child_id
	for_in_node := flat.nodes[for_in_id]
	iterator_id := flat.edges[for_in_node.first_edge + 1].child_id
	iterable_id := flat.edges[for_in_node.first_edge + 2].child_id
	push_id := flat.edges[flat.nodes[body_stmt_id].first_edge].child_id
	push_node := flat.nodes[push_id]
	lhs_id := flat.edges[push_node.first_edge].child_id
	rhs_id := flat.edges[push_node.first_edge + 1].child_id
	root_id := flat.edges[flat.nodes[lhs_id].first_edge].child_id
	field_id := flat.edges[flat.nodes[lhs_id].first_edge + 1].child_id
	root_name := flat.string_at(flat.nodes[root_id].name_id)
	field_name := flat.string_at(flat.nodes[field_id].name_id)
	iterable_name := flat.string_at(flat.nodes[iterable_id].name_id)
	iterator_name := flat.string_at(flat.nodes[iterator_id].name_id)
	rhs_name := flat.string_at(flat.nodes[rhs_id].name_id)
	if !autofree_collect_name_is_usable(root_name) || !autofree_collect_name_is_usable(field_name)
		|| !autofree_collect_name_is_usable(iterable_name)
		|| !autofree_collect_name_is_usable(iterator_name) || rhs_name != iterator_name {
		return none
	}
	if iterator_name == root_name || iterator_name == iterable_name {
		return none
	}
	root_binding := param_bindings[root_name] or { return none }
	iterable_binding := param_bindings[iterable_name] or { return none }
	root_binding_typ := root_binding.typ
	iterable_binding_typ := iterable_binding.typ
	if root_binding.storage != .parameter || iterable_binding.storage != .parameter
		|| !type_has_valid_payload(root_binding_typ)
		|| !type_has_valid_payload(iterable_binding_typ) {
		return none
	}
	iterator_pos_id := flat.nodes[iterator_id].pos.id
	iterable_pos_id := flat.nodes[iterable_id].pos.id
	lhs_pos_id := flat.nodes[lhs_id].pos.id
	root_pos_id := flat.nodes[root_id].pos.id
	field_pos_id := flat.nodes[field_id].pos.id
	rhs_pos_id := flat.nodes[rhs_id].pos.id
	push_pos_id := push_node.pos.id
	if iterator_pos_id <= 0 || iterable_pos_id <= 0 || lhs_pos_id <= 0 || root_pos_id <= 0
		|| field_pos_id <= 0 || rhs_pos_id <= 0 || push_pos_id <= 0 {
		return none
	}
	root_obj := fn_scope.lookup_parent(root_name, root_pos_id) or { return none }
	if root_obj is Global {
		return none
	}
	root_scope_typ := object_as_type(root_obj) or { return none }
	iterable_obj := fn_scope.lookup_parent(iterable_name, iterable_pos_id) or { return none }
	if iterable_obj is Global {
		return none
	}
	iterable_scope_typ := object_as_type(iterable_obj) or { return none }
	iterator_obj := fn_scope.lookup_parent(iterator_name, iterator_pos_id) or { return none }
	if iterator_obj is Global {
		return none
	}
	iterator_scope_typ := object_as_type(iterator_obj) or { return none }
	iterable_typ := e.get_expr_type(iterable_pos_id) or { return none }
	iterator_typ := e.get_expr_type(iterator_pos_id) or { return none }
	lhs_typ := e.get_expr_type(lhs_pos_id) or { return none }
	root_typ := e.get_expr_type(root_pos_id) or { return none }
	rhs_typ := e.get_expr_type(rhs_pos_id) or { return none }
	if !type_has_valid_payload(iterable_typ) || !type_has_valid_payload(iterator_typ)
		|| !type_has_valid_payload(root_scope_typ) || !type_has_valid_payload(iterable_scope_typ)
		|| !type_has_valid_payload(iterator_scope_typ) || !type_has_valid_payload(lhs_typ)
		|| !type_has_valid_payload(root_typ) || !type_has_valid_payload(rhs_typ) {
		return none
	}
	if !same_type_name(root_typ, root_binding_typ)
		|| !same_type_name(root_scope_typ, root_binding_typ) {
		return none
	}
	iterable_elem_typ := match iterable_typ {
		Array {
			iterable_typ.elem_type
		}
		else {
			return none
		}
	}

	iterable_scope_elem_typ := match iterable_scope_typ {
		Array {
			iterable_scope_typ.elem_type
		}
		else {
			return none
		}
	}

	iterable_binding_elem_typ := match iterable_binding_typ {
		Array {
			iterable_binding_typ.elem_type
		}
		else {
			return none
		}
	}

	dest_elem_typ := match lhs_typ {
		Array {
			lhs_typ.elem_type
		}
		else {
			return none
		}
	}

	transfer_typ := autofree_collect_canonical_decl_transfer_type(iterator_typ, rhs_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(iterator_scope_typ, transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(iterable_elem_typ, transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(iterable_scope_elem_typ, transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(iterable_binding_elem_typ, transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(dest_elem_typ, transfer_typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action == .move || action == .clone_value {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    iterator_name
		name:         iterator_name
		root_node_id: iterator_id
		root_pos_id:  iterator_pos_id
		node_id:      rhs_id
		pos_id:       rhs_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .borrowed_no_free
		reason:       'for-in iterator field array push source'
	}
	to_name := '${root_name}.${field_name}[]'
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .array_element
		root_storage: .parameter
		root_name:    root_name
		name:         to_name
		root_node_id: root_id
		root_pos_id:  root_pos_id
		node_id:      push_id
		pos_id:       push_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage: .struct_field
				name:    field_name
				node_id: field_id
				pos_id:  field_pos_id
			},
			AutofreeEndpointPathSegment{
				storage:       .array_element
				name:          '[]'
				node_id:       push_id
				pos_id:        push_pos_id
				index_node_id: ast.invalid_flat_node_id
				index_pos_id:  0
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .owned_unique
		reason:       'for-in iterator field array push target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .array_push
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     iterator_name
		to_name:       to_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       push_id
		pos_id:        push_pos_id
		reason:        'for-in field array push'
	}
}

fn (mut e Environment) collect_autofree_for_in_array_push_transfers_from_flat(flat &ast.FlatAst) {
	for file in flat.files {
		if !autofree_collect_node_is(flat, file.file_id, .file) {
			continue
		}
		module_name := flat.string_at(file.mod_idx)
		stmts_id := autofree_collect_required_child(flat, file.file_id, 2, .aux_list)
		if stmts_id == ast.invalid_flat_node_id {
			continue
		}
		stmt_count := autofree_collect_exact_edge_count(flat, stmts_id)
		if stmt_count < 0 {
			continue
		}
		stmt_node := flat.nodes[stmts_id]
		for i in 0 .. stmt_count {
			stmt_id := flat.edges[stmt_node.first_edge + i].child_id
			if !autofree_collect_node_is(flat, stmt_id, .stmt_fn_decl) {
				continue
			}
			e.collect_autofree_for_in_array_push_transfer_from_fn(flat, module_name, stmt_id)
		}
	}
}

fn (mut e Environment) collect_autofree_for_in_array_push_transfer_from_fn(flat &ast.FlatAst, module_name string, fn_id ast.FlatNodeId) {
	if !autofree_collect_node_is(flat, fn_id, .stmt_fn_decl) {
		return
	}
	fn_node := flat.nodes[fn_id]
	if (fn_node.flags & ast.flag_is_method) != 0 {
		return
	}
	fn_name := flat.string_at(fn_node.name_id)
	if fn_name.len == 0 || !autofree_collect_fn_schema_is_complete(flat, fn_id) {
		return
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	body_count := autofree_collect_exact_edge_count(flat, body_id)
	if body_count != 1 {
		return
	}
	fn_scope := e.get_fn_scope(module_name, fn_name) or { return }
	fn_key := autofree_fn_key(module_name, fn_name, '')
	param_bindings := e.autofree_bindings_by_fn_key[fn_key] or { return }
	param_bindings_by_name := autofree_collect_parameter_bindings_by_name(param_bindings)
	if param_bindings_by_name.len == 0 {
		return
	}
	body_node := flat.nodes[body_id]
	loop_stmt_id := flat.edges[body_node.first_edge].child_id
	transfer := e.collect_autofree_for_in_array_push_transfer_from_stmt(flat, fn_key, fn_name,
		loop_stmt_id, fn_scope, param_bindings_by_name) or { return }
	mut facts := e.autofree_transfers_by_fn_key[fn_key] or { []AutofreeTransferFact{} }
	facts << transfer
	e.autofree_transfers_by_fn_key[fn_key] = facts
}

fn (mut e Environment) collect_autofree_for_in_array_push_transfer_from_stmt(flat &ast.FlatAst, fn_key string, fn_name string, stmt_id ast.FlatNodeId, fn_scope &Scope, param_bindings map[string]AutofreeBindingFact) ?AutofreeTransferFact {
	if !autofree_collect_for_in_array_push_schema_is_exact(flat, stmt_id) {
		return none
	}
	for_node := flat.nodes[stmt_id]
	for_in_id := flat.edges[for_node.first_edge].child_id
	body_stmt_id := flat.edges[for_node.first_edge + 3].child_id
	for_in_node := flat.nodes[for_in_id]
	iterator_id := flat.edges[for_in_node.first_edge + 1].child_id
	iterable_id := flat.edges[for_in_node.first_edge + 2].child_id
	push_id := flat.edges[flat.nodes[body_stmt_id].first_edge].child_id
	push_node := flat.nodes[push_id]
	root_id := flat.edges[push_node.first_edge].child_id
	rhs_id := flat.edges[push_node.first_edge + 1].child_id
	root_name := flat.string_at(flat.nodes[root_id].name_id)
	iterable_name := flat.string_at(flat.nodes[iterable_id].name_id)
	iterator_name := flat.string_at(flat.nodes[iterator_id].name_id)
	rhs_name := flat.string_at(flat.nodes[rhs_id].name_id)
	if !autofree_collect_name_is_usable(root_name)
		|| !autofree_collect_name_is_usable(iterable_name)
		|| !autofree_collect_name_is_usable(iterator_name) || rhs_name != iterator_name {
		return none
	}
	if root_name == iterable_name || iterator_name == root_name || iterator_name == iterable_name {
		return none
	}
	root_binding := param_bindings[root_name] or { return none }
	iterable_binding := param_bindings[iterable_name] or { return none }
	root_binding_typ := root_binding.typ
	iterable_binding_typ := iterable_binding.typ
	if root_binding.storage != .parameter || iterable_binding.storage != .parameter
		|| !type_has_valid_payload(root_binding_typ)
		|| !type_has_valid_payload(iterable_binding_typ) {
		return none
	}
	iterator_pos_id := flat.nodes[iterator_id].pos.id
	iterable_pos_id := flat.nodes[iterable_id].pos.id
	root_pos_id := flat.nodes[root_id].pos.id
	rhs_pos_id := flat.nodes[rhs_id].pos.id
	push_pos_id := push_node.pos.id
	if iterator_pos_id <= 0 || iterable_pos_id <= 0 || root_pos_id <= 0 || rhs_pos_id <= 0
		|| push_pos_id <= 0 {
		return none
	}
	root_obj := fn_scope.lookup_parent(root_name, root_pos_id) or { return none }
	if root_obj is Global {
		return none
	}
	root_scope_typ := object_as_type(root_obj) or { return none }
	iterable_obj := fn_scope.lookup_parent(iterable_name, iterable_pos_id) or { return none }
	if iterable_obj is Global {
		return none
	}
	iterable_scope_typ := object_as_type(iterable_obj) or { return none }
	iterator_obj := fn_scope.lookup_parent(iterator_name, iterator_pos_id) or { return none }
	if iterator_obj is Global {
		return none
	}
	iterator_scope_typ := object_as_type(iterator_obj) or { return none }
	root_typ := e.get_expr_type(root_pos_id) or { return none }
	iterable_typ := e.get_expr_type(iterable_pos_id) or { return none }
	iterator_typ := e.get_expr_type(iterator_pos_id) or { return none }
	rhs_typ := e.get_expr_type(rhs_pos_id) or { return none }
	if !type_has_valid_payload(root_typ) || !type_has_valid_payload(iterable_typ)
		|| !type_has_valid_payload(iterator_typ) || !type_has_valid_payload(rhs_typ)
		|| !type_has_valid_payload(root_scope_typ) || !type_has_valid_payload(iterable_scope_typ)
		|| !type_has_valid_payload(iterator_scope_typ) {
		return none
	}
	root_elem_typ := match root_typ {
		Array {
			root_typ.elem_type
		}
		else {
			return none
		}
	}

	root_scope_elem_typ := match root_scope_typ {
		Array {
			root_scope_typ.elem_type
		}
		else {
			return none
		}
	}

	root_binding_elem_typ := match root_binding_typ {
		Array {
			root_binding_typ.elem_type
		}
		else {
			return none
		}
	}

	iterable_elem_typ := match iterable_typ {
		Array {
			iterable_typ.elem_type
		}
		else {
			return none
		}
	}

	iterable_scope_elem_typ := match iterable_scope_typ {
		Array {
			iterable_scope_typ.elem_type
		}
		else {
			return none
		}
	}

	iterable_binding_elem_typ := match iterable_binding_typ {
		Array {
			iterable_binding_typ.elem_type
		}
		else {
			return none
		}
	}

	transfer_typ := autofree_collect_canonical_decl_transfer_type(iterator_typ, rhs_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(iterator_scope_typ, transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(iterable_elem_typ, transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(iterable_scope_elem_typ, transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(iterable_binding_elem_typ, transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(root_elem_typ, transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(root_scope_elem_typ, transfer_typ) or {
		return none
	}
	_ = autofree_collect_canonical_decl_transfer_type(root_binding_elem_typ, transfer_typ) or {
		return none
	}
	shape := e.autofree_resource_shape(transfer_typ)
	if shape.fail_closed {
		return none
	}
	action := autofree_collect_transfer_action_from_shape(shape)
	if action == .move || action == .clone_value {
		return none
	}
	from_endpoint := AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    iterator_name
		name:         iterator_name
		root_node_id: iterator_id
		root_pos_id:  iterator_pos_id
		node_id:      rhs_id
		pos_id:       rhs_pos_id
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .borrowed_no_free
		reason:       'for-in iterator array push source'
	}
	to_name := '${root_name}[]'
	to_endpoint := AutofreeTransferEndpoint{
		storage:      .array_element
		root_storage: .parameter
		root_name:    root_name
		name:         to_name
		root_node_id: root_id
		root_pos_id:  root_pos_id
		node_id:      push_id
		pos_id:       push_pos_id
		path:         [
			AutofreeEndpointPathSegment{
				storage:       .array_element
				name:          '[]'
				node_id:       push_id
				pos_id:        push_pos_id
				index_node_id: ast.invalid_flat_node_id
				index_pos_id:  0
			},
		]
		has_type:     true
		typ:          transfer_typ
		type_name:    transfer_typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .owned_unique
		reason:       'for-in iterator array push target'
	}
	return AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       fn_name
		kind:          .array_push
		action:        action
		from_endpoint: from_endpoint
		to_endpoint:   to_endpoint
		from_name:     iterator_name
		to_name:       to_name
		typ:           transfer_typ
		type_name:     transfer_typ.name()
		shape:         shape
		node_id:       push_id
		pos_id:        push_pos_id
		reason:        'for-in array push'
	}
}

fn autofree_collect_record_assignment_lhs_names(flat &ast.FlatAst, stmt_id ast.FlatNodeId, mut local_decls map[string]bool, mut proven_locals map[string]AutofreeTransferEndpoint) {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_assign) {
		proven_locals.clear()
		return
	}
	stmt_node := flat.nodes[stmt_id]
	edge_count := autofree_collect_exact_edge_count(flat, stmt_id)
	lhs_count := stmt_node.extra
	if lhs_count <= 0 || edge_count < lhs_count {
		proven_locals.clear()
		return
	}
	is_decl := unsafe { token.Token(int(stmt_node.aux)) } == .decl_assign
	mut keep_other_proofs := is_decl && lhs_count == 1 && edge_count == 2
	for i in 0 .. lhs_count {
		lhs_id := flat.edges[stmt_node.first_edge + i].child_id
		if !autofree_collect_node_is(flat, lhs_id, .expr_ident)
			|| autofree_collect_exact_edge_count(flat, lhs_id) != 0 {
			keep_other_proofs = false
			continue
		}
		lhs_name := flat.string_at(flat.nodes[lhs_id].name_id)
		if autofree_collect_name_is_usable(lhs_name) {
			if is_decl {
				local_decls[lhs_name] = true
			}
			proven_locals.delete(lhs_name)
		}
	}
	if keep_other_proofs {
		rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
		keep_other_proofs = autofree_collect_node_is(flat, rhs_id, .expr_ident)
			&& autofree_collect_exact_edge_count(flat, rhs_id) == 0
	}
	if !keep_other_proofs {
		proven_locals.clear()
	}
}

fn autofree_collect_param_names(flat &ast.FlatAst, param_ids []ast.FlatNodeId) map[string]bool {
	mut names := map[string]bool{}
	for param_id in param_ids {
		name := flat.string_at(flat.nodes[param_id].name_id)
		if name.len > 0 {
			names[name] = true
		}
	}
	return names
}

fn autofree_collect_param_ids_by_name(flat &ast.FlatAst, param_ids []ast.FlatNodeId) map[string]ast.FlatNodeId {
	mut ids_by_name := map[string]ast.FlatNodeId{}
	for param_id in param_ids {
		name := flat.string_at(flat.nodes[param_id].name_id)
		if name.len > 0 {
			ids_by_name[name] = param_id
		}
	}
	return ids_by_name
}

fn autofree_collect_parameter_bindings_by_name(bindings []AutofreeBindingFact) map[string]AutofreeBindingFact {
	mut by_name := map[string]AutofreeBindingFact{}
	for binding in bindings {
		if binding.storage == .parameter && binding.name.len > 0 {
			by_name[binding.name] = binding
		}
	}
	return by_name
}

fn autofree_collect_decl_assign_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_assign) {
		return false
	}
	stmt_node := flat.nodes[stmt_id]
	if unsafe { token.Token(int(stmt_node.aux)) } != .decl_assign {
		return false
	}
	if stmt_node.extra != 1 || autofree_collect_exact_edge_count(flat, stmt_id) != 2 {
		return false
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	return autofree_collect_node_is(flat, lhs_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, lhs_id) == 0
		&& autofree_collect_node_is(flat, rhs_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, rhs_id) == 0
}

fn autofree_collect_global_store_assign_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_assign) {
		return false
	}
	stmt_node := flat.nodes[stmt_id]
	if unsafe { token.Token(int(stmt_node.aux)) } != .assign {
		return false
	}
	if stmt_node.extra != 1 || autofree_collect_exact_edge_count(flat, stmt_id) != 2 {
		return false
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	return autofree_collect_node_is(flat, lhs_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, lhs_id) == 0
		&& autofree_collect_node_is(flat, rhs_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, rhs_id) == 0
}

fn autofree_collect_field_store_assign_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_assign) {
		return false
	}
	stmt_node := flat.nodes[stmt_id]
	if unsafe { token.Token(int(stmt_node.aux)) } != .assign {
		return false
	}
	if stmt_node.extra != 1 || autofree_collect_exact_edge_count(flat, stmt_id) != 2 {
		return false
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	if !autofree_collect_node_is(flat, lhs_id, .expr_selector)
		|| autofree_collect_exact_edge_count(flat, lhs_id) != 2 {
		return false
	}
	root_id := flat.edges[flat.nodes[lhs_id].first_edge].child_id
	field_id := flat.edges[flat.nodes[lhs_id].first_edge + 1].child_id
	return autofree_collect_node_is(flat, root_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, root_id) == 0
		&& autofree_collect_node_is(flat, field_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, field_id) == 0
		&& autofree_collect_node_is(flat, rhs_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, rhs_id) == 0
}

fn autofree_collect_map_value_store_assign_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_assign) {
		return false
	}
	stmt_node := flat.nodes[stmt_id]
	if unsafe { token.Token(int(stmt_node.aux)) } != .assign {
		return false
	}
	if stmt_node.extra != 1 || autofree_collect_exact_edge_count(flat, stmt_id) != 2 {
		return false
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	if !autofree_collect_node_is(flat, lhs_id, .expr_index)
		|| autofree_collect_exact_edge_count(flat, lhs_id) != 2 {
		return false
	}
	root_id := flat.edges[flat.nodes[lhs_id].first_edge].child_id
	key_id := flat.edges[flat.nodes[lhs_id].first_edge + 1].child_id
	if !autofree_collect_node_is(flat, key_id, .expr_basic_literal)
		|| autofree_collect_exact_edge_count(flat, key_id) != 0
		|| unsafe { token.Token(int(flat.nodes[key_id].aux)) } != .number {
		return false
	}
	return autofree_collect_node_is(flat, root_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, root_id) == 0
		&& autofree_collect_node_is(flat, rhs_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, rhs_id) == 0
}

fn autofree_collect_array_element_store_assign_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_assign) {
		return false
	}
	stmt_node := flat.nodes[stmt_id]
	if unsafe { token.Token(int(stmt_node.aux)) } != .assign {
		return false
	}
	if stmt_node.extra != 1 || autofree_collect_exact_edge_count(flat, stmt_id) != 2 {
		return false
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	if !autofree_collect_node_is(flat, lhs_id, .expr_index)
		|| autofree_collect_exact_edge_count(flat, lhs_id) != 2 {
		return false
	}
	root_id := flat.edges[flat.nodes[lhs_id].first_edge].child_id
	index_id := flat.edges[flat.nodes[lhs_id].first_edge + 1].child_id
	if !autofree_collect_node_is(flat, index_id, .expr_basic_literal)
		|| autofree_collect_exact_edge_count(flat, index_id) != 0
		|| unsafe { token.Token(int(flat.nodes[index_id].aux)) } != .number {
		return false
	}
	return autofree_collect_node_is(flat, root_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, root_id) == 0
		&& autofree_collect_node_is(flat, rhs_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, rhs_id) == 0
}

fn autofree_collect_array_push_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_expr)
		|| autofree_collect_exact_edge_count(flat, stmt_id) != 1 {
		return false
	}
	push_id := flat.edges[flat.nodes[stmt_id].first_edge].child_id
	if !autofree_collect_node_is(flat, push_id, .expr_infix)
		|| autofree_collect_exact_edge_count(flat, push_id) != 2
		|| unsafe { token.Token(int(flat.nodes[push_id].aux)) } != .left_shift {
		return false
	}
	root_id := flat.edges[flat.nodes[push_id].first_edge].child_id
	rhs_id := flat.edges[flat.nodes[push_id].first_edge + 1].child_id
	return autofree_collect_node_is(flat, root_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, root_id) == 0
		&& autofree_collect_node_is(flat, rhs_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, rhs_id) == 0
}

fn autofree_collect_field_array_push_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_expr)
		|| autofree_collect_exact_edge_count(flat, stmt_id) != 1 {
		return false
	}
	push_id := flat.edges[flat.nodes[stmt_id].first_edge].child_id
	if !autofree_collect_node_is(flat, push_id, .expr_infix)
		|| autofree_collect_exact_edge_count(flat, push_id) != 2
		|| unsafe { token.Token(int(flat.nodes[push_id].aux)) } != .left_shift {
		return false
	}
	lhs_id := flat.edges[flat.nodes[push_id].first_edge].child_id
	rhs_id := flat.edges[flat.nodes[push_id].first_edge + 1].child_id
	if !autofree_collect_node_is(flat, lhs_id, .expr_selector)
		|| autofree_collect_exact_edge_count(flat, lhs_id) != 2 {
		return false
	}
	root_id := flat.edges[flat.nodes[lhs_id].first_edge].child_id
	field_id := flat.edges[flat.nodes[lhs_id].first_edge + 1].child_id
	return autofree_collect_node_is(flat, root_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, root_id) == 0
		&& autofree_collect_node_is(flat, field_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, field_id) == 0
		&& autofree_collect_node_is(flat, rhs_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, rhs_id) == 0
}

fn autofree_collect_borrowed_pointer_loop_cursor_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_for)
		|| autofree_collect_exact_edge_count(flat, stmt_id) != 3 {
		return false
	}
	for_node := flat.nodes[stmt_id]
	init_id := flat.edges[for_node.first_edge].child_id
	cond_id := flat.edges[for_node.first_edge + 1].child_id
	post_id := flat.edges[for_node.first_edge + 2].child_id
	if !autofree_collect_decl_assign_schema_is_exact(flat, init_id)
		|| !autofree_collect_node_is(flat, cond_id, .expr_basic_literal)
		|| autofree_collect_exact_edge_count(flat, cond_id) != 0
		|| unsafe { token.Token(int(flat.nodes[cond_id].aux)) } != .key_true
		|| !autofree_collect_node_is(flat, post_id, .stmt_assign) {
		return false
	}
	post_node := flat.nodes[post_id]
	if unsafe { token.Token(int(post_node.aux)) } != .assign || post_node.extra != 1
		|| autofree_collect_exact_edge_count(flat, post_id) != 2 {
		return false
	}
	lhs_id := flat.edges[post_node.first_edge].child_id
	rhs_id := flat.edges[post_node.first_edge + 1].child_id
	if !autofree_collect_node_is(flat, lhs_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, lhs_id) != 0
		|| !autofree_collect_node_is(flat, rhs_id, .expr_selector)
		|| autofree_collect_exact_edge_count(flat, rhs_id) != 2 {
		return false
	}
	root_id := flat.edges[flat.nodes[rhs_id].first_edge].child_id
	field_id := flat.edges[flat.nodes[rhs_id].first_edge + 1].child_id
	return autofree_collect_node_is(flat, root_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, root_id) == 0
		&& autofree_collect_node_is(flat, field_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, field_id) == 0
}

fn autofree_collect_borrowed_pointer_field_read_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_assign) {
		return false
	}
	stmt_node := flat.nodes[stmt_id]
	if unsafe { token.Token(int(stmt_node.aux)) } != .decl_assign || stmt_node.extra != 1
		|| autofree_collect_exact_edge_count(flat, stmt_id) != 2 {
		return false
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	if !autofree_collect_node_is(flat, lhs_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, lhs_id) != 0
		|| !autofree_collect_node_is(flat, rhs_id, .expr_selector)
		|| autofree_collect_exact_edge_count(flat, rhs_id) != 2 {
		return false
	}
	root_id := flat.edges[flat.nodes[rhs_id].first_edge].child_id
	field_id := flat.edges[flat.nodes[rhs_id].first_edge + 1].child_id
	return autofree_collect_node_is(flat, root_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, root_id) == 0
		&& autofree_collect_node_is(flat, field_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, field_id) == 0
}

fn autofree_collect_borrowed_pointer_field_store_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_assign) {
		return false
	}
	stmt_node := flat.nodes[stmt_id]
	if unsafe { token.Token(int(stmt_node.aux)) } != .assign || stmt_node.extra != 1
		|| autofree_collect_exact_edge_count(flat, stmt_id) != 2 {
		return false
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	if !autofree_collect_node_is(flat, lhs_id, .expr_selector)
		|| autofree_collect_exact_edge_count(flat, lhs_id) != 2
		|| !autofree_collect_node_is(flat, rhs_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, rhs_id) != 0 {
		return false
	}
	root_id := flat.edges[flat.nodes[lhs_id].first_edge].child_id
	field_id := flat.edges[flat.nodes[lhs_id].first_edge + 1].child_id
	return autofree_collect_node_is(flat, root_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, root_id) == 0
		&& autofree_collect_node_is(flat, field_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, field_id) == 0
}

fn autofree_collect_prior_local_borrowed_pointer_field_store_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_assign) {
		return false
	}
	stmt_node := flat.nodes[stmt_id]
	if unsafe { token.Token(int(stmt_node.aux)) } != .assign || stmt_node.extra != 1
		|| autofree_collect_exact_edge_count(flat, stmt_id) != 2 {
		return false
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	if !autofree_collect_node_is(flat, lhs_id, .expr_selector)
		|| autofree_collect_exact_edge_count(flat, lhs_id) != 2
		|| !autofree_collect_node_is(flat, rhs_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, rhs_id) != 0 {
		return false
	}
	root_id := flat.edges[flat.nodes[lhs_id].first_edge].child_id
	field_id := flat.edges[flat.nodes[lhs_id].first_edge + 1].child_id
	return autofree_collect_node_is(flat, root_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, root_id) == 0
		&& autofree_collect_node_is(flat, field_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, field_id) == 0
}

fn autofree_collect_struct_init_borrowed_pointer_field_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_assign) {
		return false
	}
	stmt_node := flat.nodes[stmt_id]
	if unsafe { token.Token(int(stmt_node.aux)) } != .decl_assign || stmt_node.extra != 1
		|| autofree_collect_exact_edge_count(flat, stmt_id) != 2 {
		return false
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	init_id := flat.edges[stmt_node.first_edge + 1].child_id
	if !autofree_collect_node_is(flat, lhs_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, lhs_id) != 0
		|| !autofree_collect_node_is(flat, init_id, .expr_init)
		|| autofree_collect_exact_edge_count(flat, init_id) != 2 {
		return false
	}
	type_id := flat.edges[flat.nodes[init_id].first_edge].child_id
	field_init_id := flat.edges[flat.nodes[init_id].first_edge + 1].child_id
	if !autofree_collect_node_is_valid(flat, type_id)
		|| !autofree_collect_node_is(flat, field_init_id, .aux_field_init)
		|| autofree_collect_exact_edge_count(flat, field_init_id) != 1 {
		return false
	}
	field_name := flat.string_at(flat.nodes[field_init_id].name_id)
	if !autofree_collect_name_is_usable(field_name) {
		return false
	}
	source_id := flat.edges[flat.nodes[field_init_id].first_edge].child_id
	return autofree_collect_node_is(flat, source_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, source_id) == 0
}

fn autofree_collect_return_struct_init_borrowed_pointer_field_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_return)
		|| autofree_collect_exact_edge_count(flat, stmt_id) != 1 {
		return false
	}
	return_expr_id := flat.edges[flat.nodes[stmt_id].first_edge].child_id
	if !autofree_collect_node_is(flat, return_expr_id, .expr_init)
		|| autofree_collect_exact_edge_count(flat, return_expr_id) != 2 {
		return false
	}
	type_id := flat.edges[flat.nodes[return_expr_id].first_edge].child_id
	field_init_id := flat.edges[flat.nodes[return_expr_id].first_edge + 1].child_id
	if !autofree_collect_node_is(flat, type_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, type_id) != 0
		|| !autofree_collect_node_is(flat, field_init_id, .aux_field_init)
		|| autofree_collect_exact_edge_count(flat, field_init_id) != 1 {
		return false
	}
	field_name := flat.string_at(flat.nodes[field_init_id].name_id)
	if !autofree_collect_name_is_usable(field_name) {
		return false
	}
	source_id := flat.edges[flat.nodes[field_init_id].first_edge].child_id
	return autofree_collect_node_is(flat, source_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, source_id) == 0
}

fn autofree_collect_struct_init_field_sumtype_wrap_payload_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_assign) {
		return false
	}
	stmt_node := flat.nodes[stmt_id]
	if unsafe { token.Token(int(stmt_node.aux)) } != .decl_assign || stmt_node.extra != 1
		|| autofree_collect_exact_edge_count(flat, stmt_id) != 2 {
		return false
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	init_id := flat.edges[stmt_node.first_edge + 1].child_id
	if !autofree_collect_node_is(flat, lhs_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, lhs_id) != 0
		|| !autofree_collect_node_is(flat, init_id, .expr_init)
		|| autofree_collect_exact_edge_count(flat, init_id) != 2 {
		return false
	}
	type_id := flat.edges[flat.nodes[init_id].first_edge].child_id
	field_init_id := flat.edges[flat.nodes[init_id].first_edge + 1].child_id
	if !autofree_collect_node_is(flat, type_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, type_id) != 0
		|| !autofree_collect_node_is(flat, field_init_id, .aux_field_init)
		|| autofree_collect_exact_edge_count(flat, field_init_id) != 1 {
		return false
	}
	struct_type_name := flat.string_at(flat.nodes[type_id].name_id)
	field_name := flat.string_at(flat.nodes[field_init_id].name_id)
	if !autofree_collect_name_is_usable(struct_type_name)
		|| !autofree_collect_name_is_usable(field_name) {
		return false
	}
	wrap_id := flat.edges[flat.nodes[field_init_id].first_edge].child_id
	if !autofree_collect_node_is(flat, wrap_id, .expr_call_or_cast)
		|| autofree_collect_exact_edge_count(flat, wrap_id) != 2 {
		return false
	}
	target_id := flat.edges[flat.nodes[wrap_id].first_edge].child_id
	source_id := flat.edges[flat.nodes[wrap_id].first_edge + 1].child_id
	return autofree_collect_node_is(flat, target_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, target_id) == 0
		&& autofree_collect_node_is(flat, source_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, source_id) == 0
}

fn autofree_collect_return_struct_init_field_sumtype_wrap_payload_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_return)
		|| autofree_collect_exact_edge_count(flat, stmt_id) != 1 {
		return false
	}
	return_expr_id := flat.edges[flat.nodes[stmt_id].first_edge].child_id
	if !autofree_collect_node_is(flat, return_expr_id, .expr_init)
		|| autofree_collect_exact_edge_count(flat, return_expr_id) != 2 {
		return false
	}
	type_id := flat.edges[flat.nodes[return_expr_id].first_edge].child_id
	field_init_id := flat.edges[flat.nodes[return_expr_id].first_edge + 1].child_id
	if !autofree_collect_node_is(flat, type_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, type_id) != 0
		|| !autofree_collect_node_is(flat, field_init_id, .aux_field_init)
		|| autofree_collect_exact_edge_count(flat, field_init_id) != 1 {
		return false
	}
	return_struct_type_name := flat.string_at(flat.nodes[type_id].name_id)
	field_name := flat.string_at(flat.nodes[field_init_id].name_id)
	if !autofree_collect_name_is_usable(return_struct_type_name)
		|| !autofree_collect_name_is_usable(field_name) {
		return false
	}
	wrap_id := flat.edges[flat.nodes[field_init_id].first_edge].child_id
	if !autofree_collect_node_is(flat, wrap_id, .expr_call_or_cast)
		|| autofree_collect_exact_edge_count(flat, wrap_id) != 2 {
		return false
	}
	target_id := flat.edges[flat.nodes[wrap_id].first_edge].child_id
	source_id := flat.edges[flat.nodes[wrap_id].first_edge + 1].child_id
	return autofree_collect_node_is(flat, target_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, target_id) == 0
		&& autofree_collect_node_is(flat, source_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, source_id) == 0
}

fn autofree_collect_direct_sumtype_wrap_payload_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_assign) {
		return false
	}
	stmt_node := flat.nodes[stmt_id]
	if unsafe { token.Token(int(stmt_node.aux)) } != .decl_assign || stmt_node.extra != 1
		|| autofree_collect_exact_edge_count(flat, stmt_id) != 2 {
		return false
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	wrap_id := flat.edges[stmt_node.first_edge + 1].child_id
	if !autofree_collect_node_is(flat, lhs_id, .expr_ident)
		|| autofree_collect_exact_edge_count(flat, lhs_id) != 0
		|| !autofree_collect_node_is(flat, wrap_id, .expr_call_or_cast)
		|| autofree_collect_exact_edge_count(flat, wrap_id) != 2 {
		return false
	}
	target_id := flat.edges[flat.nodes[wrap_id].first_edge].child_id
	source_id := flat.edges[flat.nodes[wrap_id].first_edge + 1].child_id
	return autofree_collect_node_is(flat, target_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, target_id) == 0
		&& autofree_collect_node_is(flat, source_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, source_id) == 0
}

fn autofree_collect_direct_struct_field_type(lhs_typ Type, init_typ Type, field_name string) ?Type {
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(init_typ)
		|| !autofree_collect_name_is_usable(field_name) {
		return none
	}
	lhs_struct := match lhs_typ {
		Struct {
			lhs_typ
		}
		else {
			return none
		}
	}

	init_struct := match init_typ {
		Struct {
			init_typ
		}
		else {
			return none
		}
	}

	lhs_field_typ := autofree_collect_unique_direct_struct_field_type(lhs_struct, field_name) or {
		return none
	}
	init_field_typ := autofree_collect_unique_direct_struct_field_type(init_struct, field_name) or {
		return none
	}
	return autofree_collect_canonical_decl_transfer_type(lhs_field_typ, init_field_typ)
}

fn autofree_collect_direct_struct_scope_field_type(lhs_typ Type, init_typ Type, lhs_scope_typ Type, field_name string) ?Type {
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(init_typ)
		|| !type_has_valid_payload(lhs_scope_typ) || !autofree_collect_name_is_usable(field_name) {
		return none
	}
	lhs_struct := match lhs_typ {
		Struct {
			lhs_typ
		}
		else {
			return none
		}
	}

	init_struct := match init_typ {
		Struct {
			init_typ
		}
		else {
			return none
		}
	}

	scope_struct := match lhs_scope_typ {
		Struct {
			lhs_scope_typ
		}
		else {
			return none
		}
	}

	if !autofree_collect_same_direct_struct_payload(lhs_struct, init_struct)
		|| !autofree_collect_same_direct_struct_payload(lhs_struct, scope_struct) {
		return none
	}
	field_typ := autofree_collect_direct_struct_field_type(lhs_typ, init_typ, field_name) or {
		return none
	}
	scope_field_typ := autofree_collect_unique_direct_struct_field_type(scope_struct, field_name) or {
		return none
	}
	return autofree_collect_canonical_decl_transfer_type(field_typ, scope_field_typ)
}

fn autofree_collect_same_direct_struct_payload(left Struct, right Struct) bool {
	if !autofree_collect_name_is_usable(left.name) || left.name != right.name
		|| left.embedded.len != 0 || right.embedded.len != 0
		|| left.generic_params.len != right.generic_params.len
		|| left.fields.len != right.fields.len {
		return false
	}
	for i, param in left.generic_params {
		if param != right.generic_params[i] {
			return false
		}
	}
	for i, left_field in left.fields {
		right_field := right.fields[i]
		if !autofree_collect_name_is_usable(left_field.name) || left_field.name != right_field.name
			|| !type_has_valid_payload(left_field.typ) || !type_has_valid_payload(right_field.typ)
			|| !autofree_collect_same_direct_struct_field_type(left_field.typ, right_field.typ) {
			return false
		}
	}
	return true
}

fn autofree_collect_same_direct_struct_field_type(left Type, right Type) bool {
	if !type_has_valid_payload(left) || !type_has_valid_payload(right) {
		return false
	}
	return match left {
		Struct {
			if right is Struct {
				autofree_collect_same_direct_struct_payload(left, right)
			} else {
				false
			}
		}
		SumType {
			if right is SumType {
				autofree_collect_same_direct_sumtype_payload(left, right)
			} else {
				false
			}
		}
		else {
			same_type_name(left, right)
		}
	}
}

fn autofree_collect_unique_direct_struct_field_type(typ Struct, field_name string) ?Type {
	if !autofree_collect_name_is_usable(field_name) {
		return none
	}
	if typ.embedded.len != 0 {
		return none
	}
	mut match_count := 0
	mut field_typ := Type(void_)
	for field in typ.fields {
		if field.name != field_name {
			continue
		}
		if !type_has_valid_payload(field.typ) {
			return none
		}
		match_count++
		field_typ = field.typ
	}
	if match_count != 1 {
		return none
	}
	return field_typ
}

fn autofree_collect_direct_sumtype_wrap_target(lhs_typ Type, wrap_typ Type, lhs_scope_typ Type) ?SumType {
	if !type_has_valid_payload(lhs_typ) || !type_has_valid_payload(wrap_typ)
		|| !type_has_valid_payload(lhs_scope_typ) {
		return none
	}
	lhs_sumtype := match lhs_typ {
		SumType {
			lhs_typ
		}
		else {
			return none
		}
	}

	wrap_sumtype := match wrap_typ {
		SumType {
			wrap_typ
		}
		else {
			return none
		}
	}

	scope_sumtype := match lhs_scope_typ {
		SumType {
			lhs_scope_typ
		}
		else {
			return none
		}
	}

	if !same_type_name(lhs_typ, wrap_typ) || !same_type_name(lhs_typ, lhs_scope_typ)
		|| !autofree_collect_same_direct_sumtype_payload(lhs_sumtype, wrap_sumtype)
		|| !autofree_collect_same_direct_sumtype_payload(lhs_sumtype, scope_sumtype) {
		return none
	}
	return lhs_sumtype
}

fn autofree_collect_same_direct_sumtype_payload(left SumType, right SumType) bool {
	if left.name != right.name || left.variants.len != right.variants.len {
		return false
	}
	for i, left_variant in left.variants {
		right_variant := right.variants[i]
		if !type_has_valid_payload(left_variant) || !type_has_valid_payload(right_variant)
			|| !same_type_name(left_variant, right_variant) {
			return false
		}
	}
	return true
}

fn autofree_collect_direct_sumtype_variant_for_source(target SumType, source_typ Type) ?AutofreeDirectSumtypeVariantProof {
	if target.variants.len == 0 || !type_has_valid_payload(source_typ) {
		return none
	}
	mut match_count := 0
	mut matched_typ := Type(void_)
	mut matched_shape := AutofreeResourceShape{}
	for variant in target.variants {
		if !type_has_valid_payload(variant) {
			return none
		}
		if variant is SumType {
			return none
		}
		transfer_typ := autofree_collect_canonical_decl_transfer_type(variant, source_typ) or {
			continue
		}
		shape := autofree_resource_shape_for_type(transfer_typ)
		if shape.fail_closed || !shape.needs_autofree() {
			return none
		}
		action := autofree_collect_transfer_action_from_shape(shape)
		if action != .ambiguous_no_free {
			return none
		}
		match_count++
		matched_typ = transfer_typ
		matched_shape = shape
	}
	if match_count != 1 {
		return none
	}
	return AutofreeDirectSumtypeVariantProof{
		typ:   matched_typ
		shape: matched_shape
	}
}

fn autofree_collect_for_in_field_array_push_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_for)
		|| autofree_collect_exact_edge_count(flat, stmt_id) != 4 {
		return false
	}
	for_node := flat.nodes[stmt_id]
	for_in_id := flat.edges[for_node.first_edge].child_id
	cond_id := flat.edges[for_node.first_edge + 1].child_id
	post_id := flat.edges[for_node.first_edge + 2].child_id
	body_stmt_id := flat.edges[for_node.first_edge + 3].child_id
	if !autofree_collect_node_is(flat, for_in_id, .stmt_for_in)
		|| autofree_collect_exact_edge_count(flat, for_in_id) != 3
		|| !autofree_collect_node_is(flat, cond_id, .expr_empty)
		|| autofree_collect_exact_edge_count(flat, cond_id) != 0
		|| !autofree_collect_node_is(flat, post_id, .stmt_empty)
		|| autofree_collect_exact_edge_count(flat, post_id) != 0 {
		return false
	}
	for_in_node := flat.nodes[for_in_id]
	key_id := flat.edges[for_in_node.first_edge].child_id
	value_id := flat.edges[for_in_node.first_edge + 1].child_id
	iterable_id := flat.edges[for_in_node.first_edge + 2].child_id
	return autofree_collect_node_is(flat, key_id, .expr_empty)
		&& autofree_collect_exact_edge_count(flat, key_id) == 0
		&& autofree_collect_node_is(flat, value_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, value_id) == 0
		&& autofree_collect_node_is(flat, iterable_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, iterable_id) == 0
		&& autofree_collect_field_array_push_schema_is_exact(flat, body_stmt_id)
}

fn autofree_collect_for_in_array_push_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_for)
		|| autofree_collect_exact_edge_count(flat, stmt_id) != 4 {
		return false
	}
	for_node := flat.nodes[stmt_id]
	for_in_id := flat.edges[for_node.first_edge].child_id
	cond_id := flat.edges[for_node.first_edge + 1].child_id
	post_id := flat.edges[for_node.first_edge + 2].child_id
	body_stmt_id := flat.edges[for_node.first_edge + 3].child_id
	if !autofree_collect_node_is(flat, for_in_id, .stmt_for_in)
		|| autofree_collect_exact_edge_count(flat, for_in_id) != 3
		|| !autofree_collect_node_is(flat, cond_id, .expr_empty)
		|| autofree_collect_exact_edge_count(flat, cond_id) != 0
		|| !autofree_collect_node_is(flat, post_id, .stmt_empty)
		|| autofree_collect_exact_edge_count(flat, post_id) != 0 {
		return false
	}
	for_in_node := flat.nodes[for_in_id]
	key_id := flat.edges[for_in_node.first_edge].child_id
	value_id := flat.edges[for_in_node.first_edge + 1].child_id
	iterable_id := flat.edges[for_in_node.first_edge + 2].child_id
	return autofree_collect_node_is(flat, key_id, .expr_empty)
		&& autofree_collect_exact_edge_count(flat, key_id) == 0
		&& autofree_collect_node_is(flat, value_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, value_id) == 0
		&& autofree_collect_node_is(flat, iterable_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, iterable_id) == 0
		&& autofree_collect_array_push_schema_is_exact(flat, body_stmt_id)
}

fn autofree_collect_map_value_store_key_type_matches(map_key_typ Type, key_typ Type) bool {
	if !type_has_valid_payload(map_key_typ) || !type_has_valid_payload(key_typ) {
		return false
	}
	if key_typ.is_int_literal() {
		return same_type_name(map_key_typ, key_typ.typed_default())
	}
	if !key_typ.is_integer() {
		return false
	}
	return same_type_name(map_key_typ, key_typ)
}

fn autofree_collect_array_element_store_index_type_matches(index_typ Type) bool {
	if !type_has_valid_payload(index_typ) {
		return false
	}
	return index_typ.is_int_literal() || index_typ.is_integer()
}

fn autofree_collect_fresh_array_decl_lhs_rhs_schema_is_exact(flat &ast.FlatAst, stmt_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, stmt_id, .stmt_assign) {
		return false
	}
	stmt_node := flat.nodes[stmt_id]
	if unsafe { token.Token(int(stmt_node.aux)) } != .decl_assign {
		return false
	}
	if stmt_node.extra != 1 || autofree_collect_exact_edge_count(flat, stmt_id) != 2 {
		return false
	}
	lhs_id := flat.edges[stmt_node.first_edge].child_id
	rhs_id := flat.edges[stmt_node.first_edge + 1].child_id
	return autofree_collect_fresh_array_lhs_ident_id(flat, lhs_id) != ast.invalid_flat_node_id
		&& (autofree_collect_node_is(flat, rhs_id, .expr_array_init)
		|| autofree_collect_node_is(flat, rhs_id, .expr_call))
}

fn autofree_collect_fresh_array_lhs_ident_id(flat &ast.FlatAst, lhs_id ast.FlatNodeId) ast.FlatNodeId {
	if autofree_collect_node_is(flat, lhs_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, lhs_id) == 0 {
		return lhs_id
	}
	if !autofree_collect_node_is(flat, lhs_id, .expr_modifier)
		|| autofree_collect_exact_edge_count(flat, lhs_id) != 1 {
		return ast.invalid_flat_node_id
	}
	lhs_node := flat.nodes[lhs_id]
	if unsafe { token.Token(int(lhs_node.aux)) } != .key_mut
		|| !autofree_collect_child_is_valid(flat, lhs_id, 0) {
		return ast.invalid_flat_node_id
	}
	inner_id := flat.edges[lhs_node.first_edge].child_id
	if autofree_collect_node_is(flat, inner_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, inner_id) == 0 {
		return inner_id
	}
	return ast.invalid_flat_node_id
}

fn autofree_collect_fresh_array_lhs_is_mut(flat &ast.FlatAst, lhs_id ast.FlatNodeId) bool {
	if !autofree_collect_node_is(flat, lhs_id, .expr_modifier)
		|| autofree_collect_exact_edge_count(flat, lhs_id) != 1 {
		return false
	}
	lhs_node := flat.nodes[lhs_id]
	if unsafe { token.Token(int(lhs_node.aux)) } != .key_mut
		|| !autofree_collect_child_is_valid(flat, lhs_id, 0) {
		return false
	}
	inner_id := flat.edges[lhs_node.first_edge].child_id
	return autofree_collect_node_is(flat, inner_id, .expr_ident)
		&& autofree_collect_exact_edge_count(flat, inner_id) == 0
}

fn autofree_collect_empty_dynamic_array_init_is_exact(flat &ast.FlatAst, node_id ast.FlatNodeId, elem_type Type) bool {
	if autofree_collect_empty_dynamic_array_literal_is_exact(flat, node_id, elem_type) {
		return true
	}
	return autofree_collect_empty_dynamic_array_alloc_call_is_exact(flat, node_id, elem_type)
}

fn (e Environment) autofree_collect_cap_only_array_init_is_exact(flat &ast.FlatAst, node_id ast.FlatNodeId, elem_type Type, param_names map[string]bool) bool {
	if e.autofree_collect_cap_only_array_literal_is_exact(flat, node_id, elem_type, param_names) {
		return true
	}
	return e.autofree_collect_cap_only_array_alloc_call_is_exact(flat, node_id, elem_type,
		param_names)
}

fn (e Environment) autofree_collect_len_only_array_init_is_exact(flat &ast.FlatAst, node_id ast.FlatNodeId, elem_type Type, param_names map[string]bool) bool {
	if e.autofree_collect_len_only_array_literal_is_exact(flat, node_id, elem_type, param_names) {
		return true
	}
	return e.autofree_collect_len_only_array_alloc_call_is_exact(flat, node_id, elem_type,
		param_names)
}

fn (e Environment) autofree_collect_cap_only_array_literal_is_exact(flat &ast.FlatAst, node_id ast.FlatNodeId, elem_type Type, param_names map[string]bool) bool {
	if !autofree_collect_node_is(flat, node_id, .expr_array_init)
		|| autofree_collect_exact_edge_count(flat, node_id) != 5 {
		return false
	}
	type_id := autofree_collect_required_child(flat, node_id, 0, .typ_array)
	if type_id == ast.invalid_flat_node_id || autofree_collect_exact_edge_count(flat, type_id) != 1
		|| !autofree_collect_child_is_valid(flat, type_id, 0) {
		return false
	}
	elem_type_id := flat.edges[flat.nodes[type_id].first_edge].child_id
	if !autofree_collect_type_expr_matches(flat, elem_type_id, elem_type) {
		return false
	}
	if autofree_collect_required_child(flat, node_id, 1, .expr_empty) == ast.invalid_flat_node_id
		|| autofree_collect_required_child(flat, node_id, 3, .expr_empty) == ast.invalid_flat_node_id
		|| autofree_collect_required_child(flat, node_id, 4, .expr_empty) == ast.invalid_flat_node_id {
		return false
	}
	cap_id := flat.edges[flat.nodes[node_id].first_edge + 2].child_id
	return e.autofree_collect_cap_expr_is_direct_int_param(flat, cap_id, param_names)
}

fn (e Environment) autofree_collect_len_only_array_literal_is_exact(flat &ast.FlatAst, node_id ast.FlatNodeId, elem_type Type, param_names map[string]bool) bool {
	if !autofree_collect_node_is(flat, node_id, .expr_array_init)
		|| autofree_collect_exact_edge_count(flat, node_id) != 5 {
		return false
	}
	type_id := autofree_collect_required_child(flat, node_id, 0, .typ_array)
	if type_id == ast.invalid_flat_node_id || autofree_collect_exact_edge_count(flat, type_id) != 1
		|| !autofree_collect_child_is_valid(flat, type_id, 0) {
		return false
	}
	elem_type_id := flat.edges[flat.nodes[type_id].first_edge].child_id
	if !autofree_collect_type_expr_matches(flat, elem_type_id, elem_type) {
		return false
	}
	if autofree_collect_required_child(flat, node_id, 1, .expr_empty) == ast.invalid_flat_node_id
		|| autofree_collect_required_child(flat, node_id, 2, .expr_empty) == ast.invalid_flat_node_id
		|| autofree_collect_required_child(flat, node_id, 4, .expr_empty) == ast.invalid_flat_node_id {
		return false
	}
	len_id := flat.edges[flat.nodes[node_id].first_edge + 3].child_id
	return e.autofree_collect_array_bound_expr_is_direct_int_param(flat, len_id, param_names)
}

fn (e Environment) autofree_collect_cap_only_array_alloc_call_is_exact(flat &ast.FlatAst, node_id ast.FlatNodeId, elem_type Type, param_names map[string]bool) bool {
	if !autofree_collect_node_is(flat, node_id, .expr_call)
		|| autofree_collect_exact_edge_count(flat, node_id) != 5 {
		return false
	}
	callee_id := autofree_collect_required_child(flat, node_id, 0, .expr_ident)
	if callee_id == ast.invalid_flat_node_id
		|| autofree_collect_exact_edge_count(flat, callee_id) != 0 {
		return false
	}
	callee_name := flat.string_at(flat.nodes[callee_id].name_id)
	if callee_name !in ['__new_array_with_default_noscan', 'builtin____new_array_with_default_noscan'] {
		return false
	}
	if !autofree_collect_numeric_zero_child(flat, node_id, 1) {
		return false
	}
	cap_id := flat.edges[flat.nodes[node_id].first_edge + 2].child_id
	if !e.autofree_collect_cap_expr_is_direct_int_param(flat, cap_id, param_names) {
		return false
	}
	sizeof_id := autofree_collect_required_child(flat, node_id, 3, .expr_keyword_operator)
	if sizeof_id == ast.invalid_flat_node_id
		|| autofree_collect_exact_edge_count(flat, sizeof_id) != 1
		|| unsafe { token.Token(int(flat.nodes[sizeof_id].aux)) } != .key_sizeof
		|| !autofree_collect_child_is_valid(flat, sizeof_id, 0) {
		return false
	}
	sizeof_type_id := flat.edges[flat.nodes[sizeof_id].first_edge].child_id
	if !autofree_collect_type_expr_matches(flat, sizeof_type_id, elem_type) {
		return false
	}
	return autofree_collect_empty_array_alloc_init_is_zero(flat, node_id, 4)
}

fn (e Environment) autofree_collect_len_only_array_alloc_call_is_exact(flat &ast.FlatAst, node_id ast.FlatNodeId, elem_type Type, param_names map[string]bool) bool {
	if !autofree_collect_node_is(flat, node_id, .expr_call)
		|| autofree_collect_exact_edge_count(flat, node_id) != 5 {
		return false
	}
	callee_id := autofree_collect_required_child(flat, node_id, 0, .expr_ident)
	if callee_id == ast.invalid_flat_node_id
		|| autofree_collect_exact_edge_count(flat, callee_id) != 0 {
		return false
	}
	callee_name := flat.string_at(flat.nodes[callee_id].name_id)
	if callee_name !in ['__new_array_with_default_noscan', 'builtin____new_array_with_default_noscan'] {
		return false
	}
	len_id := flat.edges[flat.nodes[node_id].first_edge + 1].child_id
	if !e.autofree_collect_array_bound_expr_is_direct_int_param(flat, len_id, param_names) {
		return false
	}
	if !autofree_collect_numeric_zero_child(flat, node_id, 2) {
		return false
	}
	sizeof_id := autofree_collect_required_child(flat, node_id, 3, .expr_keyword_operator)
	if sizeof_id == ast.invalid_flat_node_id
		|| autofree_collect_exact_edge_count(flat, sizeof_id) != 1
		|| unsafe { token.Token(int(flat.nodes[sizeof_id].aux)) } != .key_sizeof
		|| !autofree_collect_child_is_valid(flat, sizeof_id, 0) {
		return false
	}
	sizeof_type_id := flat.edges[flat.nodes[sizeof_id].first_edge].child_id
	if !autofree_collect_type_expr_matches(flat, sizeof_type_id, elem_type) {
		return false
	}
	return autofree_collect_empty_array_alloc_init_is_zero(flat, node_id, 4)
}

fn (e Environment) autofree_collect_cap_expr_is_direct_int_param(flat &ast.FlatAst, node_id ast.FlatNodeId, param_names map[string]bool) bool {
	return e.autofree_collect_array_bound_expr_is_direct_int_param(flat, node_id, param_names)
}

fn (e Environment) autofree_collect_array_bound_expr_is_direct_int_param(flat &ast.FlatAst, node_id ast.FlatNodeId, param_names map[string]bool) bool {
	if !autofree_collect_node_is_valid(flat, node_id)
		|| autofree_collect_exact_edge_count(flat, node_id) != 0 {
		return false
	}
	node := flat.nodes[node_id]
	if node.kind != .expr_ident {
		return false
	}
	bound_name := flat.string_at(node.name_id)
	if !autofree_collect_name_is_usable(bound_name) || bound_name !in param_names {
		return false
	}
	pos_id := node.pos.id
	if pos_id <= 0 {
		return false
	}
	bound_typ := e.get_expr_type(pos_id) or { return false }
	if !type_has_valid_payload(bound_typ) {
		return false
	}
	return bound_typ.is_int_literal() || bound_typ.is_integer()
}

fn autofree_collect_empty_dynamic_array_literal_is_exact(flat &ast.FlatAst, node_id ast.FlatNodeId, elem_type Type) bool {
	if !autofree_collect_node_is(flat, node_id, .expr_array_init)
		|| autofree_collect_exact_edge_count(flat, node_id) != 5 {
		return false
	}
	type_id := autofree_collect_required_child(flat, node_id, 0, .typ_array)
	if type_id == ast.invalid_flat_node_id || autofree_collect_exact_edge_count(flat, type_id) != 1
		|| !autofree_collect_child_is_valid(flat, type_id, 0) {
		return false
	}
	elem_type_id := flat.edges[flat.nodes[type_id].first_edge].child_id
	if !autofree_collect_type_expr_matches(flat, elem_type_id, elem_type) {
		return false
	}
	for edge_i in 1 .. 5 {
		if autofree_collect_required_child(flat, node_id, edge_i, .expr_empty) == ast.invalid_flat_node_id {
			return false
		}
	}
	return true
}

fn autofree_collect_empty_dynamic_array_alloc_call_is_exact(flat &ast.FlatAst, node_id ast.FlatNodeId, elem_type Type) bool {
	if !autofree_collect_node_is(flat, node_id, .expr_call)
		|| autofree_collect_exact_edge_count(flat, node_id) != 5 {
		return false
	}
	callee_id := autofree_collect_required_child(flat, node_id, 0, .expr_ident)
	if callee_id == ast.invalid_flat_node_id
		|| autofree_collect_exact_edge_count(flat, callee_id) != 0 {
		return false
	}
	callee_name := flat.string_at(flat.nodes[callee_id].name_id)
	if callee_name !in ['__new_array_with_default_noscan', 'builtin____new_array_with_default_noscan'] {
		return false
	}
	if !autofree_collect_numeric_zero_child(flat, node_id, 1)
		|| !autofree_collect_numeric_zero_child(flat, node_id, 2) {
		return false
	}
	sizeof_id := autofree_collect_required_child(flat, node_id, 3, .expr_keyword_operator)
	if sizeof_id == ast.invalid_flat_node_id
		|| autofree_collect_exact_edge_count(flat, sizeof_id) != 1
		|| unsafe { token.Token(int(flat.nodes[sizeof_id].aux)) } != .key_sizeof
		|| !autofree_collect_child_is_valid(flat, sizeof_id, 0) {
		return false
	}
	sizeof_type_id := flat.edges[flat.nodes[sizeof_id].first_edge].child_id
	if !autofree_collect_type_expr_matches(flat, sizeof_type_id, elem_type) {
		return false
	}
	return autofree_collect_empty_array_alloc_init_is_zero(flat, node_id, 4)
}

fn autofree_collect_empty_array_alloc_init_is_zero(flat &ast.FlatAst, node_id ast.FlatNodeId, edge_i int) bool {
	init_id := autofree_collect_required_child(flat, node_id, edge_i, .expr_ident)
	if init_id == ast.invalid_flat_node_id || autofree_collect_exact_edge_count(flat, init_id) != 0 {
		return false
	}
	init_name := flat.string_at(flat.nodes[init_id].name_id)
	return init_name == 'nil' || init_name == 'NULL'
}

fn autofree_collect_type_expr_matches(flat &ast.FlatAst, type_id ast.FlatNodeId, typ Type) bool {
	if !autofree_collect_node_is_valid(flat, type_id) || !type_has_valid_payload(typ) {
		return false
	}
	match typ {
		Primitive, String, Char, Rune, USize, ISize, Void, NamedType, Enum, Struct, SumType {
			return autofree_collect_exact_edge_count(flat, type_id) == 0
				&& autofree_collect_node_is(flat, type_id, .expr_ident)
				&& flat.string_at(flat.nodes[type_id].name_id) == typ.name()
		}
		Array {
			if !autofree_collect_node_is(flat, type_id, .typ_array)
				|| autofree_collect_exact_edge_count(flat, type_id) != 1 {
				return false
			}
			elem_id := flat.edges[flat.nodes[type_id].first_edge].child_id
			return autofree_collect_type_expr_matches(flat, elem_id, typ.elem_type)
		}
		else {
			return false
		}
	}
}

fn autofree_collect_numeric_zero_child(flat &ast.FlatAst, parent ast.FlatNodeId, edge_i int) bool {
	child_id := autofree_collect_required_child(flat, parent, edge_i, .expr_basic_literal)
	if child_id == ast.invalid_flat_node_id
		|| autofree_collect_exact_edge_count(flat, child_id) != 0 {
		return false
	}
	child := flat.nodes[child_id]
	return unsafe { token.Token(int(child.aux)) } == .number && flat.string_at(child.name_id) == '0'
}

fn autofree_collect_endpoint(flat &ast.FlatAst, root_node_id ast.FlatNodeId, root_pos_id int, node_id ast.FlatNodeId, name string, typ Type, shape AutofreeResourceShape, storage AutofreeStorageKind, reason string) AutofreeTransferEndpoint {
	pos_id := flat.nodes[node_id].pos.id
	return AutofreeTransferEndpoint{
		storage:      storage
		root_storage: storage
		root_name:    name
		name:         name
		root_node_id: root_node_id
		root_pos_id:  root_pos_id
		node_id:      node_id
		pos_id:       pos_id
		has_type:     true
		typ:          typ
		type_name:    typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        autofree_collect_binding_state_from_shape(shape)
		reason:       reason
	}
}

fn autofree_collect_fresh_local_endpoint(flat &ast.FlatAst, node_id ast.FlatNodeId, name string, typ Type, shape AutofreeResourceShape) AutofreeTransferEndpoint {
	pos_id := flat.nodes[node_id].pos.id
	return AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    name
		name:         name
		root_node_id: node_id
		root_pos_id:  pos_id
		node_id:      node_id
		pos_id:       pos_id
		has_type:     true
		typ:          typ
		type_name:    typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .owned_unique
		reason:       'fresh local'
	}
}

fn autofree_collect_fresh_literal_endpoint(flat &ast.FlatAst, node_id ast.FlatNodeId, typ Type, shape AutofreeResourceShape) AutofreeTransferEndpoint {
	return autofree_collect_fresh_literal_endpoint_with_reason(flat, node_id, typ, shape,
		'empty dynamic array literal')
}

fn autofree_collect_fresh_literal_endpoint_with_reason(flat &ast.FlatAst, node_id ast.FlatNodeId, typ Type, shape AutofreeResourceShape, reason string) AutofreeTransferEndpoint {
	pos_id := flat.nodes[node_id].pos.id
	return AutofreeTransferEndpoint{
		storage:      .literal
		root_storage: .literal
		root_name:    'array literal'
		name:         'array literal'
		root_node_id: node_id
		root_pos_id:  pos_id
		node_id:      node_id
		pos_id:       pos_id
		has_type:     true
		typ:          typ
		type_name:    typ.name()
		resource:     autofree_collect_resource_kind_from_shape(shape)
		shape:        shape
		state:        .owned_unique
		reason:       reason
	}
}

fn autofree_collect_name_is_usable(name string) bool {
	return name.len > 0 && name != '_'
}

fn autofree_collect_fn_schema_is_complete(flat &ast.FlatAst, fn_id ast.FlatNodeId) bool {
	if autofree_collect_exact_edge_count(flat, fn_id) != 4 {
		return false
	}
	receiver_id := autofree_collect_required_child(flat, fn_id, 0, .aux_parameter)
	if receiver_id == ast.invalid_flat_node_id
		|| !autofree_collect_parameter_schema_is_complete(flat, receiver_id) {
		return false
	}
	fn_type_id := autofree_collect_required_child(flat, fn_id, 1, .typ_fn)
	if fn_type_id == ast.invalid_flat_node_id {
		return false
	}
	attrs_id := autofree_collect_required_child(flat, fn_id, 2, .aux_list)
	if attrs_id == ast.invalid_flat_node_id || autofree_collect_exact_edge_count(flat, attrs_id) < 0 {
		return false
	}
	body_id := autofree_collect_required_child(flat, fn_id, 3, .aux_list)
	if body_id == ast.invalid_flat_node_id || autofree_collect_exact_edge_count(flat, body_id) < 0 {
		return false
	}
	if !autofree_collect_fn_type_schema_is_complete(flat, fn_type_id) {
		return false
	}
	return true
}

fn autofree_collect_fn_type_schema_is_complete(flat &ast.FlatAst, fn_type_id ast.FlatNodeId) bool {
	if autofree_collect_exact_edge_count(flat, fn_type_id) != 3 {
		return false
	}
	generic_params_id := autofree_collect_required_child(flat, fn_type_id, 0, .aux_list)
	if generic_params_id == ast.invalid_flat_node_id
		|| autofree_collect_exact_edge_count(flat, generic_params_id) < 0 {
		return false
	}
	params_id := autofree_collect_required_child(flat, fn_type_id, 1, .aux_list)
	if params_id == ast.invalid_flat_node_id
		|| autofree_collect_exact_edge_count(flat, params_id) < 0 {
		return false
	}
	return autofree_collect_child_is_valid(flat, fn_type_id, 2)
}

fn autofree_collect_fn_param_ids(flat &ast.FlatAst, fn_id ast.FlatNodeId) []ast.FlatNodeId {
	fn_type_id := autofree_collect_required_child(flat, fn_id, 1, .typ_fn)
	if fn_type_id == ast.invalid_flat_node_id {
		return []ast.FlatNodeId{}
	}
	params_id := autofree_collect_required_child(flat, fn_type_id, 1, .aux_list)
	if params_id == ast.invalid_flat_node_id {
		return []ast.FlatNodeId{}
	}
	param_count := autofree_collect_exact_edge_count(flat, params_id)
	if param_count < 0 {
		return []ast.FlatNodeId{}
	}
	params_node := flat.nodes[params_id]
	mut param_ids := []ast.FlatNodeId{cap: param_count}
	for i in 0 .. param_count {
		param_id := flat.edges[params_node.first_edge + i].child_id
		if !autofree_collect_node_is(flat, param_id, .aux_parameter)
			|| !autofree_collect_parameter_schema_is_complete(flat, param_id) {
			return []ast.FlatNodeId{}
		}
		param_ids << param_id
	}
	return param_ids
}

fn autofree_collect_fn_return_type_id(flat &ast.FlatAst, fn_id ast.FlatNodeId) ast.FlatNodeId {
	fn_type_id := autofree_collect_required_child(flat, fn_id, 1, .typ_fn)
	if fn_type_id == ast.invalid_flat_node_id {
		return ast.invalid_flat_node_id
	}
	return autofree_collect_required_child(flat, fn_type_id, 2, .expr_ident)
}

fn autofree_collect_parameter_schema_is_complete(flat &ast.FlatAst, param_id ast.FlatNodeId) bool {
	return autofree_collect_exact_edge_count(flat, param_id) == 1
		&& autofree_collect_child_is_valid(flat, param_id, 0)
}

fn autofree_collect_child_is_valid(flat &ast.FlatAst, parent ast.FlatNodeId, edge_i int) bool {
	if edge_i < 0 || !autofree_collect_node_is_valid(flat, parent) {
		return false
	}
	edge_count := autofree_collect_exact_edge_count(flat, parent)
	if edge_count < 0 || edge_i >= edge_count {
		return false
	}
	node := flat.nodes[parent]
	return autofree_collect_node_is_valid(flat, flat.edges[node.first_edge + edge_i].child_id)
}

fn autofree_collect_required_child(flat &ast.FlatAst, parent ast.FlatNodeId, edge_i int, kind ast.FlatNodeKind) ast.FlatNodeId {
	if edge_i < 0 || !autofree_collect_node_is_valid(flat, parent) {
		return ast.invalid_flat_node_id
	}
	edge_count := autofree_collect_exact_edge_count(flat, parent)
	if edge_i >= edge_count || edge_count < 0 {
		return ast.invalid_flat_node_id
	}
	node := flat.nodes[parent]
	child_id := flat.edges[node.first_edge + edge_i].child_id
	if !autofree_collect_node_is(flat, child_id, kind) {
		return ast.invalid_flat_node_id
	}
	return child_id
}

fn autofree_collect_exact_edge_count(flat &ast.FlatAst, node_id ast.FlatNodeId) int {
	if !autofree_collect_node_is_valid(flat, node_id) {
		return -1
	}
	node := flat.nodes[node_id]
	if node.edge_count < 0 {
		return -1
	}
	if node.edge_count == 0 {
		return 0
	}
	if node.first_edge < 0 || node.first_edge >= flat.edges.len {
		return -1
	}
	if node.edge_count > flat.edges.len - node.first_edge {
		return -1
	}
	return node.edge_count
}

fn autofree_collect_node_is(flat &ast.FlatAst, node_id ast.FlatNodeId, kind ast.FlatNodeKind) bool {
	if !autofree_collect_node_is_valid(flat, node_id) {
		return false
	}
	return flat.nodes[node_id].kind == kind
}

fn autofree_collect_node_is_valid(flat &ast.FlatAst, node_id ast.FlatNodeId) bool {
	return node_id >= 0 && node_id < flat.nodes.len
}

fn autofree_collect_resource_kind_from_shape(shape AutofreeResourceShape) AutofreeResourceKind {
	return match shape.kind {
		.no_resource { .no_resource }
		.string_ { .string_value }
		.array, .array_fixed { .array_value }
		.map_ { .map_container }
		.struct_ { .struct_value }
		.sumtype { .sumtype_value }
		.borrowed_pointer { .pointer_value }
		.option { .option_value }
		.result { .result_value }
		.tuple { .tuple_value }
		.alias { .alias_value }
		.ambiguous { .unknown }
	}
}

fn autofree_collect_binding_state_from_shape(shape AutofreeResourceShape) AutofreeOwnershipState {
	if shape.kind == .borrowed_pointer {
		return .borrowed_no_free
	}
	if shape.kind == .no_resource {
		return .copy_no_resource
	}
	return .ambiguous_no_free
}

fn autofree_collect_transfer_action_from_shape(shape AutofreeResourceShape) AutofreeTransferAction {
	if shape.kind == .borrowed_pointer {
		return .borrow_no_free
	}
	if shape.kind == .no_resource {
		return .copy_no_resource
	}
	return .ambiguous_no_free
}

fn (mut e Environment) collect_autofree_release_eligibility_from_transfers() {
	for fn_key, transfers in e.autofree_transfers_by_fn_key {
		for transfer in transfers {
			fact := autofree_collect_release_eligibility_from_transfer(transfer)
			mut facts := e.autofree_release_eligibility_by_fn_key[fn_key] or {
				[]AutofreeReleaseEligibilityFact{}
			}
			facts << fact
			e.autofree_release_eligibility_by_fn_key[fn_key] = facts
		}
	}
}

fn autofree_collect_release_eligibility_from_transfer(transfer AutofreeTransferFact) AutofreeReleaseEligibilityFact {
	endpoint := transfer.to_endpoint
	eligibility := autofree_collect_release_eligibility_for_endpoint(transfer.action, endpoint)
	return AutofreeReleaseEligibilityFact{
		fn_key:          transfer.fn_key
		fn_name:         transfer.fn_name
		name:            endpoint.name
		endpoint:        endpoint
		transfer_kind:   transfer.kind
		transfer_action: transfer.action
		eligibility:     eligibility
		state:           endpoint.state
		resource:        endpoint.resource
		shape:           endpoint.shape
		typ:             endpoint.typ
		type_name:       endpoint.type_name
		node_id:         endpoint.node_id
		pos_id:          endpoint.pos_id
		reason:          autofree_collect_release_eligibility_reason(transfer.action, endpoint,
			eligibility)
	}
}

fn autofree_collect_release_eligibility_for_endpoint(action AutofreeTransferAction, endpoint AutofreeTransferEndpoint) AutofreeReleaseEligibility {
	if !endpoint.has_type || !type_has_valid_payload(endpoint.typ) || endpoint.shape.fail_closed {
		return .not_release_eligible
	}
	if action == .move && endpoint.storage == .local && endpoint.root_storage == .local
		&& endpoint.path.len == 0 && endpoint.state == .owned_unique
		&& endpoint.shape.needs_autofree() {
		return .release_eligible
	}
	return .not_release_eligible
}

fn autofree_collect_release_eligibility_reason(action AutofreeTransferAction, endpoint AutofreeTransferEndpoint, eligibility AutofreeReleaseEligibility) string {
	if eligibility == .release_eligible {
		return 'owned move endpoint'
	}
	if !endpoint.has_type || !type_has_valid_payload(endpoint.typ) {
		return 'missing endpoint type'
	}
	if endpoint.shape.fail_closed {
		return 'fail closed endpoint shape'
	}
	return match action {
		.copy_no_resource { 'copy transfer is not release eligible' }
		.borrow_no_free { 'borrow transfer is not release eligible' }
		.ambiguous_no_free { 'ambiguous transfer is not release eligible' }
		else { 'transfer is not release eligible' }
	}
}
