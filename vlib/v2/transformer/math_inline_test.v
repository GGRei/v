module transformer

import os
import v2.ast
import v2.pref as vpref
import v2.token
import v2.types

fn math_inline_test_transformer(module_alias string, module_name string, importing_file string) &Transformer {
	env := &types.Environment{}
	mut scope := types.new_scope(unsafe { nil })
	scope.insert(module_alias, types.Module{
		name:  module_name
		scope: types.new_scope(unsafe { nil })
	})
	return &Transformer{
		pref:                        &vpref.Preferences{}
		env:                         unsafe { env }
		scope:                       scope
		fn_root_scope:               scope
		cur_file_name:               importing_file
		needed_clone_fns:            map[string]string{}
		needed_array_contains_fns:   map[string]ArrayMethodInfo{}
		needed_array_index_fns:      map[string]ArrayMethodInfo{}
		needed_array_last_index_fns: map[string]ArrayMethodInfo{}
		local_decl_types:            map[string]types.Type{}
	}
}

fn math_inline_repo_file() string {
	return os.join_path(os.getwd(), 'math_inline_probe.v')
}

fn math_inline_external_example_file() string {
	return os.join_path(os.getwd(), 'examples', '2048', '2048.v')
}

fn math_inline_selector_call(name string, args []ast.Expr) ast.CallExpr {
	return math_inline_selector_call_with_lhs('math', name, args)
}

fn math_inline_selector_call_with_lhs(lhs_name string, name string, args []ast.Expr) ast.CallExpr {
	return ast.CallExpr{
		lhs:  ast.SelectorExpr{
			lhs: ast.Ident{
				name: lhs_name
			}
			rhs: ast.Ident{
				name: name
			}
		}
		args: args
	}
}

fn math_inline_number(value string) ast.Expr {
	return ast.Expr(ast.BasicLiteral{
		kind:  .number
		value: value
	})
}

fn math_inline_cast(type_name string, value string) ast.Expr {
	return ast.Expr(ast.CallOrCastExpr{
		lhs:  ast.Ident{
			name: type_name
		}
		expr: math_inline_number(value)
	})
}

fn math_inline_next_call() ast.Expr {
	return ast.Expr(ast.CallExpr{
		lhs: ast.Ident{
			name: 'next'
		}
	})
}

fn math_inline_emit_expr_cursor(mut b ast.FlatBuilder, expr ast.Expr) ast.Cursor {
	id := b.emit_expr(expr)
	return ast.Cursor{
		flat: &b.flat
		id:   id
	}
}

fn math_inline_local_math_transformer() &Transformer {
	mut t := &Transformer{
		pref:                        &vpref.Preferences{}
		env:                         unsafe { &types.Environment{} }
		needed_clone_fns:            map[string]string{}
		needed_array_contains_fns:   map[string]ArrayMethodInfo{}
		needed_array_index_fns:      map[string]ArrayMethodInfo{}
		needed_array_last_index_fns: map[string]ArrayMethodInfo{}
		local_decl_types:            map[string]types.Type{}
	}
	mut scope := types.new_scope(unsafe { nil })
	scope.insert('math', value_object_from_type(types.Struct{
		name: 'LocalMath'
	}))
	t.scope = scope
	t.fn_root_scope = scope
	return t
}

fn count_math_selector_calls_in_expr(expr ast.Expr, lhs_name string, rhs_name string) int {
	mut count := 0
	match expr {
		ast.CallExpr {
			if expr.lhs is ast.SelectorExpr {
				sel := expr.lhs as ast.SelectorExpr
				if sel.lhs is ast.Ident
					&& (sel.lhs as ast.Ident).name == lhs_name && sel.rhs.name == rhs_name {
					count++
				}
			}
			count += count_math_selector_calls_in_expr(expr.lhs, lhs_name, rhs_name)
			for arg in expr.args {
				count += count_math_selector_calls_in_expr(arg, lhs_name, rhs_name)
			}
		}
		ast.CallOrCastExpr {
			count += count_math_selector_calls_in_expr(expr.lhs, lhs_name, rhs_name)
			count += count_math_selector_calls_in_expr(expr.expr, lhs_name, rhs_name)
		}
		ast.IfExpr {
			count += count_math_selector_calls_in_expr(expr.cond, lhs_name, rhs_name)
			for stmt in expr.stmts {
				count += count_math_selector_calls_in_stmt(stmt, lhs_name, rhs_name)
			}
			count += count_math_selector_calls_in_expr(expr.else_expr, lhs_name, rhs_name)
		}
		ast.InfixExpr {
			count += count_math_selector_calls_in_expr(expr.lhs, lhs_name, rhs_name)
			count += count_math_selector_calls_in_expr(expr.rhs, lhs_name, rhs_name)
		}
		ast.PrefixExpr {
			count += count_math_selector_calls_in_expr(expr.expr, lhs_name, rhs_name)
		}
		ast.SelectorExpr {
			count += count_math_selector_calls_in_expr(expr.lhs, lhs_name, rhs_name)
		}
		ast.KeywordOperator {
			for item in expr.exprs {
				count += count_math_selector_calls_in_expr(item, lhs_name, rhs_name)
			}
		}
		else {}
	}

	return count
}

