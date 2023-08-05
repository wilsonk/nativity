const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const data_structures = @import("data_structures.zig");
const ArrayList = data_structures.ArrayList;

const lexer = @import("lexer.zig");

const Integer = lexer.Integer;
const Keyword = lexer.Keyword;

pub const Result = struct {
    functions: ArrayList(Function),
    strings: StringMap,

    pub fn free(result: *Result, allocator: Allocator) void {
        result.functions.clearAndFree(allocator);
        result.strings.clearAndFree(allocator);
    }
};

const PeekResult = union(lexer.TokenId) {
    special_character: lexer.SpecialCharacter,
    identifier: []const u8,
    keyword: Keyword,
    integer: Integer,
};

const Function = struct {
    name: u32,
    return_type: u32,
    arguments: ArrayList(Argument),
    statements: ArrayList(Statement),

    const Argument = struct {
        foo: u32 = 0,
    };
};

const Statement = struct {
    foo: u32 = 0,
};

const StringMap = std.AutoHashMapUnmanaged(u32, []const u8);

const Parser = struct {
    lexer_result: *const lexer.Result,
    id_index: u32 = 0,
    identifier_index: u32 = 0,
    special_character_index: u32 = 0,
    keyword_index: u32 = 0,
    integer_index: u32 = 0,
    strings: StringMap,
    allocator: Allocator,
    functions: ArrayList(Function),

    fn parse(parser: *Parser) !Result {
        while (parser.id_index < parser.lexer_result.ids.items.len) {
            try parser.parseTopLevelDeclaration();
        }

        return Result{
            .functions = parser.functions,
            .strings = parser.strings,
        };
    }

    fn parseFunction(parser: *Parser, name: u32) !Function {
        assert(parser.lexer_result.special_characters.items[parser.special_character_index] == .left_parenthesis);
        parser.consume(.special_character);

        while (true) {
            if (parser.expectSpecialCharacter(.right_parenthesis)) {
                break;
            } else |_| {
                return error.not_implemented;
            }
        }

        try parser.expectSpecialCharacter(.arrow);

        const return_type_identifier = try parser.expectIdentifier();

        try parser.expectSpecialCharacter(.left_brace);

        while (parser.peek()) |next_token| {
            switch (next_token) {
                .special_character => |special_character| if (special_character == .right_brace) break else unreachable,
                .identifier => |identifier| try parser.parseExpressionIdentifier(identifier),
                .keyword => |keyword| try parser.parseExpressionKeyword(keyword),
                .integer => |_| unreachable,
            }
        }

        return Function{
            .name = name,
            .statements = ArrayList(Statement){},
            .arguments = ArrayList(Function.Argument){},
            .return_type = return_type_identifier,
        };
    }

    fn parseExpression(parser: *Parser) !void {
        const next_token = parser.peek() orelse unreachable; // TODO: proper error message
        switch (next_token) {
            .integer => unreachable,
            else => @panic(@tagName(next_token)),
        }

        return error.not_implemented;
    }

    fn parseExpressionIdentifier(parser: *Parser, identifier: []const u8) !void {
        _ = identifier;
        _ = parser;

        return error.not_implemented;
    }

    fn parseExpressionKeyword(parser: *Parser, keyword: Keyword) !void {
        parser.consume(.keyword);
        switch (keyword) {
            .@"return" => {
                const return_expr = try parser.parseExpression();
                _ = return_expr;
                return error.not_implemented;
            },
        }

        return error.not_implemented;
    }

    inline fn consume(parser: *Parser, comptime token_id: lexer.TokenId) void {
        assert(parser.lexer_result.ids.items[parser.id_index] == token_id);
        parser.id_index += 1;

        switch (token_id) {
            .special_character => parser.special_character_index += 1,
            .identifier => parser.identifier_index += 1,
            .keyword => parser.keyword_index += 1,
            .integer => parser.integer_index += 1,
        }
    }

    fn parseTopLevelDeclaration(parser: *Parser) !void {
        const top_level_identifier = try parser.expectIdentifier();
        const next_token = parser.peek();

        switch (next_token.?) {
            .special_character => |special_character| switch (special_character) {
                .left_parenthesis => {
                    const function = try parser.parseFunction(top_level_identifier);
                    try parser.functions.append(parser.allocator, function);
                },
                else => return error.not_implemented,
            },
            .identifier => |identifier| {
                _ = identifier;
                return error.not_implemented;
            },
            .keyword => |keyword| {
                _ = keyword;

                return error.not_implemented;
            },
            .integer => |integer| {
                _ = integer;
                return error.not_implemented;
            },
        }
    }

    inline fn peek(parser: *const Parser) ?PeekResult {
        if (parser.id_index >= parser.lexer_result.ids.items.len) {
            return null;
        }

        return switch (parser.lexer_result.ids.items[parser.id_index]) {
            .special_character => .{
                .special_character = parser.lexer_result.special_characters.items[parser.special_character_index],
            },
            .identifier => .{
                .identifier = blk: {
                    const identifier_range = parser.lexer_result.identifiers.items[parser.identifier_index];
                    break :blk parser.lexer_result.file[identifier_range.start..identifier_range.end];
                },
            },
            .keyword => .{
                .keyword = parser.lexer_result.keywords.items[parser.keyword_index],
            },
            .integer => .{
                .integer = parser.lexer_result.integers.items[parser.integer_index],
            },
        };
    }

    fn expectSpecialCharacter(parser: *Parser, expected: lexer.SpecialCharacter) !void {
        const token_id = parser.lexer_result.ids.items[parser.id_index];
        if (token_id != .special_character) {
            return error.expected_special_character;
        }

        defer parser.id_index += 1;

        const special_character = parser.lexer_result.special_characters.items[parser.special_character_index];
        if (special_character != expected) {
            return error.expected_different_special_character;
        }

        parser.special_character_index += 1;
    }

    fn acceptSpecialCharacter() void {}

    fn expectIdentifier(parser: *Parser) !u32 {
        const token_id = parser.lexer_result.ids.items[parser.id_index];
        if (token_id != .identifier) {
            return Error.expected_identifier;
        }

        parser.id_index += 1;

        const identifier_range = parser.lexer_result.identifiers.items[parser.identifier_index];
        parser.identifier_index += 1;
        const identifier = parser.lexer_result.file[identifier_range.start..identifier_range.end];
        const Hash = std.hash.Wyhash;
        const seed = @intFromPtr(identifier.ptr);
        var hasher = Hash.init(seed);
        std.hash.autoHash(&hasher, identifier.ptr);
        const hash = hasher.final();
        const truncated_hash: u32 = @truncate(hash);
        try parser.strings.put(parser.allocator, truncated_hash, identifier);
        return truncated_hash;
    }

    const Error = error{
        expected_identifier,
        expected_special_character,
        expected_different_special_character,
        not_implemented,
    };
};

pub fn runTest(allocator: Allocator, lexer_result: *const lexer.Result) !Result {
    var parser = Parser{
        .allocator = allocator,
        .strings = StringMap{},
        .functions = ArrayList(Function){},
        .lexer_result = lexer_result,
    };

    return parser.parse() catch |err| {
        std.log.err("error: {}", .{err});
        return err;
    };
}
