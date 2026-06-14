module types

import v2.ast

fn test_autofree_resource_shape_public_entrypoint_scalar() {
	mut env := Environment{}
	shape := env.autofree_resource_shape(Type(int_))
	assert shape.kind == .no_resource
	assert !shape.needs_autofree()
}

fn test_autofree_resource_shape_classifies_string() {
	shape := autofree_resource_shape_for_type(Type(string_))
	assert shape.kind == .string_
	assert shape.has_owned_resource
	assert shape.needs_autofree()
}

fn test_autofree_resource_shape_preserves_alias_identity() {
	scalar_alias := autofree_resource_shape_for_type(Type(Alias{
		name:      'ScalarAlias'
		base_type: Type(int_)
	}))
	assert scalar_alias.kind == .alias
	assert scalar_alias.identity == 'ScalarAlias'
	assert scalar_alias.target_kind == .no_resource
	assert !scalar_alias.has_owned_resource
	assert !scalar_alias.needs_autofree()

	resource_alias := autofree_resource_shape_for_type(Type(Alias{
		name:      'ResourceAlias'
		base_type: Type(string_)
	}))
	assert resource_alias.kind == .alias
	assert resource_alias.identity == 'ResourceAlias'
	assert resource_alias.target_kind == .string_
	assert resource_alias.has_owned_resource
	assert resource_alias.needs_autofree()
}

fn test_autofree_resource_shape_preserves_alias_map_details() {
	string_type := Type(string_)
	int_type := Type(int_)

	map_key_alias := autofree_resource_shape_for_type(Type(Alias{
		name:      'MapKeyAlias'
		base_type: Type(Map{
			key_type:   string_type
			value_type: int_type
		})
	}))
	assert map_key_alias.kind == .alias
	assert map_key_alias.target_kind == .map_
	assert map_key_alias.map_container_owned
	assert map_key_alias.map_container_may_need_free
	assert map_key_alias.map_key_kind == .string_
	assert map_key_alias.map_value_kind == .no_resource
	assert map_key_alias.map_key_owned
	assert !map_key_alias.map_value_owned
	assert map_key_alias.map_key_may_need_free
	assert !map_key_alias.map_value_may_need_free
	assert map_key_alias.needs_autofree()

	map_value_alias := autofree_resource_shape_for_type(Type(Alias{
		name:      'MapValueAlias'
		base_type: Type(Map{
			key_type:   int_type
			value_type: string_type
		})
	}))
	assert map_value_alias.kind == .alias
	assert map_value_alias.target_kind == .map_
	assert map_value_alias.map_container_owned
	assert map_value_alias.map_container_may_need_free
	assert map_value_alias.map_key_kind == .no_resource
	assert map_value_alias.map_value_kind == .string_
	assert !map_value_alias.map_key_owned
	assert map_value_alias.map_value_owned
	assert !map_value_alias.map_key_may_need_free
	assert map_value_alias.map_value_may_need_free
	assert map_value_alias.needs_autofree()

	map_pair_alias := autofree_resource_shape_for_type(Type(Alias{
		name:      'MapPairAlias'
		base_type: Type(Map{
			key_type:   string_type
			value_type: string_type
		})
	}))
	assert map_pair_alias.kind == .alias
	assert map_pair_alias.target_kind == .map_
	assert map_pair_alias.map_container_owned
	assert map_pair_alias.map_container_may_need_free
	assert map_pair_alias.map_key_kind == .string_
	assert map_pair_alias.map_value_kind == .string_
	assert map_pair_alias.map_key_owned
	assert map_pair_alias.map_value_owned
	assert map_pair_alias.map_key_may_need_free
	assert map_pair_alias.map_value_may_need_free
	assert map_pair_alias.needs_autofree()

	map_scalar_alias := autofree_resource_shape_for_type(Type(Alias{
		name:      'MapScalarAlias'
		base_type: Type(Map{
			key_type:   int_type
			value_type: int_type
		})
	}))
	assert map_scalar_alias.kind == .alias
	assert map_scalar_alias.target_kind == .map_
	assert map_scalar_alias.map_container_owned
	assert map_scalar_alias.map_container_may_need_free
	assert map_scalar_alias.map_key_kind == .no_resource
	assert map_scalar_alias.map_value_kind == .no_resource
	assert !map_scalar_alias.map_key_owned
	assert !map_scalar_alias.map_value_owned
	assert !map_scalar_alias.map_key_may_need_free
	assert !map_scalar_alias.map_value_may_need_free
	assert map_scalar_alias.has_owned_resource
	assert map_scalar_alias.needs_autofree()
}

fn test_autofree_resource_shape_borrowed_pointer_is_no_free() {
	string_type := Type(string_)
	pointer_type := Type(Pointer{
		base_type: string_type
	})
	shape := autofree_resource_shape_for_type(pointer_type)
	assert shape.kind == .borrowed_pointer
	assert !shape.has_owned_resource
	assert !shape.needs_autofree()
}

fn test_autofree_resource_shape_uses_struct_shape_not_tricky_name() {
	int_type := Type(int_)
	mut fields := []Field{}
	fields << Field{
		name: 'id'
		typ:  int_type
	}
	struct_type := Type(Struct{
		name:   'contains_string'
		fields: fields
	})

	shape := autofree_resource_shape_for_type(struct_type)
	assert shape.kind == .struct_
	assert shape.identity == 'contains_string'
	assert !shape.has_owned_resource
	assert !shape.needs_autofree()
}

fn test_autofree_resource_shape_embedded_struct_depth_guard_fails_closed() {
	mut deep := Struct{
		name: 'deep_leaf'
	}
	for i := 0; i < 70; i++ {
		deep = Struct{
			name:     'deep_${i}'
			embedded: [deep]
		}
	}

	shape := autofree_resource_shape_for_type(Type(deep))
	assert shape.kind == .ambiguous
	assert shape.fail_closed
	assert !shape.needs_autofree()
}

fn test_autofree_resource_shape_classifies_wrapped_resources() {
	string_type := Type(string_)
	array_shape := autofree_resource_shape_for_type(Type(Array{
		elem_type: string_type
	}))
	assert array_shape.kind == .array
	assert array_shape.target_kind == .string_
	assert array_shape.needs_autofree()

	fixed_shape := autofree_resource_shape_for_type(Type(ArrayFixed{
		len:       4
		elem_type: string_type
	}))
	assert fixed_shape.kind == .array_fixed
	assert fixed_shape.target_kind == .string_
	assert fixed_shape.needs_autofree()

	fixed_scalar_shape := autofree_resource_shape_for_type(Type(ArrayFixed{
		len:       4
		elem_type: Type(int_)
	}))
	assert fixed_scalar_shape.kind == .array_fixed
	assert fixed_scalar_shape.target_kind == .no_resource
	assert !fixed_scalar_shape.needs_autofree()

	option_shape := autofree_resource_shape_for_type(Type(OptionType{
		base_type: string_type
	}))
	assert option_shape.kind == .option
	assert option_shape.target_kind == .string_
	assert option_shape.needs_autofree()

	result_shape := autofree_resource_shape_for_type(Type(ResultType{
		base_type: string_type
	}))
	assert result_shape.kind == .result
	assert result_shape.target_kind == .string_
	assert result_shape.needs_autofree()
}

