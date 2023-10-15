typedef enum Result {
    /// No error occurred.
    SUCCESS = 0,

    /// Operation not permitted
    PERM = 1,

    /// No such file or directory
    NOENT = 2,

    /// No such process
    SRCH = 3,

    /// Interrupted system call
    INTR = 4,

    /// Input/output error
    IO = 5,

    /// Device not configured
    NXIO = 6,

    /// Argument list too long
    TOO_BIG = 7,

    /// Exec format error
    NOEXEC = 8,

    /// Bad file descriptor
    BADF = 9,

    /// No child processes
    CHILD = 10,

    /// Resource deadlock avoided
    DEADLK = 11,

    /// Cannot allocate memory
    NOMEM = 12,

    /// Permission denied
    ACCES = 13,

    /// Bad address
    FAULT = 14,

    /// Block device required
    NOTBLK = 15,

    /// Device / Resource busy
    BUSY = 16,

    /// File exists
    EXIST = 17,

    /// Cross-device link
    XDEV = 18,

    /// Operation not supported by device
    NODEV = 19,

    /// Not a directory
    NOTDIR = 20,

    /// Is a directory
    ISDIR = 21,

    /// Invalid argument
    INVAL = 22,

    /// Too many open files in system
    NFILE = 23,

    /// Too many open files
    MFILE = 24,

    /// Inappropriate ioctl for device
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

    // math software

    /// Numerical argument out of domain
    DOM = 33,

    /// Result too large
    RANGE = 34,

    // non-blocking and interrupt i/o

    /// Resource temporarily unavailable
    /// This is the same code used for `WOULDBLOCK`.
    AGAIN = 35,

    /// Operation now in progress
    INPROGRESS = 36,

    /// Operation already in progress
    ALREADY = 37,

    // ipc/network software -- argument errors

    /// Socket operation on non-socket
    NOTSOCK = 38,

    /// Destination address required
    DESTADDRREQ = 39,

    /// Message too long
    MSGSIZE = 40,

    /// Protocol wrong type for socket
    PROTOTYPE = 41,

    /// Protocol not available
    NOPROTOOPT = 42,

    /// Protocol not supported
    PROTONOSUPPORT = 43,

    /// Socket type not supported
    SOCKTNOSUPPORT = 44,

    /// Operation not supported
    /// The same code is used for `NOTSUP`.
    OPNOTSUPP = 45,

    /// Protocol family not supported
    PFNOSUPPORT = 46,

    /// Address family not supported by protocol family
    AFNOSUPPORT = 47,

    /// Address already in use
    ADDRINUSE = 48,
    /// Can't assign requested address

    // ipc/network software -- operational errors
    ADDRNOTAVAIL = 49,

    /// Network is down
    NETDOWN = 50,

    /// Network is unreachable
    NETUNREACH = 51,

    /// Network dropped connection on reset
    NETRESET = 52,

    /// Software caused connection abort
    CONNABORTED = 53,

    /// Connection reset by peer
    CONNRESET = 54,

    /// No buffer space available
    NOBUFS = 55,

    /// Socket is already connected
    ISCONN = 56,

    /// Socket is not connected
    NOTCONN = 57,

    /// Can't send after socket shutdown
    SHUTDOWN = 58,

    /// Too many references: can't splice
    TOOMANYREFS = 59,

    /// Operation timed out
    TIMEDOUT = 60,

    /// Connection refused
    CONNREFUSED = 61,

    /// Too many levels of symbolic links
    LOOP = 62,

    /// File name too long
    NAMETOOLONG = 63,

    /// Host is down
    HOSTDOWN = 64,

    /// No route to host
    HOSTUNREACH = 65,
    /// Directory not empty

    // quotas & mush
    NOTEMPTY = 66,

    /// Too many processes
    PROCLIM = 67,

    /// Too many users
    USERS = 68,
    /// Disc quota exceeded

    // Network File System
    DQUOT = 69,

    /// Stale NFS file handle
    STALE = 70,

    /// Too many levels of remote in path
    REMOTE = 71,

    /// RPC struct is bad
    BADRPC = 72,

    /// RPC version wrong
    RPCMISMATCH = 73,

    /// RPC prog. not avail
    PROGUNAVAIL = 74,

    /// Program version wrong
    PROGMISMATCH = 75,

    /// Bad procedure for program
    PROCUNAVAIL = 76,

    /// No locks available
    NOLCK = 77,

    /// Function not implemented
    NOSYS = 78,

    /// Inappropriate file type or format
    FTYPE = 79,

    /// Authentication error
    AUTH = 80,

    /// Need authenticator
    NEEDAUTH = 81,

    // Intelligent device errors

    /// Device power is off
    PWROFF = 82,

    /// Device error, e.g. paper out
    DEVERR = 83,

    /// Value too large to be stored in data type
    OVERFLOW = 84,

    // Program loading errors

    /// Bad executable
    BADEXEC = 85,

    /// Bad CPU type in executable
    BADARCH = 86,

    /// Shared library version mismatch
    SHLIBVERS = 87,

    /// Malformed Macho file
    BADMACHO = 88,

    /// Operation canceled
    CANCELED = 89,

    /// Identifier removed
    IDRM = 90,

    /// No message of desired type
    NOMSG = 91,

    /// Illegal byte sequence
    ILSEQ = 92,

    /// Attribute not found
    NOATTR = 93,

    /// Bad message
    BADMSG = 94,

    /// Reserved
    MULTIHOP = 95,

    /// No message available on STREAM
    NODATA = 96,

    /// Reserved
    NOLINK = 97,

    /// No STREAM resources
    NOSR = 98,

    /// Not a STREAM
    NOSTR = 99,

    /// Protocol error
    PROTO = 100,

    /// STREAM ioctl timeout
    TIME = 101,

    /// No such policy registered
    NOPOLICY = 103,

    /// State not recoverable
    NOTRECOVERABLE = 104,

    /// Previous owner died
    OWNERDEAD = 105,

    /// Interface output queue is full
    QFULL = 106,
} Result;
