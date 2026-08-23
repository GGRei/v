module main

#flag @VMODROOT/.github/workflows/static_pkgconfig_smoke/linker_cpp_runtime.o
#flag @VMODROOT/.github/workflows/static_pkgconfig_smoke/linker_cpp_extra.c
#flag windows -lkernel32
#include "@VMODROOT/.github/workflows/static_pkgconfig_smoke/linker_cpp_c_sentinel.h"
#linker c++

fn C.linker_cpp_runtime_probe() int
fn C.linker_cpp_extra_c_probe() int

fn main() {
	assert C.linker_cpp_runtime_probe() == 42
	assert C.linker_cpp_extra_c_probe() == 7
}
