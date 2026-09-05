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
	g.inlined_c_declared_fns['GetFinalPathNameByHandleW'] = true
	assert !g.should_emit_c_extern_decl('GetFinalPathNameByHandleW')
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
	assert !c_code.contains('DWORD WINAPI WaitForSingleObject(HANDLE handle, DWORD milliseconds);'), c_code
	assert !c_code.contains('BOOL CloseHandle(HANDLE handle);'), c_code
	assert !c_code.contains('DWORD WINAPI GetLastError(void);'), c_code
	assert c_code.count('#define FILE_ATTRIBUTE_READONLY 0x00000001U') == 1, c_code
	assert c_code.contains('typedef struct { HANDLE handle; void* context; } __v_thread;'), c_code
	assert c_code.contains('result.handle = CreateThread(NULL, __v_thread_stack_size,'), c_code
	assert c_code.contains('struct fd_set { unsigned int fd_count; SOCKET fd_array[FD_SETSIZE]; };'), c_code
	assert c_code.contains('#define O_RDONLY 0x0000'), c_code
	assert !c_code.contains('int _putenv_s(const char *name, const char *value);'), c_code
	assert !c_code.contains('struct _EXCEPTION_POINTERS;'), c_code
}

fn test_headerless_windows_tcc_preserves_only_atomic_header_sdk_functions() {
	expected_sdk := [
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
	expected_crt := ['wcslen']
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
	assert expected_sdk.len == 103
	assert expected_crt.len == 1
	assert expected_sdk.len + expected_crt.len == 104
	assert 'GetCurrentProcessId' in expected_sdk
	assert 'MultiByteToWideChar' !in expected_sdk
	assert 'WideCharToMultiByte' !in expected_sdk
	mut g := FlatGen.new()
	g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	g.set_ccompiler('tinyc')
	assert !g.windows_tcc_atomic_emitted
	g.emit_windows_tcc_atomic_header()
	assert g.windows_tcc_atomic_emitted
	assert g.inlined_c_declared_fns.len == expected_sdk.len + expected_crt.len
	assert g.inlined_c_structs['_FILETIME']
	assert '_FILETIME' !in g.inlined_c_typedef_names
	for name in expected_sdk {
		assert name in g.inlined_c_declared_fns, name
		assert !g.should_emit_c_extern_decl(name), name
	}
	for name in expected_crt {
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
	assert g.inlined_c_declared_fns.len == expected_sdk.len + expected_crt.len
	assert g.inlined_c_structs['_FILETIME']
	assert '_FILETIME' !in g.inlined_c_typedef_names
}

fn test_headerless_windows_tcc_tracks_atomic_header_macros() {
	expected_macros := [
		'atomic_load_ptr',
		'atomic_store_ptr',
		'atomic_compare_exchange_weak_ptr',
		'atomic_compare_exchange_strong_ptr',
		'atomic_exchange_ptr',
		'atomic_fetch_add_ptr',
		'atomic_fetch_sub_ptr',
		'atomic_compare_exchange_weak_byte',
		'atomic_exchange_byte',
		'atomic_fetch_add_byte',
		'atomic_fetch_sub_byte',
		'atomic_compare_exchange_weak_u16',
		'atomic_exchange_u16',
		'atomic_fetch_add_u16',
		'atomic_fetch_sub_u16',
		'atomic_compare_exchange_weak_u32',
		'atomic_exchange_u32',
		'atomic_fetch_add_u32',
		'atomic_fetch_sub_u32',
		'atomic_compare_exchange_weak_u64',
		'atomic_exchange_u64',
		'atomic_fetch_add_u64',
		'atomic_fetch_sub_u64',
		'atomic_thread_fence',
		'cpu_relax',
	]
	atomic_declarations := [
		'atomic_load_ptr',
		'atomic_store_ptr',
		'atomic_compare_exchange_weak_ptr',
		'atomic_compare_exchange_strong_ptr',
		'atomic_exchange_ptr',
		'atomic_fetch_add_ptr',
		'atomic_fetch_sub_ptr',
		'atomic_load_byte',
		'atomic_store_byte',
		'atomic_compare_exchange_weak_byte',
		'atomic_compare_exchange_strong_byte',
		'atomic_exchange_byte',
		'atomic_fetch_add_byte',
		'atomic_fetch_sub_byte',
		'atomic_load_u16',
		'atomic_store_u16',
		'atomic_compare_exchange_weak_u16',
		'atomic_compare_exchange_strong_u16',
		'atomic_exchange_u16',
		'atomic_fetch_add_u16',
		'atomic_fetch_sub_u16',
		'atomic_load_u32',
		'atomic_store_u32',
		'atomic_compare_exchange_weak_u32',
		'atomic_compare_exchange_strong_u32',
		'atomic_exchange_u32',
		'atomic_fetch_add_u32',
		'atomic_fetch_sub_u32',
		'atomic_load_u64',
		'atomic_store_u64',
		'atomic_compare_exchange_weak_u64',
		'atomic_compare_exchange_strong_u64',
		'atomic_exchange_u64',
		'atomic_fetch_add_u64',
		'atomic_fetch_sub_u64',
		'atomic_thread_fence',
		'cpu_relax',
	]
	assert expected_macros.len == 25
	assert atomic_declarations.len == 37
	mut covered_declarations := map[string]bool{}
	for name in expected_macros {
		covered_declarations[name] = true
	}
	for name in atomic_declarations {
		if name in c_static_helper_symbols {
			covered_declarations[name] = true
		}
	}
	assert covered_declarations.len == atomic_declarations.len
	for name in atomic_declarations {
		assert covered_declarations[name], name
	}
	mut g := FlatGen.new()
	g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	g.set_ccompiler('tinyc')
	g.emit_windows_tcc_atomic_header()
	assert g.inlined_c_active_macros.len == expected_macros.len
	for name in expected_macros {
		assert g.inlined_c_active_macros[name], name
	}
	for name in atomic_declarations {
		assert !g.should_emit_c_extern_decl(name), name
	}
	first_output := g.sb.after(0)
	g.emit_windows_tcc_atomic_header()
	assert g.sb.after(0) == first_output
	assert g.inlined_c_active_macros.len == expected_macros.len
	for name in expected_macros {
		assert g.inlined_c_active_macros[name], name
	}
	g.atomic_thread_fence_compat_decls()
	headerless_code := g.sb.after(0)
	assert headerless_code == first_output
	assert headerless_code.count('#include "thirdparty/stdatomic/win/atomic.h"') == 1
	assert !headerless_code.contains('_V_atomic_thread_fence')

	mut system_ast := &flat.FlatAst{}
	mut system_tc := types.TypeChecker.new(system_ast)
	mut system_g := FlatGen.new()
	system_g.a = system_ast
	system_g.tc = &system_tc
	system_g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	system_g.set_ccompiler('tinyc')
	system_g.has_builtins = true
	system_g.add_c_directive('main', '#include <stdio.h>', false)
	system_g.preamble()
	system_before_fence := system_g.sb.after(0)
	system_g.atomic_thread_fence_compat_decls()
	system_code := system_g.sb.after(0)
	assert system_code == system_before_fence
	assert system_code.contains('#include <stdatomic.h>'), system_code
	assert !system_code.contains('#include "thirdparty/stdatomic/win/atomic.h"'), system_code
	assert !system_code.contains('_V_atomic_thread_fence'), system_code
	assert !system_g.windows_tcc_atomic_emitted
	assert system_g.inlined_c_active_macros.len == 0
	assert !system_g.should_emit_c_extern_decl('atomic_thread_fence')
	assert 'wcslen' in system_g.inlined_c_declared_fns
	assert !system_g.should_emit_c_extern_decl('wcslen')
	system_g.builtin_abi_decls()
	system_builtin_code := system_g.sb.after(0)
	assert system_builtin_code.contains('#include <stdatomic.h>'), system_builtin_code
	assert system_builtin_code.count('thirdparty/stdatomic/win/atomic.h') == 1,
		system_builtin_code
	assert system_g.windows_tcc_atomic_emitted
	assert !system_builtin_code.contains('_V_atomic_thread_fence'), system_builtin_code

	mut non_tcc_g := FlatGen.new()
	non_tcc_g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	non_tcc_g.set_ccompiler('gcc')
	non_tcc_g.preamble()
	non_tcc_code := non_tcc_g.sb.str()
	assert !non_tcc_code.contains('#include "thirdparty/stdatomic/win/atomic.h"'), non_tcc_code
	assert non_tcc_g.inlined_c_active_macros.len == 0
	assert non_tcc_g.should_emit_c_extern_decl('atomic_thread_fence')
	assert non_tcc_g.should_emit_c_extern_decl('wcslen')
}

fn test_headerless_windows_emits_exact_stat_platform_struct() {
	mut a := flat.FlatAst.new()
	mut tc := types.TypeChecker.new(&a)
	stat_fields := [
		types.StructField{
			name: 'st_dev'
			typ:  types.Type(types.u32_)
		},
		types.StructField{
			name: 'st_ino'
			typ:  types.Type(types.u16_)
		},
		types.StructField{
			name: 'st_mode'
			typ:  types.Type(types.u16_)
		},
		types.StructField{
			name: 'st_nlink'
			typ:  types.Type(types.u16_)
		},
		types.StructField{
			name: 'st_uid'
			typ:  types.Type(types.u16_)
		},
		types.StructField{
			name: 'st_gid'
			typ:  types.Type(types.u16_)
		},
		types.StructField{
			name: 'st_rdev'
			typ:  types.Type(types.u32_)
		},
		types.StructField{
			name: 'st_size'
			typ:  types.Type(types.u64_)
		},
		types.StructField{
			name: 'st_atime'
			typ:  types.Type(types.i64_)
		},
		types.StructField{
			name: 'st_mtime'
			typ:  types.Type(types.i64_)
		},
		types.StructField{
			name: 'st_ctime'
			typ:  types.Type(types.i64_)
		},
	]
	assert stat_fields.len == 11
	tc.structs['C.__stat64'] = stat_fields

	for compiler in ['tinyc', 'gcc', 'clang', 'msvc'] {
		mut g := FlatGen.new()
		g.a = &a
		g.tc = &tc
		g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
		g.set_ccompiler(compiler)
		g.register_struct_decl_info('C.__stat64', 'C.__stat64', 'os',
			'/virtual/vlib/os/os_structs_stat_windows.c.v', flat.Node{
			value: '__stat64'
		})
		assert !g.skip_builtin_struct('C.__stat64'), compiler
		if compiler == 'tinyc' {
			g.emit_struct('C.__stat64')
			c_code := g.sb.str()
			expected := 'struct __stat64 {\n\tu32 st_dev;\n\tu16 st_ino;\n\tu16 st_mode;\n\tu16 st_nlink;\n\tu16 st_uid;\n\tu16 st_gid;\n\tu32 st_rdev;\n\tu64 st_size;\n\ti64 st_atime;\n\ti64 st_mtime;\n\ti64 st_ctime;\n};'
			assert c_code.count(expected) == 1, c_code
			assert c_code.count('struct __stat64;') == 0, c_code
		}

		mut system_g := FlatGen.new()
		system_g.a = &a
		system_g.tc = &tc
		system_g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
		system_g.set_ccompiler(compiler)
		system_g.add_c_directive('main', '#include <stdio.h>', false)
		system_g.register_struct_decl_info('C.__stat64', 'C.__stat64', 'os',
			'/virtual/vlib/os/os_structs_stat_windows.c.v', flat.Node{
			value: '__stat64'
		})
		assert system_g.skip_builtin_struct('C.__stat64'), compiler
	}

	mut linux_g := FlatGen.new()
	linux_g.a = &a
	linux_g.tc = &tc
	linux_g.set_target(pref.target_from('linux', 'amd64') or { panic(err) })
	linux_g.set_ccompiler('tinyc')
	linux_g.register_struct_decl_info('C.__stat64', 'C.__stat64', 'os',
		'/virtual/vlib/os/os_structs_stat_windows.c.v', flat.Node{
		value: '__stat64'
	})
	assert linux_g.skip_builtin_struct('C.__stat64')

	mut wrong_source_g := FlatGen.new()
	wrong_source_g.a = &a
	wrong_source_g.tc = &tc
	wrong_source_g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	wrong_source_g.set_ccompiler('tinyc')
	wrong_source_g.register_struct_decl_info('C.__stat64', 'C.__stat64', 'os',
		'/virtual/vlib/os/unrelated_windows.c.v', flat.Node{
		value: '__stat64'
	})
	assert wrong_source_g.skip_builtin_struct('C.__stat64')

	mut wrong_name_g := FlatGen.new()
	wrong_name_g.a = &a
	wrong_name_g.tc = &tc
	wrong_name_g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	wrong_name_g.set_ccompiler('tinyc')
	wrong_name_g.register_struct_decl_info('C.OtherStat', 'C.OtherStat', 'os',
		'/virtual/vlib/os/os_structs_stat_windows.c.v', flat.Node{
		value: 'OtherStat'
	})
	assert wrong_name_g.skip_builtin_struct('C.OtherStat')
}

fn test_headerless_windows_emits_or_aliases_exact_filetime_platform_struct() {
	mut a := flat.FlatAst.new()
	mut tc := types.TypeChecker.new(&a)
	filetime_fields := [
		types.StructField{
			name: 'dwLowDateTime'
			typ:  types.Type(types.u32_)
		},
		types.StructField{
			name: 'dwHighDateTime'
			typ:  types.Type(types.u32_)
		},
	]
	assert filetime_fields.len == 2
	tc.structs['C._FILETIME'] = filetime_fields
	alias := 'typedef struct _FILETIME _FILETIME;'
	body := 'struct _FILETIME {\n\tu32 dwLowDateTime;\n\tu32 dwHighDateTime;\n};'

	mut tinyc_g := FlatGen.new()
	tinyc_g.a = &a
	tinyc_g.tc = &tc
	tinyc_g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	tinyc_g.set_ccompiler('tinyc')
	tinyc_g.register_struct_decl_info('C._FILETIME', 'C._FILETIME', 'time',
		'/virtual/vlib/time/time_windows.c.v', flat.Node{
		value: '_FILETIME'
	})
	tinyc_g.emit_windows_tcc_atomic_header()
	assert tinyc_g.inlined_c_structs['_FILETIME']
	assert '_FILETIME' !in tinyc_g.inlined_c_typedef_names
	assert tinyc_g.skip_builtin_struct('C._FILETIME')
	tinyc_g.gen_type_declaration_block()
	tinyc_code := tinyc_g.sb.str()
	assert tinyc_code.count(alias) == 1, tinyc_code
	assert tinyc_code.count(body) == 0, tinyc_code
	assert tinyc_code.count('struct _FILETIME {') == 0, tinyc_code
	assert tinyc_code.count('struct _FILETIME;') == 0, tinyc_code
	include_pos := tinyc_code.index('#include "thirdparty/stdatomic/win/atomic.h"') or { -1 }
	alias_pos := tinyc_code.index(alias) or { -1 }
	assert include_pos >= 0 && include_pos < alias_pos, tinyc_code

	for compiler in ['gcc', 'clang', 'msvc'] {
		mut g := FlatGen.new()
		g.a = &a
		g.tc = &tc
		g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
		g.set_ccompiler(compiler)
		g.register_struct_decl_info('C._FILETIME', 'C._FILETIME', 'time',
			'/virtual/vlib/time/time_windows.c.v', flat.Node{
			value: '_FILETIME'
		})
		assert '_FILETIME' !in g.inlined_c_structs, compiler
		assert '_FILETIME' !in g.inlined_c_typedef_names, compiler
		assert !g.skip_builtin_struct('C._FILETIME'), compiler
		g.gen_type_declaration_block()
		c_code := g.sb.str()
		assert c_code.count(alias) == 2, c_code
		assert c_code.count(body) == 1, c_code
		assert c_code.count('struct _FILETIME {') == 1, c_code
		body_pos := c_code.index(body) or { -1 }
		first_alias_pos := c_code.index(alias) or { -1 }
		last_alias_pos := c_code.last_index(alias) or { -1 }
		assert first_alias_pos >= 0 && first_alias_pos < last_alias_pos, c_code
		assert last_alias_pos < body_pos, c_code
	}

	for compiler in ['tinyc', 'gcc', 'clang', 'msvc'] {
		mut system_g := FlatGen.new()
		system_g.a = &a
		system_g.tc = &tc
		system_g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
		system_g.set_ccompiler(compiler)
		system_g.add_c_directive('main', '#include <stdio.h>', false)
		system_g.system_libc_preamble()
		system_g.register_struct_decl_info('C._FILETIME', 'C._FILETIME', 'time',
			'/virtual/vlib/time/time_windows.c.v', flat.Node{
			value: '_FILETIME'
		})
		assert system_g.skip_builtin_struct('C._FILETIME'), compiler
		system_g.gen_type_declaration_block()
		system_code := system_g.sb.str()
		assert system_code.count(alias) == 1, system_code
		assert system_code.count(body) == 0, system_code
		assert system_code.count('struct _FILETIME {') == 0, system_code
	}

	mut linux_g := FlatGen.new()
	linux_g.a = &a
	linux_g.tc = &tc
	linux_g.set_target(pref.target_from('linux', 'amd64') or { panic(err) })
	linux_g.set_ccompiler('tinyc')
	linux_g.register_struct_decl_info('C._FILETIME', 'C._FILETIME', 'time',
		'/virtual/vlib/time/time_windows.c.v', flat.Node{
		value: '_FILETIME'
	})
	assert linux_g.skip_builtin_struct('C._FILETIME')

	mut wrong_source_g := FlatGen.new()
	wrong_source_g.a = &a
	wrong_source_g.tc = &tc
	wrong_source_g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	wrong_source_g.set_ccompiler('tinyc')
	wrong_source_g.register_struct_decl_info('C._FILETIME', 'C._FILETIME', 'time',
		'/virtual/vlib/time/unrelated_windows.c.v', flat.Node{
		value: '_FILETIME'
	})
	assert wrong_source_g.skip_builtin_struct('C._FILETIME')

	mut wrong_name_g := FlatGen.new()
	wrong_name_g.a = &a
	wrong_name_g.tc = &tc
	wrong_name_g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	wrong_name_g.set_ccompiler('tinyc')
	wrong_name_g.register_struct_decl_info('C.OtherFileTime', 'C.OtherFileTime', 'time',
		'/virtual/vlib/time/time_windows.c.v', flat.Node{
		value: 'OtherFileTime'
	})
	assert wrong_name_g.skip_builtin_struct('C.OtherFileTime')
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
	assert_windows_system_dword_storage_is_nominal_only_in_sdk_mode()
	expected_central := [
		'CloseClipboard',
		'CopyFileW',
		'CreateDirectoryW',
		'CreateFileW',
		'CreatePipe',
		'CreateProcessW',
		'CreateWindowExW',
		'DefWindowProcW',
		'EmptyClipboard',
		'ExpandEnvironmentStringsW',
		'FileTimeToSystemTime',
		'FindClose',
		'FindFirstFileW',
		'FindNextFileW',
		'FormatMessageW',
		'FreeLibrary',
		'GetConsoleMode',
		'GetConsoleScreenBufferInfo',
		'GetCurrentProcessId',
		'GetCurrentThreadId',
		'GetExitCodeProcess',
		'GetFileAttributesW',
		'GetFinalPathNameByHandleW',
		'GetFullPathNameW',
		'GetLastError',
		'GetLongPathNameW',
		'GetModuleFileNameW',
		'GetNativeSystemInfo',
		'GetProcAddress',
		'GetStdHandle',
		'GetSystemTimeAsFileTime',
		'GetTickCount',
		'GlobalAlloc',
		'GlobalFree',
		'GlobalUnlock',
		'LoadLibraryW',
		'LocalFree',
		'OpenClipboard',
		'QueryPerformanceCounter',
		'QueryPerformanceFrequency',
		'ReadFile',
		'RegisterClassExW',
		'RemoveDirectoryW',
		'ScrollConsoleScreenBuffer',
		'SetConsoleCursorPosition',
		'SetConsoleMode',
		'SetHandleInformation',
		'SetLastError',
		'Sleep',
		'SystemTimeToTzSpecificLocalTime',
		'VirtualAlloc',
		'VirtualProtect',
		'WaitForSingleObject',
		'WriteConsoleW',
		'WriteFile',
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
	for name in ['CreateDirectoryW', 'GetFileAttributesW', 'GetFinalPathNameByHandleW',
		'GetLastError', 'WaitForSingleObject'] {
		assert c_extern_calling_convention(name) == 'WINAPI', name
	}

	mut central := map[string]bool{}
	for name in expected_central {
		assert name !in central, name
		central[name] = true
	}
	assert central.len == 70
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
	assert effective.len == 71

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
	for target_os in ['windows', 'linux', 'macos'] {
		mut unrelated := FlatGen.new()
		unrelated.set_target(pref.target_from(target_os, 'amd64') or { panic(err) })
		unrelated.set_ccompiler('gcc')
		if target_os != 'windows' {
			unrelated.add_c_directive('main', '#include <stdio.h>', false)
		}
		unrelated.preamble()
		for name in ['GetNativeSystemInfo', 'VirtualAlloc', 'VirtualProtect',
			'CreateFileW', 'CreatePipe', 'CreateProcessW', 'ExpandEnvironmentStringsW',
			'FindClose', 'FindFirstFileW', 'FormatMessageW', 'GetExitCodeProcess',
			'GetFullPathNameW', 'LocalFree', 'ReadFile', 'RemoveDirectoryW', 'SetHandleInformation'] {
			assert unrelated.should_emit_c_extern_decl(name), '${target_os}: ${name}'
		}
	}
}

fn assert_windows_system_dword_storage_is_nominal_only_in_sdk_mode() {
	dword := types.Type(types.Alias{
		name:      'C.DWORD'
		base_type: types.Type(types.u32_)
	})
	for target_os in ['windows', 'linux', 'macos'] {
		for compiler in ['gcc', 'clang', 'tinyc'] {
			for system_mode in [false, true] {
				mut ast := &flat.FlatAst{}
				mut tc := types.TypeChecker.new(ast)
				mut storage := FlatGen.new()
				storage.a = ast
				storage.tc = &tc
				storage.set_target(pref.target_from(target_os, 'amd64') or { panic(err) })
				storage.set_ccompiler(compiler)
				if system_mode {
					storage.add_c_directive('main', '#include <stdio.h>', false)
				}
				expected := if target_os == 'windows' && system_mode { 'DWORD' } else { 'u32' }
				assert storage.value_c_type(dword) == expected
				assert storage.cast_c_type(dword) == expected
				for alias_name in ['C.OtherDword', 'AppDword'] {
					other := types.Type(types.Alias{
						name:      alias_name
						base_type: types.Type(types.u32_)
					})
					assert storage.value_c_type(other) == 'u32'
					assert storage.cast_c_type(other) == 'u32'
				}
				for other_base in [types.Type(types.i32_), types.Type(types.Pointer{
					base_type: types.Type(types.u32_)
				}), types.Type(types.Struct{
					name: 'C.OtherStorage'
				})] {
					other := types.Type(types.Alias{
						name:      'C.DWORD'
						base_type: other_base
					})
					assert storage.value_c_type(other) == tc.c_type(other_base)
					assert storage.cast_c_type(other) == tc.c_type(other_base)
				}
				pointer := types.Type(types.Pointer{
					base_type: dword
				})
				// This change does not alter general pointer storage/signatures.
				assert storage.value_c_type(pointer) == 'u32*'
			}
		}
	}
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

fn test_windows_system_libc_replays_v1_gcc_stdio_provider() {
	predicate := '#if defined(__GNUC__) && !defined(__TINYC__) && !defined(__cplusplus) && !defined(__clang__) && !defined(_MSC_VER)'
	identity := predicate + '\n#ifndef __V_GCC__\n#define __V_GCC__\n#endif\n#endif\n'
	// V3 embeds only the c_headers fragment, after V1's compiler-identity block.
	fragment := manual_stdlib_c_headers()
	assert !fragment.contains('#define __V_GCC__')
	assert fragment.contains('#elif (defined(__MINGW32__) || defined(__MINGW64__)) && defined(__V_GCC__)')
	for target_os in ['windows', 'linux', 'macos'] {
		for system_mode in [false, true] {
			mut g := FlatGen.new()
			g.set_target(pref.target_from(target_os, 'amd64') or { panic(err) })
			g.set_ccompiler('gcc')
			if system_mode {
				g.add_c_directive('main', '#include <stddef.h>', false)
			}
			assert g.c_directives_use_system_libc() == system_mode
			g.preamble()
			code := g.sb.str()
			if target_os == 'windows' && system_mode {
				assert code.count(identity) == 1, code
				identity_pos := code.index(identity) or { -1 }
				fragment_pos := code.index(fragment) or { -1 }
				assert identity_pos >= 0 && fragment_pos > identity_pos, code
			} else {
				assert !code.contains(identity), '${target_os} system=${system_mode}'
			}
		}
	}
}

fn test_windows_preserved_sdk_headers_own_cross_file_externs() {
	provider_source := '/virtual/issue74/sdk_providers.c.v'
	// Canonical exports and declaration owners from the issue74 full-showcase C.
	// GetProcAddress has two declarations; the C does not identify which won.
	owners := [
		['BCryptGenRandom', 'builtin/cfns.c.v', 'bcrypt'],
		['FindNextFileW', 'builtin/cfns.c.v', 'windows'],
		['GetModuleFileNameW', 'builtin/cfns.c.v', 'windows'],
		['GetTickCount', 'builtin/cfns.c.v', 'windows'],
		['WSAStartup', 'builtin/cfns.c.v', 'winsock'],
		['closesocket', 'builtin/cfns.c.v', 'winsock'],
		['CloseClipboard', 'clipboard/clipboard_windows.c.v', 'windows'],
		['CreateWindowExW', 'clipboard/clipboard_windows.c.v', 'windows'],
		['DefWindowProcW', 'clipboard/clipboard_windows.c.v', 'windows'],
		['EmptyClipboard', 'clipboard/clipboard_windows.c.v', 'windows'],
		['GlobalAlloc', 'clipboard/clipboard_windows.c.v', 'windows'],
		['GlobalFree', 'clipboard/clipboard_windows.c.v', 'windows'],
		['GlobalUnlock', 'clipboard/clipboard_windows.c.v', 'windows'],
		['OpenClipboard', 'clipboard/clipboard_windows.c.v', 'windows'],
		['RegisterClassExW', 'clipboard/clipboard_windows.c.v', 'windows'],
		['SetLastError', 'clipboard/clipboard_windows.c.v', 'windows'],
		['CopyFileW', 'os/os.c.v', 'windows'],
		['GetLongPathNameW', 'os/os_windows.c.v', 'windows'],
		['FreeLibrary', 'dl/dl_windows.c.v', 'windows'],
		['GetProcAddress', 'dl/dl_windows.c.v', 'windows'],
		['LoadLibraryW', 'dl/dl_windows.c.v', 'windows'],
		['GetProcAddress', 'os/process_windows.c.v', 'windows'],
	]
	mut exports := map[string]bool{}
	mut pairs := map[string]bool{}
	for owner in owners {
		assert owner.len == 3
		assert owner[2] in ['windows', 'winsock', 'bcrypt']
		assert '/virtual/vlib/' + owner[1] != provider_source
		exports[owner[0]] = true
		pairs[owner[0] + '\t' + owner[1]] = true
	}
	assert owners.len == 22 && pairs.len == 22 && exports.len == 21
	mut mismatches := []string{}
	for state in ['headerless', 'nonwindows', 'windows', 'winsock', 'bcrypt', 'all'] {
		mut a := flat.FlatAst.new()
		mut tc := types.TypeChecker.new(&a)
		mut g := FlatGen.new()
		g.a = &a
		g.tc = &tc
		target_os := if state == 'nonwindows' { 'linux' } else { 'windows' }
		g.set_target(pref.target_from(target_os, 'amd64') or { panic(err) })
		// The headerless negative is GNU, not TCC's SDK-backed atomic provider.
		g.set_ccompiler('gcc')
		assert !g.uses_windows_tcc_atomic_header()
		assert c_flag_include_dirs(g.c_flags).len == 0
		if state != 'headerless' {
			g.collect_c_directive('sdk_provider', flat.Node{
				kind:  .directive
				value: 'preinclude'
				typ:   '<stdio.h>'
			}, provider_source, false)
			if state in ['winsock', 'all'] {
				g.collect_c_directive('sdk_provider', flat.Node{
					kind:  .directive
					value: 'include'
					typ:   '<winsock2.h>'
				}, provider_source, false)
			}
			if state in ['bcrypt', 'all'] {
				g.collect_c_directive('sdk_provider', flat.Node{
					kind:  .directive
					value: 'preinclude'
					typ:   '<bcrypt.h>'
				}, provider_source, false)
			}
			g.emit_preinclude_directives()
			g.emit_preserved_c_directives()
			g.system_libc_headers()
			g.system_libc_preamble()
		}
		assert g.c_directives_use_system_libc() == (state != 'headerless'), state
		code := g.sb.str()
		if state != 'headerless' {
			assert code.contains('#include <stdio.h>'), state
			assert code.contains('#include <windows.h>'), state
		}
		assert code.contains('#include <winsock2.h>') == (state in ['winsock', 'all']), state
		assert code.contains('#include <bcrypt.h>') == (state in ['bcrypt', 'all']), state
		before := mismatches.len
		for owner in owners {
			declaration_source := '/virtual/vlib/' + owner[1]
			assert !g.header_owned_c_extern_sources[c_extern_source_key(declaration_source)],
				declaration_source
			// Without explicit Winsock tracking, retain the historical route. This
			// does not claim windows.h can never transitively provide Winsock1.
			provider_present := state !in ['headerless', 'nonwindows']
				&& (owner[2] == 'windows' || (owner[2] == 'winsock'
				&& state in ['winsock', 'all']) || (owner[2] == 'bcrypt'
				&& state in ['bcrypt', 'all']))
			expected_emit := !provider_present
			observed_emit := g.should_emit_c_extern_decl_from_file(owner[0], declaration_source)
			if observed_emit != expected_emit {
				mismatches << '${state}: ${owner[0]} owner=${owner[1]} expected_emit=${expected_emit} observed_emit=${observed_emit}'
			}
		}
		if !g.should_emit_c_extern_decl_from_file('issue74_unrelated_c_symbol',
			'/virtual/issue74/unrelated.c.v') {
			mismatches << '${state}: unrelated C symbol was suppressed'
		}
		println('sdk-cross-file-state=${state} checked=${owners.len} mismatches=${mismatches.len - before}')
	}
	// This is a metadata predicate reproduction, not a native SDK compile/run.
	assert mismatches.len == 0, mismatches.join('\n')
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
	manual_sdk_fns := ['GetLastError', 'WaitForSingleObject']
	assert c_headerless_windows_manual_sdk_declared_fns == manual_sdk_fns
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
	assert c_code.count('DWORD WINAPI WaitForSingleObject(HANDLE handle, DWORD milliseconds);') == 1,
		c_code
	assert c_code.count('DWORD WINAPI GetLastError(void);') == 1, c_code
	assert c_code.count('#define FILE_ATTRIBUTE_READONLY 0x00000001U') == 1, c_code
	for name in manual_sdk_fns {
		assert name in g.inlined_c_declared_fns, name
		assert !g.should_emit_c_extern_decl(name), name
	}
	// The TCC-only inserted helper is scanned conservatively. Headerless GCC/Clang/MSVC
	// must still emit the one GetFinalPathNameByHandleW fallback that they need.
	g.inlined_c_declared_fns['GetFinalPathNameByHandleW'] = true
	assert g.should_emit_c_extern_decl('GetFinalPathNameByHandleW')

	assert !g.should_emit_c_extern_decl('_aligned_malloc')
	assert !g.should_emit_c_extern_decl('_aligned_free')
	assert !g.should_emit_c_extern_decl('_putenv_s')
	assert !g.should_emit_c_extern_decl('SetUnhandledExceptionFilter')

	mut x86_g := FlatGen.new()
	x86_g.set_target(pref.target_from('windows', 'x86') or { panic(err) })
	x86_g.set_ccompiler('gcc')
	x86_g.has_builtins = true
	x86_g.preamble()
	x86_code := x86_g.sb.str()
	assert x86_code.contains('#if defined(_WIN32) && (defined(__i386__) || defined(_M_IX86))\n#define WINAPI __stdcall'),
		x86_code
	assert x86_code.count('DWORD WINAPI WaitForSingleObject(HANDLE handle, DWORD milliseconds);') == 1,
		x86_code
	assert x86_code.count('DWORD WINAPI GetLastError(void);') == 1, x86_code
	for compiler in ['clang', 'msvc'] {
		mut family_g := FlatGen.new()
		family_g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
		family_g.set_ccompiler(compiler)
		family_g.has_builtins = true
		family_g.preamble()
		family_g.inlined_c_declared_fns['GetFinalPathNameByHandleW'] = true
		assert family_g.should_emit_c_extern_decl('GetFinalPathNameByHandleW'), compiler
		for name in manual_sdk_fns {
			assert name in family_g.inlined_c_declared_fns, '${compiler}: ${name}'
			assert !family_g.should_emit_c_extern_decl(name), '${compiler}: ${name}'
		}
	}
}

fn test_headerless_windows_non_tcc_emits_early_runtime_providers() {
	thread_start_alias := 'typedef DWORD (WINAPI *PTHREAD_START_ROUTINE)(void*);'
	lpthread_start_alias := 'typedef PTHREAD_START_ROUTINE LPTHREAD_START_ROUTINE;'
	timezone_alias := 'typedef struct _TIME_ZONE_INFORMATION TIME_ZONE_INFORMATION;'
	wide_console_alias := '#ifndef ScrollConsoleScreenBuffer\n#define ScrollConsoleScreenBuffer ScrollConsoleScreenBufferW\n#endif'
	expected_fns := [
		'AcquireSRWLockExclusive',
		'ReleaseSRWLockExclusive',
	]
	assert c_headerless_windows_early_runtime_declared_fns == expected_fns
	for compiler in ['gcc', 'clang', 'msvc'] {
		mut g := FlatGen.new()
		g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
		g.set_ccompiler(compiler)
		g.preamble()
		c_code := g.sb.str()
		for declaration in [thread_start_alias, lpthread_start_alias, timezone_alias] {
			assert c_code.count(declaration) == 1, '${compiler}: ${declaration}'
		}
		thread_start_pos := c_code.index(thread_start_alias) or { -1 }
		lpthread_start_pos := c_code.index(lpthread_start_alias) or { -1 }
		timezone_pos := c_code.index(timezone_alias) or { -1 }
		wide_console_pos := c_code.index(wide_console_alias) or { -1 }
		assert thread_start_pos >= 0 && thread_start_pos < lpthread_start_pos, compiler
		assert lpthread_start_pos < timezone_pos, compiler
		assert c_code.count(wide_console_alias) == 1, compiler
		assert timezone_pos < wide_console_pos, compiler
		assert 'ScrollConsoleScreenBuffer' !in g.inlined_c_active_macros, compiler
		for name in expected_fns {
			declaration := 'void WINAPI ${name}(void*);'
			assert c_code.count(declaration) == 1, '${compiler}: ${name}'
			assert name in g.inlined_c_declared_fns, '${compiler}: ${name}'
			assert !g.should_emit_c_extern_decl(name), '${compiler}: ${name}'
		}
		assert g.should_emit_c_extern_decl('AcquireSRWLockShared'), compiler
	}

	mut tcc_g := FlatGen.new()
	tcc_g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
	tcc_g.set_ccompiler('tinyc')
	tcc_g.preamble()
	tcc_code := tcc_g.sb.str()
	assert !tcc_code.contains(wide_console_alias), tcc_code
	assert 'ScrollConsoleScreenBuffer' !in tcc_g.inlined_c_active_macros
	for declaration in [thread_start_alias, lpthread_start_alias, timezone_alias] {
		assert !tcc_code.contains(declaration), declaration
	}
	for name in expected_fns {
		assert !tcc_code.contains('void WINAPI ${name}(void*);'), name
	}

	for compiler in ['tinyc', 'gcc', 'clang', 'msvc'] {
		mut system_g := FlatGen.new()
		system_g.set_target(pref.target_from('windows', 'amd64') or { panic(err) })
		system_g.set_ccompiler(compiler)
		system_g.add_c_directive('main', '#include <stdio.h>', false)
		system_g.preamble()
		system_code := system_g.sb.str()
		assert !system_code.contains(wide_console_alias), compiler
		assert 'ScrollConsoleScreenBuffer' !in system_g.inlined_c_active_macros, compiler
		for declaration in [thread_start_alias, lpthread_start_alias, timezone_alias] {
			assert !system_code.contains(declaration), '${compiler}: ${declaration}'
		}
		for name in expected_fns {
			assert !system_code.contains('void WINAPI ${name}(void*);'), '${compiler}: ${name}'
		}
	}
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
	for name in c_headerless_windows_manual_sdk_declared_fns {
		assert name !in g.inlined_c_declared_fns, name
	}
	g.inlined_c_declared_fns['GetFinalPathNameByHandleW'] = true
	assert !g.should_emit_c_extern_decl('GetFinalPathNameByHandleW')
	for declaration in [
		'int _putenv_s(const char *name, const char *value);',
		'struct _EXCEPTION_POINTERS;',
		'PTOP_LEVEL_EXCEPTION_FILTER',
		'LPTOP_LEVEL_EXCEPTION_FILTER',
		'SetUnhandledExceptionFilter(',
		'PTHREAD_START_ROUTINE',
		'LPTHREAD_START_ROUTINE',
		'TIME_ZONE_INFORMATION',
		'#define ScrollConsoleScreenBuffer ScrollConsoleScreenBufferW',
		'AcquireSRWLockExclusive(',
		'ReleaseSRWLockExclusive(',
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

	mut linux_g := FlatGen.new()
	linux_g.set_target(pref.target_from('linux', 'amd64') or { panic(err) })
	linux_g.set_ccompiler('tinyc')
	linux_g.atomic_thread_fence_compat_decls()
	linux_code := linux_g.sb.str()
	assert linux_code.contains('(defined(__x86_64__) && defined(_WIN32))'), linux_code
	assert linux_code.count('_V_atomic_thread_fence') == 3, linux_code
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