fn test_autofree_resource_shape_merges_composites() {
	string_type := Type(string_)
	int_type := Type(int_)
	map_string_key_shape := autofree_resource_shape_for_type(Type(Map{
		key_type:   string_type
		value_type: int_type
	}))
	assert map_string_key_shape.kind == .map_
	assert map_string_key_shape.map_container_owned
	assert map_string_key_shape.map_container_may_need_free
	assert map_string_key_shape.map_key_kind == .string_
	assert map_string_key_shape.map_value_kind == .no_resource
	assert map_string_key_shape.map_key_owned
	assert !map_string_key_shape.map_value_owned
	assert map_string_key_shape.map_key_may_need_free
	assert !map_string_key_shape.map_value_may_need_free
	assert map_string_key_shape.has_owned_resource
	assert map_string_key_shape.needs_autofree()

	map_string_value_shape := autofree_resource_shape_for_type(Type(Map{
		key_type:   int_type
		value_type: string_type
	}))
	assert map_string_value_shape.kind == .map_
	assert map_string_value_shape.map_container_owned
	assert map_string_value_shape.map_container_may_need_free
	assert map_string_value_shape.map_key_kind == .no_resource
	assert map_string_value_shape.map_value_kind == .string_
	assert !map_string_value_shape.map_key_owned
	assert map_string_value_shape.map_value_owned
	assert !map_string_value_shape.map_key_may_need_free
	assert map_string_value_shape.map_value_may_need_free
	assert map_string_value_shape.has_owned_resource
	assert map_string_value_shape.needs_autofree()

	map_string_pair_shape := autofree_resource_shape_for_type(Type(Map{
		key_type:   string_type
		value_type: string_type
	}))
	assert map_string_pair_shape.kind == .map_
	assert map_string_pair_shape.map_container_owned
	assert map_string_pair_shape.map_container_may_need_free
	assert map_string_pair_shape.map_key_kind == .string_
	assert map_string_pair_shape.map_value_kind == .string_
	assert map_string_pair_shape.map_key_owned
	assert map_string_pair_shape.map_value_owned
	assert map_string_pair_shape.map_key_may_need_free
	assert map_string_pair_shape.map_value_may_need_free
	assert map_string_pair_shape.has_owned_resource
	assert map_string_pair_shape.needs_autofree()

	map_scalar_shape := autofree_resource_shape_for_type(Type(Map{
		key_type:   int_type
		value_type: int_type
	}))
	assert map_scalar_shape.kind == .map_
	assert map_scalar_shape.map_container_owned
	assert map_scalar_shape.map_container_may_need_free
	assert map_scalar_shape.map_key_kind == .no_resource
	assert map_scalar_shape.map_value_kind == .no_resource
	assert !map_scalar_shape.map_key_owned
	assert !map_scalar_shape.map_value_owned
	assert !map_scalar_shape.map_key_may_need_free
	assert !map_scalar_shape.map_value_may_need_free
	assert map_scalar_shape.has_owned_resource
	assert map_scalar_shape.needs_autofree()

	tuple_shape := autofree_resource_shape_for_type(Type(Tuple{
		types: [int_type, string_type]
	}))
	assert tuple_shape.kind == .tuple
	assert tuple_shape.has_owned_resource
	assert tuple_shape.needs_autofree()
}

fn test_autofree_fn_key_matches_codegen_names() {
	assert autofree_fn_key('', 'store', '') == 'store'
	assert autofree_fn_key('main', 'store', '') == 'store'
	assert autofree_fn_key('main', 'main', '') == 'main'
	assert autofree_fn_key('math', 'sum', '') == 'math__sum'
	assert autofree_fn_key('math', 'math__sum', '') == 'math__sum'
	assert autofree_fn_key('builtin', 'len', '') == 'len'
	assert autofree_fn_key('builtin', 'panic', '') == 'v_panic'
	assert autofree_fn_key('builtin', 'v_panic', '') == 'v_panic'
	assert autofree_fn_key('', 'push', 'Bucket') == 'Bucket__push'
	assert autofree_fn_key('main', 'push', 'Bucket') == 'Bucket__push'
	assert autofree_fn_key('main', 'push', 'main__Bucket') == 'Bucket__push'
	assert autofree_fn_key('math', 'push', 'Bucket') == 'math__Bucket__push'
	assert autofree_fn_key('math', 'push', 'math__Bucket') == 'math__Bucket__push'
	assert autofree_fn_key('math', 'push', 'other__Bucket') == 'other__Bucket__push'
	assert autofree_fn_key('builtin', 'trim', 'string') == 'string__trim'
	assert autofree_fn_key('builtin', 'trim', 'builtin__string') == 'string__trim'
}

fn test_autofree_facts_carry_complete_map_shape() {
	map_shape := autofree_resource_shape_for_type(Type(Map{
		key_type:   Type(string_)
		value_type: Type(int_)
	}))
	fn_key := autofree_fn_key('main', 'store', '')
	binding := AutofreeBindingFact{
		fn_key:   fn_key
		fn_name:  'store'
		name:     'items'
		resource: .map_container
		shape:    map_shape
	}
	assert binding.fn_key == 'store'
	assert binding.fn_name == 'store'
	assert binding.shape.kind == .map_
	assert binding.shape.map_container_may_need_free
	assert binding.shape.map_key_kind == .string_
	assert binding.shape.map_value_kind == .no_resource
	assert binding.shape.map_key_may_need_free
	assert !binding.shape.map_value_may_need_free

	transfer := AutofreeTransferFact{
		fn_key:  fn_key
		fn_name: 'store'
		kind:    .map_set
		action:  .ambiguous_no_free
		shape:   map_shape
	}
	assert transfer.fn_key == 'store'
	assert transfer.fn_name == 'store'
	assert transfer.shape.kind == .map_
	assert transfer.shape.map_container_may_need_free
	assert transfer.shape.map_key_kind == .string_
	assert transfer.shape.map_value_kind == .no_resource
	assert transfer.shape.map_key_may_need_free
	assert !transfer.shape.map_value_may_need_free
}

