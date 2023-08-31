#pragma once

typedef s32 FileDescriptor;

enum
{
    STDIN_HANDLE = 1,
    STDOUT_HANDLE = 1,
    STDERR_HANDLE = 2,
};

enum
{
    SYSCALL_READ = 0,
    SYSCALL_WRITE = 1,
    SYSCALL_OPEN = 2,
    SYSCALL_CLOSE = 3,
    SYSCALL_STAT = 4,
    SYSCALL_FSTAT = 5,
    SYSCALL_LSTAT = 6,
    SYSCALL_POLL = 7,
    SYSCALL_LSEEK = 8,
    SYSCALL_MMAP = 9,
    SYSCALL_MPROTECT = 10,
    SYSCALL_MUNMAP = 11,
    SYSCALL_BRK = 12,
    SYSCALL_RT_SIGACTION = 13,
    SYSCALL_RT_SIGPROCMASK = 14,
    SYSCALL_RT_SIGRETURN = 15,
    SYSCALL_IOCTL = 16,
    SYSCALL_PREAD64 = 17,
    SYSCALL_PWRITE64 = 18,
    SYSCALL_READV = 19,
    SYSCALL_WRITEV = 20,
    SYSCALL_ACCESS = 21,
    SYSCALL_PIPE = 22,
    SYSCALL_SELECT = 23,
    SYSCALL_SCHED_YIELD = 24,
    SYSCALL_MREMAP = 25,
    SYSCALL_MSYNC = 26,
    SYSCALL_MINCORE = 27,
    SYSCALL_MADVISE = 28,
    SYSCALL_SHMGET = 29,
    SYSCALL_SHMAT = 30,
    SYSCALL_SHMCTL = 31,
    SYSCALL_DUP = 32,
    SYSCALL_DUP2 = 33,
    SYSCALL_PAUSE = 34,
    SYSCALL_NANOSLEEP = 35,
    SYSCALL_GETITIMER = 36,
    SYSCALL_ALARM = 37,
    SYSCALL_SETITIMER = 38,
    SYSCALL_GETPID = 39,
    SYSCALL_SENDFILE = 40,
    SYSCALL_SOCKET = 41,
    SYSCALL_CONNECT = 42,
    SYSCALL_ACCEPT = 43,
    SYSCALL_SENDTO = 44,
    SYSCALL_RECVFROM = 45,
    SYSCALL_SENDMSG = 46,
    SYSCALL_RECVMSG = 47,
    SYSCALL_SHUTDOWN = 48,
    SYSCALL_BIND = 49,
    SYSCALL_LISTEN = 50,
    SYSCALL_GETSOCKNAME = 51,
    SYSCALL_GETPEERNAME = 52,
    SYSCALL_SOCKETPAIR = 53,
    SYSCALL_SETSOCKOPT = 54,
    SYSCALL_GETSOCKOPT = 55,
    SYSCALL_CLONE = 56,
    SYSCALL_FORK = 57,
    SYSCALL_VFORK = 58,
    SYSCALL_EXECVE = 59,
    SYSCALL_EXIT = 60,
    SYSCALL_WAIT4 = 61,
    SYSCALL_KILL = 62,
    SYSCALL_UNAME = 63,
    SYSCALL_SEMGET = 64,
    SYSCALL_SEMOP = 65,
    SYSCALL_SEMCTL = 66,
    SYSCALL_SHMDT = 67,
    SYSCALL_MSGGET = 68,
    SYSCALL_MSGSND = 69,
    SYSCALL_MSGRCV = 70,
    SYSCALL_MSGCTL = 71,
    SYSCALL_FCNTL = 72,
    SYSCALL_FLOCK = 73,
    SYSCALL_FSYNC = 74,
    SYSCALL_FDATASYNC = 75,
    SYSCALL_TRUNCATE = 76,
    SYSCALL_FTRUNCATE = 77,
    SYSCALL_GETDENTS = 78,
    SYSCALL_GETCWD = 79,
    SYSCALL_CHDIR = 80,
    SYSCALL_FCHDIR = 81,
    SYSCALL_RENAME = 82,
    SYSCALL_MKDIR = 83,
    SYSCALL_RMDIR = 84,
    SYSCALL_CREAT = 85,
    SYSCALL_LINK = 86,
    SYSCALL_UNLINK = 87,
    SYSCALL_SYMLINK = 88,
    SYSCALL_READLINK = 89,
    SYSCALL_CHMOD = 90,
    SYSCALL_FCHMOD = 91,
    SYSCALL_CHOWN = 92,
    SYSCALL_FCHOWN = 93,
    SYSCALL_LCHOWN = 94,
    SYSCALL_UMASK = 95,
    SYSCALL_GETTIMEOFDAY = 96,
    SYSCALL_GETRLIMIT = 97,
    SYSCALL_GETRUSAGE = 98,
    SYSCALL_SYSINFO = 99,
    SYSCALL_TIMES = 100,
    SYSCALL_PTRACE = 101,
    SYSCALL_GETUID = 102,
    SYSCALL_SYSLOG = 103,
    SYSCALL_GETGID = 104,
    SYSCALL_SETUID = 105,
    SYSCALL_SETGID = 106,
    SYSCALL_GETEUID = 107,
    SYSCALL_GETEGID = 108,
    SYSCALL_SETPGID = 109,
    SYSCALL_GETPPID = 110,
    SYSCALL_GETPGRP = 111,
    SYSCALL_SETSID = 112,
    SYSCALL_SETREUID = 113,
    SYSCALL_SETREGID = 114,
    SYSCALL_GETGROUPS = 115,
    SYSCALL_SETGROUPS = 116,
    SYSCALL_SETRESUID = 117,
    SYSCALL_GETRESUID = 118,
    SYSCALL_SETRESGID = 119,
    SYSCALL_GETRESGID = 120,
    SYSCALL_GETPGID = 121,
    SYSCALL_SETFSUID = 122,
    SYSCALL_SETFSGID = 123,
    SYSCALL_GETSID = 124,
    SYSCALL_CAPGET = 125,
    SYSCALL_CAPSET = 126,
    SYSCALL_RT_SIGPENDING = 127,
    SYSCALL_RT_SIGTIMEDWAIT = 128,
    SYSCALL_RT_SIGQUEUEINFO = 129,
    SYSCALL_RT_SIGSUSPEND = 130,
    SYSCALL_SIGALTSTACK = 131,
    SYSCALL_UTIME = 132,
    SYSCALL_MKNOD = 133,
    SYSCALL_USELIB = 134,
    SYSCALL_PERSONALITY = 135,
    SYSCALL_USTAT = 136,
    SYSCALL_STATFS = 137,
    SYSCALL_FSTATFS = 138,
    SYSCALL_SYSFS = 139,
    SYSCALL_GETPRIORITY = 140,
    SYSCALL_SETPRIORITY = 141,
    SYSCALL_SCHED_SETPARAM = 142,
    SYSCALL_SCHED_GETPARAM = 143,
    SYSCALL_SCHED_SETSCHEDULER = 144,
    SYSCALL_SCHED_GETSCHEDULER = 145,
    SYSCALL_SCHED_GET_PRIORITY_MAX = 146,
    SYSCALL_SCHED_GET_PRIORITY_MIN = 147,
    SYSCALL_SCHED_RR_GET_INTERVAL = 148,
    SYSCALL_MLOCK = 149,
    SYSCALL_MUNLOCK = 150,
    SYSCALL_MLOCKALL = 151,
    SYSCALL_MUNLOCKALL = 152,
    SYSCALL_VHANGUP = 153,
    SYSCALL_MODIFY_LDT = 154,
    SYSCALL_PIVOT_ROOT = 155,
    SYSCALL__SYSCTL = 156,
    SYSCALL_PRCTL = 157,
    SYSCALL_ARCH_PRCTL = 158,
    SYSCALL_ADJTIMEX = 159,
    SYSCALL_SETRLIMIT = 160,
    SYSCALL_CHROOT = 161,
    SYSCALL_SYNC = 162,
    SYSCALL_ACCT = 163,
    SYSCALL_SETTIMEOFDAY = 164,
    SYSCALL_MOUNT = 165,
    SYSCALL_UMOUNT2 = 166,
    SYSCALL_SWAPON = 167,
    SYSCALL_SWAPOFF = 168,
    SYSCALL_REBOOT = 169,
    SYSCALL_SETHOSTNAME = 170,
    SYSCALL_SETDOMAINNAME = 171,
    SYSCALL_IOPL = 172,
    SYSCALL_IOPERM = 173,
    SYSCALL_CREATE_MODULE = 174,
    SYSCALL_INIT_MODULE = 175,
    SYSCALL_DELETE_MODULE = 176,
    SYSCALL_GET_KERNEL_SYMS = 177,
    SYSCALL_QUERY_MODULE = 178,
    SYSCALL_QUOTACTL = 179,
    SYSCALL_NFSSERVCTL = 180,
    SYSCALL_GETPMSG = 181,
    SYSCALL_PUTPMSG = 182,
    SYSCALL_AFS_SYSCALL = 183,
    SYSCALL_TUXCALL = 184,
    SYSCALL_SECURITY = 185,
    SYSCALL_GETTID = 186,
    SYSCALL_READAHEAD = 187,
    SYSCALL_SETXATTR = 188,
    SYSCALL_LSETXATTR = 189,
    SYSCALL_FSETXATTR = 190,
    SYSCALL_GETXATTR = 191,
    SYSCALL_LGETXATTR = 192,
    SYSCALL_FGETXATTR = 193,
    SYSCALL_LISTXATTR = 194,
    SYSCALL_LLISTXATTR = 195,
    SYSCALL_FLISTXATTR = 196,
    SYSCALL_REMOVEXATTR = 197,
    SYSCALL_LREMOVEXATTR = 198,
    SYSCALL_FREMOVEXATTR = 199,
    SYSCALL_TKILL = 200,
    SYSCALL_TIME = 201,
    SYSCALL_FUTEX = 202,
    SYSCALL_SCHED_SETAFFINITY = 203,
    SYSCALL_SCHED_GETAFFINITY = 204,
    SYSCALL_SET_THREAD_AREA = 205,
    SYSCALL_IO_SETUP = 206,
    SYSCALL_IO_DESTROY = 207,
    SYSCALL_IO_GETEVENTS = 208,
    SYSCALL_IO_SUBMIT = 209,
    SYSCALL_IO_CANCEL = 210,
    SYSCALL_GET_THREAD_AREA = 211,
    SYSCALL_LOOKUP_DCOOKIE = 212,
    SYSCALL_EPOLL_CREATE = 213,
    SYSCALL_EPOLL_CTL_OLD = 214,
    SYSCALL_EPOLL_WAIT_OLD = 215,
    SYSCALL_REMAP_FILE_PAGES = 216,
    SYSCALL_GETDENTS64 = 217,
    SYSCALL_SET_TID_ADDRESS = 218,
    SYSCALL_RESTART_SYSCALL = 219,
    SYSCALL_SEMTIMEDOP = 220,
    SYSCALL_FADVISE64 = 221,
    SYSCALL_TIMER_CREATE = 222,
    SYSCALL_TIMER_SETTIME = 223,
    SYSCALL_TIMER_GETTIME = 224,
    SYSCALL_TIMER_GETOVERRUN = 225,
    SYSCALL_TIMER_DELETE = 226,
    SYSCALL_CLOCK_SETTIME = 227,
    SYSCALL_CLOCK_GETTIME = 228,
    SYSCALL_CLOCK_GETRES = 229,
    SYSCALL_CLOCK_NANOSLEEP = 230,
    SYSCALL_EXIT_GROUP = 231,
    SYSCALL_EPOLL_WAIT = 232,
    SYSCALL_EPOLL_CTL = 233,
    SYSCALL_TGKILL = 234,
    SYSCALL_UTIMES = 235,
    SYSCALL_VSERVER = 236,
    SYSCALL_MBIND = 237,
    SYSCALL_SET_MEMPOLICY = 238,
    SYSCALL_GET_MEMPOLICY = 239,
    SYSCALL_MQ_OPEN = 240,
    SYSCALL_MQ_UNLINK = 241,
    SYSCALL_MQ_TIMEDSEND = 242,
    SYSCALL_MQ_TIMEDRECEIVE = 243,
    SYSCALL_MQ_NOTIFY = 244,
    SYSCALL_MQ_GETSETATTR = 245,
    SYSCALL_KEXEC_LOAD = 246,
    SYSCALL_WAITID = 247,
    SYSCALL_ADD_KEY = 248,
    SYSCALL_REQUEST_KEY = 249,
    SYSCALL_KEYCTL = 250,
    SYSCALL_IOPRIO_SET = 251,
    SYSCALL_IOPRIO_GET = 252,
    SYSCALL_INOTIFY_INIT = 253,
    SYSCALL_INOTIFY_ADD_WATCH = 254,
    SYSCALL_INOTIFY_RM_WATCH = 255,
    SYSCALL_MIGRATE_PAGES = 256,
    SYSCALL_OPENAT = 257,
    SYSCALL_MKDIRAT = 258,
    SYSCALL_MKNODAT = 259,
    SYSCALL_FCHOWNAT = 260,
    SYSCALL_FUTIMESAT = 261,
    SYSCALL_FSTATAT64 = 262,
    SYSCALL_UNLINKAT = 263,
    SYSCALL_RENAMEAT = 264,
    SYSCALL_LINKAT = 265,
    SYSCALL_SYMLINKAT = 266,
    SYSCALL_READLINKAT = 267,
    SYSCALL_FCHMODAT = 268,
    SYSCALL_FACCESSAT = 269,
    SYSCALL_PSELECT6 = 270,
    SYSCALL_PPOLL = 271,
    SYSCALL_UNSHARE = 272,
    SYSCALL_SET_ROBUST_LIST = 273,
    SYSCALL_GET_ROBUST_LIST = 274,
    SYSCALL_SPLICE = 275,
    SYSCALL_TEE = 276,
    SYSCALL_SYNC_FILE_RANGE = 277,
    SYSCALL_VMSPLICE = 278,
    SYSCALL_MOVE_PAGES = 279,
    SYSCALL_UTIMENSAT = 280,
    SYSCALL_EPOLL_PWAIT = 281,
    SYSCALL_SIGNALFD = 282,
    SYSCALL_TIMERFD_CREATE = 283,
    SYSCALL_EVENTFD = 284,
    SYSCALL_FALLOCATE = 285,
    SYSCALL_TIMERFD_SETTIME = 286,
    SYSCALL_TIMERFD_GETTIME = 287,
    SYSCALL_ACCEPT4 = 288,
    SYSCALL_SIGNALFD4 = 289,
    SYSCALL_EVENTFD2 = 290,
    SYSCALL_EPOLL_CREATE1 = 291,
    SYSCALL_DUP3 = 292,
    SYSCALL_PIPE2 = 293,
    SYSCALL_INOTIFY_INIT1 = 294,
    SYSCALL_PREADV = 295,
    SYSCALL_PWRITEV = 296,
    SYSCALL_RT_TGSIGQUEUEINFO = 297,
    SYSCALL_PERF_EVENT_OPEN = 298,
    SYSCALL_RECVMMSG = 299,
    SYSCALL_FANOTIFY_INIT = 300,
    SYSCALL_FANOTIFY_MARK = 301,
    SYSCALL_PRLIMIT64 = 302,
    SYSCALL_NAME_TO_HANDLE_AT = 303,
    SYSCALL_OPEN_BY_HANDLE_AT = 304,
    SYSCALL_CLOCK_ADJTIME = 305,
    SYSCALL_SYNCFS = 306,
    SYSCALL_SENDMMSG = 307,
    SYSCALL_SETNS = 308,
    SYSCALL_GETCPU = 309,
    SYSCALL_PROCESS_VM_READV = 310,
    SYSCALL_PROCESS_VM_WRITEV = 311,
    SYSCALL_KCMP = 312,
    SYSCALL_FINIT_MODULE = 313,
    SYSCALL_SCHED_SETATTR = 314,
    SYSCALL_SCHED_GETATTR = 315,
    SYSCALL_RENAMEAT2 = 316,
    SYSCALL_SECCOMP = 317,
    SYSCALL_GETRANDOM = 318,
    SYSCALL_MEMFD_CREATE = 319,
    SYSCALL_KEXEC_FILE_LOAD = 320,
    SYSCALL_BPF = 321,
    SYSCALL_EXECVEAT = 322,
    SYSCALL_USERFAULTFD = 323,
    SYSCALL_MEMBARRIER = 324,
    SYSCALL_MLOCK2 = 325,
    SYSCALL_COPY_FILE_RANGE = 326,
    SYSCALL_PREADV2 = 327,
    SYSCALL_PWRITEV2 = 328,
    SYSCALL_PKEY_MPROTECT = 329,
    SYSCALL_PKEY_ALLOC = 330,
    SYSCALL_PKEY_FREE = 331,
    SYSCALL_STATX = 332,
    SYSCALL_IO_PGETEVENTS = 333,
    SYSCALL_RSEQ = 334,
    SYSCALL_PIDFD_SEND_SIGNAL = 424,
    SYSCALL_IO_URING_SETUP = 425,
    SYSCALL_IO_URING_ENTER = 426,
    SYSCALL_IO_URING_REGISTER = 427,
    SYSCALL_OPEN_TREE = 428,
    SYSCALL_MOVE_MOUNT = 429,
    SYSCALL_FSOPEN = 430,
    SYSCALL_FSCONFIG = 431,
    SYSCALL_FSMOUNT = 432,
    SYSCALL_FSPICK = 433,
    SYSCALL_PIDFD_OPEN = 434,
    SYSCALL_CLONE3 = 435,
    SYSCALL_CLOSE_RANGE = 436,
    SYSCALL_OPENAT2 = 437,
    SYSCALL_PIDFD_GETFD = 438,
    SYSCALL_FACCESSAT2 = 439,
    SYSCALL_PROCESS_MADVISE = 440,
    SYSCALL_EPOLL_PWAIT2 = 441,
    SYSCALL_MOUNT_SETATTR = 442,
    SYSCALL_QUOTACTL_FD = 443,
    SYSCALL_LANDLOCK_CREATE_RULESET = 444,
    SYSCALL_LANDLOCK_ADD_RULE = 445,
    SYSCALL_LANDLOCK_RESTRICT_SELF = 446,
    SYSCALL_MEMFD_SECRET = 447,
    SYSCALL_PROCESS_MRELEASE = 448,
    SYSCALL_FUTEX_WAITV = 449,
    SYSCALL_SET_MEMPOLICY_HOME_NODE = 450,
};

