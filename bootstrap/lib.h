#pragma once

#include "types.h"

#ifdef __x86_64__
#include <arch/x86_64/syscall.h>
#elif __ARM64_ARCH_8__
#else
#error "Architecture not supported"
#endif

#ifdef __x86_64__
#define CURRENT_ARCH "x86_64"
#elif __ARM64_ARCH_8__
#define CURRENT_ARCH "aarch64"
#else
#error "Arch not supported"
#endif


#ifdef __linux__
#define CURRENT_OS "linux"
#define CURRENT_ABI "gnu"
#elif defined(__APPLE__)
#define CURRENT_OS "macos"
#define CURRENT_ABI "none"
#elif defined(_WIN32)
#define CURRENT_OS "windows"
#define CURRENT_ABI "msvc"
#else
#error "OS not supported"
#endif

#define STATIC_ARRAY_LEN(x) (sizeof(x) / sizeof(x[0]))

#define CURRENT_TARGET_TRIPLET CURRENT_ARCH "-" CURRENT_OS "-" CURRENT_ABI

#define DECL_RESULT(NAME, T, T_NAME) typedef struct { \
        T T_NAME; \
        Result result; \
} NAME ## Result

#include <os.h>

typedef void FormatFunction(Writer writer, String format_string, va_list va);
typedef struct {
    String string;
    FormatFunction* callback;
}FormatterDescriptor;

extern FormatterDescriptor formatters[];
extern usize formatter_count;

enum IntegerFormatType{
    INTEGER_FORMAT_TYPE_HEXADECIMAL = 0,
    INTEGER_FORMAT_TYPE_DECIMAL = 1,
    INTEGER_FORMAT_TYPE_BINARY = 2,
};

enum IntegerFormatType get_integer_format_type(String format_content_string, String type_name, enum IntegerFormatType preferred_format_type)
{
    enum IntegerFormatType result = preferred_format_type;

    if (format_content_string.ptr[type_name.len] == ':') {
        String integer_format_type_string = string_slice(format_content_string, type_name.len + 1, format_content_string.len);
        if (string_equal(integer_format_type_string, TEXT("x"))) {
            result = INTEGER_FORMAT_TYPE_HEXADECIMAL;
        } else if (string_equal(integer_format_type_string, TEXT("d"))) {
            result = INTEGER_FORMAT_TYPE_DECIMAL;
        } else if (string_equal(integer_format_type_string, TEXT("b"))) {
            result = INTEGER_FORMAT_TYPE_BINARY;
        } else {
            UNREACHABLE;
        }
    }

    return result;
}

