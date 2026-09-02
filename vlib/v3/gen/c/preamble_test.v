module c

import v3.flat
import v3.pref
import v3.types

fn test_thread_local_decl_uses_portable_c_dialects() {
	mut g := FlatGen.new()
	g.emit_thread_local_decl_after_tinyc('int state;')
	c_code := g.sb.str()
	assert c_code.contains('#elif defined(_MSC_VER)\n__declspec(thread) int state;')
	assert c_code.contains('#elif defined(__cplusplus)\nthread_local int state;')
	assert c_code.contains('#else\n_Thread_local int state;\n#endif')
}

fn test_tinyc_windows_thread_local_slot_uses_win32_tls() {
	mut g := FlatGen.new()
	g.emit_tinyc_windows_thread_local_slot('state', 'int', '')
	c_code := g.sb.str()
	windows_code := c_code.all_before('#elif defined(__TINYC__)')
	assert windows_code.contains('#if defined(__TINYC__) && defined(_WIN32)')
	assert windows_code.contains('state_key = FlsAlloc(state_slot_free);')
	assert windows_code.contains('FlsGetValue(state_key)')
	assert windows_code.contains('FlsSetValue(state_key, p)')
	assert windows_code.contains('state_slot_free(void* p) { free(p); }')
	assert !windows_code.contains('pthread_')
}

fn test_autostr_thread_local_matching_is_restricted_to_builtin_global() {
	mut g := FlatGen.new()
	g.global_modules['g_autostr_addr_state'] = 'builtin'
	g.global_modules['foo.g_autostr_addr_state'] = 'foo'
	assert g.is_builtin_autostr_addr_state('g_autostr_addr_state')
	assert !g.is_builtin_autostr_addr_state('foo.g_autostr_addr_state')
	g.global_modules['g_autostr_addr_state'] = 'main'
	assert !g.is_builtin_autostr_addr_state('g_autostr_addr_state')
}

fn test_headerless_windows_tcc_uses_one_compat_header_and_sdk_declarations() {
	mut g := FlatGen.new()
	g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	g.set_ccompiler('tinyc')
	g.preamble()
	g.atomic_builtin_compat_decls()
	c_code := g.sb.str()
	compat_include := '#include "thirdparty/stdatomic/win/atomic.h"'
	compat_pos := c_code.index(compat_include) or { -1 }
	file_pos := c_code.index('typedef struct FILE FILE;') or { -1 }
	tcc_file_pos := c_code.index('struct _iobuf {') or { -1 }
	tcc_stream_pos := c_code.index('FILE* __cdecl __iob_func(void);') or { -1 }
	generic_stream_pos := c_code.index('#elif defined(_WIN32)\nextern FILE* stdin;\nextern FILE* stdout;\nextern FILE* stderr;') or { -1 }
	assert c_code.count(compat_include) == 1, c_code
	assert compat_pos >= 0, c_code
	assert compat_pos < file_pos, c_code
	assert compat_pos < tcc_file_pos, c_code
	assert tcc_file_pos < file_pos, c_code
	assert tcc_stream_pos < generic_stream_pos, c_code
	assert c_code.count('struct _iobuf {') == 1, c_code
	assert c_code.count('typedef struct _iobuf FILE;') == 2, c_code
	assert c_code.count('FILE* __cdecl __iob_func(void);') == 1, c_code
	assert c_code.contains('#define stdin (&__iob_func()[0])'), c_code
	assert c_code.contains('#define stdout (&__iob_func()[1])'), c_code
	assert c_code.contains('#define stderr (&__iob_func()[2])'), c_code
	assert !c_code.contains('typedef struct SECURITY_ATTRIBUTES {'), c_code
	assert !c_code.contains('typedef struct OVERLAPPED {'), c_code
	assert c_code.contains('#ifndef _SYNCHAPI_H_\ntypedef struct SRWLOCK { void* Ptr; } SRWLOCK;\n#endif'), c_code
	assert !c_code.contains('typedef struct CONDITION_VARIABLE { void* Ptr; } CONDITION_VARIABLE;'), c_code
	assert !c_code.contains('typedef void* atomic_uintptr_t;'), c_code
	assert !c_code.contains('typedef struct COORD { i16 X; i16 Y; } COORD;'), c_code
	assert !c_code.contains('typedef struct INPUT_RECORD {'), c_code
	assert !c_code.contains('HANDLE CreateThread(void* attributes'), c_code
	assert !c_code.contains('DWORD WaitForSingleObject(HANDLE handle, DWORD milliseconds);'), c_code
	assert !c_code.contains('BOOL CloseHandle(HANDLE handle);'), c_code
	assert !c_code.contains('DWORD GetLastError(void);'), c_code
	assert c_code.contains('typedef struct { HANDLE handle; void* context; } __v_thread;'), c_code
	assert c_code.contains('result.handle = CreateThread(NULL, __v_thread_stack_size,'), c_code
	assert c_code.contains('struct fd_set { unsigned int fd_count; SOCKET fd_array[FD_SETSIZE]; };'), c_code
	assert c_code.contains('#define O_RDONLY 0x0000'), c_code
	assert !c_code.contains('int _putenv_s(const char *name, const char *value);'), c_code
	assert !c_code.contains('struct _EXCEPTION_POINTERS;'), c_code
}

