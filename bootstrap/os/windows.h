#pragma once 

#include "lib.h"
typedef void* HANDLE;
typedef HANDLE HMODULE;
typedef int BOOL;
typedef u32 ACCESS_MASK;
typedef unsigned long ULONG;
typedef u16 WCHAR;
typedef void* PVOID;
typedef u8 BYTE;
typedef BYTE BOOLEAN;
typedef unsigned char UCHAR;
typedef unsigned short WORD;
typedef unsigned DWORD;
typedef long LONG;
typedef usize ULONG_PTR ;
typedef HANDLE RTL_BITMAP;
typedef s64 LARGE_INTEGER;
typedef unsigned short USHORT;
typedef usize KAFFINITY;
typedef u64 ULARGE_INTEGER;
typedef void* ACTIVATION_CONTEXT_DATA;
typedef void* ASSEMBLY_STORAGE_MAP;
typedef void* FLS_CALLBACK_INFO;
typedef unsigned long long ULONGLONG;


u32 STDOUT_HANDLE = (u32)-11;
#define WINAPI __stdcall
#define WINBASEAPI __declspec(dllimport)

[[noreturn]]
WINBASEAPI WINAPI
void ExitProcess(u32 code);

WINBASEAPI WINAPI HANDLE GetStdHandle(u32 handle);

WINBASEAPI WINAPI BOOL WriteFile(FileDescriptor file_descriptor, const void* buffer, u32 number_of_bytes_to_write, u32* number_of_bytes_written, void* overlapped);
WINBASEAPI WINAPI BOOL ReadFile(FileDescriptor file_descriptor, const void* buffer, u32 number_of_bytes_to_read, u32* number_of_bytes_read, void* overlapped);

extern WINBASEAPI WINAPI Result GetLastError();

typedef struct {
    u16 Length;
    u16 MaximumLength;
    WCHAR* Buffer;
} UNICODE_STRING;

typedef struct {
    ULONG Length;
    HANDLE RootDirectory;
    UNICODE_STRING* ObjectName;
    ULONG Attributes;
    void* SecurityDescriptor;
    void* SecurityQualityOfService;
}OBJECT_ATTRIBUTES ;

typedef struct {
    union{
        NTSTATUS Status;
        void* Pointer;
    };
    usize Information;
} IO_STATUS_BLOCK;

WINBASEAPI WINAPI NTSTATUS NtCreateFile(HANDLE* pointer_to_file_handle, ACCESS_MASK access_mask, OBJECT_ATTRIBUTES* object_attributes, IO_STATUS_BLOCK* io_status_block, s64* allocation_size, ULONG file_attributes, ULONG shared_access, ULONG create_disposition, ULONG create_options, void* ea_buffer, ULONG e_length);

UNICODE_STRING unicode_string_from_native_string(NativeString string)
{
    u16 length = string.len * sizeof(u16);
    return (UNICODE_STRING) {
        .Length = length,
        .MaximumLength = length,
        .Buffer = string.ptr,
    };
}

#define GENERIC_READ (0x80000000)
#define GENERIC_WRITE (0x40000000)
#define GENERIC_EXECUTE (0x20000000)
#define GENERIC_ALL (0x10000000)

#define FILE_SHARE_DELETE (0x00000004)
#define FILE_SHARE_READ (0x00000001)
#define FILE_SHARE_WRITE (0x00000002)

#define DELETE (0x00010000)
#define READ_CONTROL (0x00020000)
#define WRITE_DAC (0x00040000)
#define WRITE_OWNER (0x00080000)
#define SYNCHRONIZE (0x00100000);
#define STANDARD_RIGHTS_READ (READ_CONTROL)
#define STANDARD_RIGHTS_WRITE (READ_CONTROL)
#define STANDARD_RIGHTS_EXECUTE (READ_CONTROL)
#define STANDARD_RIGHTS_REQUIRED (DELETE | READ_CONTROL | WRITE_DAC | WRITE_OWNER)
#define MAXIMUM_ALLOWED (0x02000000)
#define FILE_SUPERSEDE (0)
#define FILE_OPEN (1)
#define FILE_CREATE (2)
#define FILE_OPEN_IF (3)
#define FILE_OVERWRITE (4)
#define FILE_OVERWRITE_IF (5)
#define FILE_MAXIMUM_DISPOSITION (5)