fn test_autofree_fresh_local_fact_model_resets_with_pipeline() {
	array_type := Type(Array{
		elem_type: Type(int_)
	})
	array_shape := autofree_resource_shape_for_type(array_type)
	array_type_name := array_type.name()
	endpoint := AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    'items'
		name:         'items'
		root_node_id: 1
		root_pos_id:  10
		node_id:      1
		pos_id:       10
		has_type:     true
		typ:          array_type
		type_name:    array_type_name
		resource:     .array_value
		shape:        array_shape
		state:        .owned_unique
	}
	source_endpoint := AutofreeTransferEndpoint{
		storage:      .literal
		root_storage: .literal
		root_name:    'array literal'
		name:         'array literal'
		root_node_id: 2
		root_pos_id:  11
		node_id:      2
		pos_id:       11
		has_type:     true
		typ:          array_type
		type_name:    array_type_name
		resource:     .array_value
		shape:        array_shape
		state:        .owned_unique
	}
	fact := AutofreeFreshLocalFact{
		fn_key:          'make_items'
		fn_name:         'make_items'
		name:            'items'
		endpoint:        endpoint
		source_endpoint: source_endpoint
		state:           .owned_unique
		resource:        .array_value
		shape:           array_shape
		typ:             array_type
		type_name:       array_type_name
		node_id:         1
		pos_id:          10
		stmt_node_id:    3
		stmt_pos_id:     200
		reason:          'empty dynamic array literal'
	}
	assert fact.endpoint.storage == .local
	assert fact.endpoint.state == .owned_unique
	assert fact.source_endpoint.storage == .literal
	assert fact.shape.kind == .array
	assert fact.shape.needs_autofree()
	assert fact.type_name.len > 0
	assert fact.type_name == array_type_name
	assert fact.endpoint.type_name == array_type_name
	assert fact.source_endpoint.type_name == array_type_name

	proof := AutofreeMoveProofFact{
		fn_key:          'make_items'
		fn_name:         'make_items'
		name:            'items'
		kind:            .fresh_local_binding
		source_endpoint: source_endpoint
		target_endpoint: endpoint
		state:           .owned_unique
		resource:        .array_value
		shape:           array_shape
		typ:             array_type
		type_name:       array_type_name
		node_id:         1
		pos_id:          10
		stmt_node_id:    3
		stmt_pos_id:     200
		reason:          'fresh local candidate'
	}
	assert proof.kind == .fresh_local_binding
	assert proof.source_endpoint.storage == .literal
	assert proof.target_endpoint.storage == .local
	assert proof.source_endpoint.root_node_id == source_endpoint.root_node_id
	assert proof.target_endpoint.root_node_id == endpoint.root_node_id
	assert proof.state == .owned_unique
	assert proof.shape.kind == .array
	assert proof.shape.needs_autofree()
	assert proof.type_name.len > 0
	assert proof.type_name == array_type_name
	assert proof.source_endpoint.type_name == array_type_name
	assert proof.target_endpoint.type_name == array_type_name

	candidate := AutofreeNaturalReleaseCandidateFact{
		fn_key:                'make_items'
		fn_name:               'make_items'
		name:                  'items'
		move_kind:             .fresh_local_binding
		source_endpoint:       source_endpoint
		endpoint:              endpoint
		state:                 .owned_unique
		resource:              .array_value
		shape:                 array_shape
		typ:                   array_type
		type_name:             array_type_name
		node_id:               1
		pos_id:                10
		proof_node_id:         proof.node_id
		proof_pos_id:          proof.pos_id
		release_after_node_id: proof.stmt_node_id
		release_after_pos_id:  proof.stmt_pos_id
		reason:                'natural local cleanup candidate'
	}
	assert candidate.move_kind == .fresh_local_binding
	assert candidate.source_endpoint.storage == .literal
	assert candidate.source_endpoint.root_node_id == proof.source_endpoint.root_node_id
	assert candidate.source_endpoint.root_pos_id == proof.source_endpoint.root_pos_id
	assert candidate.source_endpoint.node_id == proof.source_endpoint.node_id
	assert candidate.source_endpoint.pos_id == proof.source_endpoint.pos_id
	assert candidate.source_endpoint.type_name == array_type_name
	assert candidate.endpoint.storage == .local
	assert candidate.endpoint.root_storage == .local
	assert candidate.endpoint.type_name == array_type_name
	assert candidate.state == .owned_unique
	assert candidate.shape.kind == .array
	assert candidate.shape.needs_autofree()
	assert candidate.type_name.len > 0
	assert candidate.type_name == array_type_name
	assert candidate.proof_node_id == proof.node_id
	assert candidate.proof_pos_id == proof.pos_id
	assert candidate.release_after_node_id == proof.stmt_node_id
	assert candidate.release_after_pos_id == proof.stmt_pos_id

	plan := AutofreeReleasePlanFact{
		fn_key:                'make_items'
		fn_name:               'make_items'
		name:                  'items'
		move_kind:             .fresh_local_binding
		plan_kind:             .natural_exit
		plan_action:           .array_container_cleanup
		helper_requirement:    .none
		source_endpoint:       source_endpoint
		endpoint:              endpoint
		state:                 .owned_unique
		resource:              .array_value
		shape:                 array_shape
		typ:                   array_type
		type_name:             array_type_name
		node_id:               1
		pos_id:                10
		proof_node_id:         proof.node_id
		proof_pos_id:          proof.pos_id
		release_after_node_id: proof.stmt_node_id
		release_after_pos_id:  proof.stmt_pos_id
		reason:                'natural release plan'
	}
	assert plan.move_kind == .fresh_local_binding
	assert plan.plan_kind == .natural_exit
	assert plan.plan_action == .array_container_cleanup
	assert plan.helper_requirement == .none
	assert plan.source_endpoint.storage == .literal
	assert plan.source_endpoint.root_node_id == proof.source_endpoint.root_node_id
	assert plan.source_endpoint.root_pos_id == proof.source_endpoint.root_pos_id
	assert plan.source_endpoint.node_id == proof.source_endpoint.node_id
	assert plan.source_endpoint.pos_id == proof.source_endpoint.pos_id
	assert plan.endpoint.storage == .local
	assert plan.endpoint.root_storage == .local
	assert plan.endpoint.type_name == array_type_name
	assert plan.state == .owned_unique
	assert plan.resource == .array_value
	assert plan.shape.kind == .array
	assert plan.shape.needs_autofree()
	assert plan.type_name == array_type_name
	assert plan.proof_node_id == proof.node_id
	assert plan.proof_pos_id == proof.pos_id
	assert plan.release_after_node_id == proof.stmt_node_id
	assert plan.release_after_pos_id == proof.stmt_pos_id

	preflight := AutofreeReleasePreflightFact{
		fn_key:                'make_items'
		fn_name:               'make_items'
		name:                  'items'
		move_kind:             .fresh_local_binding
		plan_kind:             .natural_exit
		plan_action:           .array_container_cleanup
		helper_requirement:    .none
		preflight_status:      .inert
		source_endpoint:       source_endpoint
		endpoint:              endpoint
		state:                 .owned_unique
		resource:              .array_value
		shape:                 array_shape
		typ:                   array_type
		type_name:             array_type_name
		node_id:               1
		pos_id:                10
		proof_node_id:         proof.node_id
		proof_pos_id:          proof.pos_id
		release_after_node_id: proof.stmt_node_id
		release_after_pos_id:  proof.stmt_pos_id
		reason:                'release preflight'
	}
	assert preflight.move_kind == .fresh_local_binding
	assert preflight.plan_kind == .natural_exit
	assert preflight.plan_action == .array_container_cleanup
	assert preflight.helper_requirement == .none
	assert preflight.preflight_status == .inert
	assert preflight.source_endpoint.storage == .literal
	assert preflight.source_endpoint.root_node_id == proof.source_endpoint.root_node_id
	assert preflight.source_endpoint.root_pos_id == proof.source_endpoint.root_pos_id
	assert preflight.source_endpoint.node_id == proof.source_endpoint.node_id
	assert preflight.source_endpoint.pos_id == proof.source_endpoint.pos_id
	assert preflight.endpoint.storage == .local
	assert preflight.endpoint.root_storage == .local
	assert preflight.endpoint.type_name == array_type_name
	assert preflight.state == .owned_unique
	assert preflight.resource == .array_value
	assert preflight.shape.kind == .array
	assert preflight.shape.needs_autofree()
	assert preflight.type_name == array_type_name
	assert preflight.proof_node_id == proof.node_id
	assert preflight.proof_pos_id == proof.pos_id
	assert preflight.release_after_node_id == proof.stmt_node_id
	assert preflight.release_after_pos_id == proof.stmt_pos_id

	insertion_point := AutofreeReleaseInsertionPointFact{
		fn_key:                'make_items'
		fn_name:               'make_items'
		name:                  'items'
		move_kind:             .fresh_local_binding
		plan_kind:             .natural_exit
		plan_action:           .array_container_cleanup
		helper_requirement:    .none
		preflight_status:      .inert
		insertion_kind:        .after_statement
		insertion_status:      .inert
		source_endpoint:       source_endpoint
		endpoint:              endpoint
		state:                 .owned_unique
		resource:              .array_value
		shape:                 array_shape
		typ:                   array_type
		type_name:             array_type_name
		node_id:               1
		pos_id:                10
		proof_node_id:         proof.node_id
		proof_pos_id:          proof.pos_id
		release_after_node_id: proof.stmt_node_id
		release_after_pos_id:  proof.stmt_pos_id
		insert_after_node_id:  proof.stmt_node_id
		insert_after_pos_id:   proof.stmt_pos_id
		reason:                'release insertion point'
	}
	assert insertion_point.move_kind == .fresh_local_binding
	assert insertion_point.plan_kind == .natural_exit
	assert insertion_point.plan_action == .array_container_cleanup
	assert insertion_point.helper_requirement == .none
	assert insertion_point.preflight_status == .inert
	assert insertion_point.insertion_kind == .after_statement
	assert insertion_point.insertion_status == .inert
	assert insertion_point.source_endpoint.storage == .literal
	assert insertion_point.source_endpoint.root_node_id == proof.source_endpoint.root_node_id
	assert insertion_point.source_endpoint.root_pos_id == proof.source_endpoint.root_pos_id
	assert insertion_point.source_endpoint.node_id == proof.source_endpoint.node_id
	assert insertion_point.source_endpoint.pos_id == proof.source_endpoint.pos_id
	assert insertion_point.endpoint.storage == .local
	assert insertion_point.endpoint.root_storage == .local
	assert insertion_point.endpoint.type_name == array_type_name
	assert insertion_point.state == .owned_unique
	assert insertion_point.resource == .array_value
	assert insertion_point.shape.kind == .array
	assert insertion_point.shape.needs_autofree()
	assert insertion_point.type_name == array_type_name
	assert insertion_point.proof_node_id == proof.node_id
	assert insertion_point.proof_pos_id == proof.pos_id
	assert insertion_point.release_after_node_id == proof.stmt_node_id
	assert insertion_point.release_after_pos_id == proof.stmt_pos_id
	assert insertion_point.insert_after_node_id == insertion_point.release_after_node_id
	assert insertion_point.insert_after_pos_id == insertion_point.release_after_pos_id

	mut env := Environment{}
	env.autofree_fresh_locals_by_fn_key = map[string][]AutofreeFreshLocalFact{}
	env.autofree_move_proofs_by_fn_key = map[string][]AutofreeMoveProofFact{}
	env.autofree_natural_release_candidates_by_fn_key = map[string][]AutofreeNaturalReleaseCandidateFact{}
	env.autofree_release_plans_by_fn_key = map[string][]AutofreeReleasePlanFact{}
	env.autofree_release_preflights_by_fn_key = map[string][]AutofreeReleasePreflightFact{}
	env.autofree_release_insertion_points_by_fn_key = map[string][]AutofreeReleaseInsertionPointFact{}
	env.autofree_fresh_locals_by_fn_key['make_items'] = [fact]
	env.autofree_move_proofs_by_fn_key['make_items'] = [proof]
	env.autofree_natural_release_candidates_by_fn_key['make_items'] = [candidate]
	env.autofree_release_plans_by_fn_key['make_items'] = [plan]
	env.autofree_release_preflights_by_fn_key['make_items'] = [preflight]
	env.autofree_release_insertion_points_by_fn_key['make_items'] = [insertion_point]
	flat := ast.FlatAst{
		nodes: []ast.FlatNode{len: 3}
	}
	env.reset_autofree_facts_for_flat(&flat)
	assert env.autofree_pipeline.flat_nodes == 3
	assert env.autofree_fresh_locals_by_fn_key.len == 0
	assert env.autofree_move_proofs_by_fn_key.len == 0
	assert env.autofree_natural_release_candidates_by_fn_key.len == 0
	assert env.autofree_release_plans_by_fn_key.len == 0
	assert env.autofree_release_preflights_by_fn_key.len == 0
	assert env.autofree_release_insertion_points_by_fn_key.len == 0
	assert env.autofree_transfers_by_fn_key.len == 0
	assert env.autofree_release_eligibility_by_fn_key.len == 0
	assert env.autofree_releases_by_fn_key.len == 0
	assert env.autofree_helper_roots.len == 0
}

