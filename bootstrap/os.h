#include "lib.h"
#include <os/types.h>

#ifdef __linux__
#include <os/linux.h>
#elif defined(__APPLE__)
#include <os/darwin.h>
#elif defined(_WIN32)
#include <os/windows.h>
#else
#error "OS not supported"
#endif

[[noreturn]]
void exit_process(ssize code)
{
#ifdef __linux__
    syscall1(SYSCALL_EXIT_GROUP, code);
#elif defined (__APPLE__)
    exit(code);
#elif defined (_WIN32)
    ExitProcess(code);
#else
#error "OS not supported"
#endif
    UNREACHABLE;
}

ssize writeToStdoutCallback(void* context, String string)
{
    (void)context;
#if defined(__linux__) || defined(__APPLE__)
    return write(STDOUT_HANDLE, (const u8*)string.ptr, string.len);
#elif defined(_WIN32)
    HANDLE stdout_handle = GetStdHandle(STDOUT_HANDLE);
    u32 bytes_written = 0;
    if (WriteFile(stdout_handle, string.ptr, string.len, &bytes_written, NULL) != 0) {
    } else {
        enum Result error_result = GetLastError();
        (void)error_result;
        UNREACHABLE;
    }

    return bytes_written;
#else
#error "OS not supported"
#endif
}

void print(String string, ...);

[[noreturn]]
void panic(String string, ...)
{
    print(TEXT("\nPANIC: "));
    va_list va;
    va_start(va, string.ptr);
    format(stdout_writer, string, va);
    va_end(va);
    print(TEXT("\n"));
    exit_process(1);
}

OpenFlags process_open_file_flags(OpenFileFlags open_file_flags)
{
    OpenFlags flags = (OpenFlags){
        .blocking = true,
        .file = true,
    };
    flags.read = open_file_flags.read;
    flags.write = open_file_flags.write;
    flags.exclusive = open_file_flags.exclusive;
    flags.overwrite = open_file_flags.overwrite;

    return flags;
}

OpenFlags process_open_directory_flags(OpenDirectoryFlags open_directory_flags)
{
    OpenFlags flags = (OpenFlags) {
        .directory = true,
        .blocking = true,
    };

    flags.follow_symbolic_links = open_directory_flags.follow_symbolic_links;
    flags.iterable = open_directory_flags.iterable;

    return flags;
}

OpenFileResult directory_open(Directory directory, NativeString relative_path, OpenFlags flags)
{
#if defined(__linux) || defined(__APPLE__)
#if defined(__linux__)
    u32 flags = 0;
    s64 raw = syscall4(SYSCALL_OPENAT, directory.descriptor, (s64)relative_path.ptr, flags, mode);
#elif defined(__APPLE__)
    u32 flags = 0;
    s64 raw = openat(directory.descriptor, relative_path.ptr, (int)flags, mode);
#endif
    Result result = result_from_syscall(raw);
#elif defined(_WIN32)
    OpenFileResult result = windows_open_file(directory.descriptor, relative_path, flags);
    // TODO
    return result;
#endif
}

OpenFileResult directory_open_file(Directory directory, NativeString relative_path, OpenFileFlags open_file_flags)
{
}

ReadFileResult file_read(File file, String buffer)
{
#if defined(__linux__) || defined(__APPLE__)
    assert(buffer.len <= 0x7ffff000);
    s64 raw = read(file.descriptor, (const u8*)buffer.ptr, buffer.len);
    enum Result result = result_from_syscall(raw);
#elif defined(_WIN32)
    u32 bytes_written = 0;
    BOOL raw_result = ReadFile(file.descriptor, buffer.ptr, buffer.len, &bytes_written, NULL);
    // TODO
    Result result = result_from_bool(raw_result);
    // enum Result result = result_from_syscall(raw);
    u32 raw = bytes_written;
#else
#error "OS not supported"
#endif

    return (ReadFileResult) {
        .result = result,
        .read_byte_count = (usize)raw,
    };
}

Directory directory_current()
{
#if defined(__linux__) || defined(__APPLE__)
    return (Directory){
        .descriptor = FILESYSTEM_CWD,
    };
#elif defined(_WIN32)
    return (Directory) {
        .descriptor = get_teb()->ProcessEnvironmentBlock->ProcessParameters->CurrentDirectory.Handle,
    };
#else
#error "OS not supported"
#endif
}

VirtualAllocateResult virtual_allocate(usize size, ProtectionFlags protection_flags)
{
    OSProtectionFlags os_protection_flags = 0;
    Result result = SUCCESS;
#if defined(__linux__)
    if (protection_flags.read) {
        os_protection_flags |= PROTECTION_READ;
    }
    if (protection_flags.write) {
        os_protection_flags |= PROTECTION_WRITE;
    }
    if (protection_flags.execute) {
        os_protection_flags |= PROTECTION_EXECUTE;
    }
    void* raw = (void*)syscall6(SYSCALL_MMAP, 0, (ssize)size, os_protection_flags, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
#elif defined(__APPLE__)
    if (protection_flags.read) {
        os_protection_flags |= PROTECTION_READ;
    }
    if (protection_flags.write) {
        os_protection_flags |= PROTECTION_WRITE;
    }
    if (protection_flags.execute) {
        os_protection_flags |= PROTECTION_EXECUTE;
    }
    void* raw = mmap(0, size, os_protection_flags, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
#elif defined(_WIN32)

    if (protection_flags.read && protection_flags.write && protection_flags.execute) {
        os_protection_flags = PAGE_EXECUTE_READWRITE;
    } else if (protection_flags.read && protection_flags.write) {
        os_protection_flags = PAGE_READWRITE;
    }

    void* raw = VirtualAlloc(NULL, size, MEM_COMMIT | MEM_RESERVE, os_protection_flags);
#else
#error "OS not supported"
#endif
    return (VirtualAllocateResult){
        .result = result,
        .bytes = (String) {
            .ptr = raw,
            .len = size,
        },
    };
}
