// TCC's bundled <windows.h> does not include <fileapi.h>, and TCC's own
// <fileapi.h> cannot be used either because it pulls in <apiset.h>, a header
// TCC does not ship. As a result GetFinalPathNameByHandleW has no declaration
// in scope when TCC compiles code that uses it (e.g. os.real_path).
//
// Provide the native declaration for TCC only. System-header GCC/MSVC get it
// from the Windows SDK (via <windows.h> -> <fileapi.h>); headerless V3
// non-TCC units emit their own ABI-compatible fallback.
#ifdef __TINYC__
#ifndef GetFinalPathNameByHandleW
extern DWORD WINAPI GetFinalPathNameByHandleW(void *hFile, unsigned short *lpFilePath,
	DWORD nSize, DWORD dwFlags);
#endif
#endif