fn count_math_selector_calls_in_stmt(stmt ast.Stmt, lhs_name string, rhs_name string) int {
	mut count := 0
	match stmt {
		ast.AssignStmt {
			for expr in stmt.lhs {
				count += count_math_selector_calls_in_expr(expr, lhs_name, rhs_name)
			}
			for expr in stmt.rhs {
				count += count_math_selector_calls_in_expr(expr, lhs_name, rhs_name)
			}
		}
		ast.ExprStmt {
			count += count_math_selector_calls_in_expr(stmt.expr, lhs_name, rhs_name)
		}
		ast.ReturnStmt {
			for expr in stmt.exprs {
				count += count_math_selector_calls_in_expr(expr, lhs_name, rhs_name)
			}
		}
		else {}
	}

	return count
}

fn count_math_selector_calls_in_pending(stmts []ast.Stmt, lhs_name string, rhs_name string) int {
	mut count := 0
	for stmt in stmts {
		count += count_math_selector_calls_in_stmt(stmt, lhs_name, rhs_name)
	}
	return count
}

fn collect_math_call_names_from_expr(expr ast.Expr, mut names []string) {
	match expr {
		ast.CallExpr {
			match expr.lhs {
				ast.Ident {
					names << expr.lhs.name
				}
				ast.SelectorExpr {
					names << expr.lhs.rhs.name
				}
				else {}
			}

			collect_math_call_names_from_expr(expr.lhs, mut names)
			for arg in expr.args {
				collect_math_call_names_from_expr(arg, mut names)
			}
		}
		ast.CallOrCastExpr {
			collect_math_call_names_from_expr(expr.lhs, mut names)
			collect_math_call_names_from_expr(expr.expr, mut names)
		}
		ast.IfExpr {
			collect_math_call_names_from_expr(expr.cond, mut names)
			for stmt in expr.stmts {
				collect_math_call_names_from_stmt(stmt, mut names)
			}
			collect_math_call_names_from_expr(expr.else_expr, mut names)
		}
		ast.InfixExpr {
			collect_math_call_names_from_expr(expr.lhs, mut names)
			collect_math_call_names_from_expr(expr.rhs, mut names)
		}
		ast.PrefixExpr {
			collect_math_call_names_from_expr(expr.expr, mut names)
		}
		ast.SelectorExpr {
			collect_math_call_names_from_expr(expr.lhs, mut names)
		}
		ast.KeywordOperator {
			for item in expr.exprs {
				collect_math_call_names_from_expr(item, mut names)
			}
		}
		else {}
	}
}

fn collect_math_call_names_from_stmt(stmt ast.Stmt, mut names []string) {
	match stmt {
		ast.AssignStmt {
			for expr in stmt.lhs {
				collect_math_call_names_from_expr(expr, mut names)
			}
			for expr in stmt.rhs {
				collect_math_call_names_from_expr(expr, mut names)
			}
		}
		ast.ExprStmt {
			collect_math_call_names_from_expr(stmt.expr, mut names)
		}
		ast.ReturnStmt {
			for expr in stmt.exprs {
				collect_math_call_names_from_expr(expr, mut names)
			}
		}
		else {}
	}
}

fn count_math_call_name_in_pending(stmts []ast.Stmt, name string) int {
	mut names := []string{}
	for stmt in stmts {
		collect_math_call_names_from_stmt(stmt, mut names)
	}
	mut count := 0
	for call_name in names {
		if call_name == name {
			count++
		}
	}
	return count
}

