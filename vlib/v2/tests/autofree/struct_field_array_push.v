module main

struct Param {
	name string
mut:
	attrs []string
}

fn param_from_attrs(name string, attrs []string) Param {
	mut p := Param{
		name:  name
		attrs: []string{}
	}
	for attr in attrs {
		p.attrs << attr
	}
	return p
}

fn sample_attrs() []string {
	mut attrs := []string{}
	attrs << 'inline'
	attrs << 'shared-buffer'
	return attrs
}

fn collect_params() []Param {
	mut params := []Param{}
	attrs := sample_attrs()
	param := param_from_attrs('root', attrs)
	params << param
	return params
}

fn main() {
	params := collect_params()
	println(params.len)
}
