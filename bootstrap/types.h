#pragma once

#include <stdarg.h>

#define NULL (void*)0

#define PRIVATE static
#define UNREACHABLE __builtin_unreachable()
#define EXPECT(EXPR, RESULT) __builtin_expect((EXPR), (RESULT))

#ifdef __linux__
#ifdef __x86_64__
typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long u64;
static_assert(sizeof(u8) == 1);
static_assert(sizeof(u16) == 2);
static_assert(sizeof(u32) == 4);
static_assert(sizeof(u64) == 8);

typedef signed char s8;
typedef signed short s16;
typedef signed int s32;
typedef signed long s64;
static_assert(sizeof(s8) == 1);
static_assert(sizeof(s16) == 2);
static_assert(sizeof(s32) == 4);
static_assert(sizeof(s64) == 8);

typedef u64 usize;
typedef s64 ssize;

typedef float f32;
typedef double f64;
#else
#pragma error "Unsupported architecture"
#endif
#elif defined(__APPLE__)
typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long u64;
static_assert(sizeof(u8) == 1);
static_assert(sizeof(u16) == 2);
static_assert(sizeof(u32) == 4);
static_assert(sizeof(u64) == 8);

typedef signed char s8;
typedef signed short s16;
typedef signed int s32;
typedef signed long s64;
static_assert(sizeof(s8) == 1);
static_assert(sizeof(s16) == 2);
static_assert(sizeof(s32) == 4);
static_assert(sizeof(s64) == 8);

typedef u64 usize;
typedef s64 ssize;

typedef float f32;
typedef double f64;
#elif defined(_WIN32)
typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long long u64;
static_assert(sizeof(u8) == 1);
static_assert(sizeof(u16) == 2);
static_assert(sizeof(u32) == 4);
static_assert(sizeof(u64) == 8);

typedef signed char s8;
typedef signed short s16;
typedef signed int s32;
typedef signed long long s64;
static_assert(sizeof(s8) == 1);
static_assert(sizeof(s16) == 2);
static_assert(sizeof(s32) == 4);
static_assert(sizeof(s64) == 8);

typedef u64 usize;
typedef s64 ssize;

typedef float f32;
typedef double f64;
#else
#error "Unsupported operating system
#endif

typedef struct 
{
    char* ptr;
    usize len;
} String;

typedef struct {
    usize value;
    bool valid;
}OptionalIndex;

// decrement to discard null byte
#define TEXT(S) (String) \
{ \
    .ptr = (S), \
    .len = sizeof((S)) - 1, \
}

#define FROM_STR(S) (S).ptr, (S).len

#define STRVIEW(S) (S), sizeof((S))

#define assert(COND) if (!(COND)) { \
    panic(TEXT("Assert failed!")); \
}

typedef ssize WriterCallback(void* context, String string);
typedef struct {
    WriterCallback* callback;
    void* context;
}Writer;
ssize writeToStdoutCallback(void* context, String string);

void format(Writer writer, String string, va_list va);
[[noreturn]] void panic(String string, ...);

Writer stdout_writer = (Writer) {
    .callback = writeToStdoutCallback,
};


usize cstr_len(char* raw) {
    char* ptr = raw;

    while (*raw != '\0') {
        raw += 1;
    }

    usize len = (usize)(raw - ptr);

    return len;
}

String string_slice_from_raw(char* raw) {
    usize len = cstr_len(raw);
    return (String) {
        .ptr = raw,
        .len = len,
    };
}

String string_slice_from_ptr(char* raw, usize start, usize end) {
    char* ptr = raw + start;
    usize len = end - start;
    return (String) {
        .ptr = ptr,
        .len = len,
    };
}

String string_slice(String string, usize start, usize end) {
    assert(start <= end);
    assert(end <= string.len);
    return string_slice_from_ptr(string.ptr, start, end);
}

bool string_equal(String string, String other) {
    usize len = other.len;

    if (string.len >= len) {
        String slice = string_slice(string, 0, len);
        for (usize i = 0; i < len; i += 1)
        {
            if (slice.ptr[i] != other.ptr[i]) {
                return false;
            }
        }

        return true;
    } else {
        return false;
    }

}

usize string_index_of(String string, char byte) {
    usize i;
    for (i = 0; i < string.len; i += 1) {
        char ch = string.ptr[i];
        if (ch == byte) {
            return i;
        }
    }

    return i;
}

void write_all(Writer writer, String string)
{
    usize written_bytes = 0;
    while (written_bytes < string.len) { 
        String slice = string_slice(string, written_bytes, string.len);
        ssize result = writer.callback(writer.context, slice);
        usize iteration_written_bytes = (usize)result;
        written_bytes += iteration_written_bytes;
    }
}