fn test_headerless_windows_tcc_preserves_only_atomic_header_sdk_functions() {
	expected := [
		'AddVectoredExceptionHandler',
		'BeginUpdateResourceW',
		'CloseHandle',
		'ConvertFiberToThread',
		'ConvertThreadToFiber',
		'CopyFileW',
		'CreateDirectoryW',
		'CreateEvent',
		'CreateFiber',
		'CreateFileW',
		'CreateHardLinkW',
		'CreateIoCompletionPort',
		'CreateMutex',
		'CreatePipe',
		'CreateProcessW',
		'CreateSemaphore',
		'CreateThread',
		'DeleteFiber',
		'DeleteFileW',
		'EndUpdateResourceW',
		'ExitProcess',
		'ExpandEnvironmentStringsW',
		'FileTimeToSystemTime',
		'FindClose',
		'FindFirstFileW',
		'FindNextFileW',
		'FormatMessageW',
		'FreeEnvironmentStringsW',
		'FreeLibrary',
		'GenerateConsoleCtrlEvent',
		'GetCommandLineW',
		'GetComputerNameW',
		'GetConsoleMode',
		'GetConsoleScreenBufferInfo',
		'GetCurrentProcess',
		'GetCurrentProcessId',
		'GetCurrentThreadId',
		'GetDiskFreeSpaceExA',
		'GetEnvironmentStringsW',
		'GetExitCodeProcess',
		'GetFileAttributesW',
		'GetFullPathNameW',
		'GetLastError',
		'GetLongPathNameW',
		'GetModuleFileNameW',
		'GetModuleHandleA',
		'GetNativeSystemInfo',
		'GetNumberOfConsoleInputEvents',
		'GetProcAddress',
		'GetProcessHeap',
		'GetQueuedCompletionStatus',
		'GetShortPathNameW',
		'GetStdHandle',
		'GetSystemInfo',
		'GetSystemTimeAsFileTime',
		'GetTickCount',
		'GetUserNameW',
		'GlobalAlloc',
		'GlobalFree',
		'GlobalLock',
		'GlobalMemoryStatus',
		'GlobalUnlock',
		'HeapAlloc',
		'HeapFree',
		'IsDebuggerPresent',
		'LoadLibraryW',
		'LocalFree',
		'PeekNamedPipe',
		'PostQueuedCompletionStatus',
		'QueryPerformanceCounter',
		'QueryPerformanceFrequency',
		'ReadConsoleInput',
		'ReadConsoleW',
		'ReadFile',
		'RegCloseKey',
		'RegOpenKeyExW',
		'RegQueryValueExW',
		'RegSetValueExW',
		'ReleaseMutex',
		'ReleaseSemaphore',
		'RemoveDirectoryW',
		'ScrollConsoleScreenBuffer',
		'SetConsoleCursorPosition',
		'SetConsoleMode',
		'SetConsoleTitleW',
		'SetEvent',
		'SetHandleInformation',
		'SetLastError',
		'SetUnhandledExceptionFilter',
		'Sleep',
		'SwitchToFiber',
		'SystemTimeToTzSpecificLocalTime',
		'TerminateProcess',
		'TlsAlloc',
		'TlsFree',
		'TlsGetValue',
		'TlsSetValue',
		'UpdateResourceW',
		'VirtualAlloc',
		'VirtualProtect',
		'WaitForSingleObject',
		'WriteConsoleW',
		'WriteFile',
	]
	sentinels := [
		'SymInitialize',
		'SymFromAddr',
		'SymGetLineFromAddr64',
		'WSAAddressToStringA',
		'InitializeConditionVariable',
		'SleepConditionVariableSRW',
		'WakeConditionVariable',
		'WakeAllConditionVariable',
		'TryAcquireSRWLockExclusive',
		'TryAcquireSRWLockShared',
		'CaptureStackBackTrace',
		'GetFinalPathNameByHandleW',
		'CreateSymbolicLinkW',
	]
	assert expected.len == 103
	assert 'GetCurrentProcessId' in expected
	assert 'MultiByteToWideChar' !in expected
	assert 'WideCharToMultiByte' !in expected
	mut g := FlatGen.new()
	g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	g.set_ccompiler('tinyc')
	assert !g.windows_tcc_atomic_emitted
	g.emit_windows_tcc_atomic_header()
	assert g.windows_tcc_atomic_emitted
	assert g.inlined_c_declared_fns.len == expected.len
	for name in expected {
		assert name in g.inlined_c_declared_fns, name
		assert !g.should_emit_c_extern_decl(name), name
	}
	for name in sentinels {
		assert name !in g.inlined_c_declared_fns, name
		assert g.should_emit_c_extern_decl(name), name
	}
	first_output := g.sb.after(0)
	g.emit_windows_tcc_atomic_header()
	assert g.sb.after(0) == first_output
	assert g.inlined_c_declared_fns.len == expected.len
}

