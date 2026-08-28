module types

import v3.flat

// NativeLinkRequirements records source-owned requirements that affect only the
// final native link. C translation units and compile-only outputs remain C.
pub struct NativeLinkRequirements {
pub:
	requires_cpp bool
}

// native_link_requirements resolves top-level compile-time branches before the
// whole-program cache lookup. Cached module interfaces retain #linker directives,
// so cold and warm builds observe the same requirement.
pub fn native_link_requirements(a &flat.FlatAst) !NativeLinkRequirements {
	mut tc := TypeChecker.new(a)
	tc.prepare_threads_condition()
	inactive := tc.inactive_top_level_comptime_nodes()
	mut requires_cpp := false
	for i, node in a.nodes {
		if inactive.len > 0 && i < inactive.len && inactive[i] {
			continue
		}
		if node.kind != .directive || node.value != 'linker' {
			continue
		}
		if node.typ.trim_space() != 'c++' {
			return error('`#linker` expects exactly `c++`')
		}
		requires_cpp = true
	}
	return NativeLinkRequirements{
		requires_cpp: requires_cpp
	}
}

pub fn (requirements NativeLinkRequirements) cache_key() string {
	return if requirements.requires_cpp { 'c++' } else { 'c' }
}