fn test_autofree_move_proof_facts_use_fn_key_lookup() {
	array_type := Type(Array{
		elem_type: Type(int_)
	})
	array_shape := autofree_resource_shape_for_type(array_type)
	array_type_name := array_type.name()
	endpoint := AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    'items'
		name:         'items'
		root_node_id: 1
		root_pos_id:  10
		node_id:      1
		pos_id:       10
		has_type:     true
		typ:          array_type
		type_name:    array_type_name
		resource:     .array_value
		shape:        array_shape
		state:        .owned_unique
	}
	source_endpoint := AutofreeTransferEndpoint{
		storage:      .literal
		root_storage: .literal
		root_name:    'array literal'
		name:         'array literal'
		root_node_id: 2
		root_pos_id:  11
		node_id:      2
		pos_id:       11
		has_type:     true
		typ:          array_type
		type_name:    array_type_name
		resource:     .array_value
		shape:        array_shape
		state:        .owned_unique
	}
	fn_key := autofree_fn_key('math', 'make_items', '')
	proof := AutofreeMoveProofFact{
		fn_key:          fn_key
		fn_name:         'make_items'
		name:            'items'
		kind:            .fresh_local_binding
		source_endpoint: source_endpoint
		target_endpoint: endpoint
		state:           .owned_unique
		resource:        .array_value
		shape:           array_shape
		typ:             array_type
		type_name:       array_type_name
		node_id:         1
		pos_id:          10
		reason:          'fresh local candidate'
	}
	mut env := Environment.new()
	env.autofree_move_proofs_by_fn_key = map[string][]AutofreeMoveProofFact{}
	env.autofree_move_proofs_by_fn_key[fn_key] = [proof]

	assert fn_key == 'math__make_items'
	assert fn_key in env.autofree_move_proofs_by_fn_key
	assert 'make_items' !in env.autofree_move_proofs_by_fn_key
	assert env.autofree_move_proofs_by_fn_key[fn_key][0].fn_key == fn_key
	assert env.autofree_move_proofs_by_fn_key[fn_key][0].fn_name == 'make_items'
	assert env.autofree_move_proofs_by_fn_key[fn_key][0].type_name == array_type_name
	assert env.autofree_transfers_by_fn_key.len == 0
	assert env.autofree_release_eligibility_by_fn_key.len == 0
	assert env.autofree_releases_by_fn_key.len == 0
	assert env.autofree_helper_roots.len == 0
}