#define FILE_READ_DATA (0x00000001)
#define FILE_LIST_DIRECTORY (0x00000001)
#define FILE_WRITE_DATA (0x00000002)
#define FILE_ADD_FILE (0x00000002)
#define FILE_APPEND_DATA (0x00000004)
#define FILE_ADD_SUBDIRECTORY (0x00000004)
#define FILE_CREATE_PIPE_INSTANCE (0x00000004)
#define FILE_READ_EA (0x00000008)
#define FILE_WRITE_EA (0x00000010)
#define FILE_EXECUTE (0x00000020)
#define FILE_TRAVERSE (0x00000020)
#define FILE_DELETE_CHILD (0x00000040)
#define FILE_READ_ATTRIBUTES (0x00000080)
#define FILE_WRITE_ATTRIBUTES (0x00000100)

#define FILE_DIRECTORY_FILE (0x00000001)
#define FILE_WRITE_THROUGH (0x00000002)
#define FILE_SEQUENTIAL_ONLY (0x00000004)
#define FILE_NO_INTERMEDIATE_BUFFERING (0x00000008)
#define FILE_SYNCHRONOUS_IO_ALERT (0x00000010)
#define FILE_SYNCHRONOUS_IO_NONALERT (0x00000020)
#define FILE_NON_DIRECTORY_FILE (0x00000040)
#define FILE_CREATE_TREE_CONNECTION (0x00000080)
#define FILE_COMPLETE_IF_OPLOCKED (0x00000100)
#define FILE_NO_EA_KNOWLEDGE (0x00000200)
#define FILE_OPEN_FOR_RECOVERY (0x00000400)
#define FILE_RANDOM_ACCESS (0x00000800)
#define FILE_DELETE_ON_CLOSE (0x00001000)
#define FILE_OPEN_BY_FILE_ID (0x00002000)
#define FILE_OPEN_FOR_BACKUP_INTENT (0x00004000)
#define FILE_NO_COMPRESSION (0x00008000)
#define FILE_RESERVE_OPFILTER (0x00100000)
#define FILE_OPEN_REPARSE_POINT (0x00200000)
#define FILE_OPEN_OFFLINE_FILE (0x00400000)
#define FILE_OPEN_FOR_FREE_SPACE_QUERY (0x00800000)

#define CREATE_ALWAYS (2)
#define CREATE_NEW (1)
#define OPEN_ALWAYS (4)
#define OPEN_EXISTING (3)
#define TRUNCATE_EXISTING (5)

#define FILE_ATTRIBUTE_ARCHIVE (0x20)
#define FILE_ATTRIBUTE_COMPRESSED (0x800)
#define FILE_ATTRIBUTE_DEVICE (0x40)
#define FILE_ATTRIBUTE_DIRECTORY (0x10)
#define FILE_ATTRIBUTE_ENCRYPTED (0x4000)
#define FILE_ATTRIBUTE_HIDDEN (0x2)
#define FILE_ATTRIBUTE_INTEGRITY_STREAM (0x8000)
#define FILE_ATTRIBUTE_NORMAL (0x80)
#define FILE_ATTRIBUTE_NOT_CONTENT_INDEXED (0x2000)
#define FILE_ATTRIBUTE_NO_SCRUB_DATA (0x20000)
#define FILE_ATTRIBUTE_OFFLINE (0x1000)
#define FILE_ATTRIBUTE_READONLY (0x1)
#define FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS (0x400000)
#define FILE_ATTRIBUTE_RECALL_ON_OPEN (0x40000)
#define FILE_ATTRIBUTE_REPARSE_POINT (0x400)
#define FILE_ATTRIBUTE_SPARSE_FILE (0x200)
#define FILE_ATTRIBUTE_SYSTEM (0x4)
#define FILE_ATTRIBUTE_TEMPORARY (0x100)
#define FILE_ATTRIBUTE_VIRTUAL (0x10000)

