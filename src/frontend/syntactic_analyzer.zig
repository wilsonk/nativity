const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const equal = std.mem.eql;
const log = std.log;

const data_structures = @import("../data_structures.zig");
const ArrayList = data_structures.ArrayList;
const enumFromString = data_structures.enumFromString;
const HashMap = data_structures.HashMap;

const lexical_analyzer = @import("lexical_analyzer.zig");
const Token = lexical_analyzer.Token;

const Compilation = @import("../Compilation.zig");
const File = Compilation.File;

pub const Result = struct {
    nodes: ArrayList(Node),
    node_lists: ArrayList(Node.List),
    time: u64,
};

pub const Options = packed struct {
    is_comptime: bool,
};

// TODO: pack it to be more efficient
pub const Node = packed struct(u128) {
    token: u32,
    id: Id,
    left: Node.Index,
    right: Node.Index,

    pub const List = ArrayList(Node.Index);

    pub const Index = packed struct(u32) {
        value: u31,
        valid: bool = true,

        pub const invalid = Index{
            .value = 0,
            .valid = false,
        };

        pub fn get(index: Index) ?u32 {
            return if (index.valid) index.value else null;
        }

        pub fn unwrap(index: Index) u32 {
            assert(index.valid);
            return index.value;
        }

        pub fn uniqueInteger(index: Index) u32 {
            assert(index.valid);
            return index.value;
        }
    };

    pub const Range = struct {
        start: u32,
        end: u32,
    };

    pub const Id = enum(u32) {
        main = 0,
        identifier = 1,
        number = 2,
        @"return" = 3,
        block_one = 4,
        function_declaration_no_arguments = 5,
        container_declaration = 6,
        string_literal = 7,
        compiler_intrinsic_one = 8,
        simple_variable_declaration = 9,
        assign = 10,
        @"comptime" = 11,
        node_list = 12,
        block_zero = 13,
        simple_while = 14,
        simple_function_prototype = 15,
        function_definition = 16,
        keyword_noreturn = 17,
        keyword_true = 18,
        comptime_block_zero = 19,
        comptime_block_one = 20,
        number_literal = 21,
        compiler_intrinsic_two = 22,
        comptime_block_two = 23,
        block_two = 24,
        @"unreachable" = 25,
        field_access = 26,
        call_one = 27,
        comptime_block = 28,
        block = 29,
        unsigned_integer_type = 30,
        signed_integer_type = 31,
        main_one = 32,
        main_two = 33,
        main_zero = 34,
        call_two = 35,
        slice_type = 36,
        argument_declaration = 37,
        compiler_intrinsic = 38,
        ssize_type = 39,
        usize_type = 40,
        void_type = 41,
        call = 42,
        many_pointer_type = 43,
        enum_literal = 44,
    };
};

const Error = error{
    unexpected_token,
    not_implemented,
    OutOfMemory,
};