fn count_math_call_name_in_expr(expr ast.Expr, name string) int {
	mut names := []string{}
	collect_math_call_names_from_expr(expr, mut names)
	mut count := 0
	for call_name in names {
		if call_name == name {
			count++
		}
	}
	return count
}

fn test_transformer_flat_direct_math_module_call_routes_to_inline_fallback() {
	mut t := math_inline_test_transformer('math', 'math', math_inline_repo_file())
	mut min_builder := ast.new_flat_builder()
	min_cursor := math_inline_emit_expr_cursor(mut min_builder, ast.Expr(math_inline_selector_call('min', [
		math_inline_number('1'),
		math_inline_number('2'),
	])))
	assert t.call_selector_is_official_math_inline_cursor(min_cursor)
	if direct := t.call_selector_module_name_can_transform_direct(min_cursor) {
		assert false, 'math.min should route through inline fallback, got ${direct}'
	}
	mut min_out := ast.new_flat_builder()
	min_out_id := t.transform_expr_cursor_to_flat(min_cursor, mut min_out)
	min_expr := min_out.flat.decode_expr(min_out_id)
	assert min_expr is ast.IfExpr

	mut max_builder := ast.new_flat_builder()
	max_cursor := math_inline_emit_expr_cursor(mut max_builder, ast.Expr(math_inline_selector_call('max', [
		math_inline_number('1'),
		math_inline_number('2'),
	])))
	assert t.call_selector_is_official_math_inline_cursor(max_cursor)
	if direct := t.call_selector_module_name_can_transform_direct(max_cursor) {
		assert false, 'math.max should route through inline fallback, got ${direct}'
	}

	mut clip_builder := ast.new_flat_builder()
	clip_cursor := math_inline_emit_expr_cursor(mut clip_builder, ast.Expr(math_inline_selector_call('clip', [
		math_inline_number('1'),
		math_inline_number('0'),
		math_inline_number('2'),
	])))
	assert t.call_selector_is_official_math_inline_cursor(clip_cursor)
	if direct := t.call_selector_module_name_can_transform_direct(clip_cursor) {
		assert false, 'math.clip should route through inline fallback, got ${direct}'
	}
}

fn test_transformer_flat_dump_math_min_max_uses_inline_fallback() {
	mut t := math_inline_test_transformer('math', 'math', math_inline_repo_file())
	dump_min := ast.Expr(ast.KeywordOperator{
		op:    .key_dump
		exprs: [
			ast.Expr(math_inline_selector_call('min', [
				ast.Expr(ast.InfixExpr{
					op:  token.Token.plus
					lhs: ast.Ident{
						name: 'x'
					}
					rhs: math_inline_number('1')
				}),
				math_inline_number('60'),
			])),
		]
	})
	mut min_builder := ast.new_flat_builder()
	min_cursor := math_inline_emit_expr_cursor(mut min_builder, dump_min)
	mut min_out := ast.new_flat_builder()
	min_out_id := t.transform_expr_cursor_to_flat(min_cursor, mut min_out)
	min_expr := min_out.flat.decode_expr(min_out_id)
	assert count_math_call_name_in_expr(min_expr, 'math__min') == 0
	assert count_math_selector_calls_in_expr(min_expr, 'math', 'min') == 0

	t.pending_stmts.clear()
	dump_max := ast.Expr(ast.KeywordOperator{
		op:    .key_dump
		exprs: [
			ast.Expr(math_inline_selector_call('max', [
				ast.Expr(ast.InfixExpr{
					op:  token.Token.minus
					lhs: ast.Ident{
						name: 'x'
					}
					rhs: math_inline_number('1')
				}),
				math_inline_number('1'),
			])),
		]
	})
	mut max_builder := ast.new_flat_builder()
	max_cursor := math_inline_emit_expr_cursor(mut max_builder, dump_max)
	mut max_out := ast.new_flat_builder()
	max_out_id := t.transform_expr_cursor_to_flat(max_cursor, mut max_out)
	max_expr := max_out.flat.decode_expr(max_out_id)
	assert count_math_call_name_in_expr(max_expr, 'math__max') == 0
	assert count_math_selector_calls_in_expr(max_expr, 'math', 'max') == 0
}