fn test_autofree_natural_release_candidate_facts_use_fn_key_lookup() {
	array_type := Type(Array{
		elem_type: Type(int_)
	})
	array_shape := autofree_resource_shape_for_type(array_type)
	array_type_name := array_type.name()
	endpoint := AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    'items'
		name:         'items'
		root_node_id: 1
		root_pos_id:  10
		node_id:      1
		pos_id:       10
		has_type:     true
		typ:          array_type
		type_name:    array_type_name
		resource:     .array_value
		shape:        array_shape
		state:        .owned_unique
	}
	fn_key := autofree_fn_key('math', 'make_items', '')
	candidate := AutofreeNaturalReleaseCandidateFact{
		fn_key:                fn_key
		fn_name:               'make_items'
		name:                  'items'
		move_kind:             .fresh_local_binding
		source_endpoint:       AutofreeTransferEndpoint{
			storage:      .literal
			root_storage: .literal
			root_name:    'array literal'
			name:         'array literal'
			root_node_id: 2
			root_pos_id:  11
			node_id:      2
			pos_id:       11
			has_type:     true
			typ:          array_type
			type_name:    array_type_name
			resource:     .array_value
			shape:        array_shape
			state:        .owned_unique
		}
		endpoint:              endpoint
		state:                 .owned_unique
		resource:              .array_value
		shape:                 array_shape
		typ:                   array_type
		type_name:             array_type_name
		node_id:               1
		pos_id:                10
		proof_node_id:         1
		proof_pos_id:          10
		release_after_node_id: 3
		release_after_pos_id:  200
		reason:                'natural local cleanup candidate'
	}
	mut env := Environment.new()
	env.autofree_natural_release_candidates_by_fn_key = map[string][]AutofreeNaturalReleaseCandidateFact{}
	env.autofree_natural_release_candidates_by_fn_key[fn_key] = [candidate]

	assert fn_key == 'math__make_items'
	assert fn_key in env.autofree_natural_release_candidates_by_fn_key
	assert 'make_items' !in env.autofree_natural_release_candidates_by_fn_key
	assert env.autofree_natural_release_candidates_by_fn_key[fn_key][0].fn_key == fn_key
	assert env.autofree_natural_release_candidates_by_fn_key[fn_key][0].fn_name == 'make_items'
	assert env.autofree_natural_release_candidates_by_fn_key[fn_key][0].move_kind == .fresh_local_binding
	assert env.autofree_natural_release_candidates_by_fn_key[fn_key][0].source_endpoint.storage == .literal
	assert env.autofree_natural_release_candidates_by_fn_key[fn_key][0].endpoint.root_name == 'items'
	assert env.autofree_natural_release_candidates_by_fn_key[fn_key][0].type_name == array_type_name
	assert env.autofree_natural_release_candidates_by_fn_key[fn_key][0].proof_node_id == 1
	assert env.autofree_natural_release_candidates_by_fn_key[fn_key][0].proof_pos_id == 10
	assert env.autofree_natural_release_candidates_by_fn_key[fn_key][0].release_after_node_id == 3
	assert env.autofree_natural_release_candidates_by_fn_key[fn_key][0].release_after_pos_id == 200
	assert env.autofree_transfers_by_fn_key.len == 0
	assert env.autofree_release_eligibility_by_fn_key.len == 0
	assert env.autofree_releases_by_fn_key.len == 0
	assert env.autofree_helper_roots.len == 0
}

fn test_autofree_transfer_endpoints_separate_map_container_key_and_value() {
	string_type := Type(string_)
	int_type := Type(int_)
	map_type := Type(Map{
		key_type:   string_type
		value_type: int_type
	})
	map_shape := autofree_resource_shape_for_type(map_type)
	key_shape := autofree_resource_shape_for_type(string_type)
	value_shape := autofree_resource_shape_for_type(int_type)

	container_endpoint := AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    'items'
		name:         'items'
		root_node_id: 10
		root_pos_id:  100
		node_id:      10
		pos_id:       100
		has_type:     true
		typ:          map_type
		type_name:    'map[string]int'
		resource:     .map_container
		shape:        map_shape
		state:        .ambiguous_no_free
	}
	key_endpoint := AutofreeTransferEndpoint{
		storage:      .map_key
		root_storage: .local
		root_name:    'items'
		name:         'items[key]'
		root_node_id: 10
		root_pos_id:  100
		node_id:      11
		pos_id:       101
		path:         [
			AutofreeEndpointPathSegment{
				storage:       .map_key
				name:          'key'
				node_id:       11
				pos_id:        101
				index_node_id: 11
				index_pos_id:  101
			},
		]
		has_type:     true
		typ:          string_type
		type_name:    'string'
		resource:     .string_value
		shape:        key_shape
		state:        .ambiguous_no_free
	}
	value_endpoint := AutofreeTransferEndpoint{
		storage:      .map_value
		root_storage: .local
		root_name:    'items'
		name:         'items[key]'
		root_node_id: 10
		root_pos_id:  100
		node_id:      12
		pos_id:       102
		path:         [
			AutofreeEndpointPathSegment{
				storage:       .map_value
				name:          'value'
				node_id:       12
				pos_id:        102
				index_node_id: 11
				index_pos_id:  101
			},
		]
		has_type:     true
		typ:          int_type
		type_name:    'int'
		resource:     .scalar_value
		shape:        value_shape
		state:        .copy_no_resource
	}
	transfer := AutofreeTransferFact{
		fn_key:        'store'
		fn_name:       'store'
		kind:          .map_set
		action:        .ambiguous_no_free
		from_endpoint: AutofreeTransferEndpoint{
			storage:      .literal
			root_storage: .literal
			root_name:    'literal'
			name:         'literal'
			node_id:      13
			pos_id:       103
			has_type:     true
			typ:          int_type
			type_name:    'int'
			resource:     .scalar_value
			shape:        value_shape
			state:        .copy_no_resource
		}
		to_endpoint:   value_endpoint
		from_name:     'value'
		to_name:       'items'
		typ:           map_type
		type_name:     'map[string]int'
		shape:         map_shape
		node_id:       12
		pos_id:        102
		reason:        'map assignment keeps element endpoint details'
	}

	assert container_endpoint.storage == .local
	assert container_endpoint.resource == .map_container
	assert container_endpoint.shape.map_container_may_need_free
	assert key_endpoint.storage == .map_key
	assert key_endpoint.path[0].storage == .map_key
	assert value_endpoint.storage == .map_value
	assert transfer.to_name == 'items'
	assert transfer.to_endpoint.name == 'items[key]'
	assert transfer.to_endpoint.storage == .map_value
	assert transfer.to_endpoint.path[0].storage == .map_value
	assert transfer.from_endpoint.storage == .literal
	assert transfer.shape.map_key_may_need_free
	assert !transfer.shape.map_value_may_need_free
}

fn test_autofree_transfer_endpoints_keep_field_and_array_paths() {
	string_type := Type(string_)
	string_shape := autofree_resource_shape_for_type(string_type)
	field_endpoint := AutofreeTransferEndpoint{
		storage:      .struct_field
		root_storage: .local
		root_name:    'packet'
		name:         'attrs'
		root_node_id: 20
		root_pos_id:  200
		node_id:      21
		pos_id:       201
		path:         [
			AutofreeEndpointPathSegment{
				storage: .struct_field
				name:    'attrs'
				node_id: 21
				pos_id:  201
			},
		]
		has_type:     true
		typ:          string_type
		type_name:    'string'
		resource:     .string_value
		shape:        string_shape
		state:        .ambiguous_no_free
	}
	element_endpoint := AutofreeTransferEndpoint{
		storage:      .array_element
		root_storage: .local
		root_name:    'packet'
		name:         'packet.attrs[i]'
		root_node_id: 20
		root_pos_id:  200
		node_id:      23
		pos_id:       203
		path:         [
			AutofreeEndpointPathSegment{
				storage: .struct_field
				name:    'attrs'
				node_id: 21
				pos_id:  201
			},
			AutofreeEndpointPathSegment{
				storage:       .array_element
				name:          'element'
				node_id:       23
				pos_id:        203
				index_node_id: 22
				index_pos_id:  202
			},
		]
		has_type:     true
		typ:          string_type
		type_name:    'string'
		resource:     .string_value
		shape:        string_shape
		state:        .ambiguous_no_free
	}
	transfer := AutofreeTransferFact{
		fn_key:        'push_attr'
		fn_name:       'push_attr'
		kind:          .array_push
		action:        .ambiguous_no_free
		from_endpoint: field_endpoint
		to_endpoint:   element_endpoint
		from_name:     'attrs'
		to_name:       'packet'
		typ:           string_type
		type_name:     'string'
		shape:         string_shape
	}

	assert transfer.to_name == 'packet'
	assert transfer.to_endpoint.storage == .array_element
	assert transfer.to_endpoint.path.len == 2
	assert transfer.to_endpoint.path[0].storage == .struct_field
	assert transfer.to_endpoint.path[0].name == 'attrs'
	assert transfer.to_endpoint.path[1].storage == .array_element
	assert transfer.from_endpoint.storage == .struct_field
}