void format(Writer writer, String string, va_list va)
{
    usize i = 0;
    const char* str = string.ptr;
    while (i < string.len) {
        usize start = i;
        bool is_start_format_character = false;

        while (i < string.len) {
            is_start_format_character = str[i] == '{';
            i += !is_start_format_character;
            if (is_start_format_character) {
                break;
            }
        }

        usize end = i;
        write_all(writer, string_slice(string, start, end));

        if (is_start_format_character) {
            if (i > 0) {
                if (str[i - 1] == '\\') {
                    write_all(writer, TEXT("AAAAA\n"));
                    UNREACHABLE;
                }
            }

            usize format_start = i;
            i += 1;
            
            bool is_end_format_character = false;
            while (i < string.len) {
                is_end_format_character = str[i] == '}';
                i += !is_end_format_character;
                if (is_end_format_character) {
                    break;
                }
            }

            if (is_end_format_character) {
                usize format_content_start = format_start + 1;
                usize format_content_end = i;
                i += 1;

                String format_content_string = string_slice(string, format_content_start, format_content_end);
                char buffer[128];
                usize i = sizeof(buffer);

                if (string_equal(format_content_string, TEXT("s32"))) {
                    s32 integer = va_arg(va, s32);
                    
                    enum IntegerFormatType format_type = get_integer_format_type(format_content_string, TEXT("s32"), INTEGER_FORMAT_TYPE_DECIMAL);
                    switch (format_type) {
                        case INTEGER_FORMAT_TYPE_DECIMAL:
                            {
                    write_all(writer, TEXT("D\n"));
                                UNREACHABLE;
                            } break;
                        case INTEGER_FORMAT_TYPE_HEXADECIMAL:
                            {
                                s32 it = integer;
                                while (true) {
                                    s32 digit = it % 16;
                                    i -= 1;
                                    char ch = digit + '0';
                                    buffer[i] = ch;
                                    it /= 16;
                                    if (it == 0) break;
                                }
                            } break;
                        case INTEGER_FORMAT_TYPE_BINARY:
                            {
                    write_all(writer, TEXT("B\n"));
                                UNREACHABLE;
                            } break;
                        default:
                        {
                            UNREACHABLE;
                        } break;
                    }
                String buf_slice = string_slice_from_ptr(buffer, i, sizeof(buffer));
                write_all(writer, buf_slice);
                } else if (string_equal(format_content_string, TEXT("cstr"))) {
                    char* cstr = va_arg(va, char*);
                    write_all(writer, string_slice_from_raw(cstr));
                } else if (string_equal(format_content_string, TEXT("p"))) {
                    void* ptr = va_arg(va, void*);
                    u64 integer = (u64)ptr;
                    u64 it = integer;

                    while (true) {
                        u64 digit = it % 16;
                        i -= 1;
                        // TODO: fix for hex
                        char ch = digit + '0';
                        buffer[i] = ch;
                        it /= 16;
                        if (it == 0) break;
                    }

                    buffer[--i] = 'x';
                    buffer[--i] = '0';

                    String buf_slice = string_slice_from_ptr(buffer, i, sizeof(buffer));
                    write_all(writer, buf_slice);
                } else if (string_equal(format_content_string, TEXT("str"))) {
                    String string = va_arg(va, String);
                    write_all(writer, string);
                } else {
                    bool found_format = false;
                    for (usize i = 0; i < formatter_count; i += 1) {
                        FormatterDescriptor* descriptor = &formatters[i];
                        if (string_equal(format_content_string, descriptor->string)) {
                            descriptor->callback(writer, format_content_string, va);
                            found_format = true;
                            break;
                        }
                    }

                    if (!found_format) {
                        write_all(writer, TEXT("Formatter could not be located\n"));
                        UNREACHABLE;
                    }
                }
            } else {
                write_all(writer, TEXT("2U\n"));
                UNREACHABLE;
            }
        }
    }
}

void print(String string, ...)
{
    va_list va;
    va_start(va, string.ptr);
    format(stdout_writer, string, va);
    va_end(va);
}

typedef struct {
    String value;
    bool valid;
} OptionalString;

String path_basename(String path) {
    int i = path.len - 1;
    while (i >= 0)
    {
        char ch = path.ptr[i];
        if (ch == '/') {
            if ((usize)i == path.len) {
                return (String){
                    .ptr = path.ptr + path.len,
                    .len = 0,
                };
            } else {
                return (String){
                    .ptr = path.ptr + i + 1,
                    .len = path.len - (usize)(i + 1),
                };
            }
        }

        i -= 1;
    }

    return path;
}

typedef struct {
    String bytes;
    usize allocated;
    bool initialized;
} Heap;

Heap heap;

bool heap_initialize()
{
    VirtualAllocateResult result = virtual_allocate(50*1024*1024, (ProtectionFlags){
            .read = true,
            .write = true,
            .execute = false,
            });

    if (result.result != SUCCESS) {
        return false;
    }

    String bytes = result.bytes;
    heap.bytes = bytes;
    heap.initialized = true;

    return true;
}
bool is_alignment_correct(usize alignment)
{
    return alignment == 1 || (alignment & 1) == 0;
}


usize align_forward(usize n, usize alignment)
{
    assert(is_alignment_correct(alignment));
    usize mask = alignment - 1;
    usize result = (n + mask) & ~mask;

    return result;
}

usize align_backward(usize n, usize alignment)
{
    assert(is_alignment_correct(alignment));
    usize mask = alignment - 1;
    usize result = n & ~mask;
    return result;
}

String heap_allocate(usize size, usize alignment)
{
    assert(heap.allocated < heap.bytes.len);

    heap.allocated = align_forward(heap.allocated, alignment);
    char* ptr = heap.bytes.ptr + heap.allocated;
    heap.allocated += size;
    assert(heap.allocated <= heap.bytes.len);

    return (String) {
        .ptr = ptr,
        .len = size,
    };
}

String string_concat(String a, String b) {
    usize len = a.len + b.len;
    String new_string = heap_allocate(len, 1);
    usize dst = 0;

    for (usize src = 0; src < a.len; src += 1, dst += 1)
    {
        new_string.ptr[dst] = a.ptr[src];
    }

    for (usize src = 0; src < b.len; src += 1, dst += 1)
    {
        new_string.ptr[dst] = b.ptr[src];
    }

    return new_string;
}
