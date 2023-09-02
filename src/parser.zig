const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const log = std.log;

const data_structures = @import("data_structures.zig");
const ArrayList = data_structures.ArrayList;

const lexer = @import("lexer.zig");

const Integer = lexer.Integer;
const Keyword = lexer.Keyword;

pub const Result = struct {
    functions: ArrayList(Function),
    strings: StringMap,
    integers: ArrayList(Integer),
    nodes: ArrayList(Node),

    pub fn free(result: *Result, allocator: Allocator) void {
        result.functions.clearAndFree(allocator);
        result.strings.clearAndFree(allocator);
        std.log.err("AAAAAAAAAAAAAA", .{});
    }
};

const PeekResult = union(lexer.TokenId) {
    identifier: lexer.Identifier,
    special_character: lexer.SpecialCharacter,
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
    indices: struct {
        identifier: u32 = 0,
        special_character: u32 = 0,
        keyword: u32 = 0,
        integer: u32 = 0,
        id: u32 = 0,
    } = .{},
    nodes: ArrayList(Node),
    strings: StringMap,
    integers: ArrayList(Integer),
    allocator: Allocator,
    functions: ArrayList(Function),

    fn free(parser: *Parser) void {
        parser.functions.clearAndFree(parser.allocator);
        parser.strings.clearAndFree(parser.allocator);
    }

    fn parse(parser: *Parser) !Result {
        errdefer parser.free();
        while (parser.indices.id < parser.lexer_result.arrays.id.items.len) {
            try parser.parseTopLevelDeclaration();
        }

        return Result{
            .functions = parser.functions,
            .strings = parser.strings,
            .integers = parser.integers,
            .nodes = parser.nodes,
        };
    }

    fn parseFunction(parser: *Parser, name: u32) !Function {
        assert(parser.lexer_result.arrays.special_character.items[parser.indices.special_character] == .left_parenthesis);
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

        try parser.parseBlock();

        return Function{
            .name = name,
            .statements = ArrayList(Statement){},
            .arguments = ArrayList(Function.Argument){},
            .return_type = return_type_identifier,
        };
    }
    fn parseBlock(parser: *Parser) !void {
        try parser.expectSpecialCharacter(.left_brace);

        while (parser.peek()) |next_token| {
            if (next_token == .special_character and next_token.special_character == .right_brace) break;
            const statement = try parser.parseStatement(next_token);
            _ = statement;
        }
    }

    fn parseStatement(parser: *Parser, start_token: PeekResult) !void {
        _ = start_token;
        try parser.parseAssignExpression();

        return error.not_implemented;
    }

    fn parseAssignExpression(parser: *Parser) !void {
        const expression = try parser.parseExpression();
        _ = expression;

        return error.not_implemented;
    }

    fn parseExpression(parser: *Parser) Parser.Error!Node.Index {
        return parser.parseExpressionPrecedence(0);
    }

    fn parseExpressionPrecedence(parser: *Parser, minimum_precedence: i32) !Node.Index {
        _ = minimum_precedence;

        const expr_index = try parser.parsePrefixExpression();
        log.debug("Expr index: {}", .{expr_index});

        while (true) {
            const peek_result = parser.peek() orelse unreachable;
            const node_index = try parser.parseExpressionPrecedence(1);
            log.debug("Node index: {}", .{node_index});
            _ = peek_result;
        }

        return error.not_implemented;
    }

    fn parsePrefixExpression(parser: *Parser) !Node.Index {
        switch (parser.peek() orelse unreachable) {
            // .bang => .bool_not,
            // .minus => .negation,
            // .tilde => .bit_not,
            // .minus_percent => .negation_wrap,
            // .ampersand => .address_of,
            // .keyword_try => .@"try",
            // .keyword_await => .@"await",

            else => return parser.parsePrimaryExpression(),
        }

        return error.not_implemented;
    }

    fn parsePrimaryExpression(parser: *Parser) !Node.Index {
        switch (parser.peek() orelse unreachable) {
            .keyword => |keyword| switch (keyword) {
                .@"return" => {
                    parser.indices.id += 1;
                    _ = try parser.parseExpression();
                    unreachable;
                },
            },
            .integer => |integer| {
                const index = parser.integers.items.len;
                try parser.integers.append(parser.allocator, integer);
                const node = Node{
                    .type = .integer,
                    .index = @intCast(index),
                };
                try parser.nodes.append(parser.allocator, node);
                return node.index;
            },
            else => |foo| @panic(@tagName(foo)),
        }

        return error.not_implemented;
    }

    // fn parseExpressionIdentifier(parser: *Parser, identifier: []const u8) !Node {
    //     _ = identifier;
    //     _ = parser;
    //
    //     return error.not_implemented;
    // }
    //
    // fn parseExpressionKeyword(parser: *Parser, keyword: Keyword) !Node {
    //     parser.consume(.keyword);
    //     switch (keyword) {
    //         .@"return" => {
    //             const return_expr = try parser.parseExpression();
    //             _ = return_expr;
    //             return error.not_implemented;
    //         },
    //     }
    //
    //     return error.not_implemented;
    // }
    //
    // fn parseExpressionInteger(parser: *Parser, integer: Integer) !Node {
    //     parser.consume(.integer);
    //
    //     const index = parser.integers.items.len;
    //     try parser.integers.append(parser.allocator, integer);
    //
    //     return .{
    //         .type = .integer,
    //         .index = @intCast(index),
    //     };
    // }

    inline fn consume(parser: *Parser, comptime token_id: lexer.TokenId) void {
        assert(parser.lexer_result.arrays.id.items[parser.indices.id] == token_id);
        parser.indices.id += 1;

        switch (token_id) {
            else => @field(parser.indices, @tagName(token_id)) += 1,
        }
    }

    inline fn expectTokenType(parser: *Parser, comptime expected_token_id: lexer.TokenId) !lexer.TokenTypeMap[@intFromEnum(expected_token_id)] {
        const peek_result = parser.peek() orelse return error.not_implemented;
        return switch (peek_result) {
            expected_token_id => |token| token,
            else => error.not_implemented,
        };
    }

    inline fn expectSpecificToken(parser: *Parser, comptime expected_token_id: lexer.TokenId, expected_token: lexer.TokenTypeMap[expected_token_id]) !void {
        const peek_result = parser.peek() orelse return error.not_implemented;
        switch (peek_result) {
            expected_token_id => |token| {
                if (expected_token != token) {
                    return error.not_implemented;
                }

                parser.consume(expected_token_id);
            },
            else => return error.not_implemented,
        }
    }

    inline fn peek(parser: *const Parser) ?PeekResult {
        if (parser.indices.id >= parser.lexer_result.arrays.id.items.len) {
            return null;
        }

        return switch (parser.lexer_result.arrays.id.items[parser.indices.id]) {
            // .identifier => .{
            //     .identifier = blk: {
            //         const identifier_range = parser.lexer_result.arrays.identifier.items[parser.indices.identifier];
            //         break :blk parser.lexer_result.file[identifier_range.start..identifier_range.end];
            //     },
            // },
            inline else => |token| blk: {
                var result: PeekResult = undefined;
                const tag = @tagName(token);
                const index = @field(parser.indices, tag);
                const array = &@field(parser.lexer_result.arrays, tag);
                @field(result, tag) = array.items[index];

                break :blk result;
            },
        };
    }

    fn parseTopLevelDeclaration(parser: *Parser) !void {
        const top_level_identifier = try parser.expectTokenType(.identifier);
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

    // fn expectSpecialCharacter(parser: *Parser, expected: lexer.SpecialCharacter) !void {
    //     const token_id = parser.lexer_result.arrays.id.items[parser.indices.id];
    //     if (token_id != .special_character) {
    //         return error.expected_special_character;
    //     }
    //
    //     defer parser.indices.id += 1;
    //
    //     const special_character = parser.lexer_result.arrays.special_character.items[parser.indices.special_character];
    //     if (special_character != expected) {
    //         return error.expected_different_special_character;
    //     }
    //
    //     parser.indices.special_character += 1;
    // }

    // fn acceptSpecialCharacter() void {}

    // fn expectIdentifier(parser: *Parser) !u32 {
    //     const token_id = parser.lexer_result.arrays.id.items[parser.indices.id];
    //     if (token_id != .identifier) {
    //         return Error.expected_identifier;
    //     }
    //
    //     parser.indices.id += 1;
    //
    //     const identifier_range = parser.lexer_result.arrays.identifier.items[parser.indices.identifier];
    //     parser.indices.identifier += 1;
    //     const identifier = parser.lexer_result.file[identifier_range.start..identifier_range.end];
    //     const Hash = std.hash.Wyhash;
    //     const seed = @intFromPtr(identifier.ptr);
    //     var hasher = Hash.init(seed);
    //     std.hash.autoHash(&hasher, identifier.ptr);
    //     const hash = hasher.final();
    //     const truncated_hash: u32 = @truncate(hash);
    //     try parser.strings.put(parser.allocator, truncated_hash, identifier);
    //     return truncated_hash;
    // }

    const Error = error{
        expected_identifier,
        expected_special_character,
        expected_different_special_character,
        not_implemented,
        OutOfMemory,
    };
};

pub fn runTest(allocator: Allocator, lexer_result: *const lexer.Result) !Result {
    var parser = Parser{
        .allocator = allocator,
        .nodes = ArrayList(Node){},
        .strings = StringMap{},
        .functions = ArrayList(Function){},
        .integers = ArrayList(Integer){},
        .lexer_result = lexer_result,
    };

    const result = try parser.parse();

    return result;
}

pub const Node = struct {
    type: Type,
    index: Index,

    pub const Index = u32;

    pub const Type = enum {
        integer,
    };
};
