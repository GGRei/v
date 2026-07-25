#define _CRT_SECURE_NO_WARNINGS
#define UNICODE
#define _UNICODE
#define _WIN32_WINNT 0x0A00

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <windows.h>

#ifndef SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE
#define SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE 0x2
#endif

#if defined(__TINYC__)
#define PROBE_COMPILER "tcc"
#elif defined(_MSC_VER)
#define PROBE_COMPILER "msvc"
#elif defined(__GNUC__)
#define PROBE_COMPILER "gcc"
#else
#define PROBE_COMPILER "unknown"
#endif

struct stat_snapshot {
    int result;
    int error;
    unsigned long nlink;
};

static int validate(const char *label, int condition) {
    printf("CHECK %-38s %s\n", label, condition ? "PASS" : "FAIL");
    return condition ? 0 : 1;
}

static struct stat_snapshot snapshot_wstat(const char *phase,
    const wchar_t *path) {
    struct _stat64 data;
    struct stat_snapshot snapshot;

    memset(&data, 0, sizeof(data));
    errno = 0;
    snapshot.result = _wstat64(path, &data);
    snapshot.error = errno;
    snapshot.nlink = (unsigned long)data.st_nlink;
    printf("NLINK WSTAT phase=%s rc=%d errno=%d nlink=%lu\n", phase,
        snapshot.result, snapshot.error, snapshot.nlink);
    return snapshot;
}

static int snapshot_reparse_nlink(const char *phase, const wchar_t *path,
    DWORD *nlink) {
    BY_HANDLE_FILE_INFORMATION information;
    HANDLE handle;
    DWORD error;

    memset(&information, 0, sizeof(information));
    handle = CreateFileW(path, FILE_READ_ATTRIBUTES,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
        OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    if (handle == INVALID_HANDLE_VALUE) {
        error = GetLastError();
        printf("NLINK REPARSE phase=%s ok=0 error=%lu\n", phase,
            (unsigned long)error);
        return 0;
    }
    if (!GetFileInformationByHandle(handle, &information)) {
        error = GetLastError();
        CloseHandle(handle);
        printf("NLINK REPARSE phase=%s ok=0 error=%lu\n", phase,
            (unsigned long)error);
        return 0;
    }
    CloseHandle(handle);
    *nlink = information.nNumberOfLinks;
    printf("NLINK REPARSE phase=%s ok=1 nlink=%lu attrs=0x%08lX\n", phase,
        (unsigned long)*nlink, (unsigned long)information.dwFileAttributes);
    return 1;
}

int main(void) {
    const wchar_t *target_path = L"nlink_target.tmp";
    const wchar_t *link_path = L"nlink_link.tmp";
    struct stat_snapshot ordinary;
    struct stat_snapshot valid_link;
    struct stat_snapshot deleting_link;
    struct stat_snapshot dangling_link;
    DWORD reparse_before = 0;
    DWORD reparse_during = 0;
    DWORD reparse_after = 0;
    HANDLE target;
    HANDLE held_target;
    int reparse_before_ok;
    int reparse_during_ok;
    int reparse_after_ok;
    int failures = 0;

    DeleteFileW(link_path);
    DeleteFileW(target_path);

    target = CreateFileW(target_path, GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
        CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    failures += validate("ordinary file created",
        target != INVALID_HANDLE_VALUE);
    if (target == INVALID_HANDLE_VALUE) {
        return 1;
    }
    CloseHandle(target);

    failures += validate("symbolic link created",
        CreateSymbolicLinkW(link_path, target_path,
            SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE) != 0);
    if (failures != 0) {
        DeleteFileW(target_path);
        return 1;
    }

    printf("NLINK PROBE compiler=%s\n", PROBE_COMPILER);
    ordinary = snapshot_wstat("ordinary", target_path);
    valid_link = snapshot_wstat("valid_link", link_path);
    reparse_before_ok = snapshot_reparse_nlink("valid_link", link_path,
        &reparse_before);

    failures += validate("ordinary _wstat64 succeeds",
        ordinary.result == 0 && ordinary.nlink >= 1);
    failures += validate("valid link _wstat64 succeeds",
        valid_link.result == 0 && valid_link.nlink >= 1);
    failures += validate("valid link follows target nlink",
        valid_link.nlink == ordinary.nlink);
    failures += validate("valid reparse nlink is positive",
        reparse_before_ok && reparse_before >= 1);

    held_target = CreateFileW(target_path, FILE_READ_ATTRIBUTES,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
        OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    failures += validate("target held with delete sharing",
        held_target != INVALID_HANDLE_VALUE);
    if (held_target == INVALID_HANDLE_VALUE) {
        DeleteFileW(link_path);
        DeleteFileW(target_path);
        return 1;
    }
    failures += validate("target enters delete-pending",
        DeleteFileW(target_path) != 0);

    deleting_link = snapshot_wstat("delete_pending_link", link_path);
    reparse_during_ok = snapshot_reparse_nlink("delete_pending_link",
        link_path, &reparse_during);
    failures += validate("delete-pending wstat is coherent",
        (deleting_link.result == 0 && deleting_link.nlink >= 1)
            || (deleting_link.result != 0 && deleting_link.error != 0));
    failures += validate("delete-pending reparse nlink survives",
        reparse_during_ok && reparse_during == reparse_before);

    CloseHandle(held_target);
    dangling_link = snapshot_wstat("dangling_link", link_path);
    reparse_after_ok = snapshot_reparse_nlink("dangling_link", link_path,
        &reparse_after);
    failures += validate("dangling _wstat64 is coherent",
        (dangling_link.result == 0 && dangling_link.nlink >= 1)
            || (dangling_link.result != 0 && dangling_link.error == ENOENT));
    failures += validate("dangling reparse nlink survives",
        reparse_after_ok && reparse_after == reparse_before);

    DeleteFileW(link_path);
    DeleteFileW(target_path);
    printf("NLINK NATIVE SUMMARY compiler=%s failures=%d\n",
        PROBE_COMPILER, failures);
    return failures == 0 ? 0 : 1;
}