OpenFileResult windows_open(HANDLE directory, NativeString sub_path, OpenFlags general_flags)
{
    UNICODE_STRING nt_subpath = unicode_string_from_native_string(sub_path);
    OBJECT_ATTRIBUTES object_attributes = (OBJECT_ATTRIBUTES) {
        .Length = sizeof(OBJECT_ATTRIBUTES),
        .RootDirectory = directory,
        .Attributes = 0,
        .ObjectName = &nt_subpath,
        .SecurityDescriptor = NULL,
        .SecurityQualityOfService = NULL,
    };

    HANDLE result = NULL;
    ACCESS_MASK access_mask = READ_CONTROL | FILE_WRITE_ATTRIBUTES | SYNCHRONIZE;
    if (general_flags.read) {
        access_mask |= GENERIC_READ;
    }

    if (general_flags.write) {
        access_mask |= GENERIC_WRITE;
    }

    // Is this wise?
    ULONG share_access = FILE_SHARE_WRITE | FILE_SHARE_DELETE | FILE_SHARE_READ;
    ULONG creation;
    if (general_flags.exclusive) {
        creation = FILE_CREATE;
    } else {
        creation = FILE_OPEN;
    }

    ULONG flags = 0;
    if (!(general_flags.directory && general_flags.file)) {
        if (general_flags.file) {
            flags = FILE_NON_DIRECTORY_FILE;
        } else if (general_flags.directory) {
            flags = FILE_DIRECTORY_FILE;
        }
    }

    if (general_flags.follow_symbolic_links) {
        if (general_flags.blocking) {
            flags |= FILE_SYNCHRONOUS_IO_NONALERT;
        }
    } else {
        flags |= FILE_OPEN_REPARSE_POINT;
    }

    IO_STATUS_BLOCK io_status_block;
    NTSTATUS status = NtCreateFile(&result, access_mask, &object_attributes, &io_status_block, NULL, FILE_ATTRIBUTE_NORMAL, share_access, creation, flags, NULL, 0);

    return (OpenFileResult){
        .file = result,
        .result = status,
    };
}

typedef struct LIST_ENTRY {
    struct LIST_ENTRY* Flink;
    struct LIST_ENTRY* Blink;
} LIST_ENTRY;

typedef struct {
    UNICODE_STRING DosPath;
    HANDLE Handle;
} CURDIR;

typedef struct {
    unsigned short Flags;
    unsigned short Length;
    ULONG TimeStamp;
    UNICODE_STRING DosPath;
}RTL_DRIVE_LETTER_CURDIR ;

typedef struct {
    WORD Type;
    WORD CreatorBackTraceIndex;
    struct RTL_CRITICAL_SECTION* CriticalSection;
    LIST_ENTRY ProcessLocksList;
    DWORD EntryCount;
    DWORD ContentionCount;
    DWORD Flags;
    WORD CreatorBackTraceIndexHigh;
    WORD SpareWORD;
}RTL_CRITICAL_SECTION_DEBUG;

typedef struct RTL_CRITICAL_SECTION {
    RTL_CRITICAL_SECTION_DEBUG* DebugInfo;
    LONG LockCount;
    LONG RecursionCount;
    HANDLE OwningThread;
    HANDLE LockSemaphore;
    ULONG_PTR SpinCount;
}RTL_CRITICAL_SECTION;

typedef struct {
    ULONG AllocationSize;
    ULONG Size;
    ULONG Flags;
    ULONG DebugFlags;
    HANDLE ConsoleHandle;
    ULONG ConsoleFlags;
    HANDLE hStdInput;
    HANDLE hStdOutput;
    HANDLE hStdError;
    CURDIR CurrentDirectory;
    UNICODE_STRING DllPath;
    UNICODE_STRING ImagePathName;
    UNICODE_STRING CommandLine;
    WCHAR* Environment;
    ULONG dwX;
    ULONG dwY;
    ULONG dwXSize;
    ULONG dwYSize;
    ULONG dwXCountChars;
    ULONG dwYCountChars;
    ULONG dwFillAttribute;
    ULONG dwFlags;
    ULONG dwShowWindow;
    UNICODE_STRING WindowTitle;
    UNICODE_STRING Desktop;
    UNICODE_STRING ShellInfo;
    UNICODE_STRING RuntimeInfo;
    RTL_DRIVE_LETTER_CURDIR DLCurrentDirectory[0x20];
}RTL_USER_PROCESS_PARAMETERS ;