fn test_autofree_transfer_endpoints_cover_return_captures_and_sumtype_payload() {
	string_type := Type(string_)
	string_shape := autofree_resource_shape_for_type(string_type)
	call_endpoint := AutofreeTransferEndpoint{
		storage:      .call_result
		root_storage: .call_result
		root_name:    'make_value'
		name:         'make_value()'
		node_id:      30
		pos_id:       300
		has_type:     true
		typ:          string_type
		type_name:    'string'
		resource:     .string_value
		shape:        string_shape
		state:        .ambiguous_no_free
	}
	return_endpoint := AutofreeTransferEndpoint{
		storage:      .return_value
		root_storage: .return_value
		root_name:    'return'
		name:         'return'
		node_id:      31
		pos_id:       301
		has_type:     true
		typ:          string_type
		type_name:    'string'
		resource:     .string_value
		shape:        string_shape
		state:        .ambiguous_no_free
	}
	closure_endpoint := AutofreeTransferEndpoint{
		storage:      .closure_capture
		root_storage: .local
		root_name:    'line'
		name:         'line'
		node_id:      32
		pos_id:       302
		has_type:     true
		typ:          string_type
		type_name:    'string'
		resource:     .string_value
		shape:        string_shape
		state:        .borrowed_no_free
	}
	spawn_endpoint := AutofreeTransferEndpoint{
		storage:      .spawn_capture
		root_storage: .local
		root_name:    'line'
		name:         'line'
		node_id:      33
		pos_id:       303
		has_type:     true
		typ:          string_type
		type_name:    'string'
		resource:     .string_value
		shape:        string_shape
		state:        .borrowed_no_free
	}
	sumtype_endpoint := AutofreeTransferEndpoint{
		storage:      .sumtype_payload
		root_storage: .local
		root_name:    'holder'
		name:         'Payload.Full'
		node_id:      34
		pos_id:       304
		path:         [
			AutofreeEndpointPathSegment{
				storage: .sumtype_payload
				name:    'Full'
				node_id: 34
				pos_id:  304
			},
		]
		has_type:     true
		typ:          string_type
		type_name:    'string'
		resource:     .string_value
		shape:        string_shape
		state:        .ambiguous_no_free
	}
	return_transfer := AutofreeTransferFact{
		kind:          .return_expr
		action:        .ambiguous_no_free
		from_endpoint: call_endpoint
		to_endpoint:   return_endpoint
		from_name:     'value'
		to_name:       'return'
		shape:         string_shape
	}
	capture_transfer := AutofreeTransferFact{
		kind:          .closure_capture
		action:        .borrow_no_free
		from_endpoint: closure_endpoint
		to_endpoint:   spawn_endpoint
		from_name:     'line'
		to_name:       'line'
		shape:         string_shape
	}
	sumtype_transfer := AutofreeTransferFact{
		kind:          .sumtype_wrap
		action:        .ambiguous_no_free
		from_endpoint: call_endpoint
		to_endpoint:   sumtype_endpoint
		from_name:     'payload'
		to_name:       'payload'
		typ:           string_type
		type_name:     'string'
		shape:         string_shape
	}

	assert return_transfer.to_endpoint.storage == .return_value
	assert return_transfer.from_endpoint.storage == .call_result
	assert capture_transfer.from_name == capture_transfer.to_name
	assert capture_transfer.from_endpoint.storage == .closure_capture
	assert capture_transfer.to_endpoint.storage == .spawn_capture
	assert sumtype_transfer.to_name == 'payload'
	assert sumtype_transfer.to_endpoint.storage == .sumtype_payload
	assert sumtype_transfer.to_endpoint.path[0].storage == .sumtype_payload
	assert sumtype_transfer.to_endpoint.resource == .string_value
	assert sumtype_transfer.to_endpoint.shape.kind == .string_
}

fn test_autofree_transfer_endpoint_unknown_fail_closed_is_ambiguous_no_free() {
	ambiguous_shape := autofree_resource_shape_for_type(Type(Interface{
		name: 'Readable'
	}))
	unknown_endpoint := AutofreeTransferEndpoint{
		storage:      .unknown
		root_storage: .unknown
		root_name:    'value'
		name:         'value'
		has_type:     false
		resource:     .unknown
		shape:        ambiguous_shape
		state:        .ambiguous_no_free
		reason:       'unknown endpoint shape'
	}
	transfer := AutofreeTransferFact{
		kind:          .assign
		action:        .ambiguous_no_free
		from_endpoint: unknown_endpoint
		to_endpoint:   unknown_endpoint
		from_name:     'value'
		to_name:       'value'
		shape:         ambiguous_shape
		reason:        'fail closed for unknown resource'
	}

	assert ambiguous_shape.kind == .ambiguous
	assert ambiguous_shape.fail_closed
	assert !ambiguous_shape.needs_autofree()
	assert transfer.action == .ambiguous_no_free
	assert transfer.from_endpoint.state == .ambiguous_no_free
	assert transfer.to_endpoint.shape.fail_closed
	assert !transfer.from_endpoint.has_type
	assert transfer.from_name == transfer.to_name
	assert transfer.from_endpoint.storage == .unknown
}

fn test_autofree_transfer_endpoints_cover_parameters_receivers_and_borrowed_pointers() {
	string_type := Type(string_)
	pointer_type := Type(Pointer{
		base_type: string_type
	})
	pointer_shape := autofree_resource_shape_for_type(pointer_type)
	parameter_endpoint := AutofreeTransferEndpoint{
		storage:      .parameter
		root_storage: .parameter
		root_name:    'input'
		name:         'input'
		root_node_id: 40
		root_pos_id:  400
		node_id:      40
		pos_id:       400
		has_type:     true
		typ:          pointer_type
		type_name:    '&string'
		resource:     .pointer_value
		shape:        pointer_shape
		state:        .borrowed_no_free
	}
	receiver_endpoint := AutofreeTransferEndpoint{
		storage:      .receiver
		root_storage: .receiver
		root_name:    'scope'
		name:         'scope'
		root_node_id: 41
		root_pos_id:  401
		node_id:      41
		pos_id:       401
		has_type:     true
		typ:          pointer_type
		type_name:    '&string'
		resource:     .pointer_value
		shape:        pointer_shape
		state:        .borrowed_no_free
	}
	transfer := AutofreeTransferFact{
		kind:          .call_arg
		action:        .borrow_no_free
		from_endpoint: parameter_endpoint
		to_endpoint:   receiver_endpoint
		from_name:     'input'
		to_name:       'scope'
		typ:           pointer_type
		type_name:     '&string'
		shape:         pointer_shape
	}

	assert transfer.from_endpoint.storage == .parameter
	assert transfer.to_endpoint.storage == .receiver
	assert transfer.from_endpoint.has_type
	assert transfer.to_endpoint.has_type
	assert transfer.from_endpoint.shape.kind == .borrowed_pointer
	assert transfer.from_endpoint.state == .borrowed_no_free
	assert !transfer.from_endpoint.shape.needs_autofree()
	assert transfer.action == .borrow_no_free
}

