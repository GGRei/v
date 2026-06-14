// Copyright (c) 2026 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module types

import v2.ast
import v2.token

struct AutofreeFlatTraversalCounts {
mut:
	valid_files          int
	valid_stmt_lists     int
	fn_decls_seen        int
	free_fns_seen        int
	methods_skipped      int
	valid_param_lists    int
	params_seen          int
	named_params         int
	valid_body_lists     int
	body_stmts_seen      int
	assign_stmts_seen    int
	return_stmts_seen    int
	decl_assigns_seen    int
	malformed_body_items int
	malformed_items      int
}

fn autofree_validate_flat_traversal(flat &ast.FlatAst) AutofreeFlatTraversalCounts {
	mut counts := AutofreeFlatTraversalCounts{}
	for file in flat.files {
		autofree_validate_flat_file(flat, file.file_id, mut counts)
	}
	return counts
}

fn autofree_validate_flat_file(flat &ast.FlatAst, file_id ast.FlatNodeId, mut counts AutofreeFlatTraversalCounts) {
	if !autofree_flat_node_is(flat, file_id, .file) {
		counts.malformed_items++
		return
	}
	counts.valid_files++
	stmts_id := autofree_flat_child_of_kind(flat, file_id, 2, .aux_list, mut counts)
	if stmts_id == ast.invalid_flat_node_id {
		return
	}
	autofree_validate_flat_stmt_list(flat, stmts_id, mut counts)
}

fn autofree_validate_flat_stmt_list(flat &ast.FlatAst, stmts_id ast.FlatNodeId, mut counts AutofreeFlatTraversalCounts) {
	if !autofree_flat_node_is(flat, stmts_id, .aux_list) {
		counts.malformed_items++
		return
	}
	counts.valid_stmt_lists++
	edge_count := autofree_flat_safe_edge_count(flat, stmts_id, mut counts)
	for i in 0 .. edge_count {
		stmt_id := autofree_flat_edge_child(flat, stmts_id, i, mut counts)
		if !autofree_flat_node_is_valid(flat, stmt_id) {
			counts.malformed_items++
			continue
		}
		if flat.nodes[stmt_id].kind == .stmt_fn_decl {
			autofree_validate_flat_fn_decl(flat, stmt_id, mut counts)
		}
	}
}

fn autofree_validate_flat_fn_decl(flat &ast.FlatAst, fn_id ast.FlatNodeId, mut counts AutofreeFlatTraversalCounts) {
	if !autofree_flat_node_is(flat, fn_id, .stmt_fn_decl) {
		counts.malformed_items++
		return
	}
	counts.fn_decls_seen++
	if (flat.nodes[fn_id].flags & ast.flag_is_method) != 0 {
		counts.methods_skipped++
		return
	}
	counts.free_fns_seen++
	fn_type_id := autofree_flat_child_of_kind(flat, fn_id, 1, .typ_fn, mut counts)
	if fn_type_id == ast.invalid_flat_node_id {
		return
	}
	params_id := autofree_flat_child_of_kind(flat, fn_type_id, 1, .aux_list, mut counts)
	if params_id == ast.invalid_flat_node_id {
		return
	}
	autofree_validate_flat_parameter_list(flat, params_id, mut counts)
	body_id := autofree_flat_child_of_kind(flat, fn_id, 3, .aux_list, mut counts)
	if body_id == ast.invalid_flat_node_id {
		return
	}
	autofree_validate_flat_body_list(flat, body_id, mut counts)
}

fn autofree_validate_flat_parameter_list(flat &ast.FlatAst, params_id ast.FlatNodeId, mut counts AutofreeFlatTraversalCounts) {
	if !autofree_flat_node_is(flat, params_id, .aux_list) {
		counts.malformed_items++
		return
	}
	counts.valid_param_lists++
	edge_count := autofree_flat_safe_edge_count(flat, params_id, mut counts)
	for i in 0 .. edge_count {
		param_id := autofree_flat_edge_child(flat, params_id, i, mut counts)
		if !autofree_flat_node_is(flat, param_id, .aux_parameter) {
			counts.malformed_items++
			continue
		}
		counts.params_seen++
		if flat.string_at(flat.nodes[param_id].name_id).len > 0 {
			counts.named_params++
		}
	}
}