fn test_windows_headers_guard_conditional_nls_and_vista_externs() {
	declaration := 'int MultiByteToWideChar(void);'
	mut g := FlatGen.new()
	g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	g.set_ccompiler('tinyc')
	assert !g.c_directives_use_system_libc()
	assert g.c_windows_conditional_system_extern_decl('MultiByteToWideChar', declaration) == '#ifdef NONLS\n${declaration}\n#endif'
	assert g.c_windows_conditional_system_extern_decl('WideCharToMultiByte', declaration) == '#ifdef NONLS\n${declaration}\n#endif'
	assert g.c_windows_conditional_system_extern_decl('GetConsoleMode', declaration) == declaration
	mut system_g := FlatGen.new()
	system_g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	system_g.set_ccompiler('tinyc')
	system_g.add_c_directive('main', '#include <stdio.h>', false)
	assert system_g.c_directives_use_system_libc()
	for name in ['MultiByteToWideChar', 'WideCharToMultiByte'] {
		assert system_g.c_windows_conditional_system_extern_decl(name, declaration) == '#ifdef NONLS\n${declaration}\n#endif'
	}
	system_g.set_ccompiler('gcc')
	for name in ['MultiByteToWideChar', 'WideCharToMultiByte'] {
		assert system_g.c_windows_conditional_system_extern_decl(name, declaration) == '#ifdef NONLS\n${declaration}\n#endif'
	}
	for name in c_windows_vista_conditional_extern_fns.keys() {
		assert system_g.c_windows_conditional_system_extern_decl(name, declaration) == '#if !defined(_WIN32_WINNT) || _WIN32_WINNT < 0x0600\n${declaration}\n#endif'
	}
	g.set_ccompiler('gcc')
	for name in ['MultiByteToWideChar', 'WideCharToMultiByte'] {
		assert g.c_windows_conditional_system_extern_decl(name, declaration) == declaration
	}
	g.set_target(pref.target_from('linux', 'amd64') or { panic(err) })
	g.set_ccompiler('tinyc')
	for name in ['MultiByteToWideChar', 'WideCharToMultiByte'] {
		assert g.c_windows_conditional_system_extern_decl(name, declaration) == declaration
	}
}

