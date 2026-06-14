module types

import v2.ast

pub enum AutofreeStorageKind {
	unknown
	local
	parameter
	receiver
	temp
	literal
	call_result
	global
	struct_field
	array_element
	map_key
	map_value
	return_value
	closure_capture
	spawn_capture
	sumtype_payload
}

pub enum AutofreeResourceKind {
	unknown
	no_resource
	scalar_value
	string_value
	array_value
	map_container
	struct_value
	sumtype_value
	pointer_value
	option_value
	result_value
	tuple_value
	interface_value
	alias_value
}

pub enum AutofreeOwnershipState {
	unknown
	owned_unique
	borrowed_no_free
	moved_out
	shared_no_free
	ambiguous_no_free
	copy_no_resource
}

pub enum AutofreeTransferKind {
	unknown
	decl
	assign
	call_arg
	return_expr
	array_push
	map_set
	struct_init
	field_set
	global_set
	closure_capture
	spawn_capture
	sumtype_wrap
}

pub enum AutofreeTransferAction {
	unknown
	move
	clone_value
	borrow_no_free
	copy_no_resource
	ambiguous_no_free
	reject
}

pub enum AutofreeMoveProofKind {
	unknown
	fresh_local_binding
}

pub enum AutofreeReleaseKind {
	unknown
	natural_exit
	return_path
	before_overwrite
}

pub enum AutofreeReleaseAction {
	unknown
	skip
	release_string
	release_array
	release_map
	release_struct
	release_sumtype
	call_drop
}

pub enum AutofreeReleaseEligibility {
	unknown
	not_release_eligible
	release_eligible
}

pub enum AutofreeReleasePlanKind {
	unknown
	natural_exit
}

pub enum AutofreeReleasePlanAction {
	unknown
	array_container_cleanup
}

pub enum AutofreeReleasePlanHelperRequirement {
	unknown
	none
}

pub enum AutofreeReleasePreflightStatus {
	unknown
	inert
}

pub enum AutofreeReleaseInsertionPointKind {
	unknown
	after_statement
}

pub enum AutofreeReleaseInsertionPointStatus {
	unknown
	inert
}

pub enum AutofreeHelperRootKind {
	unknown
	release_fn
	clone_fn
	drop_method
	sumtype_release_fn
}