/// The `PEB_LDR_DATA` structure is the main record of what modules are loaded in a process.
/// It is essentially the head of three double-linked lists of `LDR_DATA_TABLE_ENTRY` structures which each represent one loaded module.
///
/// Microsoft documentation of this is incomplete, the fields here are taken from various resources including:
///  - https://www.geoffchappell.com/studies/windows/win32/ntdll/structs/peb_ldr_data.htm
typedef struct {
    // Versions: 3.51 and higher
    /// The size in bytes of the structure
    ULONG Length;

    /// TRUE if the structure is prepared.
    BOOLEAN Initialized;

    PVOID SsHandle;
    LIST_ENTRY InLoadOrderModuleList;
    LIST_ENTRY InMemoryOrderModuleList;
    LIST_ENTRY InInitializationOrderModuleList;

    // Versions: 5.1 and higher

    /// No known use of this field is known in Windows 8 and higher.
    PVOID EntryInProgress;

    // Versions: 6.0 from Windows Vista SP1, and higher
    BOOLEAN ShutdownInProgress;

    /// Though ShutdownThreadId is declared as a HANDLE,
    /// it is indeed the thread ID as suggested by its name.
    /// It is picked up from the UniqueThread member of the CLIENT_ID in the
    /// TEB of the thread that asks to terminate the process.
    HANDLE ShutdownThreadId;
}PEB_LDR_DATA ;


typedef struct {
    // Versions: All
    BOOLEAN InheritedAddressSpace;

    // Versions: 3.51+
    BOOLEAN ReadImageFileExecOptions;
    BOOLEAN BeingDebugged;

    // Versions: 5.2+ (previously was padding)
    UCHAR BitField;

    // Versions: all
    HANDLE Mutant;
    HMODULE ImageBaseAddress;
    PEB_LDR_DATA* Ldr;
    RTL_USER_PROCESS_PARAMETERS* ProcessParameters;
    PVOID SubSystemData;
    HANDLE ProcessHeap;

    // Versions: 5.1+
    RTL_CRITICAL_SECTION* FastPebLock;

    // Versions: 5.2+
    PVOID AtlThunkSListPtr;
    PVOID IFEOKey;

    // Versions: 6.0+

    /// https://www.geoffchappell.com/studies/windows/win32/ntdll/structs/peb/crossprocessflags.htm
    ULONG CrossProcessFlags;

    // Versions: 6.0+
    union {
        PVOID KernelCallbackTable;
        PVOID UserSharedInfoPtr;
    };

    // Versions: 5.1+
    ULONG SystemReserved;

    // Versions: 5.1, (not 5.2, not 6.0), 6.1+
    ULONG AtlThunkSListPtr32;

    // Versions: 6.1+
    PVOID ApiSetMap;

    // Versions: all
    ULONG TlsExpansionCounter;
    // note: there is padding here on 64 bit
    RTL_BITMAP* TlsBitmap;
    ULONG TlsBitmapBits[2]; 
    PVOID ReadOnlySharedMemoryBase;

    // Versions: 1703+
    PVOID SharedData;

    // Versions: all
    PVOID* ReadOnlyStaticServerData;
    PVOID AnsiCodePageData;
    PVOID OemCodePageData;
    PVOID UnicodeCaseTableData;

    // Versions: 3.51+
    ULONG NumberOfProcessors;
    ULONG NtGlobalFlag;

    // Versions: all
    LARGE_INTEGER CriticalSectionTimeout;

    // End of Original PEB size

    // Fields appended in 3.51:
    ULONG_PTR HeapSegmentReserve;
    ULONG_PTR HeapSegmentCommit;
    ULONG_PTR HeapDeCommitTotalFreeThreshold;
    ULONG_PTR HeapDeCommitFreeBlockThreshold;
    ULONG NumberOfHeaps;
    ULONG MaximumNumberOfHeaps;
    PVOID* ProcessHeaps;

    // Fields appended in 4.0:
    PVOID GdiSharedHandleTable;
    PVOID ProcessStarterHelper;
    ULONG GdiDCAttributeList;
    // note: there is padding here on 64 bit
    RTL_CRITICAL_SECTION* LoaderLock;
    ULONG OSMajorVersion;
    ULONG OSMinorVersion;
    USHORT OSBuildNumber;
    USHORT OSCSDVersion;
    ULONG OSPlatformId;
    ULONG ImageSubSystem;
    ULONG ImageSubSystemMajorVersion;
    ULONG ImageSubSystemMinorVersion;
    // note: there is padding here on 64 bit
    KAFFINITY ActiveProcessAffinityMask;
    ULONG GdiHandleBuffer[0x3c];

    // Fields appended in 5.0 (Windows 2000):
    PVOID PostProcessInitRoutine;
    RTL_BITMAP* TlsExpansionBitmap;
    ULONG TlsExpansionBitmapBits[32];
    ULONG SessionId;
    // note: there is padding here on 64 bit
    // Versions: 5.1+
    ULARGE_INTEGER AppCompatFlags;
    ULARGE_INTEGER AppCompatFlagsUser;
    PVOID ShimData;
    // Versions: 5.0+
    PVOID AppCompatInfo;
    UNICODE_STRING CSDVersion;

    // Fields appended in 5.1 (Windows XP):
    const ACTIVATION_CONTEXT_DATA* ActivationContextData;
    ASSEMBLY_STORAGE_MAP* ProcessAssemblyStorageMap;
    const ACTIVATION_CONTEXT_DATA* SystemDefaultActivationData; 
    ASSEMBLY_STORAGE_MAP* SystemAssemblyStorageMap;
    ULONG_PTR MinimumStackCommit;

    // Fields appended in 5.2 (Windows Server 2003):
    FLS_CALLBACK_INFO* FlsCallback;
    LIST_ENTRY FlsListHead;
    RTL_BITMAP* FlsBitmap;
    ULONG FlsBitmapBits[4];
   
    ULONG FlsHighIndex;

    // Fields appended in 6.0 (Windows Vista):
    PVOID WerRegistrationData;
    PVOID WerShipAssertPtr;

    // Fields appended in 6.1 (Windows 7):
    PVOID pUnused; // previously pContextData
    PVOID pImageHeaderHash; 

    /// TODO: https://www.geoffchappell.com/studies/windows/win32/ntdll/structs/peb/tracingflags.htm
    ULONG TracingFlags;

    // Fields appended in 6.2 (Windows 8):
    ULONGLONG CsrServerReadOnlySharedMemoryBase;

    // Fields appended in 1511:
    ULONG TppWorkerpListLock;
    LIST_ENTRY TppWorkerpList;
    PVOID WaitOnAddressHashTable[0x80];

    // Fields appended in 1709:
    PVOID TelemetryCoverageHeader;
    ULONG CloudFileFlags;
} PEB;

