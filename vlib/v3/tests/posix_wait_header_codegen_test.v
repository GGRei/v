import os

const wait_header_vexe = @VEXE
const wait_header_tests_dir = os.dir(@FILE)
const wait_header_v3_dir = os.dir(wait_header_tests_dir)
const wait_header_vlib_dir = os.dir(wait_header_v3_dir)
const wait_header_v3_src = os.join_path(wait_header_v3_dir, 'v3.v')

struct WaitHeaderProgram {
	c_code          string
	out             string
	compiler_family string
}

struct WaitHeaderCompilerRoute {
	suffix string
	family string
}

fn wait_header_execute_without_vflags(command string) os.Result {
	old_vflags := os.getenv_opt('VFLAGS')
	os.unsetenv('VFLAGS')
	result := os.execute(command)
	if vflags := old_vflags {
		os.setenv('VFLAGS', vflags, true)
	} else {
		os.unsetenv('VFLAGS')
	}
	return result
}

fn wait_header_build_v3() string {
	pid := os.getpid()
	v3_bin := os.join_path(os.temp_dir(), 'v3_wait_header_test_${pid}')
	if os.is_executable(v3_bin) {
		return v3_bin
	}
	build :=
		os.execute('${wait_header_vexe} -gc none -path "${wait_header_vlib_dir}|@vlib|@vmodules" -o ${v3_bin} ${wait_header_v3_src}')
	assert build.exit_code == 0, build.output
	return v3_bin
}

fn wait_header_compiler_name_family(path string, is_cpp bool) string {
	name := os.file_name(path).to_lower_ascii()
	if is_cpp {
		return match name {
			'g++.exe', 'g++' { 'gcc' }
			'clang++.exe', 'clang++' { 'clang' }
			'tcc.exe', 'tcc' { 'tcc' }
			else { '' }
		}
	}
	return match name {
		'gcc.exe', 'gcc' { 'gcc' }
		'clang.exe', 'clang' { 'clang' }
		'tcc.exe', 'tcc' { 'tcc' }
		else { '' }
	}
}

fn wait_header_compiler_family(path string, is_cpp bool) string {
	expected := wait_header_compiler_name_family(path, is_cpp)
	if expected == '' {
		return ''
	}
	version_arg := if expected == 'tcc' { '-v' } else { '--version' }
	version := os.execute('${os.quoted_path(path)} ${version_arg}')
	if version.exit_code != 0 {
		return ''
	}
	text := version.output.to_lower_ascii()
	actual := if text.contains('clang') && !text.contains('clang-cl') {
		'clang'
	} else if text.contains('gcc') || text.contains('free software foundation')
		|| text.contains('mingw') {
		'gcc'
	} else if text.contains('tiny c compiler') || text.contains('tcc version') {
		'tcc'
	} else {
		''
	}
	return if actual == expected { actual } else { '' }
}

fn wait_header_compiler_route() WaitHeaderCompilerRoute {
	mut cc := ''
	mut cxx := ''
	mut cc_set := false
	mut cxx_set := false
	if value := os.getenv_opt('ISSUE74_V3_WAIT_HEADER_CC') {
		cc = value
		cc_set = true
	}
	if value := os.getenv_opt('ISSUE74_V3_WAIT_HEADER_CXX') {
		cxx = value
		cxx_set = true
	}
	if !cc_set && !cxx_set {
		mut historical_family := ''
		$if windows {
			historical_family = 'tcc'
		}
		return WaitHeaderCompilerRoute{
			family: historical_family
		}
	}
	assert cc_set && cxx_set, 'Issue 74 wait-header compiler paths must be set together'
	assert cc.len > 0 && cxx.len > 0, 'Issue 74 wait-header compiler paths must not be empty'
	assert os.is_abs_path(cc) && os.is_abs_path(cxx),
		'Issue 74 wait-header compiler paths must be absolute'
	assert os.is_file(cc) && os.is_file(cxx),
		'Issue 74 wait-header compiler paths must be files'
	cc_family := wait_header_compiler_family(cc, false)
	cxx_family := wait_header_compiler_family(cxx, true)
	assert cc_family.len > 0 && cc_family == cxx_family,
		'Issue 74 wait-header compiler paths must be a matching GCC, Clang, or TCC family'
	return WaitHeaderCompilerRoute{
		suffix: ' -no-retry-compilation -cc ${os.quoted_path(cc)} -c++ ${os.quoted_path(cxx)}'
		family: cc_family
	}
}

fn wait_header_compile(v3_bin string, name string, source string) WaitHeaderProgram {
	pid := os.getpid()
	src := os.join_path(os.temp_dir(), 'v3_wait_header_${name}_${pid}.v')
	out := os.join_path(os.temp_dir(), 'v3_wait_header_${name}_${pid}')
	os.write_file(src, source) or { panic(err) }
	os.rm(out) or {}
	os.rm(out + '.c') or {}
	route := wait_header_compiler_route()
	compile := wait_header_execute_without_vflags('${v3_bin}${route.suffix} -b c -o ${out} ${src}')
	assert compile.exit_code == 0, compile.output
	gen_c := wait_header_execute_without_vflags('${v3_bin}${route.suffix} -b c -o ${out}.c ${src}')
	assert gen_c.exit_code == 0, gen_c.output
	return WaitHeaderProgram{
		c_code:          os.read_file(out + '.c') or { panic(err) }
		out:             out
		compiler_family: route.family
	}
}

fn wait_header_gen_c(v3_bin string, name string, source string) string {
	pid := os.getpid()
	src := os.join_path(os.temp_dir(), 'v3_wait_header_${name}_${pid}.v')
	c_path := os.join_path(os.temp_dir(), 'v3_wait_header_${name}_${pid}.c')
	os.write_file(src, source) or { panic(err) }
	os.rm(c_path) or {}
	route := wait_header_compiler_route()
	compile := wait_header_execute_without_vflags('${v3_bin}${route.suffix} -b c -o ${c_path} ${src}')
	assert compile.exit_code == 0, compile.output
	return os.read_file(c_path) or { panic(err) }
}

fn wait_header_has_include_directive(c_code string) bool {
	for line in c_code.split_into_lines() {
		trimmed := line.trim_space()
		if trimmed.starts_with('#include') {
			return true
		}
	}
	return false
}

fn wait_header_compact_source(source string) string {
	return source.replace('\t', '').replace(' ', '').replace('\r', '').replace('\n', '')
}

fn wait_header_generated_extern_count(c_code string, name string) int {
	mut count := 0
	for line in c_code.split_into_lines() {
		if wait_header_generated_extern_name(line) == name {
			count++
		}
	}
	return count
}

fn wait_header_generated_extern_line(c_code string, name string) string {
	for line in c_code.split_into_lines() {
		if wait_header_generated_extern_name(line) == name {
			return line
		}
	}
	return ''
}

fn wait_header_generated_extern_name(line string) string {
	clean := line.trim_space()
	if line != clean || !clean.ends_with(');') {
		return ''
	}
	open := clean.index_u8(`(`)
	if open <= 0 {
		return ''
	}
	return clean[..open].all_after_last(' ').trim_left('*')
}

fn wait_header_windows_sdk_owned_fns() []string {
	return [
		'CreateDirectoryW',
		'FileTimeToSystemTime',
		'GetConsoleMode',
		'GetConsoleScreenBufferInfo',
		'GetCurrentProcessId',
		'GetCurrentThreadId',
		'GetFileAttributesW',
		'GetLastError',
		'GetStdHandle',
		'GetSystemTimeAsFileTime',
		'QueryPerformanceCounter',
		'QueryPerformanceFrequency',
		'ScrollConsoleScreenBuffer',
		'SetConsoleCursorPosition',
		'SetConsoleMode',
		'Sleep',
		'SystemTimeToTzSpecificLocalTime',
		'WaitForSingleObject',
		'WriteConsoleW',
		'WriteFile',
	]
}

fn wait_header_windows_tcc_insert_owned_fns() []string {
	return ['GetFinalPathNameByHandleW']
}

