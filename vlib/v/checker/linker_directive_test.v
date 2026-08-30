module checker

import os
import v.ast
import v.parser
import v.pref

struct CheckedLinkerDirective {
	requires_cpp bool
	errors       []string
}

fn check_linker_directive(source string) CheckedLinkerDirective {
	mut prefs := pref.new_preferences()
	prefs.os = .linux
	mut table := ast.new_table()
	mut file := parser.parse_text(source, os.join_path('/virtual', 'linker_directive.v'), mut
		table, .skip_comments, prefs)
	mut chk := new_checker(table, prefs)
	chk.check(mut file)
	return CheckedLinkerDirective{
		requires_cpp: table.requires_cpp_linker
		errors:       chk.errors.map(it.message)
	}
}

fn test_linker_cplusplus_is_idempotent() {
	checked := check_linker_directive('module main\n#linker c++\n#linker c++\nfn main() {}\n')
	assert checked.requires_cpp
	assert checked.errors == []
}

fn test_linker_cplusplus_in_inactive_branch_is_ignored() {
	checked :=
		check_linker_directive('module main\n$if windows {\n\t#linker c++\n}\nfn main() {}\n')
	assert !checked.requires_cpp
	assert checked.errors == []
}

fn test_linker_rejects_every_value_except_exact_cplusplus() {
	for value in ['', 'c', 'cpp', 'c++ extra'] {
		checked := check_linker_directive('module main\n#linker ${value}\nfn main() {}\n')
		assert !checked.requires_cpp, value
		assert checked.errors.any(it.contains('`#linker` expects exactly `c++`')), '${value}: ${checked.errors}'
	}
}