fn test_transformer_legacy_dump_math_min_max_uses_inline_fallback() {
	mut t := math_inline_test_transformer('math', 'math', math_inline_external_example_file())
	dump_min := ast.Expr(ast.KeywordOperator{
		op:    .key_dump
		exprs: [
			ast.Expr(math_inline_selector_call('min', [
				ast.Expr(ast.InfixExpr{
					op:  token.Token.plus
					lhs: ast.Ident{
						name: 'x'
					}
					rhs: math_inline_number('1')
				}),
				math_inline_number('60'),
			])),
		]
	})
	min_expr := t.transform_expr(dump_min)
	assert count_math_call_name_in_expr(min_expr, 'math__min') == 0
	assert count_math_selector_calls_in_expr(min_expr, 'math', 'min') == 0
	assert count_math_call_name_in_pending(t.pending_stmts, 'math__min') == 0
	assert count_math_selector_calls_in_pending(t.pending_stmts, 'math', 'min') == 0

	t.pending_stmts.clear()
	dump_max := ast.Expr(ast.KeywordOperator{
		op:    .key_dump
		exprs: [
			ast.Expr(math_inline_selector_call('max', [
				ast.Expr(ast.InfixExpr{
					op:  token.Token.minus
					lhs: ast.Ident{
						name: 'x'
					}
					rhs: math_inline_number('1')
				}),
				math_inline_number('1'),
			])),
		]
	})
	max_expr := t.transform_expr(dump_max)
	assert count_math_call_name_in_expr(max_expr, 'math__max') == 0
	assert count_math_selector_calls_in_expr(max_expr, 'math', 'max') == 0
	assert count_math_call_name_in_pending(t.pending_stmts, 'math__max') == 0
	assert count_math_selector_calls_in_pending(t.pending_stmts, 'math', 'max') == 0

	mut local_math := math_inline_local_math_transformer()
	local_dump := ast.Expr(ast.KeywordOperator{
		op:    .key_dump
		exprs: [
			ast.Expr(math_inline_selector_call('min', [
				math_inline_number('1'),
				math_inline_number('2'),
			])),
		]
	})
	local_expr := local_math.transform_expr(local_dump)
	assert count_math_call_name_in_expr(local_expr, 'math__min') == 0
	assert count_math_selector_calls_in_expr(local_expr, 'math', 'min') == 1
}

fn test_transformer_flat_dump_math_inline_evaluates_side_effect_args_once() {
	mut t := math_inline_test_transformer('math', 'math', math_inline_repo_file())
	dump_min := ast.Expr(ast.KeywordOperator{
		op:    .key_dump
		exprs: [
			ast.Expr(math_inline_selector_call('min', [
				math_inline_next_call(),
				math_inline_next_call(),
			])),
		]
	})
	mut builder := ast.new_flat_builder()
	cursor := math_inline_emit_expr_cursor(mut builder, dump_min)
	mut out := ast.new_flat_builder()
	out_id := t.transform_expr_cursor_to_flat(cursor, mut out)
	expr := out.flat.decode_expr(out_id)
	assert t.pending_stmts.len == 2
	assert count_math_call_name_in_pending(t.pending_stmts, 'next') == 2
	assert count_math_call_name_in_expr(expr, 'next') == 0
	assert count_math_selector_calls_in_expr(expr, 'math', 'min') == 0
}

fn test_transformer_flat_math_inline_rejects_non_math_alias_and_wrong_arity() {
	mut local_math := math_inline_local_math_transformer()
	mut local_builder := ast.new_flat_builder()
	local_cursor := math_inline_emit_expr_cursor(mut local_builder, ast.Expr(math_inline_selector_call('min', [
		math_inline_number('1'),
		math_inline_number('2'),
	])))
	assert !local_math.call_selector_is_official_math_inline_cursor(local_cursor)

	mut aliased := math_inline_test_transformer('math', 'othermath', math_inline_repo_file())
	mut alias_builder := ast.new_flat_builder()
	alias_cursor := math_inline_emit_expr_cursor(mut alias_builder, ast.Expr(math_inline_selector_call('max', [
		math_inline_number('1'),
		math_inline_number('2'),
	])))
	assert !aliased.call_selector_is_official_math_inline_cursor(alias_cursor)

	mut wrong_arity := math_inline_test_transformer('math', 'math', math_inline_repo_file())
	mut arity_builder := ast.new_flat_builder()
	arity_cursor := math_inline_emit_expr_cursor(mut arity_builder, ast.Expr(math_inline_selector_call('min', [
		math_inline_number('1'),
	])))
	assert !wrong_arity.call_selector_is_official_math_inline_cursor(arity_cursor)
}

