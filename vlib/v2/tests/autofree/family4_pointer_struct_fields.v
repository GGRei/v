module main

struct Node {
	name     string
	parent   &Node = unsafe { nil }
	children []Node
}

fn child_count(node &Node) int {
	return node.children.len
}

fn main() {
	root := Node{
		name:     'root'
		children: []Node{}
	}
	child := Node{
		name:     'child'
		parent:   unsafe { &root }
		children: []Node{}
	}
	println(child_count(unsafe { &child }))
}
