const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const log = std.log;

const equal = std.mem.eql;

const data_structures = @import("data_structures.zig");
const ArrayList = data_structures.ArrayList;

const fs = @import("fs.zig");

pub inline fn rdtsc() u64 {
    var edx: u32 = undefined;
    var eax: u32 = undefined;

    asm volatile (
        \\rdtsc
        : [eax] "={eax}" (eax),
          [edx] "={edx}" (edx),
    );

    return @as(u64, edx) << 32 | eax;
}

inline fn rdtscFast() u32 {
    return asm volatile (
        \\rdtsc
        : [eax] "={eax}" (-> u32),
        :
        : "edx"
    );
}

const vector_byte_count = 16;
// These two actually take less space due to how Zig handles bool as u1
const VBool = @Vector(vector_byte_count, bool);
const VU1 = @Vector(vector_byte_count, u1);

const VU8 = @Vector(vector_byte_count, u8);

inline fn vand(v1: VBool, v2: VBool) VBool {
    return @bitCast(@as(VU1, @bitCast(v1)) & @as(VU1, @bitCast(v2)));
}

inline fn byteMask(n: u8) VU8 {
    return @splat(n);
}

inline fn endOfIdentifier(ch: u8) bool {
    // TODO: complete
    return ch == ' ' or ch == '(' or ch == ')';
}

const Identifier = struct {
    start: u32,
    end: u32,
};

pub const TokenId = enum {
    identifier,
    special_character,
    keyword,
    integer,
};

pub const SpecialCharacter = enum(u8) {
    arrow = 0,
    left_parenthesis = '(',
    right_parenthesis = ')',
    left_brace = '{',
    right_brace = '}',
};

pub const Keyword = enum {
    @"return",
};

pub const Integer = struct {
    number: u64,
    negative: bool = false,
};

pub const Result = struct {
    arrays: struct {
        identifiers: ArrayList(Identifier),
        special_characters: ArrayList(SpecialCharacter),
        keywords: ArrayList(Keyword),
        integers: ArrayList(Integer),
        ids: ArrayList(TokenId),
    },
    file: []const u8,
    time: u64 = 0,

    pub fn free(result: *Result, allocator: Allocator) void {
        inline for (@typeInfo(@TypeOf(result.arrays)).Struct.fields) |field| {
            @field(result.arrays, field.name).clearAndFree(allocator);
        }
        // result.identifiers.clearAndFree(allocator);
        // result.special_characters.clearAndFree(allocator);
        // result.integers.clearAndFree(allocator);
        // result.ids.clearAndFree(allocator);
    }
};

fn lex(allocator: Allocator, text: []const u8) !Result {
    const time_start = std.time.Instant.now() catch unreachable;

    var index: usize = 0;

    var result = Result{
        .arrays = .{
            .identifiers = try ArrayList(Identifier).initCapacity(allocator, text.len),
            .special_characters = try ArrayList(SpecialCharacter).initCapacity(allocator, text.len),
            .keywords = try ArrayList(Keyword).initCapacity(allocator, text.len),
            .integers = try ArrayList(Integer).initCapacity(allocator, text.len),
            .ids = try ArrayList(TokenId).initCapacity(allocator, text.len),
        },
        .file = text,
    };

    defer {
        const time_end = std.time.Instant.now() catch unreachable;
        result.time = time_end.since(time_start);
    }

    next_token: while (index < text.len) {
        const first_char = text[index];
        switch (first_char) {
            'a'...'z', 'A'...'Z', '_' => {
                const start = index;
                // SIMD this
                while (!endOfIdentifier(text[index])) {
                    index += 1;
                }

                const identifier = text[start..index];

                inline for (comptime std.enums.values(Keyword)) |keyword| {
                    if (equal(u8, @tagName(keyword), identifier)) {
                        result.arrays.keywords.appendAssumeCapacity(keyword);
                        result.arrays.ids.appendAssumeCapacity(.keyword);
                        continue :next_token;
                    }
                }

                result.arrays.identifiers.appendAssumeCapacity(.{
                    .start = @intCast(start),
                    .end = @intCast(index),
                });

                result.arrays.ids.appendAssumeCapacity(.identifier);
            },
            '(', ')', '{', '}' => |special_character| {
                result.arrays.special_characters.appendAssumeCapacity(@enumFromInt(special_character));
                result.arrays.ids.appendAssumeCapacity(.special_character);
                index += 1;
            },
            ' ', '\n' => index += 1,
            '-' => {
                if (text[index + 1] == '>') {
                    result.arrays.special_characters.appendAssumeCapacity(.arrow);
                    result.arrays.ids.appendAssumeCapacity(.special_character);
                    index += 2;
                } else {
                    @panic("TODO");
                }
            },
            '0'...'9' => {
                const start = index;

                while (text[index] >= '0' and text[index] <= '9') {
                    index += 1;
                }
                const end = index;
                const number_slice = text[start..end];
                const number = try std.fmt.parseInt(u64, number_slice, 10);
                result.arrays.integers.appendAssumeCapacity(.{
                    .number = number,
                    .negative = false,
                });
                result.arrays.ids.appendAssumeCapacity(.integer);

                index += 1;
            },
            else => {
                index += 1;
                unreachable;
            },
        }
    }

    return result;
}

pub fn runTest(allocator: Allocator, file: []const u8) !Result {
    const result = try lex(allocator, file);
    errdefer result.free(allocator);

    return result;
}

test "lexer" {
    const allocator = std.testing.allocator;
    const file_path = fs.first;
    const file = try fs.readFile(allocator, file_path);
    defer allocator.free(file);
    var result = try runTest(allocator, file);
    defer result.free(allocator);
}