fn test_windows_system_libc_owns_exact_header_backed_extern_sets() {
	expected_central := [
		'FileTimeToSystemTime',
		'GetConsoleMode',
		'GetConsoleScreenBufferInfo',
		'GetCurrentProcessId',
		'GetCurrentThreadId',
		'GetStdHandle',
		'GetSystemTimeAsFileTime',
		'QueryPerformanceCounter',
		'QueryPerformanceFrequency',
		'ScrollConsoleScreenBuffer',
		'SetConsoleCursorPosition',
		'SetConsoleMode',
		'Sleep',
		'SystemTimeToTzSpecificLocalTime',
		'WriteConsoleW',
		'_chsize_s',
		'_dup',
		'_dup2',
		'_get_osfhandle',
		'_pipe',
		'_setmode',
		'_waccess',
		'_wchdir',
		'_wgetcwd',
		'_wopen',
		'_wrename',
		'_wstat',
		'_wstat64',
		'wcslen',
		'_wsystem',
	]
	expected_nls := ['MultiByteToWideChar', 'WideCharToMultiByte']
	expected_vista := [
		'AcquireSRWLockExclusive',
		'AcquireSRWLockShared',
		'InitializeConditionVariable',
		'InitializeSRWLock',
		'ReleaseSRWLockExclusive',
		'ReleaseSRWLockShared',
		'SleepConditionVariableSRW',
		'TryAcquireSRWLockExclusive',
		'TryAcquireSRWLockShared',
		'WakeConditionVariable',
	]
	assert c_windows_system_libc_declared_fns == expected_central
	assert c_windows_nls_conditional_extern_fns.keys().sorted() == expected_nls
	assert c_windows_vista_conditional_extern_fns.keys().sorted() == expected_vista

	mut central := map[string]bool{}
	for name in expected_central {
		assert name !in central, name
		central[name] = true
	}
	assert central.len == 30
	for name in expected_nls {
		assert name !in central, name
		assert c_extern_calling_convention(name) == 'WINAPI', name
	}
	for name in expected_vista {
		assert name !in central, name
		assert c_extern_calling_convention(name) == 'WINAPI', name
	}

	mut effective := central.clone()
	assert '_wremove' in c_manual_stdlib_declared_fns
	effective['_wremove'] = true
	assert effective.len == 31

	mut g := FlatGen.new()
	g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	g.add_c_directive('main', '#include <stdio.h>', false)
	g.system_libc_preamble()
	for name in expected_central {
		assert !g.should_emit_c_extern_decl(name), name
	}
	assert !g.should_emit_c_extern_decl('_wremove')
	for name in expected_nls {
		assert g.should_emit_c_extern_decl(name), name
	}
	for name in expected_vista {
		assert g.should_emit_c_extern_decl(name), name
	}
	owned_source := '/virtual/vlib/sync/sync_windows.c.v'
	g.header_owned_c_extern_sources[c_extern_source_key(owned_source)] = true
	for name in expected_nls {
		assert g.should_emit_c_extern_decl_from_file(name, owned_source), name
	}
	for name in expected_vista {
		assert g.should_emit_c_extern_decl_from_file(name, owned_source), name
	}
	assert !g.should_emit_c_extern_decl_from_file('unrelated_header_api', owned_source)
	assert g.inlined_c_structs['__stat64']
	assert g.inlined_c_structs['_FILETIME']
	assert '__stat64' !in g.inlined_c_typedef_names
	assert '_FILETIME' !in g.inlined_c_typedef_names
}

fn test_windows_system_libc_headers_define_fixed_crt_and_vista_contract() {
	mut g := FlatGen.new()
	g.system_libc_headers()
	c_code := g.sb.str()
	windows_start := c_code.index('#ifdef _WIN32\n') or { panic(c_code) }
	windows_end := c_code.index_after('\n#else\n', windows_start) or { panic(c_code) }
	windows_code := c_code[windows_start..windows_end]
	for header in ['io.h', 'direct.h', 'fcntl.h', 'process.h', 'sys/stat.h', 'windows.h',
		'synchapi.h'] {
		assert windows_code.count('#include <${header}>') == 1, header
	}
	guard := '#ifndef _WIN32_WINNT\n#define _WIN32_WINNT 0x0600\n#endif\n#include <windows.h>\n#include <synchapi.h>'
	assert c_code.contains(guard), c_code
	stat_header_pos := c_code.index('#include <sys/stat.h>') or { -1 }
	guard_pos := c_code.index(guard) or { -1 }
	assert stat_header_pos >= 0 && stat_header_pos < guard_pos, c_code
}