const Analyzer = struct {
    tokens: []const Token,
    token_i: u32 = 0,
    nodes: ArrayList(Node) = .{},
    source_file: []const u8,
    file_index: File.Index,
    allocator: Allocator,
    temporal_node_heap: ArrayList(Node.Index) = .{},
    node_lists: ArrayList(Node.List) = .{},

    fn expectToken(analyzer: *Analyzer, token_id: Token.Id) !u32 {
        if (analyzer.tokens[analyzer.token_i].id == token_id) {
            const result = analyzer.token_i;
            analyzer.token_i += 1;
            return result;
        } else {
            return error.unexpected_token;
        }
    }

    fn bytes(analyzer: *const Analyzer, token_index: Token.Index) []const u8 {
        const token = analyzer.tokens[token_index];
        return analyzer.source_file[token.start..][0..token.len];
    }

    fn symbolDeclaration(analyzer: *Analyzer) !Node.Index {
        const first = analyzer.token_i;
        assert(analyzer.tokens[first].id == .fixed_keyword_var or analyzer.tokens[first].id == .fixed_keyword_const);
        analyzer.token_i += 1;
        const declaration_name_token = try analyzer.expectToken(.identifier);
        const declaration_name = analyzer.bytes(declaration_name_token);
        std.debug.print("Starting parsing declaration \"{s}\"\n", .{declaration_name});

        std.debug.print("Current token: {}\n", .{analyzer.tokens[analyzer.token_i].id});

        // TODO: type
        _ = try analyzer.expectToken(.equal);

        const init_node_index = try analyzer.expression();

        const init_node = analyzer.nodes.items[init_node_index.unwrap()];
        switch (init_node.id) {
            .function_definition => {},
            else => _ = try analyzer.expectToken(.semicolon),
        }

        // TODO:
        const type_node = Node.Index.invalid;
        const declaration = Node{
            .id = .simple_variable_declaration,
            .token = first,
            .left = type_node,
            .right = init_node_index,
        };

        std.debug.print("Adding declaration \"{s}\" with init node of type: {s}\n", .{ declaration_name, @tagName(init_node.id) });
        // if (analyzer.token_i < analyzer.tokens.len) {
        //     const first_token = analyzer.tokens[first];
        //     const last_token = analyzer.tokens[analyzer.token_i];
        //     const declaration_source_start = first_token.start;
        //     const declaration_source_end = last_token.start;
        //
        //     std.debug.print("[ALL]\n", .{});
        //     std.debug.print("Source file ({} bytes) :\n```\n{s}\n```\n", .{ analyzer.source_file.len, analyzer.source_file });
        //
        //     std.debug.print("[BEFORE]\n", .{});
        //
        //     std.debug.print("Tokens before the declaration: ", .{});
        //     for (analyzer.tokens[0..first]) |t| {
        //         std.debug.print("{s} ", .{@tagName(t.id)});
        //     }
        //     std.debug.print("\n", .{});
        //     std.debug.print("Source before the declaration:\n```\n{s}\n```\n", .{analyzer.source_file[0..analyzer.tokens[first].start]});
        //     std.debug.print("[DECLARATION]\n", .{});
        //
        //     std.debug.print("First token: {}\n", .{first_token});
        //     std.debug.print("Last token: {}\n", .{last_token});
        //
        //     std.debug.print("Tokens including declaration ([{}-{}])", .{ first, analyzer.token_i });
        //     for (analyzer.tokens[first..][0 .. analyzer.token_i - first]) |t| {
        //         std.debug.print("{s} ", .{@tagName(t.id)});
        //     }
        //     std.debug.print("\n", .{});
        //
        //     std.debug.print("Source for the declaration:\n```\n{s}\n```\n", .{analyzer.source_file[declaration_source_start..declaration_source_end]});
        //     std.debug.print("[AFTER]\n", .{});
        //
        //     // TODO
        //     // print("Tokens for file #{}\n", .{analyzer.
        //     // for (analyzer.tokens[
        // }

        return analyzer.addNode(declaration);
    }

    fn containerMembers(analyzer: *Analyzer) !Members {
        const node_heap_top = analyzer.temporal_node_heap.items.len;
        defer analyzer.temporal_node_heap.shrinkRetainingCapacity(node_heap_top);

        while (analyzer.token_i < analyzer.tokens.len) {
            const first = analyzer.token_i;
            std.debug.print("First token for container member: {s}\n", .{@tagName(analyzer.tokens[first].id)});
            const member_node_index: Node.Index = switch (analyzer.tokens[first].id) {
                .fixed_keyword_comptime => switch (analyzer.tokens[analyzer.token_i + 1].id) {
                    .left_brace => blk: {
                        analyzer.token_i += 1;
                        const comptime_block = try analyzer.block(.{ .is_comptime = true });

                        break :blk try analyzer.addNode(.{
                            .id = .@"comptime",
                            .token = first,
                            .left = comptime_block,
                            .right = Node.Index.invalid,
                        });
                    },
                    else => |foo| @panic(@tagName(foo)),
                },
                .fixed_keyword_const, .fixed_keyword_var => try analyzer.symbolDeclaration(),
                else => |t| @panic(@tagName(t)),
            };

            std.debug.print("Container member {s}\n", .{@tagName(analyzer.nodes.items[member_node_index.unwrap()].id)});

            try analyzer.temporal_node_heap.append(analyzer.allocator, member_node_index);
        }

        const members_array = analyzer.temporal_node_heap.items[node_heap_top..];
        const members: Members = switch (members_array.len) {
            1 => .{
                .len = 1,
                .left = members_array[0],
                .right = Node.Index.invalid,
            },
            2 => .{
                .len = 2,
                .left = members_array[0],
                .right = members_array[1],
            },
            else => |len| .{
                .len = len,
                .left = try analyzer.nodeList(members_array),
                .right = Node.Index.invalid,
            },
        };

        return members;
    }

    fn function(analyzer: *Analyzer) !Node.Index {
        const token = analyzer.token_i;
        assert(analyzer.tokens[token].id == .fixed_keyword_fn);
        analyzer.token_i += 1;
        const function_prototype = try analyzer.functionPrototype();
        const is_comptime = false;
        _ = is_comptime;
        const function_body = try analyzer.block(.{ .is_comptime = false });
        return analyzer.addNode(.{
            .id = .function_definition,
            .token = token,
            .left = function_prototype,
            .right = function_body,
        });
    }

    fn functionPrototype(analyzer: *Analyzer) !Node.Index {
        const token = analyzer.token_i;
        assert(analyzer.tokens[token].id == .left_parenthesis);
        const arguments = try analyzer.argumentList(.left_parenthesis, .right_parenthesis);
        const return_type = try analyzer.typeExpression();

        return analyzer.addNode(.{
            .id = .simple_function_prototype,
            .token = token,
            .left = arguments,
            .right = return_type,
        });
    }

    fn argumentList(analyzer: *Analyzer, maybe_start_token: ?Token.Id, end_token: Token.Id) !Node.Index {
        if (maybe_start_token) |start_token| {
            _ = try analyzer.expectToken(start_token);
        }

        var list = ArrayList(Node.Index){};

        var foo = false;
        while (analyzer.tokens[analyzer.token_i].id != end_token) {
            const identifier = try analyzer.expectToken(.identifier);
            _ = try analyzer.expectToken(.colon);
            const type_expression = try analyzer.typeExpression();
            // const type_expression_node = analyzer.nodes.items[type_expression.unwrap()];
            // _ = type_expression_node;
            // std.debug.print("Type expression node: {}\n", .{type_expression_node});
            foo = true;

            if (analyzer.tokens[analyzer.token_i].id == .comma) {
                analyzer.token_i += 1;
            }

            try list.append(analyzer.allocator, try analyzer.addNode(.{
                .id = .argument_declaration,
                .token = identifier,
                .left = type_expression,
                .right = Node.Index.invalid,
            }));
        }

        _ = try analyzer.expectToken(end_token);

        if (list.items.len != 0) {
            return analyzer.nodeList(list.items);
        } else {
            return Node.Index.invalid;
        }
    }

    fn assignExpressionStatement(analyzer: *Analyzer) !Node.Index {
        const result = try analyzer.assignExpression();
        _ = try analyzer.expectToken(.semicolon);
        return result;
    }

    fn block(analyzer: *Analyzer, options: Options) !Node.Index {
        const left_brace = try analyzer.expectToken(.left_brace);
        const node_heap_top = analyzer.temporal_node_heap.items.len;
        defer analyzer.temporal_node_heap.shrinkRetainingCapacity(node_heap_top);

        while (analyzer.tokens[analyzer.token_i].id != .right_brace) {
            const first_statement_token = analyzer.tokens[analyzer.token_i];
            std.debug.print("First statement token: {s}\n", .{@tagName(first_statement_token.id)});
            const statement_index = switch (first_statement_token.id) {
                .identifier => switch (analyzer.tokens[analyzer.token_i + 1].id) {
                    .colon => {
                        unreachable;
                    },
                    else => try analyzer.assignExpressionStatement(),
                },
                .fixed_keyword_unreachable, .fixed_keyword_return, .fixed_keyword_while, .fixed_keyword_switch => try analyzer.assignExpressionStatement(),
                // .fixed_keyword_while => try analyzer.whileExpression(options),
                // .fixed_keyword_switch => try analyzer.switchExpression(),
                .fixed_keyword_const, .fixed_keyword_var => try analyzer.symbolDeclaration(),
                else => |t| @panic(@tagName(t)),
            };

            const node = analyzer.nodes.items[statement_index.unwrap()];
            std.debug.print("Adding statement: {s}\n", .{@tagName(node.id)});

            try analyzer.temporal_node_heap.append(analyzer.allocator, statement_index);
        }

        _ = try analyzer.expectToken(.right_brace);

        const statement_array = analyzer.temporal_node_heap.items[node_heap_top..];
        const node: Node = switch (statement_array.len) {
            0 => .{
                .id = switch (options.is_comptime) {
                    true => .comptime_block_zero,
                    false => .block_zero,
                },
                .token = left_brace,
                .left = Node.Index.invalid,
                .right = Node.Index.invalid,
            },
            1 => .{
                .id = switch (options.is_comptime) {
                    true => .comptime_block_one,
                    false => .block_one,
                },
                .token = left_brace,
                .left = statement_array[0],
                .right = Node.Index.invalid,
            },
            2 => .{
                .id = switch (options.is_comptime) {
                    true => .comptime_block_two,
                    false => .block_two,
                },
                .token = left_brace,
                .left = statement_array[0],
                .right = statement_array[1],
            },
            else => .{
                .id = switch (options.is_comptime) {
                    true => .comptime_block,
                    false => .block,
                },
                .token = left_brace,
                .left = try analyzer.nodeList(statement_array),
                .right = Node.Index.invalid,
            },
        };

        return analyzer.addNode(node);
    }

    fn whileExpression(analyzer: *Analyzer, options: Options) anyerror!Node.Index {
        const while_identifier_index = try analyzer.expectToken(.fixed_keyword_while);

        _ = try analyzer.expectToken(.left_parenthesis);
        // TODO:
        const while_condition = try analyzer.expression();
        _ = try analyzer.expectToken(.right_parenthesis);

        const while_block = try analyzer.block(options);

        return analyzer.addNode(.{
            .id = .simple_while,
            .token = while_identifier_index,
            .left = while_condition,
            .right = while_block,
        });
    }

    fn switchExpression(analyzer: *Analyzer) !Node.Index {
        const switch_token = analyzer.token_i;
        _ = switch_token;
        analyzer.token_i += 1;
        _ = try analyzer.expectToken(.left_parenthesis);
        const switch_expression = try analyzer.expression();
        _ = switch_expression;
        _ = try analyzer.expectToken(.right_parenthesis);
        _ = try analyzer.expectToken(.left_brace);

        while (true) {
            const case_expr = try analyzer.expression();
            _ = case_expr;
            _ = try analyzer.expectToken(.equal);
            _ = try analyzer.expectToken(.greater);
            const expr = switch (analyzer.tokens[analyzer.token_i].id) {
                .left_brace => try analyzer.block(.{
                    .is_comptime = false,
                }),
                else => try analyzer.expression(),
            };
            _ = try analyzer.expectToken(.comma);
            _ = expr;
        }
        unreachable;
    }

    fn assignExpression(analyzer: *Analyzer) !Node.Index {
        const expr = try analyzer.expression();
        const expression_id: Node.Id = switch (analyzer.tokens[analyzer.token_i].id) {
            .semicolon => return expr,
            .equal => .assign,
            else => |t| @panic(@tagName(t)),
        };

        const node = Node{
            .id = expression_id,
            .token = blk: {
                const token_i = analyzer.token_i;
                analyzer.token_i += 1;
                break :blk token_i;
            },
            .left = expr,
            .right = try analyzer.expression(),
        };
        std.debug.print("assign:\nleft: {}.\nright: {}\n", .{ node.left, node.right });
        return analyzer.addNode(node);
    }

    fn compilerIntrinsic(analyzer: *Analyzer) !Node.Index {
        const hash = try analyzer.expectToken(.hash);
        _ = try analyzer.expectToken(.identifier);
        _ = try analyzer.expectToken(.left_parenthesis);

        const temporal_heap_top = analyzer.temporal_node_heap.items.len;
        defer analyzer.temporal_node_heap.shrinkRetainingCapacity(temporal_heap_top);

        while (analyzer.tokens[analyzer.token_i].id != .right_parenthesis) {
            const parameter = try analyzer.expression();
            try analyzer.temporal_node_heap.append(analyzer.allocator, parameter);

            switch (analyzer.tokens[analyzer.token_i].id) {
                .comma => analyzer.token_i += 1,
                .right_parenthesis => continue,
                else => unreachable,
            }
        }

        // Consume the right parenthesis
        analyzer.token_i += 1;

        const parameters = analyzer.temporal_node_heap.items[temporal_heap_top..];

        return switch (parameters.len) {
            1 => analyzer.addNode(.{
                .id = .compiler_intrinsic_one,
                .token = hash,
                .left = parameters[0],
                .right = Node.Index.invalid,
            }),
            2 => analyzer.addNode(.{
                .id = .compiler_intrinsic_two,
                .token = hash,
                .left = parameters[0],
                .right = parameters[1],
            }),
            else => analyzer.addNode(.{
                .id = .compiler_intrinsic,
                .token = hash,
                .left = try analyzer.nodeList(parameters),
                .right = Node.Index.invalid,
            }),
        };
    }

    fn expression(analyzer: *Analyzer) anyerror!Node.Index {
        return analyzer.expressionPrecedence(0);
    }

    fn expressionPrecedence(analyzer: *Analyzer, minimum_precedence: i32) !Node.Index {
        var result = try analyzer.prefixExpression();

        var banned_precedence: i32 = -1;

        while (analyzer.token_i < analyzer.tokens.len) {
            const token = analyzer.tokens[analyzer.token_i];
            // std.debug.print("Looping in expression precedence with token {}\n", .{token});
            const precedence: i32 = switch (token.id) {
                .equal, .semicolon, .right_parenthesis, .right_brace, .comma, .period, .fixed_keyword_const, .fixed_keyword_var => -1,
                else => |t| {
                    const start = token.start;
                    std.debug.print("Source file:\n```\n{s}\n```\n", .{analyzer.source_file[start..]});
                    @panic(@tagName(t));
                },
            };
            std.debug.print("Precedence: {} ({s})\n", .{ precedence, @tagName(token.id) });

            if (precedence < minimum_precedence) {
                // std.debug.print("Breaking for minimum_precedence\n", .{});
                break;
            }

            if (precedence == banned_precedence) {
                break;
            }

            // TODO: fix this
            const node_index = try analyzer.expressionPrecedence(1);
            _ = node_index;
            unreachable;
        }

        return result;
    }

    fn prefixExpression(analyzer: *Analyzer) !Node.Index {
        // std.debug.print("Prefix...\n", .{});
        switch (analyzer.tokens[analyzer.token_i].id) {
            // .bang => .bool_not,
            // .minus => .negation,
            // .tilde => .bit_not,
            // .minus_percent => .negation_wrap,
            // .ampersand => .address_of,
            // .keyword_try => .@"try",
            // .keyword_await => .@"await",

            else => |pref| {
                _ = pref;
                return analyzer.primaryExpression();
            },
        }

        return error.not_implemented;
    }

    fn primaryExpression(analyzer: *Analyzer) !Node.Index {
        const result = switch (analyzer.tokens[analyzer.token_i].id) {
            .identifier => switch (analyzer.tokens[analyzer.token_i + 1].id) {
                .colon => unreachable,
                else => try analyzer.curlySuffixExpression(),
            },
            .string_literal, .number_literal, .fixed_keyword_true, .fixed_keyword_false, .hash, .fixed_keyword_unreachable, .fixed_keyword_switch, .period => try analyzer.curlySuffixExpression(),
            .fixed_keyword_fn => analyzer.function(),
            .fixed_keyword_return => try analyzer.addNode(.{
                .id = .@"return",
                .token = blk: {
                    const token = analyzer.token_i;
                    analyzer.token_i += 1;
                    break :blk token;
                },
                .left = try analyzer.expression(),
                .right = Node.Index.invalid,
            }),
            // todo:?
            // .left_brace => try analyzer.block(),
            else => |id| {
                log.warn("By default, calling curlySuffixExpression with {s}", .{@tagName(id)});
                unreachable;
            },
        };

        return result;
    }

    fn curlySuffixExpression(analyzer: *Analyzer) !Node.Index {
        const left = try analyzer.typeExpression();

        return switch (analyzer.tokens[analyzer.token_i].id) {
            .left_brace => unreachable,
            else => left,
        };
    }

    fn noReturn(analyzer: *Analyzer) !Node.Index {
        const token_i = analyzer.token_i;
        assert(analyzer.tokens[token_i].id == .fixed_keyword_noreturn);
        analyzer.token_i += 1;
        return analyzer.addNode(.{
            .id = .keyword_noreturn,
            .token = token_i,
            .left = Node.Index.invalid,
            .right = Node.Index.invalid,
        });
    }

    fn boolTrue(analyzer: *Analyzer) !Node.Index {
        const token_i = analyzer.token_i;
        assert(analyzer.tokens[token_i].id == .fixed_keyword_true);
        analyzer.token_i += 1;
        return analyzer.addNode(.{
            .id = .keyword_true,
            .token = token_i,
            .left = Node.Index.invalid,
            .right = Node.Index.invalid,
        });
    }

    fn typeExpression(analyzer: *Analyzer) !Node.Index {
        const first = analyzer.token_i;
        return switch (analyzer.tokens[first].id) {
            else => try analyzer.errorUnionExpression(),
            .at => unreachable, // pointer
            .bang => unreachable, // error
            .left_bracket => switch (analyzer.tokens[analyzer.token_i + 1].id) {
                .at => {
                    // many item pointer
                    analyzer.token_i += 2;
                    _ = try analyzer.expectToken(.right_bracket);

                    const is_const = analyzer.tokens[analyzer.token_i].id == .fixed_keyword_const;
                    analyzer.token_i += @intFromBool(is_const);

                    const pointer_element_type = try analyzer.typeExpression();

                    return analyzer.addNode(.{
                        .id = .many_pointer_type,
                        .token = first,
                        .left = pointer_element_type,
                        .right = Node.Index.invalid,
                    });
                },
                else => {
                    const left_bracket = analyzer.token_i;
                    analyzer.token_i += 1;
                    // TODO: compute length
                    const length_expression = false;
                    _ = try analyzer.expectToken(.right_bracket);

                    // Slice
                    if (!length_expression) {
                        // TODO: modifiers
                        const is_const = analyzer.tokens[analyzer.token_i].id == .fixed_keyword_const;
                        analyzer.token_i += @intFromBool(is_const);

                        const slice_type = try analyzer.typeExpression();
                        return analyzer.addNode(.{
                            .id = .slice_type,
                            .token = left_bracket,
                            .left = Node.Index.invalid,
                            .right = slice_type,
                        });
                    } else {
                        unreachable;
                    }
                },
            },
        };
    }

    fn errorUnionExpression(analyzer: *Analyzer) !Node.Index {
        const suffix_expression = try analyzer.suffixExpression();

        return switch (analyzer.tokens[analyzer.token_i].id) {
            .bang => unreachable,
            else => suffix_expression,
        };
    }

    fn suffixExpression(analyzer: *Analyzer) !Node.Index {
        var result = try analyzer.primaryTypeExpression();

        while (true) {
            const suffix_operator = try analyzer.suffixOperator(result);
            if (suffix_operator.valid) {
                result = suffix_operator;
            } else {
                if (analyzer.tokens[analyzer.token_i].id == .left_parenthesis) {
                    const left_parenthesis = analyzer.token_i;
                    analyzer.token_i += 1;

                    var expression_list = ArrayList(Node.Index){};
                    while (analyzer.tokens[analyzer.token_i].id != .right_parenthesis) {
                        const current_token = analyzer.tokens[analyzer.token_i];
                        std.debug.print("Current token: {s}\n", .{@tagName(current_token.id)});
                        const parameter = try analyzer.expression();
                        try expression_list.append(analyzer.allocator, parameter);
                        const parameter_node = analyzer.nodes.items[parameter.unwrap()];
                        std.debug.print("Paremeter node: {s}\n", .{@tagName(parameter_node.id)});
                        const next_token = analyzer.tokens[analyzer.token_i];
                        std.debug.print("next token: {s}\n", .{@tagName(next_token.id)});
                        analyzer.token_i += @intFromBool(switch (next_token.id) {
                            .comma => true,
                            .colon, .right_brace, .right_bracket => unreachable,
                            .right_parenthesis => false,
                            else => |t| @panic(@tagName(t)),
                        });
                    }

                    _ = try analyzer.expectToken(.right_parenthesis);
                    // const is_comma = analyzer.tokens[analyzer.token_i].id == .comma;
                    return analyzer.addNode(switch (expression_list.items.len) {
                        0 => .{
                            .id = .call_one,
                            .token = left_parenthesis,
                            .left = result,
                            .right = Node.Index.invalid,
                        },
                        1 => .{
                            .id = .call_two,
                            .token = left_parenthesis,
                            .left = result,
                            .right = expression_list.items[0],
                        },
                        else => .{
                            .id = .call,
                            .token = left_parenthesis,
                            .left = result,
                            .right = try analyzer.nodeList(expression_list.items),
                        },
                    });
                } else {
                    return result;
                }
            }
        }

        unreachable;
    }

    fn primaryTypeExpression(analyzer: *Analyzer) !Node.Index {
        const token_i = analyzer.token_i;
        const token = analyzer.tokens[token_i];
        return switch (token.id) {
            .string_literal => blk: {
                analyzer.token_i += 1;
                break :blk analyzer.addNode(.{
                    .id = .string_literal,
                    .token = token_i,
                    .left = Node.Index.invalid,
                    .right = Node.Index.invalid,
                });
            },
            .number_literal => blk: {
                analyzer.token_i += 1;
                break :blk analyzer.addNode(.{
                    .id = .number_literal,
                    .token = token_i,
                    .left = Node.Index.invalid,
                    .right = Node.Index.invalid,
                });
            },
            .identifier => switch (analyzer.tokens[token_i + 1].id) {
                .colon => unreachable,
                else => blk: {
                    const identifier = analyzer.bytes(token_i);
                    // std.debug.print("identifier: {s}\n", .{identifier});
                    analyzer.token_i += 1;
                    if (equal(u8, identifier, "_")) {
                        break :blk Node.Index.invalid;
                    } else break :blk analyzer.addNode(.{
                        .id = .identifier,
                        .token = token_i,
                        .left = Node.Index.invalid,
                        .right = Node.Index.invalid,
                    });
                },
            },
            .fixed_keyword_noreturn => try analyzer.noReturn(),
            .fixed_keyword_true => try analyzer.boolTrue(),
            .fixed_keyword_unreachable => try analyzer.addNode(.{
                .id = .@"unreachable",
                .token = blk: {
                    analyzer.token_i += 1;
                    break :blk token_i;
                },
                .left = Node.Index.invalid,
                .right = Node.Index.invalid,
            }),
            .hash => analyzer.compilerIntrinsic(),
            .keyword_unsigned_integer, .keyword_signed_integer => |signedness| try analyzer.addNode(.{
                .id = switch (signedness) {
                    .keyword_unsigned_integer => .unsigned_integer_type,
                    .keyword_signed_integer => .signed_integer_type,
                    else => unreachable,
                },
                .token = blk: {
                    analyzer.token_i += 1;
                    break :blk token_i;
                },
                .left = @bitCast(@as(u32, try std.fmt.parseInt(u16, analyzer.bytes(token_i)[1..], 10))),
                .right = Node.Index.invalid,
            }),
            .fixed_keyword_usize, .fixed_keyword_ssize => |size_type| try analyzer.addNode(.{
                .id = switch (size_type) {
                    .fixed_keyword_usize => .usize_type,
                    .fixed_keyword_ssize => .ssize_type,
                    else => unreachable,
                },
                .token = blk: {
                    analyzer.token_i += 1;
                    break :blk token_i;
                },
                .left = Node.Index.invalid,
                .right = Node.Index.invalid,
            }),
            .fixed_keyword_void => try analyzer.addNode(.{
                .id = .void_type,
                .token = blk: {
                    analyzer.token_i += 1;
                    break :blk token_i;
                },
                .left = Node.Index.invalid,
                .right = Node.Index.invalid,
            }),
            .fixed_keyword_switch => try analyzer.switchExpression(),
            .period => switch (analyzer.tokens[token_i + 1].id) {
                .identifier => try analyzer.addNode(.{
                    .id = .enum_literal,
                    .token = blk: {
                        analyzer.token_i += 2;
                        break :blk token_i;
                    },
                    .left = Node.Index.invalid,
                    .right = Node.Index.invalid,
                }),
                else => |t| @panic(@tagName(t)),
            },
            else => |foo| {
                switch (foo) {
                    .identifier => std.debug.panic("{s}: {s}", .{ @tagName(foo), analyzer.bytes(token_i) }),
                    else => @panic(@tagName(foo)),
                }
            },
        };
    }

    // TODO:
    fn suffixOperator(analyzer: *Analyzer, left: Node.Index) !Node.Index {
        const token = analyzer.tokens[analyzer.token_i];
        return switch (token.id) {
            .left_bracket => unreachable,
            .period => switch (analyzer.tokens[analyzer.token_i + 1].id) {
                .identifier => analyzer.addNode(.{
                    .id = .field_access,
                    .token = blk: {
                        const main_token = analyzer.token_i;
                        analyzer.token_i += 1;
                        break :blk main_token;
                    },
                    .left = left,
                    .right = blk: {
                        //TODO ???
                        const right_token = analyzer.token_i;
                        analyzer.token_i += 1;
                        const result: Node.Index = @bitCast(right_token);
                        std.debug.print("WARNING: rhs has node index {} but it's token #{}\n", .{ result, right_token });
                        break :blk result;
                    },
                }),
                else => |t| @panic(@tagName(t)),
            },
            else => Node.Index.invalid,
        };
    }

    fn addNode(analyzer: *Analyzer, node: Node) !Node.Index {
        const index = analyzer.nodes.items.len;
        try analyzer.nodes.append(analyzer.allocator, node);
        // std.debug.print("Adding node #{} (0x{x}) {s} to file #{}\n", .{ index, @intFromPtr(&analyzer.nodes.items[index]), @tagName(node.id), analyzer.file_index.uniqueInteger() });
        // if (node.id == .identifier) {
        //     std.debug.print("Node identifier: {s}\n", .{analyzer.bytes(node.token)});
        // }
        // if (node.id == .call_two) {
        //     std.debug.print("Call two: {}\n", .{node});
        // }
        return Node.Index{
            .value = @intCast(index),
        };
    }

    fn nodeList(analyzer: *Analyzer, input: []const Node.Index) !Node.Index {
        const index = analyzer.node_lists.items.len;
        var new_node_list = try ArrayList(Node.Index).initCapacity(analyzer.allocator, input.len);
        try new_node_list.appendSlice(analyzer.allocator, input);
        try analyzer.node_lists.append(analyzer.allocator, new_node_list);
        return analyzer.addNode(.{
            .id = .node_list,
            .token = 0,
            .left = .{ .value = @intCast(index) },
            .right = Node.Index.invalid,
        });
    }
};