fn autofree_validate_flat_body_list(flat &ast.FlatAst, body_id ast.FlatNodeId, mut counts AutofreeFlatTraversalCounts) {
	if !autofree_flat_node_is(flat, body_id, .aux_list) {
		counts.malformed_body_items++
		return
	}
	if autofree_flat_edge_range_is_truncated(flat, body_id) {
		counts.malformed_body_items++
		return
	}
	counts.valid_body_lists++
	edge_count := autofree_flat_safe_edge_count(flat, body_id, mut counts)
	node := flat.nodes[body_id]
	for i in 0 .. edge_count {
		stmt_id := flat.edges[node.first_edge + i].child_id
		if !autofree_flat_node_is_valid(flat, stmt_id) {
			counts.malformed_body_items++
			continue
		}
		counts.body_stmts_seen++
		stmt := flat.nodes[stmt_id]
		if stmt.kind == .stmt_assign {
			counts.assign_stmts_seen++
			if unsafe { token.Token(int(stmt.aux)) } == .decl_assign {
				counts.decl_assigns_seen++
			}
		} else if stmt.kind == .stmt_return {
			counts.return_stmts_seen++
		}
	}
}

fn autofree_flat_child_of_kind(flat &ast.FlatAst, parent ast.FlatNodeId, edge_i int, kind ast.FlatNodeKind, mut counts AutofreeFlatTraversalCounts) ast.FlatNodeId {
	child_id := autofree_flat_edge_child(flat, parent, edge_i, mut counts)
	if child_id == ast.invalid_flat_node_id {
		return ast.invalid_flat_node_id
	}
	if !autofree_flat_node_is(flat, child_id, kind) {
		counts.malformed_items++
		return ast.invalid_flat_node_id
	}
	return child_id
}

fn autofree_flat_edge_child(flat &ast.FlatAst, parent ast.FlatNodeId, edge_i int, mut counts AutofreeFlatTraversalCounts) ast.FlatNodeId {
	if edge_i < 0 || !autofree_flat_node_is_valid(flat, parent) {
		counts.malformed_items++
		return ast.invalid_flat_node_id
	}
	edge_count := autofree_flat_safe_edge_count(flat, parent, mut counts)
	if edge_i >= edge_count {
		counts.malformed_items++
		return ast.invalid_flat_node_id
	}
	node := flat.nodes[parent]
	return flat.edges[node.first_edge + edge_i].child_id
}

fn autofree_flat_safe_edge_count(flat &ast.FlatAst, node_id ast.FlatNodeId, mut counts AutofreeFlatTraversalCounts) int {
	if !autofree_flat_node_is_valid(flat, node_id) {
		counts.malformed_items++
		return 0
	}
	node := flat.nodes[node_id]
	if node.edge_count <= 0 {
		return 0
	}
	if node.first_edge < 0 || node.first_edge >= flat.edges.len {
		counts.malformed_items++
		return 0
	}
	max_count := flat.edges.len - node.first_edge
	if node.edge_count > max_count {
		counts.malformed_items++
		return max_count
	}
	return node.edge_count
}

fn autofree_flat_edge_range_is_truncated(flat &ast.FlatAst, node_id ast.FlatNodeId) bool {
	if !autofree_flat_node_is_valid(flat, node_id) {
		return true
	}
	node := flat.nodes[node_id]
	if node.edge_count < 0 {
		return true
	}
	if node.edge_count == 0 {
		return false
	}
	if node.first_edge < 0 || node.first_edge >= flat.edges.len {
		return true
	}
	return node.edge_count > flat.edges.len - node.first_edge
}

fn autofree_flat_node_is(flat &ast.FlatAst, node_id ast.FlatNodeId, kind ast.FlatNodeKind) bool {
	if !autofree_flat_node_is_valid(flat, node_id) {
		return false
	}
	return flat.nodes[node_id].kind == kind
}

fn autofree_flat_node_is_valid(flat &ast.FlatAst, node_id ast.FlatNodeId) bool {
	return node_id >= 0 && node_id < flat.nodes.len
}