fn test_unresolved_windows_header_does_not_replace_central_system_ownership() {
	source := '/virtual/vlib/builtin/builtin_windows.c.v'
	mut g := FlatGen.new()
	g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	g.collect_c_directive('builtin', flat.Node{
		kind:  .directive
		value: 'include'
		typ:   '<issue74_v37_implicit_windows_header.h>'
	}, source, false)
	assert !g.header_owned_c_extern_sources[c_extern_source_key(source)]
	assert g.should_emit_c_extern_decl_from_file('_waccess', source)

	// A different directive selects the fixed system preamble. Its central
	// metadata must own the symbol even though the source header was unresolved.
	g.add_c_directive('main', '#include <stdio.h>', false)
	g.system_libc_preamble()
	assert !g.header_owned_c_extern_sources[c_extern_source_key(source)]
	assert !g.should_emit_c_extern_decl_from_file('_waccess', source)
}

fn test_system_libc_windows_tcc_atomic_header_does_not_preserve_sdk_functions() {
	mut g := FlatGen.new()
	g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	g.set_ccompiler('tinyc')
	g.add_c_directive('main', '#include <stdio.h>', false)
	assert g.c_directives_use_system_libc()
	g.preamble()
	compat_include := '#include "thirdparty/stdatomic/win/atomic.h"'
	before_output := g.sb.after(0)
	assert before_output.contains('#include <windows.h>'), before_output
	assert before_output.contains('#include <windows.h>\n#include <synchapi.h>'), before_output
	assert before_output.contains('#ifndef _WIN32_WINNT\n#define _WIN32_WINNT 0x0600\n#endif'), before_output
	assert !before_output.contains('int _putenv_s(const char *name, const char *value);'), before_output
	assert !before_output.contains('struct _EXCEPTION_POINTERS;'), before_output
	assert before_output.count(compat_include) == 0, before_output
	assert !g.windows_tcc_atomic_emitted
	for name in c_windows_system_libc_declared_fns {
		assert name in g.inlined_c_declared_fns, name
		assert !g.should_emit_c_extern_decl(name), name
	}
	for name in c_windows_nls_conditional_extern_fns.keys() {
		assert name !in g.inlined_c_declared_fns, name
		assert g.should_emit_c_extern_decl(name), name
	}
	for name in c_windows_vista_conditional_extern_fns.keys() {
		assert name !in g.inlined_c_declared_fns, name
		assert g.should_emit_c_extern_decl(name), name
	}
	for name in c_headerless_windows_tcc_sdk_declared_fns {
		if name !in c_windows_system_libc_declared_fns {
			assert name !in g.inlined_c_declared_fns, name
		}
	}
	g.emit_windows_tcc_atomic_header()
	assert g.windows_tcc_atomic_emitted
	for name in c_windows_system_libc_declared_fns {
		assert name in g.inlined_c_declared_fns, name
		assert !g.should_emit_c_extern_decl(name), name
	}
	for name in c_windows_nls_conditional_extern_fns.keys() {
		assert name !in g.inlined_c_declared_fns, name
		assert g.should_emit_c_extern_decl(name), name
	}
	for name in c_windows_vista_conditional_extern_fns.keys() {
		assert name !in g.inlined_c_declared_fns, name
		assert g.should_emit_c_extern_decl(name), name
	}
	for name in c_headerless_windows_tcc_sdk_declared_fns {
		if name !in c_windows_system_libc_declared_fns {
			assert name !in g.inlined_c_declared_fns, name
		}
	}
	first_output := g.sb.after(0)
	compat_pos := first_output.index(compat_include) or { -1 }
	assert first_output.count(compat_include) == 1, first_output
	assert first_output.starts_with(before_output), first_output
	assert compat_pos >= before_output.len, first_output
	g.emit_windows_tcc_atomic_header()
	assert g.sb.after(0) == first_output
	assert g.windows_tcc_atomic_emitted
}