fn test_transformer_inlines_official_math_min_max_clip_with_temps() {
	mut t := math_inline_test_transformer('math', 'math', math_inline_repo_file())
	min_out := t.transform_call_expr(math_inline_selector_call('min', [
		math_inline_number('1'),
		math_inline_number('2'),
	]))
	assert min_out is ast.IfExpr
	assert t.pending_stmts.len == 2
	assert count_math_selector_calls_in_pending(t.pending_stmts, 'math', 'min') == 0
	assert count_math_selector_calls_in_expr(min_out, 'math', 'min') == 0

	t.pending_stmts.clear()
	max_out := t.transform_call_expr(math_inline_selector_call('max', [
		math_inline_cast('f32', '1'),
		math_inline_cast('f32', '2'),
	]))
	assert max_out is ast.IfExpr
	assert t.pending_stmts.len == 2
	assert count_math_selector_calls_in_pending(t.pending_stmts, 'math', 'max') == 0
	assert count_math_selector_calls_in_expr(max_out, 'math', 'max') == 0

	t.pending_stmts.clear()
	clip_out := t.transform_call_expr(math_inline_selector_call('clip', [
		math_inline_cast('f64', '0.5'),
		math_inline_cast('f64', '0.0'),
		math_inline_cast('f64', '1.0'),
	]))
	assert clip_out is ast.IfExpr
	assert t.pending_stmts.len == 3
	assert count_math_selector_calls_in_pending(t.pending_stmts, 'math', 'clip') == 0
	assert count_math_selector_calls_in_expr(clip_out, 'math', 'clip') == 0

	t.pending_stmts.clear()
	mixed_out := t.transform_call_expr(math_inline_selector_call('clip', [
		math_inline_cast('f32', '5'),
		math_inline_number('0'),
		math_inline_number('10'),
	]))
	assert mixed_out is ast.IfExpr
	assert t.pending_stmts.len == 3
	assert count_math_selector_calls_in_pending(t.pending_stmts, 'math', 'clip') == 0
	assert count_math_selector_calls_in_expr(mixed_out, 'math', 'clip') == 0
}

fn test_transformer_math_inline_evaluates_side_effect_args_once() {
	mut t := math_inline_test_transformer('math', 'math', math_inline_repo_file())
	min_out := t.transform_call_expr(math_inline_selector_call('min', [
		math_inline_next_call(),
		math_inline_next_call(),
	]))
	assert min_out is ast.IfExpr
	assert t.pending_stmts.len == 2
	assert count_math_call_name_in_pending(t.pending_stmts, 'next') == 2
	assert count_math_call_name_in_expr(min_out, 'next') == 0
	assert count_math_selector_calls_in_expr(min_out, 'math', 'min') == 0

	t.pending_stmts.clear()
	clip_out := t.transform_call_expr(math_inline_selector_call('clip', [
		math_inline_next_call(),
		math_inline_next_call(),
		math_inline_next_call(),
	]))
	assert clip_out is ast.IfExpr
	assert t.pending_stmts.len == 3
	assert count_math_call_name_in_pending(t.pending_stmts, 'next') == 3
	assert count_math_call_name_in_expr(clip_out, 'next') == 0
	assert count_math_selector_calls_in_expr(clip_out, 'math', 'clip') == 0
}

fn test_transformer_math_clip_preserves_source_branch_order_with_reversed_bounds() {
	mut t := math_inline_test_transformer('math', 'math', math_inline_repo_file())
	clip_out := t.transform_call_expr(math_inline_selector_call('clip', [
		math_inline_number('5'),
		math_inline_number('10'),
		math_inline_number('0'),
	]))
	assert clip_out is ast.IfExpr
	top := clip_out as ast.IfExpr
	assert top.cond is ast.InfixExpr
	top_cond := top.cond as ast.InfixExpr
	assert top_cond.op == token.Token.gt
	assert top.else_expr is ast.IfExpr
	nested := top.else_expr as ast.IfExpr
	assert nested.cond is ast.InfixExpr
	nested_cond := nested.cond as ast.InfixExpr
	assert nested_cond.op == token.Token.lt
	assert t.pending_stmts.len == 3
}

