#include <lib.h>

[[noreturn]]
void _start()
{
    print(STR("Hello world\n"));
    struct OpenFileResult result = directory_open_file(directory_current(), "build.zig", 0, 0);
    if (result.is_success)
    {
        print(STR("SUCCESS\n"));
        char buffer[50];
        struct ReadFileResult read_file_result = file_read_to_buffer(result.file, STR(buffer));
        if (read_file_result.is_success) {
            print(STR("FILE READ SUCCESS\n"));

            struct VirtualAllocateResult virtual_allocate_result = virtual_allocate(0x1000, PROTECTION_READ | PROTECTION_WRITE, MAP_ANONYMOUS | MAP_PRIVATE);
            if (virtual_allocate_result.is_success)
            {
                print(STR("VA OK\n"));
            }
            else
            {
                print(STR("VA KO\n"));
            }
        } else {
            print(STR("FILE READ FAILURE\n"));
        }
    }
    else
    {
        print(STR("FAILURE\n"));
    }
    exit_process(0);
}
