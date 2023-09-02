const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const log = std.log;
const print = std.debug.print;

const equal = std.meta.eql;

const compiler = @import("compiler.zig");
const AlignedFile = compiler.AlignedFile;
const BoolChunk = compiler.BoolChunk;
const ByteChunk = compiler.ByteChunk;
const ChunkMask = compiler.ChunkMask;
const chunk_len = compiler.chunk_length;
const U1Chunk = compiler.U1Chunk;
const page_size = compiler.page_size;
const options = @import("options");

pub fn lex(file: AlignedFile) !void {
    const start = std.time.Instant.now() catch unreachable;
    const result = try switch (options.simd) {
        true => runSimd(file),
        false => runScalar(file),
    };
    const end = std.time.Instant.now() catch unreachable;
    const ns = end.since(start);
    _ = ns;

    return result;

    // log.err("Result {} in {} ns", .{ result, ns });
}

inline fn isInRangeInclusive(v: ByteChunk, lower: u8, upper: u8) U1Chunk {
    return @as(U1Chunk, @bitCast(v >= @as(ByteChunk, @splat(lower)))) & @as(U1Chunk, @bitCast(v <= @as(ByteChunk, @splat(upper))));
}

fn firstOcurrence(v: ByteChunk, value: u8) u6 {
    const r = v == @as(ByteChunk, @splat(value));
    const b: u32 = @bitCast(r);
    return @ctz(b);
}

fn is(v: ByteChunk, value: u8) U1Chunk {
    return @bitCast(v == @as(ByteChunk, @splat(value)));
}

const FirstPassToken = struct {
    start: u32,
    len: u16,
    id: Id,

    const Id = enum(u8) {
        identifier,
        number,
        whitespace,
        operator,

        const count = @typeInfo(Id).Enum.fields.len;
    };
};

const benchmark = true;

test "simd basic" {
    const expect = std.testing.expect;
    _ = expect;
    const expectEqual = std.testing.expectEqual;
    _ = expectEqual;
    const ExpectedToken = struct {
        id: FirstPassToken.Id,
        len: u16,
    };
    _ = ExpectedToken;
    const operator = .{
        .id = .operator,
        .len = 1,
    };
    _ = operator;
    const whitespace = .{
        .id = .whitespace,
        .len = 1,
    };
    _ = whitespace;
    // const whitespace = "\t\t\n \t\t\r\t\r\t\t\n \t\t\r\t\r\t\t\n \t\t\r\t\r\t\t\n \t\t\r\t\r\t\t\n \t\t\r\t\r\t\t\n \t\t\r\t\r\t\t\n \t\t\r\t\r\t\t\n \t\t\r\t\r\t\t\n \t\t\r\t\r";
    const basic =
        \\const std = @import("std");
        \\const print = std.debug.print;
        \\pub fn main() !void {
        \\print("Hello world\n", .{});
        \\}
    ;
    _ = basic;
    const text = try AlignedFile.fromFilesystem("src/test/Sema.zig"); //comptime AlignedFile.fromComptime(basic);
    const tokens = try getTokenBuffer(text);

    const simd_result = lexSimd(tokens, text);
    _ = simd_result;
    // const scalar_result = lexScalar(tokens, text, 0);

    // const expected_tokens = [_]ExpectedToken{
    //     .{
    //         .id = .identifier,
    //         .len = 5,
    //     },
    //     whitespace,
    //     .{
    //         .id = .identifier,
    //         .len = 3,
    //     },
    //     whitespace,
    //     operator,
    //     whitespace,
    //     operator,
    //     .{
    //         .id = .identifier,
    //         .len = 6,
    //     },
    //     // operator,
    //     // operator,
    //     .{
    //         .id = .operator,
    //         .len = 2,
    //     },
    //     .{
    //         .id = .identifier,
    //         .len = 3,
    //     },
    //     // operator,
    //     // operator,
    //     // operator,
    //     .{
    //         .id = .operator,
    //         .len = 3,
    //     },
    //     whitespace,
    //     .{
    //         .id = .identifier,
    //         .len = 5,
    //     },
    //     whitespace,
    // };
    //
    // var file_offset: u32 = 0;
    // for (tokens[0..expected_tokens.len], expected_tokens, 0..) |token, expected, index| {
    //     // print("Index: {}. Token: {}\n", .{ index, token });
    //     expectEqual(expected.id, token.id) catch |err| {
    //         log.err("Index: {}", .{index});
    //         return err;
    //     };
    //     expectEqual(file_offset, token.start) catch |err| {
    //         log.err("Index: {}", .{index});
    //         return err;
    //     };
    //     expectEqual(expected.len, token.len) catch |err| {
    //         log.err("Index: {}", .{index});
    //         return err;
    //     };
    //
    //     file_offset += token.len;
    // }
    // if (tokens.len != expected_tokens.len) {
    //     log.err("Len mismatch. Expected: {}. Have: {}", .{ expected_tokens.len, tokens.len });
    //     return error.UnexpectedResult;
    // }
    // // _ = basic;
    // // const tokens = try runSimd(
    // //     std.testing.allocator,
    // // );
}