pub struct AutofreePipelineFact {
pub:
	enabled              bool
	flat_nodes           int
	flat_edges           int
	flat_strings         int
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

pub struct AutofreeBindingFact {
pub:
	fn_key    string
	fn_name   string
	name      string
	c_name    string
	typ       Type
	type_name string
	node_id   ast.FlatNodeId
	pos_id    int
	storage   AutofreeStorageKind
	resource  AutofreeResourceKind
	shape     AutofreeResourceShape
	state     AutofreeOwnershipState
	reason    string
}

pub struct AutofreeEndpointPathSegment {
pub:
	storage       AutofreeStorageKind
	name          string
	node_id       ast.FlatNodeId
	pos_id        int
	index_node_id ast.FlatNodeId
	index_pos_id  int
}

pub struct AutofreeTransferEndpoint {
pub:
	storage      AutofreeStorageKind
	root_storage AutofreeStorageKind
	root_name    string
	name         string
	root_node_id ast.FlatNodeId
	root_pos_id  int
	node_id      ast.FlatNodeId
	pos_id       int
	path         []AutofreeEndpointPathSegment
	has_type     bool
	typ          Type
	type_name    string
	resource     AutofreeResourceKind
	shape        AutofreeResourceShape
	state        AutofreeOwnershipState
	reason       string
}

pub struct AutofreeTransferFact {
pub:
	fn_key        string
	fn_name       string
	kind          AutofreeTransferKind
	action        AutofreeTransferAction
	from_endpoint AutofreeTransferEndpoint
	to_endpoint   AutofreeTransferEndpoint
	// Display-only metadata; endpoints carry source identity.
	from_name string
	// Display-only metadata; endpoints carry destination identity.
	to_name   string
	typ       Type
	type_name string
	shape     AutofreeResourceShape
	node_id   ast.FlatNodeId
	pos_id    int
	reason    string
}

pub struct AutofreeFreshLocalFact {
pub:
	fn_key          string
	fn_name         string
	name            string
	endpoint        AutofreeTransferEndpoint
	source_endpoint AutofreeTransferEndpoint
	state           AutofreeOwnershipState
	resource        AutofreeResourceKind
	shape           AutofreeResourceShape
	typ             Type
	type_name       string
	node_id         ast.FlatNodeId
	pos_id          int
	stmt_node_id    ast.FlatNodeId
	stmt_pos_id     int
	reason          string
}

pub struct AutofreeMoveProofFact {
pub:
	fn_key          string
	fn_name         string
	name            string
	kind            AutofreeMoveProofKind
	source_endpoint AutofreeTransferEndpoint
	target_endpoint AutofreeTransferEndpoint
	state           AutofreeOwnershipState
	resource        AutofreeResourceKind
	shape           AutofreeResourceShape
	typ             Type
	type_name       string
	node_id         ast.FlatNodeId
	pos_id          int
	stmt_node_id    ast.FlatNodeId
	stmt_pos_id     int
	reason          string
}

pub struct AutofreeNaturalReleaseCandidateFact {
pub:
	fn_key                string
	fn_name               string
	name                  string
	move_kind             AutofreeMoveProofKind
	source_endpoint       AutofreeTransferEndpoint
	endpoint              AutofreeTransferEndpoint
	state                 AutofreeOwnershipState
	resource              AutofreeResourceKind
	shape                 AutofreeResourceShape
	typ                   Type
	type_name             string
	node_id               ast.FlatNodeId
	pos_id                int
	proof_node_id         ast.FlatNodeId
	proof_pos_id          int
	release_after_node_id ast.FlatNodeId
	release_after_pos_id  int
	reason                string
}

pub struct AutofreeReleasePlanFact {
pub:
	fn_key                string
	fn_name               string
	name                  string
	move_kind             AutofreeMoveProofKind
	plan_kind             AutofreeReleasePlanKind
	plan_action           AutofreeReleasePlanAction
	helper_requirement    AutofreeReleasePlanHelperRequirement
	source_endpoint       AutofreeTransferEndpoint
	endpoint              AutofreeTransferEndpoint
	state                 AutofreeOwnershipState
	resource              AutofreeResourceKind
	shape                 AutofreeResourceShape
	typ                   Type
	type_name             string
	node_id               ast.FlatNodeId
	pos_id                int
	proof_node_id         ast.FlatNodeId
	proof_pos_id          int
	release_after_node_id ast.FlatNodeId
	release_after_pos_id  int
	reason                string
}

pub struct AutofreeReleasePreflightFact {
pub:
	fn_key                string
	fn_name               string
	name                  string
	move_kind             AutofreeMoveProofKind
	plan_kind             AutofreeReleasePlanKind
	plan_action           AutofreeReleasePlanAction
	helper_requirement    AutofreeReleasePlanHelperRequirement
	preflight_status      AutofreeReleasePreflightStatus
	source_endpoint       AutofreeTransferEndpoint
	endpoint              AutofreeTransferEndpoint
	state                 AutofreeOwnershipState
	resource              AutofreeResourceKind
	shape                 AutofreeResourceShape
	typ                   Type
	type_name             string
	node_id               ast.FlatNodeId
	pos_id                int
	proof_node_id         ast.FlatNodeId
	proof_pos_id          int
	release_after_node_id ast.FlatNodeId
	release_after_pos_id  int
	reason                string
}

pub struct AutofreeReleaseInsertionPointFact {
pub:
	fn_key                string
	fn_name               string
	name                  string
	move_kind             AutofreeMoveProofKind
	plan_kind             AutofreeReleasePlanKind
	plan_action           AutofreeReleasePlanAction
	helper_requirement    AutofreeReleasePlanHelperRequirement
	preflight_status      AutofreeReleasePreflightStatus
	insertion_kind        AutofreeReleaseInsertionPointKind
	insertion_status      AutofreeReleaseInsertionPointStatus
	source_endpoint       AutofreeTransferEndpoint
	endpoint              AutofreeTransferEndpoint
	state                 AutofreeOwnershipState
	resource              AutofreeResourceKind
	shape                 AutofreeResourceShape
	typ                   Type
	type_name             string
	node_id               ast.FlatNodeId
	pos_id                int
	proof_node_id         ast.FlatNodeId
	proof_pos_id          int
	release_after_node_id ast.FlatNodeId
	release_after_pos_id  int
	insert_after_node_id  ast.FlatNodeId
	insert_after_pos_id   int
	reason                string
}

pub struct AutofreeReleaseEligibilityFact {
pub:
	fn_key          string
	fn_name         string
	name            string
	endpoint        AutofreeTransferEndpoint
	transfer_kind   AutofreeTransferKind
	transfer_action AutofreeTransferAction
	eligibility     AutofreeReleaseEligibility
	state           AutofreeOwnershipState
	resource        AutofreeResourceKind
	shape           AutofreeResourceShape
	typ             Type
	type_name       string
	node_id         ast.FlatNodeId
	pos_id          int
	reason          string
}

pub struct AutofreeReleaseFact {
pub:
	fn_key    string
	fn_name   string
	kind      AutofreeReleaseKind
	action    AutofreeReleaseAction
	name      string
	c_name    string
	typ       Type
	type_name string
	node_id   ast.FlatNodeId
	pos_id    int
	reason    string
}

pub struct AutofreeHelperRootFact {
pub:
	kind          AutofreeHelperRootKind
	fn_name       string
	module_name   string
	method_name   string
	receiver_type string
	reason        string
}

pub fn (mut e Environment) reset_autofree_facts_for_flat(flat &ast.FlatAst) {
	e.autofree_pipeline = AutofreePipelineFact{
		enabled:      false
		flat_nodes:   flat.nodes.len
		flat_edges:   flat.edges.len
		flat_strings: flat.strings.len
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
}

pub fn autofree_fn_key(module_name string, name string, receiver_type string) string {
	is_root_module := module_name.len == 0 || module_name == 'main' || module_name == 'builtin'
	if receiver_type.len == 0 {
		if module_name == 'builtin' && name == 'panic' {
			return 'v_panic'
		}
		if is_root_module || name.contains('__') {
			return name
		}
		return '${module_name}__${name}'
	}
	if !is_root_module {
		if receiver_type.contains('__') {
			return '${receiver_type}__${name}'
		}
		return '${module_name}__${receiver_type}__${name}'
	}
	mut receiver := receiver_type
	main_prefix := 'main__'
	builtin_prefix := 'builtin__'
	if receiver.starts_with(main_prefix) {
		receiver = receiver[main_prefix.len..]
	} else if receiver.starts_with(builtin_prefix) {
		receiver = receiver[builtin_prefix.len..]
	}
	return '${receiver}__${name}'
}

pub enum AutofreeResourceShapeKind {
	no_resource
	string_
	array
	array_fixed
	map_
	struct_
	sumtype
	borrowed_pointer
	option
	result
	tuple
	alias
	ambiguous
}

pub struct AutofreeResourceShape {
pub:
	kind                        AutofreeResourceShapeKind
	identity                    string
	target_kind                 AutofreeResourceShapeKind
	target_identity             string
	map_container_owned         bool
	map_container_may_need_free bool
	map_key_kind                AutofreeResourceShapeKind
	map_key_identity            string
	map_key_owned               bool
	map_key_may_need_free       bool
	map_value_kind              AutofreeResourceShapeKind
	map_value_identity          string
	map_value_owned             bool
	map_value_may_need_free     bool
	has_owned_resource          bool
	may_need_free               bool
	fail_closed                 bool
}

pub fn (shape AutofreeResourceShape) needs_autofree() bool {
	return shape.may_need_free && !shape.fail_closed
}

pub fn (mut env Environment) autofree_resource_shape(typ Type) AutofreeResourceShape {
	return autofree_resource_shape_for_type(typ)
}

pub fn autofree_alias_resource_shape(alias_name string, target AutofreeResourceShape) AutofreeResourceShape {
	return AutofreeResourceShape{
		kind:                        .alias
		identity:                    alias_name
		target_kind:                 target.kind
		target_identity:             target.identity
		map_container_owned:         target.map_container_owned
		map_container_may_need_free: target.map_container_may_need_free
		map_key_kind:                target.map_key_kind
		map_key_identity:            target.map_key_identity
		map_key_owned:               target.map_key_owned
		map_key_may_need_free:       target.map_key_may_need_free
		map_value_kind:              target.map_value_kind
		map_value_identity:          target.map_value_identity
		map_value_owned:             target.map_value_owned
		map_value_may_need_free:     target.map_value_may_need_free
		has_owned_resource:          target.has_owned_resource
		may_need_free:               target.may_need_free
		fail_closed:                 target.fail_closed
	}
}

fn autofree_resource_shape_for_type(typ Type) AutofreeResourceShape {
	return autofree_resource_shape_for_type_depth(typ, 0)
}

fn autofree_resource_shape_for_type_depth(typ Type, depth int) AutofreeResourceShape {
	if depth > 64 {
		return autofree_ambiguous_shape('')
	}
	if typ is Primitive {
		return autofree_no_resource_shape('')
	}
	if typ is Char || typ is Enum || typ is ISize || typ is Rune || typ is USize || typ is Void
		|| typ is Nil || typ is None {
		return autofree_no_resource_shape('')
	}
	if typ is String {
		return autofree_owned_shape(.string_, '')
	}
	if typ is Array {
		elem_shape := autofree_resource_shape_for_type_depth(typ.elem_type, depth + 1)
		return autofree_container_shape(.array, '', elem_shape)
	}
	if typ is ArrayFixed {
		elem_shape := autofree_resource_shape_for_type_depth(typ.elem_type, depth + 1)
		return autofree_wrapped_shape(.array_fixed, '', elem_shape)
	}
	if typ is Map {
		key_shape := autofree_resource_shape_for_type_depth(typ.key_type, depth + 1)
		value_shape := autofree_resource_shape_for_type_depth(typ.value_type, depth + 1)
		return autofree_map_shape(key_shape, value_shape)
	}
	if typ is Pointer {
		return AutofreeResourceShape{
			kind: .borrowed_pointer
		}
	}
	if typ is OptionType {
		target := autofree_resource_shape_for_type_depth(typ.base_type, depth + 1)
		return autofree_wrapped_shape(.option, '', target)
	}
	if typ is ResultType {
		target := autofree_resource_shape_for_type_depth(typ.base_type, depth + 1)
		return autofree_wrapped_shape(.result, '', target)
	}
	if typ is Alias {
		target := autofree_resource_shape_for_type_depth(typ.base_type, depth + 1)
		return autofree_alias_resource_shape(typ.name, target)
	}
	if typ is Struct {
		return autofree_struct_shape(typ, depth + 1)
	}
	if typ is SumType {
		return autofree_sumtype_shape(typ, depth + 1)
	}
	if typ is Tuple {
		return autofree_tuple_shape(typ, depth + 1)
	}
	return autofree_ambiguous_shape('')
}

fn autofree_struct_shape(typ Struct, depth int) AutofreeResourceShape {
	if depth > 64 {
		return autofree_ambiguous_shape(typ.name)
	}
	mut shape := AutofreeResourceShape{
		kind:     .struct_
		identity: typ.name
	}
	for embedded in typ.embedded {
		embedded_shape := autofree_struct_shape(embedded, depth + 1)
		shape = autofree_merge_composite_shape(shape, embedded_shape)
		if shape.fail_closed {
			return autofree_ambiguous_shape(typ.name)
		}
	}
	for field in typ.fields {
		field_shape := autofree_resource_shape_for_type_depth(field.typ, depth + 1)
		shape = autofree_merge_composite_shape(shape, field_shape)
		if shape.fail_closed {
			return autofree_ambiguous_shape(typ.name)
		}
	}
	return shape
}

fn autofree_sumtype_shape(typ SumType, depth int) AutofreeResourceShape {
	if depth > 64 {
		return autofree_ambiguous_shape(typ.name)
	}
	mut shape := AutofreeResourceShape{
		kind:     .sumtype
		identity: typ.name
	}
	for variant in typ.variants {
		variant_shape := autofree_resource_shape_for_type_depth(variant, depth + 1)
		shape = autofree_merge_composite_shape(shape, variant_shape)
		if shape.fail_closed {
			return autofree_ambiguous_shape(typ.name)
		}
	}
	return shape
}

fn autofree_tuple_shape(typ Tuple, depth int) AutofreeResourceShape {
	if depth > 64 {
		return autofree_ambiguous_shape('')
	}
	mut shape := AutofreeResourceShape{
		kind: .tuple
	}
	for elem_type in typ.types {
		elem_shape := autofree_resource_shape_for_type_depth(elem_type, depth + 1)
		shape = autofree_merge_composite_shape(shape, elem_shape)
		if shape.fail_closed {
			return autofree_ambiguous_shape('')
		}
	}
	return shape
}

fn autofree_no_resource_shape(identity string) AutofreeResourceShape {
	return AutofreeResourceShape{
		kind:     .no_resource
		identity: identity
	}
}

fn autofree_owned_shape(kind AutofreeResourceShapeKind, identity string) AutofreeResourceShape {
	return AutofreeResourceShape{
		kind:               kind
		identity:           identity
		has_owned_resource: true
		may_need_free:      true
	}
}

fn autofree_ambiguous_shape(identity string) AutofreeResourceShape {
	return AutofreeResourceShape{
		kind:        .ambiguous
		identity:    identity
		fail_closed: true
	}
}

fn autofree_container_shape(kind AutofreeResourceShapeKind, identity string, target AutofreeResourceShape) AutofreeResourceShape {
	if target.fail_closed {
		return autofree_ambiguous_shape(identity)
	}
	return AutofreeResourceShape{
		kind:               kind
		identity:           identity
		target_kind:        target.kind
		target_identity:    target.identity
		has_owned_resource: true
		may_need_free:      true
	}
}

fn autofree_map_shape(key AutofreeResourceShape, value AutofreeResourceShape) AutofreeResourceShape {
	if key.fail_closed || value.fail_closed {
		return autofree_ambiguous_shape('')
	}
	target := if key.has_owned_resource { key } else { value }
	return AutofreeResourceShape{
		kind:                        .map_
		target_kind:                 target.kind
		target_identity:             target.identity
		map_container_owned:         true
		map_container_may_need_free: true
		map_key_kind:                key.kind
		map_key_identity:            key.identity
		map_key_owned:               key.has_owned_resource
		map_key_may_need_free:       key.may_need_free
		map_value_kind:              value.kind
		map_value_identity:          value.identity
		map_value_owned:             value.has_owned_resource
		map_value_may_need_free:     value.may_need_free
		has_owned_resource:          true
		may_need_free:               true
	}
}

fn autofree_wrapped_shape(kind AutofreeResourceShapeKind, identity string, target AutofreeResourceShape) AutofreeResourceShape {
	if target.fail_closed {
		return autofree_ambiguous_shape(identity)
	}
	return AutofreeResourceShape{
		kind:               kind
		identity:           identity
		target_kind:        target.kind
		target_identity:    target.identity
		has_owned_resource: target.has_owned_resource
		may_need_free:      target.may_need_free
	}
}

fn autofree_merge_composite_shape(base AutofreeResourceShape, part AutofreeResourceShape) AutofreeResourceShape {
	if part.fail_closed {
		return autofree_ambiguous_shape(base.identity)
	}
	return AutofreeResourceShape{
		kind:               base.kind
		identity:           base.identity
		has_owned_resource: base.has_owned_resource || part.has_owned_resource
		may_need_free:      base.may_need_free || part.may_need_free
	}
}
