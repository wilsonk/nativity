#ifdef _WIN32
typedef u16 NativeChar;
typedef struct {
    NativeChar* ptr;
    usize len;
} NativeString;
#define NATIVE_TEXT(STR)
#else
typedef char NativeChar;
typedef String NativeString;
#define NATIVE_TEXT(STR) TEXT(STR)
#endif

#if defined(__linux__) || defined(__APPLE__)
typedef s32 FileDescriptor;
#elif defined(_WIN32)
typedef void* FileDescriptor;
#else
#error "OS not supported
#endif

typedef struct {
    FileDescriptor descriptor;
}Directory ;

typedef struct {
    FileDescriptor descriptor;
} File;

#if defined(__linux__)
#include <os/linux/types.h>
#elif defined(__APPLE__)
#include <os/macos/types.h>
#elif defined(_WIN32)
#include <os/windows/types.h>
#else
#error "OS not supported"
#endif

typedef struct ProtectionFlags{
    u32 read: 1;
    u32 write: 1;
    u32 execute: 1;
}ProtectionFlags;

typedef struct {
    u32 read: 1;
    u32 write: 1;
    u32 exclusive: 1;
    u32 follow_symbolic_links: 1;
    u32 directory: 1;
    u32 file: 1;
    u32 blocking: 1;
    u32 iterable: 1;
    u32 overwrite: 1;
} OpenFlags;

typedef struct {
    u32 read: 1;
    u32 write: 1;
    u32 exclusive: 1;
    u32 overwrite: 1;
} OpenFileFlags;

typedef struct {
    u32 follow_symbolic_links: 1;
    u32 iterable: 1;
} OpenDirectoryFlags;

#if _WIN32
typedef NTSTATUS OpenResultCode;
#else
typedef Result OpenResultCode;
#endif

typedef struct {
    FileDescriptor descriptor;
    OpenResultCode code;
} OpenResult;

typedef struct {
    File file;
    OpenResultCode code;
} OpenFileResult;

typedef struct {
    Directory directory;
    OpenResultCode code;
}OpenDirectoryResult;

DECL_RESULT(ReadFile, usize, read_byte_count);
DECL_RESULT(VirtualAllocate, String, bytes);