fn test_transformer_does_not_inline_local_math_receiver_methods() {
	mut t := math_inline_local_math_transformer()
	min_out := t.transform_call_expr(math_inline_selector_call('min', [
		math_inline_number('1'),
		math_inline_number('2'),
	]))
	assert min_out is ast.CallExpr
	assert count_math_selector_calls_in_expr(min_out, 'math', 'min') == 1
	assert t.pending_stmts.len == 0

	max_out := t.transform_call_expr(math_inline_selector_call('max', [
		math_inline_number('1'),
		math_inline_number('2'),
	]))
	assert max_out is ast.CallExpr
	assert count_math_selector_calls_in_expr(max_out, 'math', 'max') == 1
	assert t.pending_stmts.len == 0

	clip_out := t.transform_call_expr(math_inline_selector_call('clip', [
		math_inline_number('1'),
		math_inline_number('0'),
		math_inline_number('2'),
	]))
	assert clip_out is ast.CallExpr
	assert count_math_selector_calls_in_expr(clip_out, 'math', 'clip') == 1
	assert t.pending_stmts.len == 0
}

fn test_transformer_does_not_inline_non_math_modules_or_aliases() {
	mut non_math := math_inline_test_transformer('othermath', 'othermath', math_inline_repo_file())
	other_out := non_math.transform_call_expr(math_inline_selector_call_with_lhs('othermath',
		'min', [
		math_inline_number('1'),
		math_inline_number('2'),
	]))
	assert other_out is ast.CallExpr
	assert count_math_selector_calls_in_expr(other_out, 'othermath', 'min') == 1
	assert non_math.pending_stmts.len == 0

	mut aliased := math_inline_test_transformer('math', 'othermath', math_inline_repo_file())
	alias_out := aliased.transform_call_expr(math_inline_selector_call('max', [
		math_inline_number('1'),
		math_inline_number('2'),
	]))
	assert alias_out is ast.CallExpr
	assert count_math_selector_calls_in_expr(alias_out, 'math', 'max') == 1
	assert aliased.pending_stmts.len == 0

	tmp_dir := os.join_path(os.temp_dir(), 'v2_math_inline_local_${os.getpid()}')
	os.mkdir_all(os.join_path(tmp_dir, 'math')) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}
	os.write_file(os.join_path(tmp_dir, 'math', 'math.v'),
		'module math\npub fn min(a int, b int) int { return a }\n') or { panic(err) }
	local_file := os.join_path(tmp_dir, 'main.v')
	os.write_file(local_file, 'module main\nimport math\n') or { panic(err) }
	mut local_math := math_inline_test_transformer('math', 'math', local_file)
	local_out := local_math.transform_call_expr(math_inline_selector_call('min', [
		math_inline_number('1'),
		math_inline_number('2'),
	]))
	assert local_out is ast.CallExpr
	assert count_math_selector_calls_in_expr(local_out, 'math', 'min') == 1
	assert local_math.pending_stmts.len == 0
}

fn test_transformer_does_not_inline_math_wrong_arity() {
	mut t := math_inline_test_transformer('math', 'math', math_inline_repo_file())
	min_out := t.transform_call_expr(math_inline_selector_call('min', [
		math_inline_number('1'),
	]))
	assert min_out is ast.CallExpr
	assert count_math_selector_calls_in_expr(min_out, 'math', 'min') == 1
	assert t.pending_stmts.len == 0

	max_out := t.transform_call_expr(math_inline_selector_call('max', [
		math_inline_number('1'),
		math_inline_number('2'),
		math_inline_number('3'),
	]))
	assert max_out is ast.CallExpr
	assert count_math_selector_calls_in_expr(max_out, 'math', 'max') == 1
	assert t.pending_stmts.len == 0

	clip_out := t.transform_call_expr(math_inline_selector_call('clip', [
		math_inline_number('1'),
		math_inline_number('2'),
	]))
	assert clip_out is ast.CallExpr
	assert count_math_selector_calls_in_expr(clip_out, 'math', 'clip') == 1
	assert t.pending_stmts.len == 0
}