enum
{
    FILESYSTEM_CWD = -100,
    FILESYSTEM_PATH_MAX = 4096,
};

enum Result
{
    /// No error occurred.
    /// Same code used for `NSROK`.
    SUCCESS = 0,

    /// Operation not permitted
    PERM = 1,

    /// No such file or directory
    NOENT = 2,

    /// No such process
    SRCH = 3,

    /// Interrupted system call
    INTR = 4,

    /// I/O error
    IO = 5,

    /// No such device or address
    NXIO = 6,

    /// Arg list too long
    TOOBIG = 7,

    /// Exec format error
    NOEXEC = 8,

    /// Bad file number
    BADF = 9,

    /// No child processes
    CHILD = 10,

    /// Try again
    /// Also means: WOULDBLOCK: operation would block
    AGAIN = 11,

    /// Out of memory
    NOMEM = 12,

    /// Permission denied
    ACCES = 13,

    /// Bad address
    FAULT = 14,

    /// Block device required
    NOTBLK = 15,

    /// Device or resource busy
    BUSY = 16,

    /// File exists
    EXIST = 17,

    /// Cross-device link
    XDEV = 18,

    /// No such device
    NODEV = 19,

    /// Not a directory
    NOTDIR = 20,

    /// Is a directory
    ISDIR = 21,

