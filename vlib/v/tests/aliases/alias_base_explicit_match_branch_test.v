type ExplicitAliasU8 = u8
type ExplicitAliasBaseValue = ExplicitAliasU8 | u8 | string
type ExplicitBaseOnlyValue = u8 | string

fn explicit_alias_first(value ExplicitAliasBaseValue) string {
	return match value {
		ExplicitAliasU8 { 'alias' }
		u8 { 'base' }
		string { 'string' }
	}
}

fn explicit_base_first(value ExplicitAliasBaseValue) string {
	return match value {
		u8 { 'base' }
		ExplicitAliasU8 { 'alias' }
		string { 'string' }
	}
}

fn alias_only_branch_matches_base_tag(value ExplicitAliasBaseValue) bool {
	return match value {
		ExplicitAliasU8 { true }
		else { false }
	}
}

fn base_only_branch_matches_alias_tag(value ExplicitAliasBaseValue) bool {
	return match value {
		u8 { true }
		else { false }
	}
}

fn aggregate_alias_and_base_same_branch(value ExplicitAliasBaseValue) string {
	return match value {
		ExplicitAliasU8, u8 { 'number' }
		string { 'string' }
	}
}

fn aggregate_alias_before_base_branch(value ExplicitAliasBaseValue) string {
	return match value {
		ExplicitAliasU8, string { 'alias-or-string' }
		u8 { 'base' }
	}
}

fn non_variant_alias_before_exact_base(value ExplicitBaseOnlyValue) string {
	return match value {
		ExplicitAliasU8 { 'alias' }
		u8 { 'base' }
		string { 'string' }
	}
}

fn non_variant_alias_without_exact_base(value ExplicitBaseOnlyValue) bool {
	return match value {
		ExplicitAliasU8 { true }
		else { false }
	}
}

fn test_match_keeps_explicit_alias_and_base_branches_distinct() {
	alias_value := ExplicitAliasBaseValue(ExplicitAliasU8(7))
	base_value := ExplicitAliasBaseValue(u8(9))
	string_value := ExplicitAliasBaseValue('ok')

	assert explicit_alias_first(alias_value) == 'alias'
	assert explicit_alias_first(base_value) == 'base'
	assert explicit_alias_first(string_value) == 'string'

	assert explicit_base_first(alias_value) == 'alias'
	assert explicit_base_first(base_value) == 'base'
	assert explicit_base_first(string_value) == 'string'
}

fn test_single_alias_or_base_branch_keeps_runtime_tag_expansion() {
	alias_value := ExplicitAliasBaseValue(ExplicitAliasU8(3))
	base_value := ExplicitAliasBaseValue(u8(4))

	assert alias_only_branch_matches_base_tag(base_value)
	assert base_only_branch_matches_alias_tag(alias_value)
}

fn test_aggregate_match_keeps_explicit_alias_and_base_tags_distinct() {
	alias_value := ExplicitAliasBaseValue(ExplicitAliasU8(11))
	base_value := ExplicitAliasBaseValue(u8(12))
	string_value := ExplicitAliasBaseValue('ok')

	assert aggregate_alias_and_base_same_branch(alias_value) == 'number'
	assert aggregate_alias_and_base_same_branch(base_value) == 'number'
	assert aggregate_alias_and_base_same_branch(string_value) == 'string'

	assert aggregate_alias_before_base_branch(alias_value) == 'alias-or-string'
	assert aggregate_alias_before_base_branch(base_value) == 'base'
	assert aggregate_alias_before_base_branch(string_value) == 'alias-or-string'
}

fn test_non_variant_alias_defers_to_explicit_variant_branch() {
	base_value := ExplicitBaseOnlyValue(u8(15))
	string_value := ExplicitBaseOnlyValue('ok')

	assert non_variant_alias_before_exact_base(base_value) == 'base'
	assert non_variant_alias_before_exact_base(string_value) == 'string'
	assert non_variant_alias_without_exact_base(base_value)
}