typedef struct {
    PVOID Reserved1[12];
    PEB* ProcessEnvironmentBlock;
    PVOID Reserved2[399];
    u8 Reserved3[1952];
    PVOID TlsSlots[64]; 
    u8 Reserved4[8];
    PVOID Reserved5[26];
    PVOID ReservedForOle;
    PVOID Reserved6[4];
    PVOID TlsExpansionSlots;
} TEB;

TEB* get_teb()
{
#ifdef __x86_64__
    void* teb;
    __asm volatile(" movq %%gs:0x30, %[ptr]": [ptr]"=r"(teb)::);
    return teb;
#else
#error "arch not supported"
#endif
}

typedef enum {
    MEM_COMMIT = 0x1000,
    MEM_RESERVE = 0x2000,
} MapFlags;

typedef enum {
    PAGE_EXECUTE = 0x10,
    PAGE_EXECUTE_READ = 0x20,
    PAGE_EXECUTE_READWRITE = 0x40,
    PAGE_EXECUTE_WRITECOPY = 0x80,
    PAGE_NO_ACCESS = 0x01,
    PAGE_READONLY = 0x02,
    PAGE_READWRITE = 0x04,
    PAGE_WRITECOPY = 0x8,
} OSProtectionFlags;

WINBASEAPI WINAPI
void* VirtualAlloc(void* address, usize size, u32 map_flags, u32 protection_flags);

Result result_from_syscall(s64 value) {
    (void)value;
    return GetLastError();
}

Result result_from_bool(BOOL b) {
    Result result = SUCCESS;
    if (b == 0) {
        result = GetLastError();
    }

    return result;
}
