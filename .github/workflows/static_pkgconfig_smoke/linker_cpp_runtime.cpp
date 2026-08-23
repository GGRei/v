#include <new>

extern "C" int linker_cpp_runtime_probe(void) {
	int* value = new int(42);
	const int result = *value;
	delete value;
	return result;
}