    /// Invalid argument
    INVAL = 22,

    /// File table overflow
    NFILE = 23,

    /// Too many open files
    MFILE = 24,

    /// Not a typewriter
    NOTTY = 25,

    /// Text file busy
    TXTBSY = 26,

    /// File too large
    FBIG = 27,

    /// No space left on device
    NOSPC = 28,

    /// Illegal seek
    SPIPE = 29,

    /// Read-only file system
    ROFS = 30,

    /// Too many links
    MLINK = 31,

    /// Broken pipe
    PIPE = 32,

    /// Math argument out of domain of func
    DOM = 33,

    /// Math result not representable
    RANGE = 34,

    /// Resource deadlock would occur
    DEADLK = 35,

    /// File name too long
    NAMETOOLONG = 36,

    /// No record locks available
    NOLCK = 37,

    /// Function not implemented
    NOSYS = 38,

    /// Directory not empty
    NOTEMPTY = 39,

    /// Too many symbolic links encountered
    LOOP = 40,

    /// No message of desired type
    NOMSG = 42,

    /// Identifier removed
    IDRM = 43,

    /// Channel number out of range
    CHRNG = 44,

    /// Level 2 not synchronized
    L2NSYNC = 45,

    /// Level 3 halted
    L3HLT = 46,

    /// Level 3 reset
    L3RST = 47,