fn test_headerless_windows_non_tcc_keeps_local_sdk_fallbacks() {
	mut ast := &flat.FlatAst{}
	mut tc := types.TypeChecker.new(ast)
	mut g := FlatGen.new()
	g.a = ast
	g.tc = &tc
	g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	g.set_ccompiler('gcc')
	g.has_builtins = true
	g.preamble()
	g.builtin_abi_decls()
	c_code := g.sb.str()
	mingw_file_pos := c_code.index('typedef struct _iobuf FILE;') or { -1 }
	mingw_stream_pos := c_code.index('FILE* __cdecl __acrt_iob_func(unsigned index);') or { -1 }
	generic_stream_pos := c_code.index('#elif defined(_WIN32)\nextern FILE* stdin;\nextern FILE* stdout;\nextern FILE* stderr;') or { -1 }
	assert mingw_file_pos >= 0, c_code
	assert mingw_stream_pos > mingw_file_pos, c_code
	assert mingw_stream_pos < generic_stream_pos, c_code
	assert c_code.count('FILE* __cdecl __acrt_iob_func(unsigned index);') == 1, c_code
	assert c_code.contains('#define stdin  (__acrt_iob_func(0))'), c_code
	assert c_code.contains('#define stdout (__acrt_iob_func(1))'), c_code
	assert c_code.contains('#define stderr (__acrt_iob_func(2))'), c_code
	assert c_code.contains('typedef struct CONDITION_VARIABLE { void* Ptr; } CONDITION_VARIABLE;'), c_code
	assert c_code.contains('typedef struct COORD { i16 X; i16 Y; } COORD;'), c_code
	assert c_code.contains('HANDLE CreateThread(void* attributes'), c_code
	assert g.should_emit_c_extern_decl('GetConsoleMode')
	assert c_code.count('void* _aligned_malloc(size_t size, size_t alignment);') == 1, c_code
	assert c_code.count('void _aligned_free(void* memblock);') == 1, c_code
	assert c_code.count('int _putenv_s(const char *name, const char *value);') == 1, c_code
	assert c_code.count('struct _EXCEPTION_POINTERS;') == 1, c_code
	assert c_code.count('typedef long (WINAPI *PTOP_LEVEL_EXCEPTION_FILTER)(struct _EXCEPTION_POINTERS*);') == 1, c_code

	assert c_code.count('typedef PTOP_LEVEL_EXCEPTION_FILTER LPTOP_LEVEL_EXCEPTION_FILTER;') == 1, c_code

	assert c_code.count('LPTOP_LEVEL_EXCEPTION_FILTER WINAPI SetUnhandledExceptionFilter(') == 1, c_code

	assert !g.should_emit_c_extern_decl('_aligned_malloc')
	assert !g.should_emit_c_extern_decl('_aligned_free')
	assert !g.should_emit_c_extern_decl('_putenv_s')
	assert !g.should_emit_c_extern_decl('SetUnhandledExceptionFilter')
}

fn test_headerless_windows_non_tcc_without_builtins_keeps_aligned_externs_owned_by_source() {
	mut ast := &flat.FlatAst{}
	mut tc := types.TypeChecker.new(ast)
	mut g := FlatGen.new()
	g.a = ast
	g.tc = &tc
	g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	g.set_ccompiler('gcc')
	assert !g.has_builtins
	g.preamble()
	g.builtin_abi_decls()
	c_code := g.sb.after(0)
	assert !c_code.contains('void* _aligned_malloc(size_t size, size_t alignment);'), c_code
	assert !c_code.contains('void _aligned_free(void* memblock);'), c_code
	assert g.should_emit_c_extern_decl('_aligned_malloc')
	assert g.should_emit_c_extern_decl('_aligned_free')
	assert c_code.count('int _putenv_s(const char *name, const char *value);') == 1, c_code
	assert c_code.count('LPTOP_LEVEL_EXCEPTION_FILTER WINAPI SetUnhandledExceptionFilter(') == 1, c_code
}

fn test_non_windows_preamble_does_not_emit_windows_abi_fallbacks() {
	mut ast := &flat.FlatAst{}
	mut tc := types.TypeChecker.new(ast)
	mut g := FlatGen.new()
	g.a = ast
	g.tc = &tc
	g.set_target(pref.target_from('linux', 'amd64') or { panic(err) })
	g.set_ccompiler('gcc')
	g.has_builtins = true
	g.preamble()
	g.builtin_abi_decls()
	c_code := g.sb.after(0)
	for declaration in [
		'int _putenv_s(const char *name, const char *value);',
		'struct _EXCEPTION_POINTERS;',
		'PTOP_LEVEL_EXCEPTION_FILTER',
		'LPTOP_LEVEL_EXCEPTION_FILTER',
		'SetUnhandledExceptionFilter(',
	] {
		assert !c_code.contains(declaration), declaration
	}
	assert c_code.contains('#ifdef _WIN32\nvoid* _aligned_malloc(size_t size, size_t alignment);'), c_code
}