fn test_autofree_transfer_endpoints_keep_shadowed_roots_distinct() {
	string_type := Type(string_)
	string_shape := autofree_resource_shape_for_type(string_type)
	outer_line := AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    'line'
		name:         'line'
		root_node_id: 50
		root_pos_id:  500
		node_id:      50
		pos_id:       500
		has_type:     true
		typ:          string_type
		type_name:    'string'
		resource:     .string_value
		shape:        string_shape
		state:        .ambiguous_no_free
	}
	inner_line := AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    'line'
		name:         'line'
		root_node_id: 51
		root_pos_id:  501
		node_id:      51
		pos_id:       501
		has_type:     true
		typ:          string_type
		type_name:    'string'
		resource:     .string_value
		shape:        string_shape
		state:        .ambiguous_no_free
	}

	assert outer_line.root_name == inner_line.root_name
	assert outer_line.root_node_id != inner_line.root_node_id
	assert outer_line.root_pos_id != inner_line.root_pos_id
	assert outer_line.node_id != inner_line.node_id
	assert outer_line.pos_id != inner_line.pos_id
}

fn test_autofree_fact_maps_use_fn_key_lookup() {
	fn_key := autofree_fn_key('math', 'push', 'Bucket')
	assert fn_key == 'math__Bucket__push'
	assert autofree_fn_key('math', 'push', 'math__Bucket') == fn_key
	assert autofree_fn_key('', 'standalone', '') == 'standalone'

	short_name := 'push'
	map_shape := autofree_resource_shape_for_type(Type(Map{
		key_type:   Type(int_)
		value_type: Type(string_)
	}))
	binding := AutofreeBindingFact{
		fn_key:  fn_key
		fn_name: short_name
		name:    'items'
		shape:   map_shape
	}
	transfer := AutofreeTransferFact{
		fn_key:  fn_key
		fn_name: short_name
		kind:    .map_set
		action:  .ambiguous_no_free
		shape:   map_shape
	}
	mut env := Environment.new()
	env.autofree_bindings_by_fn_key = map[string][]AutofreeBindingFact{}
	env.autofree_transfers_by_fn_key = map[string][]AutofreeTransferFact{}
	env.autofree_bindings_by_fn_key[fn_key] = [binding]
	env.autofree_transfers_by_fn_key[fn_key] = [transfer]

	assert fn_key in env.autofree_bindings_by_fn_key
	assert short_name !in env.autofree_bindings_by_fn_key
	assert env.autofree_bindings_by_fn_key[fn_key][0].fn_key == fn_key
	assert env.autofree_bindings_by_fn_key[fn_key][0].fn_name == short_name
	assert env.autofree_bindings_by_fn_key[fn_key][0].shape.map_value_kind == .string_
	assert fn_key in env.autofree_transfers_by_fn_key
	assert short_name !in env.autofree_transfers_by_fn_key
	assert env.autofree_transfers_by_fn_key[fn_key][0].fn_key == fn_key
	assert env.autofree_transfers_by_fn_key[fn_key][0].fn_name == short_name
	assert env.autofree_transfers_by_fn_key[fn_key][0].shape.map_value_may_need_free
	assert env.autofree_helper_roots.len == 0
}

fn test_autofree_release_eligibility_fact_model_is_fact_only() {
	assert AutofreeReleaseEligibility.unknown != AutofreeReleaseEligibility.not_release_eligible
	assert AutofreeReleaseEligibility.not_release_eligible != AutofreeReleaseEligibility.release_eligible
	fact := AutofreeReleaseEligibilityFact{
		fn_key:      'copy_value'
		fn_name:     'copy_value'
		name:        'target'
		eligibility: .not_release_eligible
		node_id:     10
		pos_id:      100
		reason:      'inert transfer is not a release proof'
	}

	assert fact.fn_key == 'copy_value'
	assert fact.fn_name == 'copy_value'
	assert fact.name == 'target'
	assert fact.eligibility == .not_release_eligible
	assert fact.node_id == 10
	assert fact.pos_id == 100
}

fn test_autofree_release_eligibility_allows_owned_move_resource() {
	string_type := Type(string_)
	endpoint := autofree_fact_test_release_endpoint('value', string_type, .owned_unique, true)

	eligibility := autofree_collect_release_eligibility_for_endpoint(.move, endpoint)

	assert endpoint.has_type
	assert endpoint.state == .owned_unique
	assert endpoint.shape.kind == .string_
	assert endpoint.shape.needs_autofree()
	assert eligibility == .release_eligible
}

fn test_autofree_release_eligibility_rejects_external_owned_move_resource_storage() {
	string_type := Type(string_)
	external_storages := [
		AutofreeStorageKind.global,
		AutofreeStorageKind.struct_field,
		AutofreeStorageKind.array_element,
		AutofreeStorageKind.map_key,
		AutofreeStorageKind.map_value,
		AutofreeStorageKind.return_value,
		AutofreeStorageKind.closure_capture,
		AutofreeStorageKind.spawn_capture,
		AutofreeStorageKind.sumtype_payload,
	]
	for storage in external_storages {
		endpoint := autofree_fact_test_release_endpoint_with_storage('value', string_type,
			.owned_unique, true, storage)
		eligibility := autofree_collect_release_eligibility_for_endpoint(.move, endpoint)

		assert endpoint.storage == storage
		assert endpoint.root_storage == storage
		assert endpoint.state == .owned_unique
		assert endpoint.shape.kind == .string_
		assert endpoint.shape.needs_autofree()
		assert eligibility == .not_release_eligible
	}
}

fn test_autofree_release_eligibility_transfer_to_external_storage_stays_not_eligible() {
	fn_key := autofree_fn_key('demo', 'store_global', '')
	string_type := Type(string_)
	source := autofree_fact_test_release_endpoint('source', string_type, .owned_unique, true)
	target := autofree_fact_test_release_endpoint_with_storage('escaped', string_type,
		.owned_unique, true, .global)
	transfer := AutofreeTransferFact{
		fn_key:        fn_key
		fn_name:       'store_global'
		kind:          .global_set
		action:        .move
		from_endpoint: source
		to_endpoint:   target
		from_name:     'source'
		to_name:       'escaped'
		typ:           string_type
		type_name:     string_type.name()
		shape:         target.shape
		node_id:       12
		pos_id:        120
		reason:        'synthetic external storage transfer'
	}
	mut env := Environment.new()
	env.autofree_transfers_by_fn_key = map[string][]AutofreeTransferFact{}
	env.autofree_transfers_by_fn_key[fn_key] = [transfer]

	env.collect_autofree_release_eligibility_from_transfers()

	assert env.autofree_release_eligibility_by_fn_key[fn_key].len == 1
	fact := env.autofree_release_eligibility_by_fn_key[fn_key][0]
	assert fact.name == 'escaped'
	assert fact.transfer_kind == .global_set
	assert fact.transfer_action == .move
	assert fact.endpoint.storage == .global
	assert fact.endpoint.root_storage == .global
	assert fact.eligibility == .not_release_eligible
	assert env.autofree_releases_by_fn_key.len == 0
	assert env.autofree_helper_roots.len == 0
}

