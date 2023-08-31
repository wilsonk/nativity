#pragma once

#define PRIVATE static
#define UNREACHABLE __builtin_unreachable()
#define EXPECT(EXPR, RESULT) __builtin_expect((EXPR), (RESULT))

#ifdef __linux__
#ifdef __x86_64__
typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long u64;

typedef signed char s8;
typedef signed short s16;
typedef signed int s32;
typedef signed long s64;

typedef u64 usize;
typedef s64 ssize;

typedef float f32;
typedef double f64;
#else
#pragma error "Unsupported architecture"
#endif
#else
#pragma error "Unsupported operating system
#endif

struct String \
{ \
    char* ptr; \
    usize len; \
};

#define STR(S) (struct String) \
{ \
    .ptr = (S), \
    .len = sizeof((S)), \
}

#define FROM_STR(S) (S).ptr, (S).len

#define STRVIEW(S) (S), sizeof((S))
