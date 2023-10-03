#include <lib.h>

extern s32 errno;

enum STDOUT {
    STDOUT_HANDLE = 1,
};

typedef enum ProtectionFlags {
    PROTECTION_NONE = 0x0,
    PROTECTION_READ = 0x1,
    PROTECTION_WRITE = 0x2,
    PROTECTION_EXECUTE = 0x4,
    PROTECTION_COPY = 0x10,
}OSProtectionFlags ;

typedef enum MapFlags {
    MAP_SHARED = 0x1,
    MAP_PRIVATE = 0x2,
    MAP_FIXED = 0x10,
    MAP_ANONYMOUS = 0x1000,
}MapFlags ;

[[noreturn]] extern void exit(s32 code);

extern ssize write(FileDescriptor descriptor, const void* bytes, usize len);
extern ssize read(FileDescriptor descriptor, const void* bytes, usize len);

     extern void * mmap(void *addr, usize len, int prot, int flags, int fd, ssize offset);


[[gnu::always_inline]]
PRIVATE enum Result result_from_syscall(s64 syscall_result) {
    if (syscall_result == -1) {
        return (enum Result) errno;
    } else {
        return SUCCESS;
    }
}

extern int openat(FileDescriptor file_descriptor, const char* path, int oflag, ...);

enum AT{
    FILESYSTEM_CWD = -2,
};