fn test_manual_stdlib_headers_clear_fortified_memory_macros() {
	headers := manual_stdlib_c_headers()
	for name in ['memcpy', 'memmove', 'memset'] {
		assert headers.contains('#ifdef ${name}\n#undef ${name}\n#endif'), name
	}
}

fn test_system_libc_thread_preamble_uses_native_windows_api() {
	mut g := FlatGen.new()
	g.system_libc_preamble()
	c_code := g.sb.str()
	windows_start := c_code.index('#ifdef _WIN32') or { panic('missing Windows guard') }
	posix_start := c_code.index('#else\ntypedef struct { pthread_t handle; } __v_thread;') or {
		panic('missing POSIX fallback')
	}
	windows_code := c_code[windows_start..posix_start]
	assert windows_code.contains('CreateThread('), windows_code
	assert windows_code.contains('WaitForSingleObject('), windows_code
	assert windows_code.contains('CloseHandle('), windows_code
	assert windows_code.contains('return a.handle == b.handle;'), windows_code
	assert !windows_code.contains('pthread_'), windows_code
	posix_code := c_code[posix_start..]
	assert posix_code.contains('pthread_equal(a.handle, b.handle) != 0'), posix_code
}

fn test_headerless_pthread_fallback_respects_darwin_type_guards() {
	mut g := FlatGen.new()
	g.headerless_libc_preamble()
	c_code := g.sb.str()
	guard := c_code.all_before('typedef void* pthread_t;')
	assert guard.contains('!defined(_SYS__PTHREAD_TYPES_H_)'), guard
	assert guard.contains('!defined(_PTHREAD_T)'), guard
	assert c_code.contains('#if defined(__APPLE__) && defined(_SYS__PTHREAD_TYPES_H_)'), c_code
	assert c_code.contains('#define V_HEADERLESS_DARWIN_PTHREAD_TYPES 1'), c_code
	assert c_code.contains('typedef __darwin_pthread_t pthread_t;'), c_code
	assert c_code.contains('typedef __darwin_pthread_key_t pthread_key_t;'), c_code
	assert c_code.contains('#define PTHREAD_MUTEX_INITIALIZER { 0x32AAABA7, { 0 } }'), c_code
	assert c_code.contains('int pthread_equal(pthread_t t1, pthread_t t2);'), c_code
	assert c_code.contains('pthread_equal(a.handle, b.handle) != 0'), c_code
}

fn test_headerless_libc_preamble_declares_printf_for_cached_test_harnesses() {
	mut g := FlatGen.new()
	g.headerless_libc_preamble()
	c_code := g.sb.str()
	assert c_code.contains('int printf(const char* format, ...);'), c_code
	assert c_code.contains('void perror(const char* message);'), c_code
	assert c_code.contains('void* memchr(const void* s, int c, size_t n);'), c_code
	assert c_code.contains('DWORD WINAPI TlsAlloc(void);'), c_code
	assert c_code.contains('void* WINAPI TlsGetValue(DWORD index);'), c_code
	assert c_code.contains('BOOL WINAPI TlsSetValue(DWORD index, void* value);'), c_code
	assert c_code.contains('DWORD WINAPI FlsAlloc(void (WINAPI *callback)(void*));'), c_code
	assert c_code.contains('void* WINAPI FlsGetValue(DWORD index);'), c_code
	assert c_code.contains('BOOL WINAPI FlsSetValue(DWORD index, void* value);'), c_code
}

fn test_headerless_libc_preamble_declares_qsort_for_generated_sort_helpers() {
	mut g := FlatGen.new()
	g.headerless_libc_preamble()
	c_code := g.sb.str()
	assert c_code.contains('void qsort(void* base, size_t items, size_t item_size, int (*cb)(const void*, const void*));'), c_code
}