    /// Link number out of range
    LNRNG = 48,

    /// Protocol driver not attached
    UNATCH = 49,

    /// No CSI structure available
    NOCSI = 50,

    /// Level 2 halted
    L2HLT = 51,

    /// Invalid exchange
    BADE = 52,

    /// Invalid request descriptor
    BADR = 53,

    /// Exchange full
    XFULL = 54,

    /// No anode
    NOANO = 55,

    /// Invalid request code
    BADRQC = 56,

    /// Invalid slot
    BADSLT = 57,

    /// Bad font file format
    BFONT = 59,

    /// Device not a stream
    NOSTR = 60,

    /// No data available
    NODATA = 61,

    /// Timer expired
    TIME = 62,

    /// Out of streams resources
    NOSR = 63,

    /// Machine is not on the network
    NONET = 64,

    /// Package not installed
    NOPKG = 65,

    /// Object is remote
    REMOTE = 66,

    /// Link has been severed
    NOLINK = 67,

    /// Advertise error
    ADV = 68,

    /// Srmount error
    SRMNT = 69,

    /// Communication error on send
    COMM = 70,

    /// Protocol error
    PROTO = 71,

    /// Multihop attempted
    MULTIHOP = 72,

    /// RFS specific error
    DOTDOT = 73,

    /// Not a data message
    BADMSG = 74,