fn getTokenBuffer(aligned_file: AlignedFile) ![]FirstPassToken {
    const allocation = try compiler.PageAllocator.allocate(aligned_file.real_size, .{});
    const token_max_len = @divExact(allocation.len, @sizeOf(FirstPassToken));
    const tokens = @as([*]FirstPassToken, @ptrCast(allocation.ptr))[0..token_max_len];

    return tokens;
}

const Result = struct {
    tokens: []const FirstPassToken,
    line_count: u32,
};

fn lexScalar(tokens: []FirstPassToken, aligned_file: AlignedFile, index: usize) Result {
    const file = aligned_file.buffer[0..aligned_file.real_size];
    var i: u32 = @intCast(index);
    var token_count: usize = 0;

    var line_count: u32 = 1;

    const start = if (benchmark) std.time.Instant.now() catch unreachable else {};

    while (i < file.len) switch (file[i]) {
        '\t', '\n', '\r', ' ', 0 => |ch| {
            tokens[token_count] = FirstPassToken{
                .id = .whitespace,
                .start = i,
                .len = 1,
            };
            line_count += @intFromBool(ch == '\n');
            token_count += 1;
            i += 1;
        },
        'a'...'z', 'A'...'Z' => {
            var start_index = i;
            while (true) {
                const ch = file[i];
                if ((ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z')) {
                    i += 1;
                    continue;
                }
                break;
            }
            const end = i;

            tokens[token_count] = FirstPassToken{
                .id = .identifier,
                .start = start_index,
                .len = @intCast(end - start_index),
            };
            token_count += 1;

            i += 1;
        },
        '0'...'9' => {
            var start_index = i;
            while (true) {
                const ch = file[i];
                if (ch >= '0' and ch <= '9') {
                    i += 1;
                    continue;
                }

                break;
            }

            const end = i;

            tokens[token_count] = FirstPassToken{
                .id = .number,
                .start = start_index,
                .len = @intCast(end - start_index),
            };
            token_count += 1;

            i += 1;
        },
        '=',
        '@',
        '\'',
        '"',
        ':',
        ';',
        '(',
        ')',
        '.',
        ',',
        '?',
        '!',
        '{',
        '}',
        '/',
        '\\',
        '-',
        '*',
        '`',
        '[',
        ']',
        '_',
        '&',
        '>',
        '<',
        '|',
        '+',
        '%',
        '#',
        '~',
        => {
            tokens[token_count] = FirstPassToken{
                .id = .operator,
                .start = i,
                .len = 1,
            };

            token_count += 1;
            i += 1;
        },
        else => |ch| std.debug.panic("Unhandled char: '{c}' (0x{x})", .{ ch, ch }), // unreachable,
    };

    if (benchmark) {
        const end = std.time.Instant.now() catch unreachable;
        const ns = end.since(start);
        const ns_f: f64 = @floatFromInt(ns);
        const byte_count = file.len;
        const megabytes_per_second = @as(f64, @floatFromInt(byte_count * 1000)) / ns_f;
        log.err("[SCALAR] {} bytes in {} ns ({d} MB/s, {d} LOC/s)", .{ byte_count, ns, megabytes_per_second, @as(f64, @floatFromInt(@as(usize, line_count) * 1000 * 1000 * 1000)) / ns_f });
    }

    return .{
        .tokens = tokens[0..token_count],
        .line_count = line_count,
    };
}

fn lexSimd(tokens: []FirstPassToken, file: AlignedFile) Result {
    const vectorized_file = file.vectorize();

    var still = false;
    var last_token: FirstPassToken = undefined;
    var token_count: usize = 0;
    var file_offset: u32 = 0;
    var line_count: u32 = 1;

    const start = if (benchmark) std.time.Instant.now() catch unreachable else {};
    var first: usize = 0;
    var second: usize = 0;

    for (vectorized_file) |chunk| {
        const first_start = std.time.Instant.now() catch unreachable;
        const is_space = is(chunk, ' ');
        const is_lf = is(chunk, '\n');
        const new_line_mask: u32 = @bitCast(is_lf);
        const new_line_count = @popCount(new_line_mask);
        line_count += new_line_count;
        const is_cr = is(chunk, '\r');
        const is_tab = is(chunk, '\t');
        const is_zero = is(chunk, 0);

        const is_lower = isInRangeInclusive(chunk, 'a', 'z');
        const is_upper = isInRangeInclusive(chunk, 'A', 'Z');
        const is_numeric = isInRangeInclusive(chunk, '0', '9');

        const is_operator = blk: {
            if (false) {
                const is_equal = is(chunk, '=');
                const is_at = is(chunk, '@');
                const is_single_quote = is(chunk, '\'');
                const is_double_quote = is(chunk, '"');
                const is_colon = is(chunk, ':');
                const is_semicolon = is(chunk, ';');
                const is_left_parenthesis = is(chunk, '(');
                const is_right_parenthesis = is(chunk, ')');
                const is_dot = is(chunk, '.');
                const is_comma = is(chunk, ',');
                const is_question_mark = is(chunk, '?');
                const is_exclamation_mark = is(chunk, '!');
                const is_left_brace = is(chunk, '{');
                const is_right_brace = is(chunk, '}');
                const is_slash = is(chunk, '/');
                const is_backslash = is(chunk, '\\');
                const is_dash = is(chunk, '-');
                const is_asterisk = is(chunk, '*');
                const is_tick = is(chunk, '`');
                const is_left_bracket = is(chunk, '[');
                const is_right_bracket = is(chunk, ']');
                const is_underscore = is(chunk, '_');
                const is_ampersand = is(chunk, '&');
                const is_greater = is(chunk, '>');
                const is_less = is(chunk, '<');
                const is_bar = is(chunk, '|');
                const is_plus = is(chunk, '+');
                const is_mod = is(chunk, '%');
                const is_hash = is(chunk, '#');
                const is_tilde = is(chunk, '~');
                // TODO: add more operators
                break :blk (is_equal | is_at) | (is_left_parenthesis | is_right_parenthesis) | (is_single_quote | is_double_quote) | (is_colon | is_semicolon) | (is_dot | is_comma) | (is_exclamation_mark | is_question_mark) | (is_left_brace | is_right_brace) | (is_slash | is_backslash) | (is_dash | is_asterisk) | (is_tick | is_underscore) | (is_left_bracket | is_right_bracket) | (is_ampersand | is_bar) | (is_greater | is_less) | (is_plus | is_mod) | (is_hash | is_tilde);
            } else {
                break :blk (isInRangeInclusive(chunk, '!', '/') | isInRangeInclusive(chunk, ':', '@')) | (isInRangeInclusive(chunk, '[', '`') | isInRangeInclusive(chunk, '{', '~'));
            }
        };
        const is_whitespace = ((is_space | is_lf) | (is_cr | is_tab)) | is_zero;
        const is_alpha = is_lower | is_upper;
        const arr_len = FirstPassToken.Id.count;
        const is_arr = [arr_len]U1Chunk{
            is_alpha,
            is_numeric,
            is_whitespace,
            is_operator,
        };

        const is_arr_bool: [arr_len]BoolChunk = @bitCast(is_arr);

        var offset: usize = 0;

        const first_end = std.time.Instant.now() catch unreachable;

        while (offset < chunk_len) {
            // const ch = chunk[offset];
            // print("CH: {c} {x} {b} {d}\n", .{ ch, ch, ch, ch });
            // TODO: use a lookup table to compute the shift at compile time and jump to it
            // because shifting for a variable value is very costly
            const offset_mask = ~((@as(ChunkMask, 1) << @as(u5, @intCast(offset))) - 1);
            const is_start = blk: {
                var result: @Vector(arr_len, bool) = undefined;
                inline for (0..is_arr_bool.len) |i| {
                    result[i] = is_arr_bool[i][offset];
                }

                break :blk result;
            };
            const is_start_u1: @Vector(arr_len, u1) = @bitCast(is_start);
            const is_start_mask: @Type(.{
                .Int = .{
                    .signedness = .unsigned,
                    .bits = arr_len,
                },
            }) = @bitCast(is_start_u1);
            const token_index = @ctz(is_start_mask);
            const mask_vector = is_arr_bool[token_index];
            const generic_mask = @as(ChunkMask, @bitCast(mask_vector));
            const mask = generic_mask & offset_mask;
            const inverse_mask = ~generic_mask & offset_mask;
            const start_offset_if_new = @ctz(mask);
            const start_index_vector = @select(ChunkMask, @Vector(1, bool){still}, @Vector(1, ChunkMask){last_token.start}, @Vector(1, ChunkMask){file_offset + start_offset_if_new});
            const start_index = start_index_vector[0];
            const next_offset = @ctz(inverse_mask);
            still = next_offset == chunk_len;
            const next_index = file_offset + next_offset;
            const token_len: u16 = @intCast(next_index - start_index);
            // print("Token index: {}\n", .{token_index});
            // const token_name = @tagName(@as(FirstPassToken.Id, @enumFromInt(token_index)));
            // _ = token_name;
            // assert(!still);
            // print("#{} {s}: '{s}'. Offset: {}. Offset mask: {b}. Start: {}. Mask: {b}. Next: {}. Next mask: {b}\n", .{ token_count, token_name, file[start_index..][0..token_len], offset, offset_mask, start_index, mask, next_index, inverse_mask });
            // TODO: take into account offset
            last_token = FirstPassToken{
                .start = start_index,
                .len = token_len,
                .id = @enumFromInt(token_index),
            };
            tokens[token_count] = last_token;
            token_count += @intFromBool(!still or is_arr_bool[@intFromEnum(FirstPassToken.Id.whitespace)][offset]);
            offset += next_offset - start_offset_if_new;
        }

        file_offset += chunk_len;

        const second_end = std.time.Instant.now() catch unreachable;
        second += second_end.since(first_end);
        first += first_end.since(first_start);
    }

    if (benchmark) {
        const end = std.time.Instant.now() catch unreachable;
        const ns = end.since(start);
        const ns_f: f64 = @floatFromInt(ns);
        const byte_count = file.real_size;
        const megabytes_per_second = @as(f64, @floatFromInt(byte_count * 1000)) / ns_f;
        log.err("[SIMD] {} bytes in {} ns ({d} MB/s, {d} LOC/s). First: {}. Second: {}", .{ byte_count, ns, megabytes_per_second, @as(f64, @floatFromInt(@as(usize, line_count) * 1000 * 1000 * 1000)) / ns_f, first, second });
    }

    return .{
        .tokens = tokens[0..token_count],
        .line_count = line_count,
    };
}

fn runSimd(file: AlignedFile) !void {
    // var tokens = try allocateTokens(allocator, file.len);
    try lexSimd(file);
    unreachable;
}

fn runScalar(file: AlignedFile) !void {
    // var tokens = try allocateTokens(allocator, file.len);
    try lexScalar(file, 0);
    // return tokens;
    unreachable;
}

// pub inline fn rdtsc() u64 {
//     var edx: u32 = undefined;
//     var eax: u32 = undefined;
//
//     asm volatile (
//         \\rdtsc
//         : [eax] "={eax}" (eax),
//           [edx] "={edx}" (edx),
//     );
//
//     return @as(u64, edx) << 32 | eax;
// }
//
// inline fn rdtscFast() u32 {
//     return asm volatile (
//         \\rdtsc
//         : [eax] "={eax}" (-> u32),
//         :
//         : "edx"
//     );
// }
//
// const vector_byte_count = 16;
// // These two actually take less space due to how Zig handles bool as u1
// const VBool = @Vector(vector_byte_count, bool);
// const U1Chunk = @Vector(vector_byte_count, u1);
//
// const VU8 = @Vector(vector_byte_count, u8);
//
// inline fn vand(v1: VBool, v2: VBool) VBool {
//     return @bitCast(@as(U1Chunk, @bitCast(v1)) & @as(U1Chunk, @bitCast(v2)));
// }
//
// inline fn byteMask(n: u8) VU8 {
//     return @splat(n);
// }
//
// inline fn endOfIdentifier(ch: u8) bool {
//     // TODO: complete
//     return ch == ' ' or ch == '(' or ch == ')';
// }
//
// pub const Identifier = struct {
//     start: u32,
//     end: u32,
// };
//
// pub const TokenId = enum {
//     identifier,
//     special_character,
//     keyword,
//     integer,
// };
//
// pub const TokenTypeMap = std.enums.directEnumArray(TokenId, type, 0, .{
//     .identifier = Identifier,
//     .special_character = SpecialCharacter,
//     .keyword = Keyword,
//     .integer = Integer,
// });
//
// pub const SpecialCharacter = enum(u8) {
//     arrow = 0,
//     left_parenthesis = '(',
//     right_parenthesis = ')',
//     left_brace = '{',
//     right_brace = '}',
// };
//
// pub const Keyword = enum {
//     @"return",
// };
//
// pub const Integer = struct {
//     number: u64,
//     negative: bool = false,
// };
//
// pub const Result = struct {
//     arrays: struct {
//         identifier: ArrayList(Identifier),
//         special_character: ArrayList(SpecialCharacter),
//         keyword: ArrayList(Keyword),
//         integer: ArrayList(Integer),
//         id: ArrayList(TokenId),
//     },
//     file: []const align(page_size) u8,
//     time: u64 = 0,
//
//     pub fn free(result: *Result, allocator: Allocator) void {
//         inline for (@typeInfo(@TypeOf(result.arrays)).Struct.fields) |field| {
//             @field(result.arrays, field.name).clearAndFree(allocator);
//         }
//         // result.identifiers.clearAndFree(allocator);
//         // result.special_character.clearAndFree(allocator);
//         // result.integer.clearAndFree(allocator);
//         // result.id.clearAndFree(allocator);
//     }
// };
//
// fn lex(allocator: Allocator, text: []const align(page_size) u8) !Result {
//     const time_start = std.time.Instant.now() catch unreachable;
//
//     var index: usize = 0;
//
//     var result = Result{
//         .arrays = .{
//             .identifier = try ArrayList(Identifier).initCapacity(allocator, text.len),
//             .special_character = try ArrayList(SpecialCharacter).initCapacity(allocator, text.len),
//             .keyword = try ArrayList(Keyword).initCapacity(allocator, text.len),
//             .integer = try ArrayList(Integer).initCapacity(allocator, text.len),
//             .id = try ArrayList(TokenId).initCapacity(allocator, text.len),
//         },
//         .file = text,
//     };
//
//     defer {
//         const time_end = std.time.Instant.now() catch unreachable;
//         result.time = time_end.since(time_start);
//     }
//
//     next_token: while (index < text.len) {
//         const first_char = text[index];
//         switch (first_char) {
//             'a'...'z', 'A'...'Z', '_' => {
//                 const start = index;
//                 // SIMD this
//                 while (!endOfIdentifier(text[index])) {
//                     index += 1;
//                 }
//
//                 const identifier = text[start..index];
//
//                 inline for (comptime std.enums.values(Keyword)) |keyword| {
//                     if (equal(u8, @tagName(keyword), identifier)) {
//                         result.arrays.keyword.appendAssumeCapacity(keyword);
//                         result.arrays.id.appendAssumeCapacity(.keyword);
//                         continue :next_token;
//                     }
//                 }
//
//                 result.arrays.identifier.appendAssumeCapacity(.{
//                     .start = @intCast(start),
//                     .end = @intCast(index),
//                 });
//
//                 result.arrays.id.appendAssumeCapacity(.identifier);
//             },
//             '(', ')', '{', '}' => |special_character| {
//                 result.arrays.special_character.appendAssumeCapacity(@enumFromInt(special_character));
//                 result.arrays.id.appendAssumeCapacity(.special_character);
//                 index += 1;
//             },
//             ' ', '\n' => index += 1,
//             '-' => {
//                 if (text[index + 1] == '>') {
//                     result.arrays.special_character.appendAssumeCapacity(.arrow);
//                     result.arrays.id.appendAssumeCapacity(.special_character);
//                     index += 2;
//                 } else {
//                     @panic("TODO");
//                 }
//             },
//             '0'...'9' => {
//                 const start = index;
//
//                 while (text[index] >= '0' and text[index] <= '9') {
//                     index += 1;
//                 }
//                 const end = index;
//                 const number_slice = text[start..end];
//                 const number = try std.fmt.parseInt(u64, number_slice, 10);
//                 result.arrays.integer.appendAssumeCapacity(.{
//                     .number = number,
//                     .negative = false,
//                 });
//                 result.arrays.id.appendAssumeCapacity(.integer);
//
//                 index += 1;
//             },
//             else => {
//                 index += 1;
//                 unreachable;
//             },
//         }
//     }
//
//     return result;
// }
//
// pub fn runTest(allocator: Allocator, file: []const align(page_size) u8) !Result {
//     const result = try lex(allocator, file);
//     errdefer result.free(allocator);
//
//     return result;
// }
//
// test "lexer" {
//     const allocator = std.testing.allocator;
//     const file_path = fs.first;
//     const file = try fs.readFile(allocator, file_path);
//     defer allocator.free(file);
//     var result = try runTest(allocator, file);
//     defer result.free(allocator);
// }
