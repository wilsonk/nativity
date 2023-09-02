const std = @import("std");

const lexer = @import("lexer.zig");
test {
    _ = lexer;
    // _ = parser;
    // _ = ir;
    // _ = emit;
}

pub const chunk_length = 32;
pub const ByteChunk = @Vector(chunk_length, u8);
pub const BoolChunk = @Vector(chunk_length, bool);
pub const U1Chunk = @Vector(chunk_length, u1);
pub const ChunkMask = @Type(.{
    .Int = .{
        .signedness = .unsigned,
        .bits = chunk_length,
    },
});

pub const page_size = 0x1000;
pub const page_shift = @ctz(@as(u16, page_size));

const OS = @field(std.os, @tagName(os));
const os = @import("builtin").os.tag;

pub const PageAllocator = struct {
    pub fn allocate(page_count: usize, flags: packed struct {
        execute: bool = false,
    }) ![]align(page_size) u8 {
        const size = page_count << page_shift;
        const protection_execution_flags = if (flags.execute) @as(u32, OS.PROT.EXEC) else @as(u32, 0);
        const protection_flags: u32 = OS.PROT.READ | OS.PROT.WRITE | protection_execution_flags;
        const map_flags: u32 = OS.MAP.ANONYMOUS | OS.MAP.PRIVATE;
        return switch (os) {
            .linux => try std.os.mmap(null, size, protection_flags, map_flags, -1, 0),
            else => @compileError("TODO: OS"),
        };
    }
};

pub const AlignedFile = struct {
    buffer: []align(page_size) const u8,
    real_size: usize,
    chunk_aligned_size: usize,

    pub fn vectorize(file: AlignedFile) []const ByteChunk {
        const vectorized_file = @as([*]const ByteChunk, @ptrCast(file.buffer.ptr))[0..@divExact(file.chunk_aligned_size, chunk_length)];
        return vectorized_file;
    }

    pub fn fromComptime(comptime text: []const u8) AlignedFile {
        comptime {
            const total_size = std.mem.alignForward(usize, text.len, page_size);
            var buffer: [total_size]u8 align(page_size) = undefined;
            buffer = (text ++ .{0} ** (page_size - text.len)).*;

            return .{
                .buffer = &buffer,
                .real_size = text.len,
                .chunk_aligned_size = std.mem.alignForward(usize, text.len, chunk_length),
            };
        }
    }

    pub fn fromFilesystem(file_relative_path: []const u8) !AlignedFile {
        const file_descriptor = try std.fs.cwd().openFile(file_relative_path, .{});
        defer file_descriptor.close();
        const file_size = file_descriptor.getEndPos() catch unreachable;
        const aligned_file_size = std.mem.alignForward(u64, file_size, page_size);
        const file = try PageAllocator.allocate(aligned_file_size >> page_shift, .{});
        _ = try file_descriptor.readAll(file);

        return .{
            .buffer = file,
            .real_size = file_size,
            .chunk_aligned_size = std.mem.alignForward(usize, file_size, chunk_length),
        };
    }
};

pub fn cycle(file_relative_path: []const u8) !void {
    const file = try AlignedFile.fromFilesystem(file_relative_path);
    const r = try lexer.lex(file);
    _ = r;
}