    /// Value too large for defined data type
    OVERFLOW = 75,

    /// Name not unique on network
    NOTUNIQ = 76,

    /// File descriptor in bad state
    BADFD = 77,

    /// Remote address changed
    REMCHG = 78,

    /// Can not access a needed shared library
    LIBACC = 79,

    /// Accessing a corrupted shared library
    LIBBAD = 80,

    /// .lib section in a.out corrupted
    LIBSCN = 81,

    /// Attempting to link in too many shared libraries
    LIBMAX = 82,

    /// Cannot exec a shared library directly
    LIBEXEC = 83,

    /// Illegal byte sequence
    ILSEQ = 84,

    /// Interrupted system call should be restarted
    RESTART = 85,

    /// Streams pipe error
    STRPIPE = 86,

    /// Too many users
    USERS = 87,

    /// Socket operation on non-socket
    NOTSOCK = 88,

    /// Destination address required
    DESTADDRREQ = 89,

    /// Message too long
    MSGSIZE = 90,

    /// Protocol wrong type for socket
    PROTOTYPE = 91,

    /// Protocol not available
    NOPROTOOPT = 92,

    /// Protocol not supported
    PROTONOSUPPORT = 93,

    /// Socket type not supported
    SOCKTNOSUPPORT = 94,

    /// Operation not supported on transport endpoint
    /// This code also means `NOTSUP`.
    OPNOTSUPP = 95,