const Members = struct {
    len: usize,
    left: Node.Index,
    right: Node.Index,
};

pub fn analyze(allocator: Allocator, tokens: []const Token, source_file: []const u8, file_index: File.Index) !Result {
    const start = std.time.Instant.now() catch unreachable;
    var analyzer = Analyzer{
        .tokens = tokens,
        .source_file = source_file,
        .file_index = file_index,
        .allocator = allocator,
    };
    const node_index = try analyzer.addNode(.{
        .id = .main,
        .token = 0,
        .left = Node.Index.invalid,
        .right = Node.Index.invalid,
    });

    assert(node_index.value == 0);
    assert(node_index.valid);

    std.debug.print("Start Parsing file root members\n", .{});
    const members = try analyzer.containerMembers();
    std.debug.print("End Parsing file root members\n", .{});

    switch (members.len) {
        0 => unreachable,
        1 => {
            analyzer.nodes.items[0].id = .main_one;
            analyzer.nodes.items[0].left = members.left;
        },
        2 => {
            analyzer.nodes.items[0].id = .main_two;
            analyzer.nodes.items[0].left = members.left;
            analyzer.nodes.items[0].right = members.right;
        },
        else => {
            analyzer.nodes.items[0].id = .main;
            analyzer.nodes.items[0].left = members.left;
        },
    }

    const end = std.time.Instant.now() catch unreachable;

    analyzer.temporal_node_heap.clearAndFree(allocator);

    return .{
        .nodes = analyzer.nodes,
        .node_lists = analyzer.node_lists,
        .time = end.since(start),
    };
}

const ExpressionMutabilityQualifier = enum {
    @"const",
    @"var",
};

const Keyword = enum {
    @"return",
    @"fn",
    @"while",
    void,
    noreturn,
};

// These types are meant to be used by the semantic analyzer
pub const ContainerDeclaration = struct {
    members: []const Node.Index,
};

pub const SymbolDeclaration = struct {
    type_node: Node.Index,
    initialization_node: Node.Index,
    mutability_token: Token.Index,
};