fn test_headerless_linux_stat_preamble_supports_s390x() {
	mut g := FlatGen.new()
	g.headerless_linux_stat_struct()
	c_code := g.sb.str()
	s390_guard := '#elif defined(__s390x__)'
	s390_layout := 'struct stat { u64 st_dev; u64 st_ino; u64 st_nlink; u32 st_mode; u32 st_uid; u32 st_gid; int __glibc_reserved0; u64 st_rdev; i64 st_size; i64 st_atime; unsigned long st_atimensec; i64 st_mtime; unsigned long st_mtimensec; i64 st_ctime; unsigned long st_ctimensec; i64 st_blksize; i64 st_blocks; i64 __glibc_reserved[3]; };'
	assert c_code.contains('${s390_guard}\n${s390_layout}'), c_code
}

fn test_arch_macros_cover_all_supported_targets() {
	mut g := FlatGen.new()
	g.write_arch_macros()
	c_code := g.sb.str()
	for architecture, id in {
		'amd64':       1
		'arm64':       2
		'arm32':       3
		'rv64':        4
		'rv32':        5
		'x86':         6
		's390x':       7
		'ppc64le':     8
		'loongarch64': 9
		'sparc64':     10
		'ppc64':       11
		'ppc':         12
	} {
		assert c_code.contains('#define __V_${architecture} 1'), architecture
		assert c_code.contains('#define __V_architecture ${id}'), architecture
	}
}

fn test_libc_compat_gettid_supports_s390x() {
	mut g := FlatGen.new()
	g.libc_compat_fns['gettid'] = true
	g.libc_compat_decls()
	c_code := g.sb.str()
	assert c_code.contains('#elif defined(__s390x__)\n#define SYS_gettid 236'), c_code
}

fn test_headerless_libc_preamble_suppresses_its_mach_timebase_declaration() {
	mut g := FlatGen.new()
	g.headerless_libc_preamble()
	assert !g.should_emit_c_extern_decl('mach_timebase_info')
}

fn test_headerless_platform_constants_include_process_errno_values() {
	mut g := FlatGen.new()
	g.headerless_platform_constants()
	c_code := g.sb.str()
	for definition in ['#define EPERM 1', '#define ESRCH 3', '#define EACCES 13'] {
		assert c_code.contains(definition), definition
	}
}

fn test_manual_stdlib_headers_define_l_tmpnam_for_glibc() {
	// The v3 backend embeds and reuses the v1 c_headers prelude (see manual_stdlib_c_headers).
	// Make sure the glibc L_tmpnam define is inherited, so a module header that pulls <stdio.h>
	// in on glibc still finds L_tmpnam; see https://github.com/vlang/v/issues/28108 .
	headers := manual_stdlib_c_headers()
	assert headers.contains('#if defined(__GLIBC__) || defined(__GNU_LIBRARY__)'), headers#[-500..]
	assert headers.contains('#ifndef L_tmpnam\n#define L_tmpnam 20\n#endif'), headers#[-500..]
}

fn test_builtin_abi_decls_reuse_tcc_x64_stdatomic_fence_declaration() {
	mut g := FlatGen.new()
	g.atomic_thread_fence_compat_decls()
	c_code := g.sb.str()
	assert c_code.contains('#define atomic_thread_fence(order) __atomic_thread_fence(order)')
	assert !c_code.contains('extern void __atomic_thread_fence(int order);')
}

fn test_builtin_heap_tracking_fallbacks_do_not_redefine_user_hooks() {
	mut fallback := FlatGen.new()
	fallback.heap_tracking_fallback_decls()
	assert fallback.sb.str().contains('__attribute__((weak)) void vheap_alloc')

	mut tracked := FlatGen.new()
	tracked.set_track_heap(true)
	tracked.heap_tracking_fallback_decls()
	assert tracked.sb.len == 0
}

fn test_system_libc_headers_make_stdatomic_compatible_with_gnu_objective_c() {
	mut g := FlatGen.new()
	g.system_libc_headers()
	c_code := g.sb.str()
	compat_guard := '#if defined(__OBJC__) && defined(__GNUC__) && !defined(__clang__)'
	assert c_code.contains('${compat_guard}\n#define _Atomic volatile\n#endif\n#include <stdatomic.h>')
	assert c_code.contains('#include <stdatomic.h>\n${compat_guard}\n#undef _Atomic\n#endif')
}