    /// Protocol family not supported
    PFNOSUPPORT = 96,

    /// Address family not supported by protocol
    AFNOSUPPORT = 97,

    /// Address already in use
    ADDRINUSE = 98,

    /// Cannot assign requested address
    ADDRNOTAVAIL = 99,

    /// Network is down
    NETDOWN = 100,

    /// Network is unreachable
    NETUNREACH = 101,

    /// Network dropped connection because of reset
    NETRESET = 102,

    /// Software caused connection abort
    CONNABORTED = 103,

    /// Connection reset by peer
    CONNRESET = 104,

    /// No buffer space available
    NOBUFS = 105,

    /// Transport endpoint is already connected
    ISCONN = 106,

    /// Transport endpoint is not connected
    NOTCONN = 107,

    /// Cannot send after transport endpoint shutdown
    SHUTDOWN = 108,

    /// Too many references: cannot splice
    TOOMANYREFS = 109,

    /// Connection timed out
    TIMEDOUT = 110,

    /// Connection refused
    CONNREFUSED = 111,

    /// Host is down
    HOSTDOWN = 112,

    /// No route to host
    HOSTUNREACH = 113,

    /// Operation already in progress
    ALREADY = 114,

    /// Operation now in progress
    INPROGRESS = 115,

    /// Stale NFS file handle
    STALE = 116,