fn test_autofree_release_eligibility_rejects_owned_move_scalar() {
	int_type := Type(int_)
	endpoint := autofree_fact_test_release_endpoint('value', int_type, .owned_unique, true)

	eligibility := autofree_collect_release_eligibility_for_endpoint(.move, endpoint)

	assert endpoint.has_type
	assert endpoint.state == .owned_unique
	assert endpoint.shape.kind == .no_resource
	assert !endpoint.shape.needs_autofree()
	assert eligibility == .not_release_eligible
}

fn test_autofree_release_eligibility_rejects_missing_type() {
	string_type := Type(string_)
	endpoint := autofree_fact_test_release_endpoint('value', string_type, .owned_unique, false)

	eligibility := autofree_collect_release_eligibility_for_endpoint(.move, endpoint)

	assert !endpoint.has_type
	assert endpoint.state == .owned_unique
	assert endpoint.shape.kind == .string_
	assert eligibility == .not_release_eligible
}

fn test_autofree_release_eligibility_rejects_fail_closed_shape() {
	interface_type := Type(Interface{
		name: 'Readable'
	})
	endpoint := autofree_fact_test_release_endpoint('value', interface_type, .owned_unique, true)

	eligibility := autofree_collect_release_eligibility_for_endpoint(.move, endpoint)

	assert endpoint.has_type
	assert endpoint.state == .owned_unique
	assert endpoint.shape.fail_closed
	assert eligibility == .not_release_eligible
}

fn test_autofree_release_eligibility_rejects_non_move_or_non_owned() {
	string_type := Type(string_)
	owned_endpoint := autofree_fact_test_release_endpoint('value', string_type, .owned_unique, true)
	borrowed_endpoint := autofree_fact_test_release_endpoint('value', string_type,
		.borrowed_no_free, true)
	ambiguous_endpoint := autofree_fact_test_release_endpoint('value', string_type,
		.ambiguous_no_free, true)

	assert autofree_collect_release_eligibility_for_endpoint(.ambiguous_no_free, owned_endpoint) == .not_release_eligible
	assert autofree_collect_release_eligibility_for_endpoint(.borrow_no_free, owned_endpoint) == .not_release_eligible
	assert autofree_collect_release_eligibility_for_endpoint(.move, borrowed_endpoint) == .not_release_eligible
	assert autofree_collect_release_eligibility_for_endpoint(.move, ambiguous_endpoint) == .not_release_eligible
}

fn test_autofree_release_eligibility_facts_use_fn_key_lookup() {
	fn_key := autofree_fn_key('math', 'copy_value', '')
	fact := AutofreeReleaseEligibilityFact{
		fn_key:      fn_key
		fn_name:     'copy_value'
		name:        'target'
		eligibility: .not_release_eligible
		reason:      'not eligible by transfer action'
	}
	mut env := Environment.new()
	env.autofree_release_eligibility_by_fn_key = map[string][]AutofreeReleaseEligibilityFact{}
	env.autofree_release_eligibility_by_fn_key[fn_key] = [fact]

	assert fn_key == 'math__copy_value'
	assert fn_key in env.autofree_release_eligibility_by_fn_key
	assert 'copy_value' !in env.autofree_release_eligibility_by_fn_key
	assert env.autofree_release_eligibility_by_fn_key[fn_key][0].fn_key == fn_key
	assert env.autofree_release_eligibility_by_fn_key[fn_key][0].fn_name == 'copy_value'
	assert env.autofree_release_eligibility_by_fn_key[fn_key][0].eligibility == .not_release_eligible
	assert env.autofree_releases_by_fn_key.len == 0
	assert env.autofree_helper_roots.len == 0
}

fn test_reset_autofree_facts_clears_release_eligibility_map() {
	mut env := Environment.new()
	env.autofree_release_eligibility_by_fn_key = map[string][]AutofreeReleaseEligibilityFact{}
	env.autofree_release_eligibility_by_fn_key['copy_value'] = [
		AutofreeReleaseEligibilityFact{
			fn_key:      'copy_value'
			fn_name:     'copy_value'
			name:        'target'
			eligibility: .not_release_eligible
		},
	]
	flat := ast.FlatAst{}

	env.reset_autofree_facts_for_flat(&flat)

	assert env.autofree_release_eligibility_by_fn_key.len == 0
	assert env.autofree_releases_by_fn_key.len == 0
	assert env.autofree_helper_roots.len == 0
}

fn test_autofree_resource_shape_fails_closed_for_ambiguous_resources() {
	interface_shape := autofree_resource_shape_for_type(Type(Interface{
		name: 'Readable'
	}))
	assert interface_shape.kind == .ambiguous
	assert interface_shape.fail_closed
	assert !interface_shape.needs_autofree()

	named_shape := autofree_resource_shape_for_type(Type(NamedType('T')))
	assert named_shape.kind == .ambiguous
	assert named_shape.fail_closed
	assert !named_shape.needs_autofree()

	thread_shape := autofree_resource_shape_for_type(Type(Thread{}))
	assert thread_shape.kind == .ambiguous
	assert thread_shape.fail_closed
	assert !thread_shape.needs_autofree()

	channel_shape := autofree_resource_shape_for_type(Type(Channel{}))
	assert channel_shape.kind == .ambiguous
	assert channel_shape.fail_closed
	assert !channel_shape.needs_autofree()

	fn_shape := autofree_resource_shape_for_type(Type(FnType{}))
	assert fn_shape.kind == .ambiguous
	assert fn_shape.fail_closed
	assert !fn_shape.needs_autofree()
}

fn test_autofree_resource_shape_does_not_guess_from_names() {
	mut fields := []Field{}
	drop_named_shape := autofree_resource_shape_for_type(Type(Struct{
		name:   'has_free_and_drop_methods'
		fields: fields
	}))
	assert drop_named_shape.kind == .struct_
	assert !drop_named_shape.has_owned_resource
	assert !drop_named_shape.needs_autofree()
}

fn autofree_fact_test_release_endpoint(name string, typ Type, state AutofreeOwnershipState, has_type bool) AutofreeTransferEndpoint {
	shape := autofree_resource_shape_for_type(typ)
	return AutofreeTransferEndpoint{
		storage:      .local
		root_storage: .local
		root_name:    name
		name:         name
		root_node_id: 10
		root_pos_id:  100
		node_id:      10
		pos_id:       100
		has_type:     has_type
		typ:          typ
		type_name:    typ.name()
		resource:     autofree_fact_test_resource_kind_for_shape(shape)
		shape:        shape
		state:        state
		reason:       'release eligibility endpoint'
	}
}

fn autofree_fact_test_release_endpoint_with_storage(name string, typ Type, state AutofreeOwnershipState, has_type bool, storage AutofreeStorageKind) AutofreeTransferEndpoint {
	return AutofreeTransferEndpoint{
		...autofree_fact_test_release_endpoint(name, typ, state, has_type)
		storage:      storage
		root_storage: storage
	}
}

fn autofree_fact_test_resource_kind_for_shape(shape AutofreeResourceShape) AutofreeResourceKind {
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