fn wait_header_windows_crt_referenced_fns() []string {
	return [
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
}

fn wait_header_windows_atomic_crt_owned_fns() []string {
	return ['wcslen']
}

fn wait_header_windows_crt_generated_fns() []string {
	return [
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
		'_wsystem',
	]
}

fn wait_header_windows_nls_fns() []string {
	return ['MultiByteToWideChar', 'WideCharToMultiByte']
}

fn wait_header_windows_vista_fns() []string {
	return [
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
}

fn wait_header_windows_system_owner_source(cflags string) string {
	mut refs := []string{}
	for name in wait_header_windows_sdk_owned_fns() {
		refs << '\t_ = voidptr(&C.${name})'
	}
	for name in wait_header_windows_tcc_insert_owned_fns() {
		refs << '\t_ = voidptr(&C.${name})'
	}
	for name in wait_header_windows_crt_referenced_fns() {
		refs << '\t_ = voidptr(&C.${name})'
	}
	for name in wait_header_windows_nls_fns() {
		refs << '\t_ = voidptr(&C.${name})'
	}
	for name in wait_header_windows_vista_fns() {
		refs << '\t_ = voidptr(&C.${name})'
	}
	return 'module main

import os
import sync
import term
import time

${cflags}

fn main() {
${refs.join('\n')}
	mut mutex := sync.new_mutex()
	mutex.lock()
	mutex.unlock()
	mut semaphore := sync.new_semaphore()
	_ = semaphore.timed_wait(1)
	width, height := term.get_terminal_size()
	_ = width
	_ = height
	_ = time.now()
	stat_result := os.stat(\'.\') or { panic(err) }
	_ = stat_result
}
'
}

fn test_os_import_uses_waitpid_without_headers() {
	$if windows {
		return
	}
	v3_bin := wait_header_build_v3()
	with_os := wait_header_compile(v3_bin, 'with_os_execute', "module main

import os

fn main() {
	result := os.execute('true')
	assert result.exit_code == 0
	stat_info := os.stat(@FILE) or { panic(err) }
	assert stat_info.size > 0
	uname_info := os.uname()
	assert uname_info.sysname.len > 0
	entries := os.ls(os.dir(@FILE)) or { panic(err) }
	usage := os.disk_usage(os.dir(@FILE)) or { panic(err) }
	os.signal_ignore(.pipe)
	signals_ok := (C.SIGSTOP > 0) && (C.SIGCONT > 0) && (C.SIGTERM == 15)
		&& (C.SIGKILL == 9)
	println('waitpid-ok')
	println((entries.len > 0 && usage.total > 0 && signals_ok).str())
}
")
	assert !wait_header_has_include_directive(with_os.c_code), with_os.c_code
	assert with_os.c_code.contains('waitpid('), with_os.c_code
	assert with_os.c_code.contains('int close(int fd);'), with_os.c_code
	assert with_os.c_code.contains('typedef _Bool bool;'), with_os.c_code
	assert with_os.c_code.contains('typedef unsigned char bool;'), with_os.c_code
	assert with_os.c_code.contains('#define __bool_true_false_are_defined 1'), with_os.c_code
	assert with_os.c_code.contains('#if !defined(__FILE_defined) && !defined(_FILE_DEFINED) && !defined(_FILEDEFED) && !defined(__DEFINED_FILE) && !defined(_FILE_DECLARED) && !defined(__FILE_DECLARED)'), with_os.c_code
	assert with_os.c_code.contains('typedef intptr_t ssize_t;'), with_os.c_code
	assert with_os.c_code.contains('int setenv(const char* name, const char* value, int overwrite);'), with_os.c_code
	assert with_os.c_code.contains('void abort(void);'), with_os.c_code
	assert with_os.c_code.contains('void* memset(void* s, int c, size_t n);'), with_os.c_code
	assert with_os.c_code.contains('void* memcpy(void* dest, const void* src, size_t n);'), with_os.c_code
	assert with_os.c_code.contains('void* memmove(void* dest, const void* src, size_t n);'), with_os.c_code
	assert with_os.c_code.contains('int memcmp(const void* s1, const void* s2, size_t n);'), with_os.c_code
	assert with_os.c_code.contains('size_t strlen(const char* s);'), with_os.c_code
	assert !with_os.c_code.contains('i32 strlen(char* s);'), with_os.c_code
	assert with_os.c_code.contains('int strcmp(const char* s1, const char* s2);'), with_os.c_code
	assert with_os.c_code.contains('int strncmp(const char* s1, const char* s2, size_t n);'), with_os.c_code
	assert with_os.c_code.contains('char* strncpy(char* dest, const char* src, size_t n);'), with_os.c_code
	assert with_os.c_code.contains('double floor(double x);'), with_os.c_code
	assert with_os.c_code.contains('double ceil(double x);'), with_os.c_code
	assert with_os.c_code.contains('float floorf(float x);'), with_os.c_code
	assert with_os.c_code.contains('float ceilf(float x);'), with_os.c_code
	assert with_os.c_code.contains('double sqrt(double x);'), with_os.c_code
	assert with_os.c_code.contains('double pow(double x, double y);'), with_os.c_code
	assert with_os.c_code.contains('double ldexp(double x, int exp);'), with_os.c_code
	assert with_os.c_code.contains('double fmod(double x, double y);'), with_os.c_code
	assert with_os.c_code.contains('double cos(double x);'), with_os.c_code
	assert with_os.c_code.contains('double acos(double x);'), with_os.c_code
	assert with_os.c_code.contains('double fabs(double x);'), with_os.c_code
	assert with_os.c_code.contains('int open(const char* path, int flags, ...);'), with_os.c_code
	assert with_os.c_code.contains('ssize_t read(int fd, void* buf, size_t count);'), with_os.c_code
	assert with_os.c_code.contains('int fork(void);'), with_os.c_code
	assert with_os.c_code.contains('int dup2(int oldfd, int newfd);'), with_os.c_code
	assert with_os.c_code.contains('int execlp(const char* file, const char* arg, ...);'), with_os.c_code
	assert with_os.c_code.contains('int execvp(const char* file, char* const argv[]);'), with_os.c_code
	assert with_os.c_code.contains('void _exit(int status);'), with_os.c_code
	ssize_typedef_idx := with_os.c_code.index('typedef intptr_t ssize_t;') or { -1 }
	read_proto_idx := with_os.c_code.index('ssize_t read(int fd, void* buf, size_t count);') or {
		-1
	}
	assert ssize_typedef_idx >= 0 && ssize_typedef_idx < read_proto_idx, with_os.c_code
	assert with_os.c_code.contains('int access(const char* path, int mode);'), with_os.c_code
	assert with_os.c_code.contains('char* realpath(const char* path, char* resolved_path);'), with_os.c_code
	assert with_os.c_code.contains('char* strrchr(const char* s, int c);'), with_os.c_code
	assert with_os.c_code.contains('char* strstr(const char* haystack, const char* needle);'), with_os.c_code
	assert with_os.c_code.contains('int snprintf(char* str, size_t size, const char* format, ...);'), with_os.c_code
	assert with_os.c_code.contains('#elif defined(__ANDROID__)'), with_os.c_code
	assert with_os.c_code.contains('int* __errno(void);'), with_os.c_code
	assert with_os.c_code.contains('#define errno (*__errno())'), with_os.c_code
	assert with_os.c_code.contains('int* __errno_location(void);'), with_os.c_code
	assert with_os.c_code.contains('#define errno (*__errno_location())'), with_os.c_code
	assert with_os.c_code.contains('#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__DragonFly__)'), with_os.c_code
	assert with_os.c_code.contains('#define stdout __stdoutp'), with_os.c_code
	assert with_os.c_code.contains('#elif defined(__OpenBSD__)'), with_os.c_code
	assert with_os.c_code.contains('extern struct __sFstub __stdout[];'), with_os.c_code
	assert with_os.c_code.contains('#define stdout ((FILE*)__stdout)'), with_os.c_code
	assert with_os.c_code.contains('#elif defined(__NetBSD__)'), with_os.c_code
	assert with_os.c_code.contains('struct __netbsd_FILE_stub { unsigned char _opaque[152]; };'), with_os.c_code
	assert with_os.c_code.contains('#define stdout ((FILE*)&__sF[1])'), with_os.c_code
	assert with_os.c_code.contains('typedef union { unsigned char _opaque[128]; long long _align; } pthread_mutex_t;'), with_os.c_code
	assert with_os.c_code.contains('typedef union { unsigned char _opaque[256]; long long _align; } pthread_rwlock_t;'), with_os.c_code
	assert with_os.c_code.contains('#define PTHREAD_MUTEX_INITIALIZER'), with_os.c_code
	assert with_os.c_code.contains('int pthread_mutex_lock(void* mutex);'), with_os.c_code
	assert with_os.c_code.contains('int pthread_mutex_unlock(void* mutex);'), with_os.c_code
	assert with_os.c_code.contains('typedef union { unsigned char _opaque[128]; long long _align; } sigset_t;'), with_os.c_code
	assert with_os.c_code.contains('struct winsize { unsigned short ws_row; unsigned short ws_col; unsigned short ws_xpixel; unsigned short ws_ypixel; };'), with_os.c_code
	assert with_os.c_code.contains('typedef union epoll_data { void* ptr; int fd; u32 u32; u64 u64; } epoll_data_t;'), with_os.c_code
	assert with_os.c_code.contains('struct epoll_event { u32 events; epoll_data_t data; } __attribute__((packed));'), with_os.c_code
	assert with_os.c_code.contains('#elif defined(__linux__) && (defined(__i386__) || defined(__arm__))'), with_os.c_code
	assert with_os.c_code.contains('struct dirent { unsigned long d_ino; long d_off; unsigned short d_reclen; unsigned char d_type; char d_name[256]; };'), with_os.c_code
	assert with_os.c_code.contains('struct dirent { u64 d_ino; i64 d_off; unsigned short d_reclen; unsigned char d_type; char d_name[256]; };'), with_os.c_code
	assert with_os.c_code.contains('struct dirent { u64 d_ino; u64 d_seekoff; u16 d_reclen; u16 d_namlen; u8 d_type; char d_name[1024]; };'), with_os.c_code
	assert with_os.c_code.contains('struct dirent { u64 d_ino; i64 d_seekoff; u16 d_reclen; u8 d_type; u8 __pad0; u16 d_namlen; u16 __pad1; char d_name[256]; };'), with_os.c_code
	assert with_os.c_code.contains('struct statvfs { unsigned long f_flag; unsigned long f_bsize; unsigned long f_frsize; unsigned long f_iosize; u64 f_blocks;'), with_os.c_code
	assert with_os.c_code.contains('char f_mntfromlabel[1024];'), with_os.c_code
	assert with_os.c_code.contains('struct statvfs { unsigned long f_bsize; unsigned long f_frsize; unsigned long f_blocks; unsigned long f_bfree; unsigned long f_bavail;'), with_os.c_code
	assert with_os.c_code.contains('#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__)'), with_os.c_code
	assert with_os.c_code.contains('struct utsname { char sysname[256]; char nodename[256]; char release[256]; char version[256]; char machine[256]; };'), with_os.c_code
	assert with_os.c_code.contains('struct utsname { char sysname[65]; char nodename[65]; char release[65]; char version[65]; char machine[65]; char domainname[65]; };'), with_os.c_code
	assert with_os.c_code.contains('#if defined(__x86_64__) && !defined(__ILP32__)'), with_os.c_code
	assert with_os.c_code.contains('struct stat { u64 st_dev; u64 st_ino; u64 st_nlink; u32 st_mode; u32 st_uid; u32 st_gid; int __pad0; u64 st_rdev; i64 st_size; i64 st_blksize; i64 st_blocks; i64 st_atime; i64 st_atimensec; i64 st_mtime; i64 st_mtimensec; i64 st_ctime; i64 st_ctimensec; i64 __glibc_reserved[3]; };'), with_os.c_code
	assert with_os.c_code.contains('#elif defined(__s390x__)'), with_os.c_code
	assert with_os.c_code.contains('struct stat { u64 st_dev; u64 st_ino; u64 st_nlink; u32 st_mode; u32 st_uid; u32 st_gid; int __glibc_reserved0; u64 st_rdev; i64 st_size; i64 st_atime; unsigned long st_atimensec; i64 st_mtime; unsigned long st_mtimensec; i64 st_ctime; unsigned long st_ctimensec; i64 st_blksize; i64 st_blocks; i64 __glibc_reserved[3]; };'), with_os.c_code
	assert with_os.c_code.contains('#elif defined(__aarch64__) || (defined(__riscv) && __riscv_xlen == 64) || defined(__loongarch_lp64)'), with_os.c_code
	assert with_os.c_code.contains('#elif defined(__i386__) || defined(__arm__)'), with_os.c_code
	assert with_os.c_code.contains('struct stat { u64 st_dev; unsigned short __pad1; unsigned long st_ino; u32 st_mode; unsigned long st_nlink;'), with_os.c_code
	assert with_os.c_code.contains('#error unsupported Linux struct stat layout for this architecture'), with_os.c_code
	assert with_os.c_code.contains('i32 st_atim_ext; i64 st_atime; long st_atimensec;'), with_os.c_code
	assert with_os.c_code.contains('struct stat { u64 st_dev; u64 st_ino; u64 st_nlink; u16 st_mode; i16 st_bsdflags;'), with_os.c_code
	assert with_os.c_code.contains('struct stat { u32 st_mode; i32 st_dev; u64 st_ino; u32 st_nlink;'), with_os.c_code
	assert with_os.c_code.contains('struct stat { u64 st_dev; u32 st_mode; u64 st_ino; u32 st_nlink;'), with_os.c_code
	assert with_os.c_code.contains('struct stat { u64 st_ino; u32 st_nlink; u32 st_dev; u16 st_mode;'), with_os.c_code
	assert with_os.c_code.contains('#elif defined(__sun)'), with_os.c_code
	assert with_os.c_code.contains('struct stat { u64 st_dev; u64 st_ino; u32 st_mode; u32 st_nlink; u32 st_uid; u32 st_gid;'), with_os.c_code
	assert with_os.c_code.contains('char st_fstype[16];'), with_os.c_code
	assert with_os.c_code.contains('#elif defined(__QNX__) || defined(__QNXNTO__)'), with_os.c_code
	assert with_os.c_code.contains('#if _FILE_OFFSET_BITS - 0 == 64'), with_os.c_code
	assert with_os.c_code.contains('struct stat { u64 st_ino; i64 st_size; u64 st_dev; u64 st_rdev;'), with_os.c_code
	assert with_os.c_code.contains('#elif defined(__BIGENDIAN__)'), with_os.c_code
	assert with_os.c_code.contains('#error unsupported headerless Unix struct stat layout for this platform'), with_os.c_code
	assert with_os.c_code.contains('int stat(const char* path, struct stat* buf);'), with_os.c_code
	assert !with_os.c_code.contains('i32 stat(char*, void*);'), with_os.c_code
	assert with_os.c_code.contains('i64 st_birthtime;'), with_os.c_code
	assert with_os.c_code.contains('struct rusage { struct timeval ru_utime; struct timeval ru_stime; long ru_maxrss; long ru_ixrss; long ru_idrss;'), with_os.c_code
	assert with_os.c_code.contains('#if !defined(_STRUCT_TIMESPEC) && !defined(_TIMESPEC_DEFINED) && !defined(_TIMESPEC_DECLARED) && !defined(__timespec_defined)'), with_os.c_code
	assert with_os.c_code.contains('typedef struct timespec timespec;'), with_os.c_code
	assert with_os.c_code.contains('int clock_gettime(int clock_id, struct timespec* tp);'), with_os.c_code
	assert !with_os.c_code.contains('typedef struct stat stat;'), with_os.c_code
	assert !with_os.c_code.contains('typedef struct sigset_t sigset_t;'), with_os.c_code
	assert !with_os.c_code.contains('struct winsize {\n\tws_row'), with_os.c_code
	assert !with_os.c_code.contains('struct rusage {\n\tru_maxrss int'), with_os.c_code
	assert !with_os.c_code.contains('typedef union epoll_data_t epoll_data_t;'), with_os.c_code
	assert !with_os.c_code.contains('u64 d_seekoff;\n\tu64 d_reclen;'), with_os.c_code
	assert with_os.c_code.contains('#define SIGSTOP'), with_os.c_code
	assert with_os.c_code.contains('#define SIGCONT'), with_os.c_code
	assert with_os.c_code.contains('#define SIGTERM 15'), with_os.c_code
	assert with_os.c_code.contains('#define SIGKILL 9'), with_os.c_code
	assert with_os.c_code.contains('#define SIGPIPE 13'), with_os.c_code
	assert with_os.c_code.contains('#define SIG_IGN ((void*)1)'), with_os.c_code
	assert with_os.c_code.contains('#define SIG_BLOCK'), with_os.c_code
	assert with_os.c_code.contains('#define PTRACE_ATTACH 16'), with_os.c_code
	assert with_os.c_code.contains('#define PTRACE_DETACH 17'), with_os.c_code
	assert with_os.c_code.contains('#define PT_TRACE_ME 0'), with_os.c_code
	assert with_os.c_code.contains('#define PT_ATTACH 10'), with_os.c_code
	assert with_os.c_code.contains('#define PT_DETACH 11'), with_os.c_code
	assert with_os.c_code.contains('#define WNOHANG 1'), with_os.c_code
	assert with_os.c_code.contains('#define ENOENT 2'), with_os.c_code
	assert with_os.c_code.contains('#define RUSAGE_SELF 0'), with_os.c_code
	assert with_os.c_code.contains('#define EACCES 13'), with_os.c_code
	assert with_os.c_code.contains('#define EIO 5'), with_os.c_code
	assert with_os.c_code.contains('#define EBADF 9'), with_os.c_code
	assert with_os.c_code.contains('#define ENOMEM 12'), with_os.c_code
	assert with_os.c_code.contains('#define EFAULT 14'), with_os.c_code
	assert with_os.c_code.contains('#define ESPIPE 29'), with_os.c_code
	assert with_os.c_code.contains('#define EOVERFLOW 75'), with_os.c_code
	assert with_os.c_code.contains('#define _SC_PAGESIZE 0x0027'), with_os.c_code
	assert with_os.c_code.contains('#define _SC_NPROCESSORS_ONLN 0x0061'), with_os.c_code
	assert with_os.c_code.contains('#define _SC_PHYS_PAGES 0x0062'), with_os.c_code
	assert with_os.c_code.contains('#define _SC_AVPHYS_PAGES 0x0063'), with_os.c_code
	assert with_os.c_code.contains('#define _SC_PAGESIZE 30'), with_os.c_code
	assert with_os.c_code.contains('#define _SC_NPROCESSORS_ONLN 84'), with_os.c_code
	assert with_os.c_code.contains('#define _SC_PHYS_PAGES 85'), with_os.c_code
	assert with_os.c_code.contains('#define _SC_AVPHYS_PAGES 86'), with_os.c_code
	assert with_os.c_code.contains('#define PROT_READ 0x1'), with_os.c_code
	assert with_os.c_code.contains('#define PROT_WRITE 0x2'), with_os.c_code
	assert with_os.c_code.contains('#define PROT_EXEC 0x4'), with_os.c_code
	assert with_os.c_code.contains('#define MAP_PRIVATE 0x0002'), with_os.c_code
	assert with_os.c_code.contains('#define MAP_ANONYMOUS 0x20'), with_os.c_code
	assert with_os.c_code.contains('#define MAP_ANONYMOUS 0x1000'), with_os.c_code
	assert with_os.c_code.contains('#define MAP_FAILED ((void*)-1)'), with_os.c_code
	assert with_os.c_code.contains('#define SYS_getrandom 318'), with_os.c_code
	assert with_os.c_code.contains('#define SYS_getrandom 355'), with_os.c_code
	assert with_os.c_code.contains('#define SYS_getrandom 384'), with_os.c_code
	assert with_os.c_code.contains('#define SYS_getrandom 278'), with_os.c_code
	assert with_os.c_code.contains('#define CTL_KERN 1'), with_os.c_code
	assert with_os.c_code.contains('#define CTL_VM 2'), with_os.c_code
	assert with_os.c_code.contains('#define KERN_PROC_PATHNAME 12'), with_os.c_code
	assert with_os.c_code.contains('#define KERN_PROC_INC_THREAD 0x10'), with_os.c_code
	assert with_os.c_code.contains('#define KERN_PROC_ARGS 55'), with_os.c_code
	assert with_os.c_code.contains('#define KERN_PROC_ARGV 1'), with_os.c_code
	assert with_os.c_code.contains('#define VM_UVMEXP 4'), with_os.c_code
	assert with_os.c_code.contains('__atomic_fetch_add((uintptr_t*)ptr, (uintptr_t)0, 5)'), with_os.c_code
	assert with_os.c_code.contains('__atomic_load_n((void**)ptr, 5)'), with_os.c_code
	assert !with_os.c_code.contains('*(void* volatile*)ptr'), with_os.c_code
	assert with_os.c_code.contains('#define SOCK_NONBLOCK 04000'), with_os.c_code
	assert with_os.c_code.contains('#define SOCK_NONBLOCK 0x20000000'), with_os.c_code
	assert with_os.c_code.contains('#define SO_REUSEPORT 15'), with_os.c_code
	assert with_os.c_code.contains('#define TCP_QUICKACK 12'), with_os.c_code
	assert with_os.c_code.contains('#define TCP_DEFER_ACCEPT 9'), with_os.c_code
	assert with_os.c_code.contains('#define TCP_FASTOPEN 23'), with_os.c_code
	assert with_os.c_code.contains('#define SOMAXCONN 4096'), with_os.c_code
	assert with_os.c_code.contains('#define MEM_COMMIT 0x00001000U'), with_os.c_code
	assert with_os.c_code.contains('#define MEM_RESERVE 0x00002000U'), with_os.c_code
	assert with_os.c_code.contains('#define PAGE_READWRITE 0x04U'), with_os.c_code
	assert with_os.c_code.contains('#define PAGE_EXECUTE_READ 0x20U'), with_os.c_code
	assert with_os.c_code.contains('#define TLS_OUT_OF_INDEXES 0xffffffffU'), with_os.c_code
	assert with_os.c_code.contains('#define SOCKET_ERROR (-1)'), with_os.c_code
	assert with_os.c_code.contains('#define WSAEWOULDBLOCK 10035'), with_os.c_code
	run := os.execute(with_os.out)
	assert run.exit_code == 0, run.output
	assert run.output.trim_space() == 'waitpid-ok\ntrue', run.output

	hello := wait_header_compile(v3_bin, 'hello', "module main

fn main() {
	println('hello')
}
")
	assert !wait_header_has_include_directive(hello.c_code), hello.c_code
}

fn test_linux_system_preamble_provides_syscall_constants() {
	$if !linux {
		return
	}
	v3_bin := wait_header_build_v3()
	with_rand := wait_header_compile(v3_bin, 'with_crypto_rand', 'module main

import crypto.rand

fn main() {
	assert rand.bytes(1)!.len == 1
}
')
	assert with_rand.c_code.contains('#include <sys/syscall.h>'), with_rand.c_code
}

fn test_user_c_decl_emits_extern_prototype_without_headers() {
	$if windows {
		return
	}
	v3_bin := wait_header_build_v3()
	program := wait_header_compile(v3_bin, 'user_c_getppid', 'module main

#flag -Werror=implicit-function-declaration

fn C.getppid() int

fn main() {
	println(C.getppid().str())
}
')
	assert !wait_header_has_include_directive(program.c_code), program.c_code
	assert program.c_code.contains('int getppid(void);'), program.c_code
	run := os.execute(program.out)
	assert run.exit_code == 0, run.output
	assert run.output.trim_space().int() > 0, run.output
}

fn test_windows_crt_underscore_c_decls_emit_extern_prototypes() {
	v3_bin := wait_header_build_v3()
	c_code := wait_header_gen_c(v3_bin, 'windows_crt_underscore_decls', 'module main

fn C._wfopen(&u16, &u16) voidptr
fn C._wsystem(&u16) int
fn C._wgetenv(&u16) voidptr
fn C._waccess(&u16, int) int
fn C._wchdir(&u16) int
fn C._chsize_s(voidptr, u64) int

fn main() {
	p := &u16(unsafe { nil })
	h := voidptr(0)
	_ = C._wfopen(p, p)
	_ = C._wsystem(p)
	_ = C._wgetenv(p)
	_ = C._waccess(p, 0)
	_ = C._wchdir(p)
	_ = C._chsize_s(h, u64(0))
}
')
	assert !wait_header_has_include_directive(c_code), c_code
	assert c_code.contains('#ifdef _MSC_VER'), c_code
	assert c_code.contains('typedef unsigned __int64 size_t;'), c_code
	assert c_code.contains('typedef __int64 ptrdiff_t;'), c_code
	assert c_code.contains('typedef unsigned __int64 uintptr_t;'), c_code
	assert c_code.contains('typedef __int64 intptr_t;'), c_code
	assert c_code.contains('#elif defined(_WIN32)'), c_code
	assert c_code.contains('int* _errno(void);'), c_code
	assert c_code.contains('#define errno (*_errno())'), c_code
	assert c_code.contains('void* _wfopen(u16*, u16*);'), c_code
	assert c_code.contains('int _wsystem(u16*);'), c_code
	assert c_code.contains('void* _wgetenv(u16*);'), c_code
	assert c_code.contains('int _waccess(u16*, int);'), c_code
	assert c_code.contains('int _wchdir(u16*);'), c_code
	assert c_code.contains('int _chsize_s(void*, u64);'), c_code
}

fn wait_header_windows_vschannel_connect_source() string {
	vschannel_dir := os.join_path(os.dir(wait_header_vlib_dir), 'thirdparty', 'vschannel').replace('\\',
		'/')
	return "module main

#preinclude <stdio.h>
#preinclude <winsock2.h>
#preinclude <windows.h>
#flag -I \$first_existing('${vschannel_dir}')
#flag -DUNICODE -D_UNICODE
#flag -l ws2_32 -l crypt32 -l secur32 -l user32
#include \"vschannel.c\"

fn C.vschannel_format_proxy_connect(&char, int, &u16, int) int

fn check_connect(host string, port int) {
	expected := 'CONNECT ' + host + ':' + port.str() +
		' HTTP/1.0\\r\\nUser-Agent: webclient\\r\\n\\r\\n'
	for capacity in [200, expected.len + 1] {
		mut buffer := []u8{len: capacity + 2, init: 0xa5}
		length := C.vschannel_format_proxy_connect(unsafe { &char(&buffer[1]) },
			capacity, host.to_wide(), port)
		assert length == expected.len
		assert buffer[1..1 + length] == expected.bytes()
		assert buffer[1 + length] == 0
		assert buffer[0] == 0xa5 && buffer[capacity + 1] == 0xa5
	}
	check_rejected(host.to_wide(), expected.len, int(C.ERROR_INSUFFICIENT_BUFFER), port)
}

fn check_rejected(host &u16, capacity int, expected_error int, port int) {
	mut buffer := []u8{len: capacity + 2, init: 0xa5}
	length := C.vschannel_format_proxy_connect(unsafe { &char(&buffer[1]) },
		capacity, host, port)
	assert length == 0
	assert int(C.GetLastError()) == expected_error
	for value in buffer {
		assert value == 0xa5
	}
}

fn main() {
	check_connect('example.com', 443)
	check_connect('héllo-世界', 8443)
	overhead := 'CONNECT :443 HTTP/1.0\\r\\nUser-Agent: webclient\\r\\n\\r\\n'.len
	check_connect('x'.repeat(199 - overhead), 443)
	check_rejected('x'.repeat(200).to_wide(), 200, int(C.ERROR_INSUFFICIENT_BUFFER), 443)
	invalid_host := [u16(0xd800), 0]
	check_rejected(unsafe { &invalid_host[0] }, 200, int(C.ERROR_NO_UNICODE_TRANSLATION), 443)
	println('windows-vschannel-connect-ok')
}
"
}

fn test_windows_ordinary_winsock_headers_preserve_ipv6_contract() {
	$if !windows {
		return
	}
	source := "module main

import net

fn main() {
	if int(net.AddrFamily.ip6) != 23 {
		panic('unexpected Windows IPv6 address family')
	}
	if int(net.Protocol.ipv6) != 41 {
		panic('unexpected IPv6 protocol')
	}
	if int(net.Protocol.icmpv6) != 58 {
		panic('unexpected ICMPv6 protocol')
	}
	println('windows-ordinary-winsock-ok')
}
"
	v1_compiler := os.quoted_path(wait_header_vexe) + ' -old-compiler -gc none'
	v1_program := wait_header_compile(v1_compiler, 'windows_ordinary_winsock_v1', source)
	v1_run := wait_header_execute_without_vflags(os.quoted_path(v1_program.out))
	assert v1_run.exit_code == 0, v1_run.output
	assert v1_run.output.trim_space() == 'windows-ordinary-winsock-ok', v1_run.output
	println('ordinary-winsock-stage=v1-runtime-pass')
	v3_bin := wait_header_build_v3()
	c_code := wait_header_gen_c(v3_bin, 'windows_ordinary_winsock_v3_order', source)
	println('ordinary-winsock-stage=v3-generated')
	winsock_idx := c_code.index('#include <winsock2.h>') or { -1 }
	ws2tcpip_idx := c_code.index('#include <ws2tcpip.h>') or { -1 }
	windows_idx := c_code.index('#include <windows.h>') or { -1 }
	assert winsock_idx >= 0 && ws2tcpip_idx > winsock_idx && windows_idx > ws2tcpip_idx,
		'ordinary Windows includes: winsock2=${winsock_idx}, ws2tcpip=${ws2tcpip_idx}, windows=${windows_idx}'
	println('ordinary-winsock-stage=v3-header-order-pass')
	// An earlier failure proves neither native compilation nor WSA startup.
	v3_program := wait_header_compile(v3_bin, 'windows_ordinary_winsock_v3', source)
	v3_run := wait_header_execute_without_vflags(os.quoted_path(v3_program.out))
	assert v3_run.exit_code == 0, v3_run.output
	assert v3_run.output.trim_space() == 'windows-ordinary-winsock-ok', v3_run.output
	println('ordinary-winsock-stage=v3-runtime-pass')
}

fn test_windows_system_headers_own_crt_externs_and_native_tags() {
	$if !windows {
		return
	}
	v3_bin := wait_header_build_v3()
	stdio_program := wait_header_compile(v3_bin, 'windows_headerless_stdio_modes', "module main

fn main() {
	assert C._IOFBF == 0
	assert C._IOLBF == 0x0040
	assert C._IONBF == 0x0004
	_ = voidptr(&C.WriteFile)
	_ = voidptr(&C.WriteConsoleW)
	unbuffer_stdout()
	println('windows-headerless-stdio-ok')
}
")
	if stdio_program.compiler_family == 'tcc' {
		mut includes := []string{}
		for line in stdio_program.c_code.split_into_lines() {
			if line.trim_space().starts_with('#include') {
				includes << line.trim_space()
			}
		}
		assert includes.len == 1, stdio_program.c_code
		assert includes[0].starts_with('#include "') && includes[0].ends_with('"'),
			stdio_program.c_code
		header := includes[0]['#include "'.len..includes[0].len - 1]
		expected_header := os.join_path(os.dir(wait_header_vlib_dir), 'thirdparty', 'stdatomic',
			'win', 'atomic.h')
		assert os.real_path(header) == os.real_path(expected_header), stdio_program.c_code
	} else {
		assert !wait_header_has_include_directive(stdio_program.c_code), stdio_program.c_code
	}
	assert stdio_program.c_code.count('#define FILE_ATTRIBUTE_READONLY 0x00000001U') == 1,
		stdio_program.c_code
	// This source has no imports or SDK request. Keep the native headerless ABI
	// witness here instead of inferring headerlessness from the C compiler name.
	for declaration in ['bool WINAPI WriteFile(void*, u8*, u32, DWORD*, void*);',
		'bool WINAPI WriteConsoleW(void*, u16*, u32, DWORD*, void*);'] {
		name := wait_header_generated_extern_name(declaration)
		expected := if stdio_program.compiler_family == 'tcc' { '' } else { declaration }
		assert wait_header_generated_extern_line(stdio_program.c_code, name) == expected,
			stdio_program.c_code
	}
	stdio_run := wait_header_execute_without_vflags(os.quoted_path(stdio_program.out))
	assert stdio_run.exit_code == 0, stdio_run.output
	assert stdio_run.output.trim_space() == 'windows-headerless-stdio-ok', stdio_run.output
	sdk_program := wait_header_compile(v3_bin, 'windows_closure_sdk_owners', "module main

import os
import json2

#preinclude <stdio.h>
#preinclude <windows.h>

struct SdkRecord {
	driver            string
	driver_basename   string
	expanded_argv     []string
	generation        string
	link_output_token string
	linkage           string
	output_basename   string
	response_path     string
	transport         string
}

fn main() {
	if os.args.len == 2 && os.args[1] == 'windows-sdk-exec-child' {
		println('windows-sdk-exec-ok')
		return
	}
	mut info := C.SYSTEM_INFO{}
	C.GetNativeSystemInfo(&info)
	assert info.dwPageSize > 0
	_ = voidptr(&C.VirtualAlloc)
	_ = voidptr(&C.VirtualProtect)
	_ = voidptr(&C.CreateFileW)
	_ = voidptr(&C.CreatePipe)
	_ = voidptr(&C.CreateProcessW)
	_ = voidptr(&C.ExpandEnvironmentStringsW)
	_ = voidptr(&C.FindClose)
	_ = voidptr(&C.FindFirstFileW)
	_ = voidptr(&C.FormatMessageW)
	_ = voidptr(&C.GetExitCodeProcess)
	_ = voidptr(&C.GetFullPathName)
	_ = voidptr(&C.LocalFree)
	_ = voidptr(&C.ReadFile)
	_ = voidptr(&C.RemoveDirectoryW)
	_ = voidptr(&C.SetHandleInformation)
	expected_output := 'probe-世界.exe'
	captured := fn [expected_output] () string {
		return expected_output
	}
	assert captured() == expected_output
	record := SdkRecord{
		driver:            'clang.exe'
		driver_basename:   'clang.exe'
		expanded_argv:     ['-o', expected_output]
		generation:        'v3'
		link_output_token: expected_output
		linkage:           'static'
		output_basename:   expected_output
		response_path:     ''
		transport:         'direct'
	}
	encoded := json2.encode(record, escape_unicode: true)
	value := json2.decode[json2.Any](encoded, strict: true) or { panic(err) }
	assert value is map[string]json2.Any
	fields := value as map[string]json2.Any
	assert fields.len == 9
	output := fields['output_basename'] or { panic('missing output_basename') }
	assert output is string
	assert (output as string) == expected_output
	assert os.args.len == 2
	assert os.is_dir(os.args[1])
	root := os.join_path(os.args[1], 'v3_sdk_helper_' + os.getpid().str())
	os.mkdir(root) or { panic(err) }
	path := os.join_path(root, 'report-世界.json')
	defer {
		os.rm(path) or {}
		os.rmdir(root) or {}
	}
	os.write_file(path, encoded) or { panic(err) }
	stat := os.lstat(path) or { panic(err) }
	assert stat.size == u64(encoded.len)
	assert !os.is_link(path)
	assert os.is_file(os.real_path(path))
	assert os.read_file(path) or { panic(err) } == encoded
	exec_result := os.exec([os.args[0], 'windows-sdk-exec-child'])
	assert exec_result.exit_code == 0, exec_result.output
	assert exec_result.output.trim_space() == 'windows-sdk-exec-ok', exec_result.output
	println('windows-closure-sdk-ok')
}
")
	assert sdk_program.c_code.contains('#include <stdio.h>'), sdk_program.c_code
	assert sdk_program.c_code.contains('#include <windows.h>'), sdk_program.c_code
	sdk_compact := wait_header_compact_source(sdk_program.c_code)
	assert sdk_compact.contains('GetNativeSystemInfo('), sdk_program.c_code
	assert sdk_compact.contains('&VirtualAlloc'), sdk_program.c_code
	assert sdk_compact.contains('&VirtualProtect'), sdk_program.c_code
	for name in ['GetNativeSystemInfo', 'VirtualAlloc', 'VirtualProtect',
		'CreateFileW', 'CreatePipe', 'CreateProcessW', 'ExpandEnvironmentStringsW',
		'FindClose', 'FindFirstFileW', 'FormatMessageW', 'GetExitCodeProcess',
		'GetFullPathNameW', 'LocalFree', 'ReadFile', 'RemoveDirectoryW', 'SetHandleInformation'] {
		assert wait_header_generated_extern_count(sdk_program.c_code, name) == 0,
			sdk_program.c_code
	}
	for name in ['CreateFileW', 'CreatePipe', 'CreateProcessW', 'ExpandEnvironmentStringsW',
		'FindClose', 'FindFirstFileW', 'FormatMessageW', 'GetExitCodeProcess',
		'GetFullPathNameW', 'LocalFree', 'ReadFile', 'RemoveDirectoryW', 'SetHandleInformation'] {
		assert sdk_compact.contains('&' + name), sdk_program.c_code
	}
	assert sdk_compact.contains('DWORDtmp=(u32)(0)'), sdk_program.c_code
	assert sdk_compact.contains('VirtualProtect(ptr,size,PAGE_EXECUTE_READ,&tmp)'),
		sdk_program.c_code
	assert sdk_compact.contains('VirtualProtect(ptr,size,PAGE_READWRITE,&tmp)'),
		sdk_program.c_code
	sdk_parent := os.dir(sdk_program.out)
	sdk_exe := sdk_program.out + '.exe'
	assert os.is_file(sdk_exe), sdk_exe
	sdk_run := wait_header_execute_without_vflags(os.quoted_path(sdk_exe) + ' ' +
		os.quoted_path(sdk_parent))
	assert sdk_run.exit_code == 0, sdk_run.output
	assert sdk_run.output.trim_space() == 'windows-closure-sdk-ok', sdk_run.output
	connect_source := wait_header_windows_vschannel_connect_source()
	for generation in ['v1', 'v3'] {
		compiler := if generation == 'v1' {
			os.quoted_path(wait_header_vexe) + ' -old-compiler -gc none'
		} else {
			v3_bin
		}
		connect_program := wait_header_compile(compiler, 'windows_vschannel_connect_' +
			generation, connect_source)
		assert connect_program.c_code.contains('vschannel_format_proxy_connect('),
			connect_program.c_code
		connect_run := wait_header_execute_without_vflags(os.quoted_path(connect_program.out))
		assert connect_run.exit_code == 0, connect_run.output
		assert connect_run.output.trim_space() == 'windows-vschannel-connect-ok',
			connect_run.output
	}
	default_program := wait_header_compile(v3_bin, 'windows_system_header_owners_default',
		wait_header_windows_system_owner_source(''))
	fallback_program := wait_header_compile(v3_bin, 'windows_system_header_owners_fallback',
		wait_header_windows_system_owner_source('#flag -DNONLS\n#flag -D_WIN32_WINNT=0x0502'))
	argv_program := wait_header_compile(v3_bin, 'windows_wide_runtime_arguments', "module main

import os

fn main() {
	runtime_args := arguments()
	assert runtime_args == os.args
	assert runtime_args.len == 3
	assert runtime_args[0].len > 0
	assert runtime_args[1] == 'ascii-argument'
	assert runtime_args[2] == 'héllo-世界'
	println('windows-wide-argv-ok')
}
")
	top_level_argv_program := wait_header_compile(v3_bin, 'windows_wide_top_level_arguments', "module main

import os

@[export: 'v3_argv_callback']
pub fn argv_callback() {}

runtime_args := arguments()
assert runtime_args == os.args
assert runtime_args.len == 3
assert runtime_args[0].len > 0
assert runtime_args[1] == 'ascii-argument'
assert runtime_args[2] == 'héllo-世界'
println('windows-wide-top-level-argv-ok')
")
	for generated_code in [default_program.c_code, fallback_program.c_code, argv_program.c_code,
		top_level_argv_program.c_code] {
		assert generated_code.count('int wmain(int argc, wchar_t** argv) {') == 1,
			generated_code
		assert !generated_code.contains('int main(int argc, char** argv) {'), generated_code
		assert !generated_code.contains('wWinMain'), generated_code
	}
	unicode_argument := 'héllo-世界'
	argv_run :=
		wait_header_execute_without_vflags('${os.quoted_path(argv_program.out)} ascii-argument ${os.quoted_path(unicode_argument)}')
	assert argv_run.exit_code == 0, argv_run.output
	assert argv_run.output.trim_space() == 'windows-wide-argv-ok', argv_run.output
	top_level_argv_run :=
		wait_header_execute_without_vflags('${os.quoted_path(top_level_argv_program.out)} ascii-argument ${os.quoted_path(unicode_argument)}')
	assert top_level_argv_run.exit_code == 0, top_level_argv_run.output
	assert top_level_argv_run.output.trim_space() == 'windows-wide-top-level-argv-ok',
		top_level_argv_run.output
	assert top_level_argv_program.c_code.contains('if (g_main_argv == NULL) {'),
		top_level_argv_program.c_code
	fn_source := os.read_file(os.join_path(wait_header_v3_dir, 'gen', 'c', 'fn.v')) or {
		panic(err)
	}
	assert fn_source.count('g.writeln(v3_c_main_signature(g.target.os))') == 3
	assert fn_source.count("return 'int wmain(int argc, wchar_t** argv) {'") == 1
	assert fn_source.count("return 'int main(int argc, char** argv) {'") == 1
	c_code := default_program.c_code
	assert default_program.compiler_family in ['tcc', 'gcc', 'clang'],
		default_program.compiler_family
	assert fallback_program.compiler_family == default_program.compiler_family,
		fallback_program.compiler_family
	uses_tcc_atomic_header := default_program.compiler_family == 'tcc'
	cfns_source := os.read_file(os.join_path(wait_header_vlib_dir, 'builtin', 'cfns.c.v')) or {
		panic(err)
	}
	cfns_tcc_source := os.read_file(os.join_path(wait_header_vlib_dir, 'builtin',
		'cfns_windows_tcc.h')) or { panic(err) }
	builtin_windows_source := os.read_file(os.join_path(wait_header_vlib_dir, 'builtin',
		'builtin_windows.c.v')) or { panic(err) }
	os_source := os.read_file(os.join_path(wait_header_vlib_dir, 'os', 'os.c.v')) or {
		panic(err)
	}
	os_stat_windows_source := os.read_file(os.join_path(wait_header_vlib_dir, 'os',
		'os_stat_windows.c.v')) or { panic(err) }
	os_windows_source := os.read_file(os.join_path(wait_header_vlib_dir, 'os', 'os_windows.c.v')) or {
		panic(err)
	}
	process_windows_source := os.read_file(os.join_path(wait_header_vlib_dir, 'os',
		'process_windows.c.v')) or { panic(err) }
	compact_cfns_source := wait_header_compact_source(cfns_source)
	compact_cfns_tcc_source := wait_header_compact_source(cfns_tcc_source)
	compact_builtin_source := wait_header_compact_source(builtin_windows_source)
	compact_os_source := wait_header_compact_source(os_source)
	compact_os_stat_windows_source := wait_header_compact_source(os_stat_windows_source)
	compact_os_windows_source := wait_header_compact_source(os_windows_source)
	compact_process_source := wait_header_compact_source(process_windows_source)
	assert compact_cfns_source.count('fnC.GetFileAttributesW(lpFileName&u16)u32') == 1,
		'GetFileAttributesW binding'
	assert compact_cfns_source.count('fnC.CreateDirectory(&u16,voidptr)bool') == 1,
		'CreateDirectory binding'
	assert compact_cfns_source.count('fnC.WaitForSingleObject(voidptr,u32)u32') == 1,
		'WaitForSingleObject binding'
	assert compact_cfns_tcc_source.count('externDWORDWINAPIGetFinalPathNameByHandleW(void*hFile,unsignedshort*lpFilePath,DWORDnSize,DWORDdwFlags);') == 1,
		'GetFinalPathNameByHandleW TCC provider'
	assert compact_cfns_tcc_source.contains('#ifdef__TINYC__#ifndefGetFinalPathNameByHandleWexternDWORDWINAPIGetFinalPathNameByHandleW'),
		'GetFinalPathNameByHandleW TCC guard'
	assert compact_builtin_source.count('C.WriteConsoleW(console_handle,wide_ptr,C.DWORD(remaining_chars),voidptr(&chars_written),nil)') == 2,
		'WriteConsoleW source call count'
	assert compact_builtin_source.count('C.WriteFile(handle,ptr,C.DWORD(chunk),voidptr(&written),nil)') == 1,
		'builtin WriteFile source call count'
	assert compact_process_source.count('C.WriteFile(rhandle,_s.str,u32(_s.len),voidptr(&bytes_write),0)') == 1,
		'os WriteFile source call count'
	get_file_attributes_source_calls := compact_os_source.count('C.GetFileAttributesW(') +
		compact_os_stat_windows_source.count('C.GetFileAttributesW(')
	assert get_file_attributes_source_calls == 4,
		'GetFileAttributesW source call count'
	assert compact_os_windows_source.count('C.CreateDirectory(') == 1,
		'CreateDirectory source call count'
	assert compact_os_source.count('C.GetFinalPathNameByHandleW(') == 2,
		'GetFinalPathNameByHandleW source call count'
	wait_source_calls := compact_os_windows_source.count('C.WaitForSingleObject(') +
		compact_process_source.count('C.WaitForSingleObject(')
	assert wait_source_calls == 2,
		'WaitForSingleObject source call count'
	for generated_code in [c_code, fallback_program.c_code] {
		compact_calls := generated_code.replace('\t', '').replace(' ', '').replace('\r', '').replace('\n',
			'')
		// os/fd.c.v explicitly requests Winsock even without an import of net.
		// Both programs therefore use the SDK, including the conditional fallback case.
		winsock_pos := generated_code.index('#include <winsock2.h>') or { -1 }
		windows_pos := generated_code.index('#include <windows.h>') or { -1 }
		assert winsock_pos >= 0 && windows_pos > winsock_pos, generated_code
		assert generated_code.count('#define FILE_ATTRIBUTE_READONLY 0x00000001U') == 0,
			generated_code
		assert compact_calls.count('externDWORDWINAPIGetFinalPathNameByHandleW(void*hFile,unsignedshort*lpFilePath,DWORDnSize,DWORDdwFlags);') == 1,
			generated_code
		get_final_provider_pos := generated_code.index('extern DWORD WINAPI GetFinalPathNameByHandleW(') or {
			-1
		}
		assert get_final_provider_pos >= 0, generated_code
		if uses_tcc_atomic_header {
			atomic_header_pos := generated_code.index('thirdparty/stdatomic/win/atomic.h') or {
				-1
			}
			assert atomic_header_pos >= 0 && atomic_header_pos < get_final_provider_pos,
				generated_code
		} else {
			assert windows_pos < get_final_provider_pos, generated_code
		}
		for expected in [
			'GetConsoleMode(osfh,(void*)(&mode))',
			'QueryPerformanceCounter((void*)(&counter))',
			'QueryPerformanceFrequency((void*)(&frequency))',
			'SystemTimeToTzSpecificLocalTime(NULL,(void*)(&st_utc),(void*)(&st_local))',
			'FileTimeToSystemTime(&ft_utc,(void*)(&st_utc))',
			'(DWORD*)(void*)(&chars_written)',
		] {
			assert compact_calls.contains(expected), expected
		}
		for rejected in [
			'GetConsoleMode(osfh,(u32*)((void*)(&mode)))',
			'QueryPerformanceCounter((u64*)((void*)',
			'QueryPerformanceFrequency((u64*)((void*)',
			'SystemTimeToTzSpecificLocalTime(NULL,(time__SystemTime*)((void*)',
			'FileTimeToSystemTime(&ft_utc,(time__SystemTime*)((void*)',
		] {
			assert !compact_calls.contains(rejected), rejected
		}
		assert compact_calls.count('WriteConsoleW(console_handle,wide_ptr,') == 1,
			'active WriteConsoleW backend call count'
		for name in ['WaitForSingleObject', 'GetLastError', 'CreateDirectoryW',
			'GetFileAttributesW', 'WriteConsoleW', 'WriteFile'] {
			assert wait_header_generated_extern_line(generated_code, name) == '', generated_code
		}
		assert wait_header_generated_extern_line(generated_code, 'GetFinalPathNameByHandleW') == 'DWORD WINAPI GetFinalPathNameByHandleW(HANDLE, LPWSTR, DWORD, DWORD);',
			generated_code
		assert !generated_code.contains('bool WINAPI WriteConsoleW(void*, u16*, u32, u32*, void*);'),
			generated_code
		assert !generated_code.contains('bool WINAPI WriteFile(void*, u8*, u32, u32*, void*);'),
			generated_code
	}
	sdk_owned := wait_header_windows_sdk_owned_fns()
	crt_referenced := wait_header_windows_crt_referenced_fns()
	assert sdk_owned.len == 20
	assert wait_header_windows_tcc_insert_owned_fns() == ['GetFinalPathNameByHandleW']
	assert crt_referenced.len == 15
	thread_start_alias := 'typedef DWORD (WINAPI *PTHREAD_START_ROUTINE)(void*);'
	lpthread_start_alias := 'typedef PTHREAD_START_ROUTINE LPTHREAD_START_ROUTINE;'
	timezone_alias := 'typedef struct _TIME_ZONE_INFORMATION TIME_ZONE_INFORMATION;'
	wide_console_alias := '#ifndef ScrollConsoleScreenBuffer\n#define ScrollConsoleScreenBuffer ScrollConsoleScreenBufferW\n#endif'
	early_vista_block := '#if !defined(_WIN32_WINNT) || _WIN32_WINNT < 0x0600\nvoid WINAPI AcquireSRWLockExclusive(void*);\nvoid WINAPI ReleaseSRWLockExclusive(void*);\n#ifndef __TINYC__\nDWORD WINAPI GetFinalPathNameByHandleW(HANDLE, LPWSTR, DWORD, DWORD);\n#endif\n#endif'
	for generated_code in [c_code, fallback_program.c_code] {
		thread_helper_pos := generated_code.index('static inline int v_sync_thread_create_detached') or {
			-1
		}
		closure_helper_pos := generated_code.index('V_CLOSURE_STATIC_INLINE void v_closure_init_once') or {
			-1
		}
		timezone_extern := wait_header_generated_extern_line(generated_code,
			'SystemTimeToTzSpecificLocalTime')
		assert thread_helper_pos >= 0, generated_code
		assert closure_helper_pos >= 0, generated_code
		assert generated_code.count(early_vista_block) == 1, generated_code
		early_pos := generated_code.index(early_vista_block) or { -1 }
		windows_pos := generated_code.index('#include <windows.h>') or { -1 }
		assert windows_pos >= 0 && early_pos > windows_pos && early_pos < closure_helper_pos,
			generated_code
		assert !generated_code.contains(wide_console_alias), generated_code
		assert !generated_code.contains('ScrollConsoleScreenBufferA'), generated_code
		assert generated_code.count(thread_start_alias) == 0, generated_code
		assert generated_code.count(lpthread_start_alias) == 0, generated_code
		assert generated_code.count(timezone_alias) == 0, generated_code
		assert timezone_extern == '', generated_code
		for name in ['AcquireSRWLockExclusive', 'ReleaseSRWLockExclusive'] {
			prototype := 'void WINAPI ${name}(void*);'
			assert generated_code.count(prototype) == 1, generated_code
			prototype_pos := generated_code.index(prototype) or { -1 }
			assert prototype_pos >= early_pos && prototype_pos < closure_helper_pos, generated_code
		}
	}
	for name in sdk_owned {
		assert wait_header_generated_extern_count(c_code, name) == 0, name
		assert wait_header_generated_extern_count(fallback_program.c_code, name) == 0,
			name
	}
	// The early non-TCC fallback and the existing multiline TCC insert have
	// complementary C guards; only the former is a generated single-line extern.
	assert wait_header_generated_extern_count(c_code, 'GetFinalPathNameByHandleW') == 1
	assert wait_header_generated_extern_count(fallback_program.c_code, 'GetFinalPathNameByHandleW') == 1
	for name in crt_referenced {
		assert wait_header_generated_extern_count(c_code, name) == 0, name
		assert wait_header_generated_extern_count(fallback_program.c_code, name) == 0, name
	}
	stat_body := 'struct __stat64 {\n\tu32 st_dev;\n\tu16 st_ino;\n\tu16 st_mode;\n\tu16 st_nlink;\n\tu16 st_uid;\n\tu16 st_gid;\n\tu32 st_rdev;\n\tu64 st_size;\n\ti64 st_atime;\n\ti64 st_mtime;\n\ti64 st_ctime;\n};'
	stat_init := '(struct __stat64){'
	filetime_alias := 'typedef struct _FILETIME _FILETIME;'
	filetime_body := 'struct _FILETIME {\n\tu32 dwLowDateTime;\n\tu32 dwHighDateTime;\n};'
	filetime_init := '(_FILETIME){'
	for generated_code in [c_code, fallback_program.c_code] {
		assert generated_code.count(stat_body) == 0, generated_code
		assert generated_code.count('struct __stat64 {') == 0, generated_code
		assert generated_code.count(stat_init) == 1, generated_code
		assert generated_code.count('struct __stat64;') == 0, generated_code
		assert generated_code.count('typedef struct __stat64 __stat64;') == 0, generated_code
		assert generated_code.count(filetime_alias) == 1, generated_code
		assert generated_code.count(filetime_body) == 0, generated_code
		assert generated_code.count('struct _FILETIME {') == 0, generated_code
		assert generated_code.count('struct _FILETIME;') == 0, generated_code
		assert generated_code.count(filetime_init) == 1, generated_code
		filetime_alias_pos := generated_code.index(filetime_alias) or { -1 }
		filetime_init_pos := generated_code.index(filetime_init) or { -1 }
		assert filetime_alias_pos >= 0 && filetime_alias_pos < filetime_init_pos,
			generated_code
	}
	assert wait_header_generated_extern_count(c_code, 'atomic_thread_fence') == 0
	assert wait_header_generated_extern_count(fallback_program.c_code, 'atomic_thread_fence') == 0
	if uses_tcc_atomic_header {
		for generated_code in [c_code, fallback_program.c_code] {
			assert !generated_code.contains('_V_atomic_thread_fence'), generated_code
			assert generated_code.contains('thirdparty/stdatomic/win/atomic.h'), generated_code
			for name in ['FlsAlloc', 'FlsGetValue', 'FlsSetValue'] {
				assert generated_code.contains('${name}('), name
			}
		}
	}
	bad_wstat := 'i32 _wstat(u16* path, _stat* buffer);'
	assert wait_header_generated_extern_line(c_code, '_wstat') == '', c_code
	assert wait_header_generated_extern_line(fallback_program.c_code, '_wstat') == '',
		fallback_program.c_code
	assert c_code.count(bad_wstat) == 0, c_code
	assert fallback_program.c_code.count(bad_wstat) == 0, fallback_program.c_code
	for name in wait_header_windows_nls_fns() {
		default_line := wait_header_generated_extern_line(c_code, name)
		fallback_line := wait_header_generated_extern_line(fallback_program.c_code, name)
		assert default_line.contains(' WINAPI ${name}('), default_line
		assert fallback_line.contains(' WINAPI ${name}('), fallback_line
		assert wait_header_generated_extern_count(c_code, name) == 1, name
		assert wait_header_generated_extern_count(fallback_program.c_code, name) == 1, name
		default_guard := '#ifdef NONLS\n${default_line}\n#endif'
		fallback_guard := '#ifdef NONLS\n${fallback_line}\n#endif'
		assert c_code.contains(default_guard), default_line
		assert fallback_program.c_code.contains(fallback_guard), fallback_line
	}
	// The SDK owns the enabled APIs; unchanged fallback declarations remain only
	// under their real C guards, including the deliberately older target above.
	for name in wait_header_windows_vista_fns() {
		default_line := wait_header_generated_extern_line(c_code, name)
		fallback_line := wait_header_generated_extern_line(fallback_program.c_code, name)
		assert default_line.contains(' WINAPI ${name}('), default_line
		assert fallback_line.contains(' WINAPI ${name}('), fallback_line
		assert wait_header_generated_extern_count(c_code, name) == 1, name
		assert wait_header_generated_extern_count(fallback_program.c_code, name) == 1, name
		if name in ['AcquireSRWLockExclusive', 'ReleaseSRWLockExclusive'] {
			assert c_code.contains(early_vista_block), default_line
			assert fallback_program.c_code.contains(early_vista_block), fallback_line
		} else {
			assert c_code.contains('#if !defined(_WIN32_WINNT) || _WIN32_WINNT < 0x0600\n${default_line}\n#endif'),
				default_line
			assert fallback_program.c_code.contains('#if !defined(_WIN32_WINNT) || _WIN32_WINNT < 0x0600\n${fallback_line}\n#endif'),
				fallback_line
		}
	}
	for generated_code in [c_code, fallback_program.c_code] {
		wide_line := wait_header_generated_extern_line(generated_code, 'WideCharToMultiByte')
		assert wide_line.contains('int*'), wide_line
		assert !wide_line.contains('bool*'), wide_line
	}
	for generated_code in [c_code, fallback_program.c_code] {
		for name in ['TryAcquireSRWLockExclusive', 'TryAcquireSRWLockShared'] {
			line := wait_header_generated_extern_line(generated_code, name)
			assert line.starts_with('u8 WINAPI '), line
		}
	}
	assert fallback_program.c_code.contains('#flag') == false
}

fn test_windows_sdk_types_are_emitted_before_extern_prototypes() {
	v3_bin := wait_header_build_v3()
	c_code := wait_header_gen_c(v3_bin, 'windows_sdk_type_order', 'module main

@[typedef]
struct C.SECURITY_ATTRIBUTES {}

fn C.CreateHardLinkW(&u16, &u16, &C.SECURITY_ATTRIBUTES) int

fn main() {
	path := &u16(unsafe { nil })
	attrs := &C.SECURITY_ATTRIBUTES(unsafe { nil })
	_ = C.CreateHardLinkW(path, path, attrs)
}
')
	security_typedef := 'typedef struct SECURITY_ATTRIBUTES { DWORD nLength; void* lpSecurityDescriptor; BOOL bInheritHandle; } SECURITY_ATTRIBUTES;'
	security_typedef_idx := c_code.index(security_typedef) or { -1 }
	prototype_idx := c_code.index('int WINAPI CreateHardLinkW(u16*, u16*, SECURITY_ATTRIBUTES*);') or {
		-1
	}
	assert security_typedef_idx >= 0, c_code
	assert prototype_idx >= 0, c_code
	assert security_typedef_idx < prototype_idx, c_code
	assert !c_code.contains('typedef struct SECURITY_ATTRIBUTES SECURITY_ATTRIBUTES;'), c_code
}

fn test_winapi_extern_prototypes_use_calling_convention() {
	v3_bin := wait_header_build_v3()
	c_code := wait_header_gen_c(v3_bin, 'winapi_calling_convention', 'module main

fn C.GetStdHandle(u32) voidptr
fn C.CreateFileW(&u16, u32, u32, voidptr, u32, u32, voidptr) voidptr

fn main() {
	path := &u16(unsafe { nil })
	_ = C.GetStdHandle(u32(0))
	_ = C.CreateFileW(path, 0, 0, voidptr(0), 0, 0, voidptr(0))
}
')
	assert c_code.contains('#ifndef WINAPI'), c_code
	assert c_code.contains('#define WINAPI __stdcall'), c_code
	assert c_code.contains('void* WINAPI GetStdHandle(u32);'), c_code
	assert c_code.contains('void* WINAPI CreateFileW(u16*, u32, u32, void*, u32, u32, void*);'), c_code
	assert !c_code.contains('void* GetStdHandle(u32);'), c_code
	assert !c_code.contains('void* CreateFileW(u16*, u32, u32, void*, u32, u32, void*);'), c_code
}

fn test_unsuffixed_winapi_decls_use_wide_exports() {
	v3_bin := wait_header_build_v3()
	c_code := wait_header_gen_c(v3_bin, 'winapi_unsuffixed_wide_exports', 'module main

fn C.GetModuleFileName(voidptr, &u16, u32) u32
fn C.CreateFile(&u16, u32, u32, voidptr, u32, u32, voidptr) voidptr
fn C.LoadLibrary(&u16) voidptr
fn C.DefWindowProc(voidptr, u32, usize, isize) isize

fn main() {
	path := &u16(unsafe { nil })
	_ = C.GetModuleFileName(voidptr(0), path, 0)
	_ = C.CreateFile(path, 0, 0, voidptr(0), 0, 0, voidptr(0))
	_ = C.LoadLibrary(path)
	_ = voidptr(&C.DefWindowProc)
}
')
	assert c_code.contains('u32 WINAPI GetModuleFileNameW(void*, u16*, u32);'), c_code
	assert c_code.contains('void* WINAPI CreateFileW(u16*, u32, u32, void*, u32, u32, void*);'), c_code
	assert c_code.contains('void* WINAPI LoadLibraryW(u16*);'), c_code
	assert c_code.contains('ptrdiff_t WINAPI DefWindowProcW(void*, u32, size_t, ptrdiff_t);'), c_code
	assert c_code.contains('GetModuleFileNameW('), c_code
	assert c_code.contains('CreateFileW('), c_code
	assert c_code.contains('LoadLibraryW('), c_code
	assert c_code.contains('&DefWindowProcW'), c_code
	assert !c_code.contains('GetModuleFileName('), c_code
	assert !c_code.contains('CreateFile('), c_code
	assert !c_code.contains('LoadLibrary('), c_code
	assert !c_code.contains('&DefWindowProc)'), c_code
}

fn test_synthesized_c_extern_prototypes_preserve_const_pointer_params() {
	v3_bin := wait_header_build_v3()
	c_code := wait_header_gen_c(v3_bin, 'c_extern_const_pointer_params', 'module main

fn C.SSL_CTX_load_verify_locations(ctx voidptr, const_file &char, const_ca_path &char) int

fn main() {
	path := &char(unsafe { nil })
	_ = C.SSL_CTX_load_verify_locations(voidptr(0), path, path)
}
')
	assert c_code.contains('int SSL_CTX_load_verify_locations(void* ctx, const char* const_file, const char* const_ca_path);'), c_code
	assert !c_code.contains('int SSL_CTX_load_verify_locations(void* ctx, char* const_file'), c_code
}

fn test_windows_sync_structs_use_headerless_preamble_storage() {
	v3_bin := wait_header_build_v3()
	c_code := wait_header_gen_c(v3_bin, 'windows_sync_struct_storage', 'module main

@[typedef]
struct C.SRWLOCK {}

@[typedef]
struct C.CONDITION_VARIABLE {}

struct SyncHolder {
	rw C.SRWLOCK
	cv C.CONDITION_VARIABLE
}

fn main() {
	_ := SyncHolder{}
}
')
	assert !wait_header_has_include_directive(c_code), c_code
	assert c_code.contains('typedef struct SRWLOCK { void* Ptr; } SRWLOCK;'), c_code
	assert c_code.contains('typedef struct CONDITION_VARIABLE { void* Ptr; } CONDITION_VARIABLE;'), c_code
	assert c_code.contains('SRWLOCK rw;'), c_code
	assert c_code.contains('CONDITION_VARIABLE cv;'), c_code
	assert !c_code.contains('typedef struct SRWLOCK SRWLOCK;'), c_code
	assert !c_code.contains('typedef struct CONDITION_VARIABLE CONDITION_VARIABLE;'), c_code
}

fn test_epoll_data_tag_uses_headerless_preamble_definition() {
	v3_bin := wait_header_build_v3()
	c_code := wait_header_gen_c(v3_bin, 'epoll_data_tag_storage', 'module main

@[typedef]
union C.epoll_data {
mut:
	ptr voidptr
	fd  int
	u32 u32
	u64 u64
}

@[packed]
struct C.epoll_event {
	events u32
	data   C.epoll_data
}

fn main() {
	_ := C.epoll_event{}
}
')
	assert c_code.contains('typedef union epoll_data { void* ptr; int fd; u32 u32; u64 u64; } epoll_data_t;'), c_code
	assert !c_code.contains('union epoll_data {\n'), c_code
}

fn test_windows_console_records_use_headerless_preamble_definitions() {
	v3_bin := wait_header_build_v3()
	c_code := wait_header_gen_c(v3_bin, 'windows_console_records', 'module main

pub union C.Event {
	KeyEvent              C.KEY_EVENT_RECORD
	MouseEvent            C.MOUSE_EVENT_RECORD
	WindowBufferSizeEvent C.WINDOW_BUFFER_SIZE_RECORD
	MenuEvent             C.MENU_EVENT_RECORD
	FocusEvent            C.FOCUS_EVENT_RECORD
}

@[typedef]
pub struct C.INPUT_RECORD {
	EventType u16
	Event     C.Event
}

pub union C.uChar {
mut:
	UnicodeChar rune
	AsciiChar   u8
}

@[typedef]
pub struct C.KEY_EVENT_RECORD {
	bKeyDown          int
	wRepeatCount      u16
	wVirtualKeyCode   u16
	wVirtualScanCode  u16
	uChar             C.uChar
	dwControlKeyState u32
}

@[typedef]
pub struct C.MOUSE_EVENT_RECORD {
	dwMousePosition   C.COORD
	dwButtonState     u32
	dwControlKeyState u32
	dwEventFlags      u32
}

@[typedef]
pub struct C.WINDOW_BUFFER_SIZE_RECORD {
	dwSize C.COORD
}

@[typedef]
pub struct C.MENU_EVENT_RECORD {
	dwCommandId u32
}

@[typedef]
pub struct C.FOCUS_EVENT_RECORD {
	bSetFocus int
}

@[typedef]
pub struct C.COORD {
	X i16
	Y i16
}

@[typedef]
pub struct C.SMALL_RECT {
	Left   u16
	Top    u16
	Right  u16
	Bottom u16
}

@[typedef]
pub struct C.CONSOLE_SCREEN_BUFFER_INFO {
	dwSize              C.COORD
	dwCursorPosition    C.COORD
	wAttributes         u16
	srWindow            C.SMALL_RECT
	dwMaximumWindowSize C.COORD
}

@[typedef]
pub struct C.CHAR_INFO {
	Char       C.uChar
	Attributes u16
}

fn main() {
	_ := C.INPUT_RECORD{}
	_ := C.CHAR_INFO{}
}
')
	assert c_code.contains('typedef union uChar { u16 UnicodeChar; u8 AsciiChar; } uChar;'), c_code
	assert c_code.contains('typedef struct KEY_EVENT_RECORD { int bKeyDown; u16 wRepeatCount; u16 wVirtualKeyCode; u16 wVirtualScanCode; uChar uChar; u32 dwControlKeyState; } KEY_EVENT_RECORD;'), c_code
	assert c_code.contains('typedef struct INPUT_RECORD { u16 EventType; Event Event; } INPUT_RECORD;'), c_code
	assert !c_code.contains('union uChar {\n'), c_code
	assert !c_code.contains('struct uChar'), c_code
	assert !c_code.contains('struct KEY_EVENT_RECORD {\n'), c_code
}

fn test_time_import_uses_platform_tm_layout_without_headers() {
	$if windows {
		return
	}
	v3_bin := wait_header_build_v3()
	program := wait_header_compile(v3_bin, 'time_tm_layout', 'module main

import time

fn main() {
	now := time.now()
	println((now.year > 0).str())
}
')
	assert !wait_header_has_include_directive(program.c_code), program.c_code
	assert program.c_code.contains('struct tm { int tm_sec; int tm_min; int tm_hour; int tm_mday; int tm_mon; int tm_year; int tm_wday; int tm_yday; int tm_isdst; long tm_gmtoff; const char* tm_zone; };'), program.c_code
	assert program.c_code.contains('typedef struct tm tm;'), program.c_code
	assert !program.c_code.contains('int tm_gmtoff;'), program.c_code
	run := os.execute(program.out)
	assert run.exit_code == 0, run.output
	assert run.output.trim_space() == 'true', run.output
}

fn test_term_import_uses_platform_termios_layout_without_headers() {
	$if windows {
		return
	}
	v3_bin := wait_header_build_v3()
	program := wait_header_compile(v3_bin, 'term_termios', 'module main

import term
import term.termios

fn main() {
	mut t := termios.Termios{}
	t.disable_echo()
	width, height := term.get_terminal_size()
	println((width > 0 && height > 0).str())
}
')
	assert !wait_header_has_include_directive(program.c_code), program.c_code
	assert program.c_code.contains('struct termios { size_t c_iflag; size_t c_oflag; size_t c_cflag; size_t c_lflag; u8 c_cc[20]; size_t c_ispeed; size_t c_ospeed; };'), program.c_code
	assert program.c_code.contains('struct termios { int c_iflag; int c_oflag; int c_cflag; int c_lflag; u8 c_line; u8 c_cc[32]; int c_ispeed; int c_ospeed; };'), program.c_code
	assert program.c_code.contains('struct termios { int c_iflag; int c_oflag; int c_cflag; int c_lflag; u8 c_cc[20]; };'), program.c_code
	assert program.c_code.contains('struct termios { int c_iflag; int c_oflag; int c_cflag; int c_lflag; u8 c_cc[20]; u32 reserved[3]; int c_ispeed; int c_ospeed; };'), program.c_code
	assert program.c_code.contains('struct termios { int c_iflag; int c_oflag; int c_cflag; int c_lflag; u8 c_cc[20]; int c_ispeed; int c_ospeed; };'), program.c_code
	assert program.c_code.contains('#define VMIN'), program.c_code
	assert program.c_code.contains('#define TIOCGWINSZ'), program.c_code
	run := os.execute(program.out)
	assert run.exit_code == 0, run.output
	assert run.output.trim_space() == 'true', run.output
}

fn test_filelock_uses_headerless_fcntl_helpers() {
	$if windows {
		return
	}
	v3_bin := wait_header_build_v3()
	program := wait_header_compile(v3_bin, 'filelock_helpers', "module main

import os

fn C.open(&char, i32, ...int) i32
fn C.close(i32) i32
fn C.v_filelock_lock(i32, i32, i32, u64, u64) i32
fn C.v_filelock_unlock(i32, u64, u64) i32

fn main() {
	path := os.join_path(os.temp_dir(), 'v3_headerless_filelock_target')
	os.write_file(path, 'abcdef') or { panic(err) }
	fd := C.open(&char(path.str), C.O_RDWR, 0)
	println(fd)
	lock_result := C.v_filelock_lock(fd, 1, 1, u64(0), u64(3))
	unlock_result := C.v_filelock_unlock(fd, u64(0), u64(3))
	println(lock_result)
	println(unlock_result)
	C.close(fd)
	os.rm(path) or {}
}
")
	assert !wait_header_has_include_directive(program.c_code), program.c_code
	assert program.c_code.contains('#define LOCK_EX 2'), program.c_code
	assert program.c_code.contains('int open(const char* path, int flags, ...);'), program.c_code
	assert !program.c_code.contains('int open(char*'), program.c_code
	assert program.c_code.contains('#elif defined(_WIN32)'), program.c_code
	assert program.c_code.contains('#define GENERIC_READ 0x80000000U'), program.c_code
	assert program.c_code.contains('#define OPEN_ALWAYS 4'), program.c_code
	assert program.c_code.contains('static inline int v_filelock_lock(int fd, int exclusive, int immediate, u64 start, u64 len) { struct flock fl;'), program.c_code
	assert program.c_code.contains('return fcntl(fd, immediate ? F_SETLK : F_SETLKW, &fl);'), program.c_code
	assert program.c_code.contains('typedef struct SECURITY_ATTRIBUTES { DWORD nLength; void* lpSecurityDescriptor; BOOL bInheritHandle; } SECURITY_ATTRIBUTES;'), program.c_code
	assert program.c_code.contains('BOOL LockFileEx(HANDLE handle, DWORD flags, DWORD reserved, DWORD low, DWORD high, OVERLAPPED* overlap);'), program.c_code
	assert program.c_code.contains('return LockFileEx(handle, flags, 0, low, high, &overlap) ? 0 : -1;'), program.c_code
	assert program.c_code.contains('return UnlockFileEx(handle, 0, low, high, &overlap) ? 0 : -1;'), program.c_code
	run := os.execute(program.out)
	assert run.exit_code == 0, run.output
	lines := run.output.trim_space().split_into_lines()
	assert lines.len == 3, run.output
	assert lines[0].int() != -1, run.output
	assert lines[1] == '0', run.output
	assert lines[2] == '0', run.output
}

fn test_net_import_uses_headerless_socket_constants() {
	$if windows {
		return
	}
	v3_bin := wait_header_build_v3()
	program := wait_header_compile(v3_bin, 'net_socket_constants', 'module main

import net

fn C.getaddrinfo(&char, &char, &C.addrinfo, &&C.addrinfo) int
fn C.freeaddrinfo(&C.addrinfo)

fn main() {
	println((int(net.SocketType.tcp) > 0).str())
	println((int(net.AddrFamily.ip) > 0).str())
	host := "127.0.0.1"
	service := "80"
	mut hints := C.addrinfo{}
	unsafe { vmemset(&hints, 0, int(sizeof(hints))) }
	hints.ai_family = C.AF_INET
	hints.ai_socktype = C.SOCK_STREAM
	hints.ai_flags = C.AI_PASSIVE
	mut results := &C.addrinfo(unsafe { nil })
	code := C.getaddrinfo(&char(host.str), &char(service.str), &hints, &results)
	if code != 0 {
		println("false")
		return
	}
	ok := !isnil(results) && results.ai_family == C.AF_INET
	C.freeaddrinfo(results)
	println(ok.str())
}
')
	assert !wait_header_has_include_directive(program.c_code), program.c_code
	assert program.c_code.contains('typedef unsigned short wchar_t;'), program.c_code
	assert program.c_code.contains('typedef unsigned int wchar_t;'), program.c_code
	assert program.c_code.contains('typedef uintptr_t SOCKET;'), program.c_code
	assert program.c_code.contains('struct fd_set { unsigned int fd_count; SOCKET fd_array[FD_SETSIZE]; };'), program.c_code
	assert program.c_code.contains('static inline void v_fd_set(SOCKET fd, fd_set* set)'), program.c_code
	assert program.c_code.contains('#elif defined(__APPLE__)'), program.c_code
	assert program.c_code.contains('#define __V_FD_BITS 32'), program.c_code
	assert program.c_code.contains('struct fd_set { unsigned int fds_bits[FD_SETSIZE / __V_FD_BITS]; };'), program.c_code
	assert program.c_code.contains('struct fd_set { unsigned long fds_bits[FD_SETSIZE / __V_FD_BITS]; };'), program.c_code
	assert program.c_code.contains('struct kevent { uintptr_t ident; u32 filter; u32 flags; u32 fflags; i64 data; void* udata; u64 ext[4]; };'), program.c_code
	assert program.c_code.contains('struct kevent { uintptr_t ident; i16 filter; u16 flags; u32 fflags; intptr_t data; void* udata; };'), program.c_code
	assert program.c_code.contains('struct winsize { unsigned short ws_row; unsigned short ws_col; unsigned short ws_xpixel; unsigned short ws_ypixel; };'), program.c_code
	assert program.c_code.contains('struct addrinfo { int ai_flags; int ai_family; int ai_socktype; int ai_protocol; size_t ai_addrlen; char* ai_canonname; void* ai_addr; struct addrinfo* ai_next; };'), program.c_code
	assert program.c_code.contains('struct addrinfo { int ai_flags; int ai_family; int ai_socktype; int ai_protocol; unsigned int ai_addrlen; char* ai_canonname; void* ai_addr; struct addrinfo* ai_next; };'), program.c_code
	assert program.c_code.contains('struct addrinfo { int ai_flags; int ai_family; int ai_socktype; int ai_protocol; unsigned int ai_addrlen; void* ai_addr; char* ai_canonname; struct addrinfo* ai_next; };'), program.c_code
	assert program.c_code.contains('typedef struct addrinfo addrinfo;'), program.c_code
	assert !program.c_code.contains('int ai_family; int ai_socktype; int ai_flags;'), program.c_code
	assert program.c_code.contains('struct sockaddr { u8 sa_len; u8 sa_family; char sa_data[14]; };'), program.c_code
	assert program.c_code.contains('struct sockaddr_in { u8 sin_len; u8 sin_family; u16 sin_port; u32 sin_addr; char sin_zero[8]; };'), program.c_code
	assert program.c_code.contains('struct sockaddr_in6 { u8 sin6_len; u8 sin6_family; u16 sin6_port; u32 sin6_flowinfo; u8 sin6_addr[16]; u32 sin6_scope_id; };'), program.c_code
	assert program.c_code.contains('struct sockaddr { u16 sa_family; char sa_data[14]; };'), program.c_code
	assert program.c_code.contains('struct sockaddr_in { u16 sin_family; u16 sin_port; u32 sin_addr; char sin_zero[8]; };'), program.c_code
	assert program.c_code.contains('struct sockaddr_in6 { u16 sin6_family; u16 sin6_port; u32 sin6_flowinfo; u8 sin6_addr[16]; u32 sin6_scope_id; };'), program.c_code
	assert !program.c_code.contains('struct sockaddr_in6 {\n\tu16 sin6_family;\n\tu16 sin6_port;\n\tu32 sin6_addr[4];'), program.c_code
	assert program.c_code.contains('#define FLT_EPSILON 1.19209290e-7F'), program.c_code
	assert program.c_code.contains('#define DBL_EPSILON 2.2204460492503131e-16'), program.c_code
	assert program.c_code.contains('#define FLT_MAX __FLT_MAX__'), program.c_code
	assert program.c_code.contains('#define DBL_MAX __DBL_MAX__'), program.c_code
	assert program.c_code.contains('#define KEY_EVENT 0x0001'), program.c_code
	assert program.c_code.contains('#define MOUSE_MOVED 0x0001'), program.c_code
	assert program.c_code.contains('#define DOUBLE_CLICK 0x0002'), program.c_code
	assert program.c_code.contains('#define MOUSE_WHEELED 0x0004'), program.c_code
	assert program.c_code.contains('#define VK_BACK 0x08'), program.c_code
	assert program.c_code.contains('#define VK_RETURN 0x0d'), program.c_code
	assert program.c_code.contains('struct timeval { long tv_sec; long tv_usec; };'), program.c_code
	assert program.c_code.contains('typedef struct timeval timeval;'), program.c_code
	assert program.c_code.contains('struct rusage { struct timeval ru_utime; struct timeval ru_stime; long ru_maxrss; long ru_ixrss; long ru_idrss;'), program.c_code
	assert !program.c_code.contains('u64 tv_sec;'), program.c_code
	assert program.c_code.contains('struct timespec { i64 tv_sec; long tv_nsec; };'), program.c_code
	assert program.c_code.contains('struct timespec { long tv_sec; long tv_nsec; };'), program.c_code
	assert program.c_code.contains('typedef struct timespec timespec;'), program.c_code
	assert !program.c_code.contains('struct timespec {\n\ttv_sec'), program.c_code
	assert program.c_code.contains('#define F_GETFL 3'), program.c_code
	assert program.c_code.contains('#define F_SETFL 4'), program.c_code
	assert program.c_code.contains('#define SOCK_STREAM 1'), program.c_code
	assert program.c_code.contains('#define AF_INET 2'), program.c_code
	assert program.c_code.contains('#define SOL_SOCKET'), program.c_code
	assert program.c_code.contains('#define SOMAXCONN 128'), program.c_code
	assert program.c_code.contains('#define EV_SET(kevp, a, b, c, d, e, f) do'), program.c_code
	assert program.c_code.contains('#define EVFILT_READ (-1)'), program.c_code
	assert program.c_code.contains('#define EVFILT_MACHPORT (-8)'), program.c_code
	assert program.c_code.contains('#define EV_ADD 0x0001'), program.c_code
	assert program.c_code.contains('#define EV_CLEAR 0x0020'), program.c_code
	assert program.c_code.contains('#define EV_ERROR 0x4000'), program.c_code
	assert program.c_code.contains('#elif defined(__FreeBSD__)'), program.c_code
	assert program.c_code.contains('#define O_CLOEXEC 0x00100000'), program.c_code
	assert program.c_code.contains('#define F_SETLK 12'), program.c_code
	assert program.c_code.contains('#define AF_INET6 28'), program.c_code
	assert program.c_code.contains('#elif defined(__OpenBSD__)'), program.c_code
	assert program.c_code.contains('#define O_CLOEXEC 0x10000'), program.c_code
	assert program.c_code.contains('#define AF_INET6 24'), program.c_code
	assert program.c_code.contains('#elif defined(__sun)'), program.c_code
	assert program.c_code.contains('#define O_NONBLOCK 0x80'), program.c_code
	assert program.c_code.contains('#define SOCK_STREAM 2'), program.c_code
	assert program.c_code.contains('#define AI_PASSIVE 0x0008'), program.c_code
	assert program.c_code.contains('#elif defined(__QNX__) || defined(__QNXNTO__)'), program.c_code

	assert program.c_code.contains('#define O_NONBLOCK 000200'), program.c_code
	assert program.c_code.contains('#define EINPROGRESS 236'), program.c_code
	assert program.c_code.contains('#elif defined(__linux__) || defined(__ANDROID__)'), program.c_code
	assert program.c_code.contains('#define EPOLLIN 0x001'), program.c_code
	assert program.c_code.contains('#define EPOLLET (1U << 31)'), program.c_code
	assert program.c_code.contains('#define EPOLL_CTL_ADD 1'), program.c_code

	assert program.c_code.contains('#error unsupported headerless C platform constants'), program.c_code

	assert program.c_code.contains('#define TCP_NODELAY 1'), program.c_code
	run := os.execute(program.out)
	assert run.exit_code == 0, run.output
	assert run.output.trim_space() == 'true\ntrue\ntrue', run.output
}

// The same system header may appear under different guards. v3 drops system
// includes in both contexts while preserving the surrounding C directives.
fn test_same_system_include_under_different_guards_is_dropped() {
	$if windows {
		return
	}
	v3_bin := wait_header_build_v3()
	c_code := wait_header_gen_c(v3_bin, 'dup_guarded_include', "module main

#ifdef __linux__
#include <sys/v3dup_guard.h>
#endif
#ifdef __APPLE__
#include <sys/v3dup_guard.h>
#endif

fn main() {
	println('ok')
}
")
	assert !wait_header_has_include_directive(c_code), c_code
	assert c_code.count('#include <sys/v3dup_guard.h>') == 0, c_code
	assert c_code.contains('#ifdef __linux__\n#endif'), c_code
	assert c_code.contains('#ifdef __APPLE__\n#endif'), c_code
}