    /// Structure needs cleaning
    UCLEAN = 117,

    /// Not a XENIX named type file
    NOTNAM = 118,

    /// No XENIX semaphores available
    NAVAIL = 119,

    /// Is a named type file
    ISNAM = 120,

    /// Remote I/O error
    REMOTEIO = 121,

    /// Quota exceeded
    DQUOT = 122,

    /// No medium found
    NOMEDIUM = 123,

    /// Wrong medium type
    MEDIUMTYPE = 124,

    /// Operation canceled
    CANCELED = 125,

    /// Required key not available
    NOKEY = 126,

    /// Key has expired
    KEYEXPIRED = 127,

    /// Key has been revoked
    KEYREVOKED = 128,

    /// Key was rejected by service
    KEYREJECTED = 129,

    // for robust mutexes

    /// Owner died
    OWNERDEAD = 130,

    /// State not recoverable
    NOTRECOVERABLE = 131,

    /// Operation not possible due to RF-kill
    RFKILL = 132,

    /// Memory page has hardware error
    HWPOISON = 133,

    // nameserver query return codes

    /// DNS server returned answer with no data
    NSRNODATA = 160,

    /// DNS server claims query was misformatted
    NSRFORMERR = 161,

    /// DNS server returned general failure
    NSRSERVFAIL = 162,

    /// Domain name not found
    NSRNOTFOUND = 163,

    /// DNS server does not implement requested operation
    NSRNOTIMP = 164,

    /// DNS server refused query
    NSRREFUSED = 165,

    /// Misformatted DNS query
    NSRBADQUERY = 166,

    /// Misformatted domain name
    NSRBADNAME = 167,

    /// Unsupported address family
    NSRBADFAMILY = 168,

    /// Misformatted DNS reply
    NSRBADRESP = 169,

    /// Could not contact DNS servers
    NSRCONNREFUSED = 170,

    /// Timeout while contacting DNS servers
    NSRTIMEOUT = 171,

    /// End of file
    NSROF = 172,

    /// Error reading file
    NSRFILE = 173,

    /// Out of memory
    NSRNOMEM = 174,

    /// Application terminated lookup
    NSRDESTRUCTION = 175,

    /// Domain name is too long
    NSRQUERYDOMAINTOOLONG = 176,

    /// Domain name is too long
    NSRCNAMELOOP = 177,
};

#define DECL_RESULT(NAME, T, T_NAME) struct NAME ## Result { \
    union { \
        T T_NAME; \
        enum Result result; \
    }; \
    bool is_success; \
}

[[gnu::always_inline]]
PRIVATE enum Result result_from_errno(s64 syscall_result)
{
    u64 result;
    if (EXPECT(syscall_result > -4096 && syscall_result < 0, false))
    {
        result = (u64)(-syscall_result);
    }
    else
    {
        result = 0;
    }

    return result;
}

#ifdef __x86_64__
#include <arch/x86_64/syscall.h>
#else 
#error "Arch not supported"
#endif

[[gnu::always_inline]]
PRIVATE ssize write(FileDescriptor descriptor, struct String bytes)
{
    return syscall3(SYSCALL_WRITE, descriptor, (ssize)bytes.ptr, (ssize)bytes.len);
}

[[gnu::always_inline]]
PRIVATE ssize read(FileDescriptor descriptor, struct String bytes)
{
    return syscall3(SYSCALL_READ, descriptor, (ssize)bytes.ptr, (ssize)bytes.len);
}


enum ProtectionFlags {
    PROTECTION_NONE = 0x0,
    PROTECTION_READ = 0x1,
    PROTECTION_WRITE = 0x2,
    PROTECTION_EXECUTE = 0x4,
};

enum MapFlags {
    MAP_SHARED = 0x1,
    MAP_PRIVATE = 0x2,
    MAP_FIXED = 0x10,
    MAP_ANONYMOUS = 0x20,
};
