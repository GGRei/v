module main

struct Scope {
mut:
	name   string
	parent &Scope = unsafe { nil }
}

fn (mut scope Scope) drop() {
	scope.name = ''
}

fn (mut scope Scope) free() {
	scope.name = ''
}

fn walk_scope(scope &Scope) int {
	mut total := 0
	for sc := scope; sc != unsafe { nil }; sc = sc.parent {
		total += sc.name.len
	}
	return total
}

fn main() {
	root := Scope{
		name:   'root'
		parent: unsafe { nil }
	}
	child := Scope{
		name:   'child'
		parent: unsafe { &root }
	}
	println(walk_scope(unsafe { &child }))
}
