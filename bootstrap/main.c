#include "lib.h"


typedef enum{
    CPU_ARCH_X86_64 = 0,
    CPU_ARCH_AARCH64 = 1,
} CPU;

typedef enum{
    OS_LINUX = 0,
    OS_MACOS = 1,
    OS_WINDOWS = 2,
} OS;

void format_os(Writer writer, String format_string_content, va_list va) {
    (void)format_string_content;
    OS os = va_arg(va, OS);
    switch (os) {
        case OS_LINUX:
            {
                write_all(writer, TEXT("linux"));
            } break;
        case OS_MACOS:
            {
                write_all(writer, TEXT("macos"));
            } break;
        case OS_WINDOWS:
            {
                write_all(writer, TEXT("windows"));
            } break;
        default:
        {
            write_all(writer, TEXT("Unknown enum type"));
        } break;
    };
}


typedef enum{
    ABI_NONE = 0,
    ABI_GNU = 1,
    ABI_MSVC = 2,
} ABI;

typedef struct {
    CPU cpu;
    OS os;
    ABI abi;
}Target;

typedef struct {
    Target target;
    String executable_path;
    String main_package_path;
} CompilationDescriptor;

void compile_module(CompilationDescriptor descriptor)
{
    String builtin_file_name = TEXT("builtin.nat");
}

int main(int argc, char** argv)
{
    print(TEXT("Argument count: {s32:x}\n"), argc);

    OptionalString maybe_executable_path = {};
    OptionalString maybe_main_package_path = {};
    String target_triplet = TEXT(CURRENT_TARGET_TRIPLET);
    print(TEXT("Current target triplet: {str}\n"), target_triplet);

    if (!heap_initialize()) {
        return -1;
    }

    for (int i = 1; i < argc; i += 1) {
        String arg = string_slice_from_raw(argv[i]);

        if (string_equal(arg, TEXT("-o"))) {
            if (i <= argc) {
                String executable_path = string_slice_from_raw(argv[i + 1]);
                assert(executable_path.len > 0);
                maybe_executable_path.value = executable_path;
                maybe_executable_path.valid = true;
                i += 1;
            } else {
                UNREACHABLE;
            }
        } else if (string_equal(arg, TEXT("-target"))) {
            if (i <= argc) {
                target_triplet = string_slice_from_raw(argv[i + 1]);
                assert(target_triplet.len > 0);
                i += 1;
            } else {
                UNREACHABLE;
            }
        } else {
            maybe_main_package_path.value = arg;
            maybe_main_package_path.valid = true;
        }
    }

    if (!maybe_main_package_path.valid) {
        panic(TEXT("Main package path not found"));
    }

    if (!maybe_executable_path.valid) {
        String main_package_path = maybe_main_package_path.value;
        String basename_of = string_slice(main_package_path, 0, main_package_path.len - TEXT("/main.nat").len);
        String executable_name = path_basename(basename_of);
        print(TEXT("Main package path: {str}\n"), main_package_path);
        print(TEXT("Basename of: {str}\n"), basename_of);
        print(TEXT("Executable name: {str}\n"), executable_name);

        String executable_path = string_concat(TEXT("nat/"), executable_name);
        print(TEXT("Executable path: {str}\n"), executable_path);
        maybe_main_package_path.value = executable_path;
        maybe_main_package_path.valid = true;
    }

    CPU cpu;
    OS os;
    ABI abi;

    usize first_dash_index = string_index_of(target_triplet, '-');
    if (first_dash_index == target_triplet.len) {
        return -1;
    }

    String cpu_string = string_slice(target_triplet, 0, first_dash_index);

    String it = string_slice(target_triplet, first_dash_index + 1, target_triplet.len);
    usize second_dash_index = string_index_of(it, '-');
    if (second_dash_index == it.len) {
        return -1;
    }

    String os_string = string_slice(it, 0, second_dash_index);

    String abi_string = string_slice(it, second_dash_index + 1, it.len);

    if (string_equal(cpu_string, TEXT("x86_64"))) {
        cpu = CPU_ARCH_X86_64;
    } else if (string_equal(cpu_string, TEXT("aarch64"))) {
        cpu = CPU_ARCH_AARCH64;
    } else {
        return -1;
    }

    if (string_equal(os_string, TEXT("linux"))) {
        os = OS_LINUX;
    } else if (string_equal(os_string, TEXT("macos"))) {
        os = OS_MACOS;
    } else if (string_equal(os_string, TEXT("windows"))) {
        os = OS_WINDOWS;
    } else {
        return -1;
    }

    if (string_equal(abi_string, TEXT("none"))) {
        abi = ABI_NONE;
    } else if (string_equal(abi_string, TEXT("gnu"))) {
        abi = ABI_GNU;
    } else if (string_equal(abi_string, TEXT("msvc"))) {
        abi = ABI_MSVC;
    } else {
        return -1;
    }

    print(TEXT("OS: {os}\n"), os);
    (void)cpu;
    (void)abi;

    Target target = (Target) {
        .cpu = cpu,
            .os = os,
            .abi = abi,
    };

    return 0;
}

FormatterDescriptor formatters[] = {
    [0] = (FormatterDescriptor) {
        .string = TEXT("os"),
        .callback = format_os,
    },
};

usize formatter_count = STATIC_ARRAY_LEN(formatters);
