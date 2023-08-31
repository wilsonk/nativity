#pragma once

#include "types.h"

#ifdef __x86_64__
#include <arch/x86_64/syscall.h>
#else
#error "Architecture not supported"
#endif

#ifdef __linux__
#include <os/linux.h>
#else
#endif

[[noreturn]]
void exit_process(ssize code)
{
#ifdef __linux__
    syscall1(SYSCALL_EXIT_GROUP, code);
#else
#error "OS not supported"
#endif
    UNREACHABLE;
}

void print(struct String string)
{
#ifdef __linux__
    write(STDOUT_HANDLE, string);
#else
#error "OS not supported"
#endif
}

[[noreturn]]
void panic(struct String string)
{
    print(string);
    exit_process(1);
}

#define assert(COND) if (!(COND)) { \
    panic(STR("Assert failed!")); \
}

struct Directory {
#ifdef __linux__
    FileDescriptor descriptor;
#else
#error "OS not supported"
#endif
};

struct File {
#ifdef __linux__
    FileDescriptor descriptor;
#else
#error "OS not supported"
#endif
};

DECL_RESULT(OpenFile, struct File, file);

struct OpenFileResult directory_open_file(struct Directory directory, const char* relative_path, u32 flags, u32 mode)
{
#ifdef __linux__
    s64 raw = syscall4(SYSCALL_OPENAT, directory.descriptor, (s64)relative_path, flags, mode);
    enum Result result = result_from_errno(raw);
    bool is_success = result == SUCCESS;

    if (is_success) {
        return (struct OpenFileResult){
            .is_success = is_success,
            .file = (struct File) {
                .descriptor = (FileDescriptor)raw,
            },
        };
    } else {
        return (struct OpenFileResult){
            .is_success = is_success,
            .result = result,
        };
    }
#else
#error "OS not supported"
#endif
}

DECL_RESULT(ReadFile, usize, read_byte_count);

struct ReadFileResult file_read_to_buffer(struct File file, struct String buffer)
{
    assert(buffer.len <= 0x7ffff000);
    s64 raw = read(file.descriptor, buffer);
    enum Result result = result_from_errno(raw);
    bool is_success = result == SUCCESS;
    if (is_success)
    {
        return (struct ReadFileResult) {
            .is_success = is_success,
            .read_byte_count = (usize)raw,
        };
    }
    else
    {
        return (struct ReadFileResult){
            .is_success = is_success,
            .result = result,
        };
    }
}

struct Directory directory_current()
{
#ifdef __linux__
    return (struct Directory){
        .descriptor = FILESYSTEM_CWD,
    };
#else
#error "OS not supported"
#endif
}

DECL_RESULT(VirtualAllocate, struct String, bytes);

struct VirtualAllocateResult virtual_allocate(usize size, enum ProtectionFlags protection_flags, enum MapFlags map_flags)
{
    ssize raw = syscall6(SYSCALL_MMAP, 0, (ssize)size, protection_flags, map_flags, -1, 0);
    enum Result result = result_from_errno(raw);
    bool is_success = result == SUCCESS;
    if (is_success)
    {
        return (struct VirtualAllocateResult){
            .is_success = is_success,
            .bytes = (struct String) {
                .ptr = (char*)raw,
                .len = size,
            },
        };
    }
    else
    {
        return (struct VirtualAllocateResult){
            .is_success = is_success,
            .result = result,
        };
    }
}
