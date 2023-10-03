const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const equal = std.mem.eql;
const Compilation = @import("../Compilation.zig");
const File = Compilation.File;
const Module = Compilation.Module;
const Package = Compilation.Package;

const ArgumentList = Compilation.ArgumentList;
const Assignment = Compilation.Assignment;
const Block = Compilation.Block;
const Call = Compilation.Call;
const Declaration = Compilation.Declaration;
const Field = Compilation.Field;
const Function = Compilation.Function;
const Loop = Compilation.Loop;
const Scope = Compilation.Scope;
const ScopeType = Compilation.ScopeType;
const Struct = Compilation.Struct;
const Type = Compilation.Type;
const Value = Compilation.Value;

const lexical_analyzer = @import("lexical_analyzer.zig");
const Token = lexical_analyzer.Token;

const syntactic_analyzer = @import("syntactic_analyzer.zig");
const ContainerDeclaration = syntactic_analyzer.ContainerDeclaration;
const Node = syntactic_analyzer.Node;
const SymbolDeclaration = syntactic_analyzer.SymbolDeclaration;

const data_structures = @import("../data_structures.zig");
const ArrayList = data_structures.ArrayList;
const HashMap = data_structures.AutoHashMap;

const print = std.debug.print;

const Analyzer = struct {
    allocator: Allocator,
    module: *Module,
    current_file: File.Index,

    fn getScopeSourceFile(analyzer: *Analyzer, scope_index: Scope.Index) []const u8 {
        const scope = analyzer.module.scopes.get(scope_index);
        const file = analyzer.module.files.get(scope.file);
        return file.source_code;
    }

    fn getScopeNode(analyzer: *Analyzer, scope_index: Scope.Index, node_index: Node.Index) Node {
        const scope = analyzer.module.scopes.get(scope_index);
        const file = analyzer.module.files.get(scope.file);
        const result = &file.syntactic_analyzer_result.nodes.items[node_index.unwrap()];
        print("Fetching node #{} (0x{x}) from scope #{} from file #{} with id: {s}\n", .{ node_index.uniqueInteger(), @intFromPtr(result), scope_index.uniqueInteger(), scope.file.uniqueInteger(), @tagName(result.id) });
        return result.*;
    }

    fn getScopeToken(analyzer: *Analyzer, scope_index: Scope.Index, token_index: Token.Index) Token {
        const scope = analyzer.module.scopes.get(scope_index);
        const file = analyzer.module.files.get(scope.file);
        const result = file.lexical_analyzer_result.tokens.items[token_index];

        return result;
    }

    fn getScopeNodeList(analyzer: *Analyzer, scope_index: Scope.Index, node: Node) ArrayList(Node.Index) {
        const scope = analyzer.module.scopes.get(scope_index);
        return getFileNodeList(analyzer, scope.file, node);
    }

    fn getFileNodeList(analyzer: *Analyzer, file_index: File.Index, node: Node) ArrayList(Node.Index) {
        assert(node.id == .node_list);
        const file = analyzer.module.files.get(file_index);
        const list_index = node.left;
        return file.syntactic_analyzer_result.node_lists.items[list_index.uniqueInteger()];
    }

    fn getFileToken(analyzer: *Analyzer, file_index: File.Index, token: Token.Index) Token {
        const file = analyzer.module.files.get(file_index);
        const result = file.lexical_analyzer_result.tokens.items[token];
        return result;
    }

    fn getFileNode(analyzer: *Analyzer, file_index: File.Index, node_index: Node.Index) Node {
        const file = analyzer.module.files.get(file_index);
        const result = file.syntactic_analyzer_result.nodes.items[node_index.unwrap()];
        return result;
    }

    fn comptimeBlock(analyzer: *Analyzer, scope_index: Scope.Index, node_index: Node.Index) !Value.Index {
        const comptime_node = analyzer.getScopeNode(scope_index, node_index);

        const comptime_block = try analyzer.block(scope_index, .{ .none = {} }, comptime_node.left);
        const value_allocation = try analyzer.module.values.append(analyzer.allocator, .{
            .block = comptime_block,
        });
        return value_allocation.index;
    }

    fn unresolved(analyzer: *Analyzer, node_index: Node.Index) !Value.Allocation {
        const value_allocation = try analyzer.module.values.addOne(analyzer.allocator);
        value_allocation.ptr.* = .{
            .unresolved = .{
                .node_index = node_index,
            },
        };

        return value_allocation;
    }

    fn unresolvedAllocate(analyzer: *Analyzer, scope_index: Scope.Index, expect_type: ExpectType, node_index: Node.Index) !Value.Allocation {
        const new = try analyzer.unresolved(node_index);
        try analyzer.resolveNode(new.ptr, scope_index, expect_type, node_index);
        return new;
    }

    fn block(analyzer: *Analyzer, scope_index: Scope.Index, expect_type: ExpectType, node_index: Node.Index) anyerror!Block.Index {
        print("Resolving block from scope #{} in file #{}\n", .{ scope_index.uniqueInteger(), analyzer.module.scopes.get(scope_index).file.uniqueInteger() });
        var reaches_end = true;
        const block_node = analyzer.getScopeNode(scope_index, node_index);
        var statement_nodes = ArrayList(Node.Index){};
        switch (block_node.id) {
            .block_one, .comptime_block_one => {
                try statement_nodes.append(analyzer.allocator, block_node.left);
            },
            .block_zero, .comptime_block_zero => {},
            .block_two, .comptime_block_two => {
                try statement_nodes.append(analyzer.allocator, block_node.left);
                try statement_nodes.append(analyzer.allocator, block_node.right);
            },
            .block, .comptime_block => unreachable, //statement_nodes = analyzer.getNodeList(scope_index, block_node.left.unwrap()),
            else => |t| @panic(@tagName(t)),
        }

        const is_comptime = switch (block_node.id) {
            .comptime_block, .comptime_block_zero, .comptime_block_one, .comptime_block_two => true,
            .block, .block_zero, .block_one, .block_two => false,
            else => |t| @panic(@tagName(t)),
        };
        print("Is comptime: {}\n", .{is_comptime});

        var statements = ArrayList(Value.Index){};

        for (statement_nodes.items) |statement_node_index| {
            if (!reaches_end) {
                unreachable;
            }

            const statement_node = analyzer.getScopeNode(scope_index, statement_node_index);
            const statement_value = switch (statement_node.id) {
                inline .assign, .simple_while => |statement_id| blk: {
                    const specific_value_index = switch (statement_id) {
                        .assign => {
                            print("Assign: #{}\n", .{node_index.value});
                            assert(statement_node.id == .assign);
                            switch (statement_node.left.valid) {
                                // In an assignment, the node being invalid means a discarding underscore, like this: ```_ = result```
                                false => {
                                    const right_value_allocation = try analyzer.module.values.addOne(analyzer.allocator);
                                    right_value_allocation.ptr.* = .{
                                        .unresolved = .{
                                            .node_index = statement_node.right,
                                        },
                                    };
                                    try analyzer.resolveNode(right_value_allocation.ptr, scope_index, ExpectType.none, statement_node.right);
                                    // switch (right_value_allocation.ptr.*) {
                                    //     else => |t| std.debug.print("\n\n\n\n\nASSIGN RIGHT: {s}\n\n\n\n", .{@tagName(t)}),
                                    // }
                                    try statements.append(analyzer.allocator, right_value_allocation.index);
                                    continue;
                                },
                                true => {
                                    // const id = analyzer.tokenIdentifier(.token);
                                    // print("id: {s}\n", .{id});
                                    // const left = try analyzer.expression(scope_index, ExpectType.none, statement_node.left);

                                    // if (analyzer.module.values.get(left).isComptime() and analyzer.module.values.get(right).isComptime()) {
                                    //     unreachable;
                                    // } else {
                                    //                                 const assignment_index = try analyzer.module.assignments.append(analyzer.allocator, .{
                                    //                                     .store = result.left,
                                    //                                     .load = result.right,
                                    //                                 });
                                    //                                 return assignment_index;
                                    // }
                                    unreachable;
                                },
                            }
                        },
                        .simple_while => statement: {
                            const loop_allocation = try analyzer.module.loops.append(analyzer.allocator, .{
                                .condition = Value.Index.invalid,
                                .body = Value.Index.invalid,
                                .breaks = false,
                            });
                            loop_allocation.ptr.condition = (try analyzer.unresolvedAllocate(scope_index, ExpectType.boolean, statement_node.left)).index;
                            loop_allocation.ptr.body = (try analyzer.unresolvedAllocate(scope_index, ExpectType.none, statement_node.right)).index;

                            // TODO: bool true
                            reaches_end = loop_allocation.ptr.breaks or unreachable;

                            break :statement loop_allocation.index;
                        },
                        else => unreachable,
                    };
                    const value = @unionInit(Value, switch (statement_id) {
                        .assign => "assign",
                        .simple_while => "loop",
                        else => unreachable,
                    }, specific_value_index);
                    const value_allocation = try analyzer.module.values.append(analyzer.allocator, value);
                    break :blk value_allocation.index;
                },
                .@"unreachable" => blk: {
                    reaches_end = false;
                    break :blk Values.@"unreachable".getIndex();
                },
                .simple_variable_declaration => (try analyzer.module.values.append(analyzer.allocator, .{
                    .declaration = try analyzer.symbolDeclaration(scope_index, statement_node_index, .local),
                })).index,
                .@"return" => blk: {
                    reaches_end = false;
                    const return_expression: Value.Index = switch (statement_node_index.valid) {
                        // TODO: expect type
                        true => ret: {
                            const return_value_allocation = try analyzer.module.values.addOne(analyzer.allocator);
                            return_value_allocation.ptr.* = .{
                                .unresolved = .{
                                    .node_index = statement_node.left,
                                },
                            };
                            try analyzer.resolveNode(return_value_allocation.ptr, scope_index, expect_type, statement_node.left);
                            break :ret return_value_allocation.index;
                        },
                        false => @panic("TODO: ret void"),
                    };

                    const return_value_allocation = try analyzer.module.returns.append(analyzer.allocator, .{
                        .value = return_expression,
                    });

                    const return_expression_value_allocation = try analyzer.module.values.append(analyzer.allocator, .{
                        .@"return" = return_value_allocation.index,
                    });

                    break :blk return_expression_value_allocation.index;
                },
                .call_two, .call => (try analyzer.module.values.append(analyzer.allocator, .{
                    .call = try analyzer.processCall(scope_index, statement_node_index),
                })).index,
                else => |t| @panic(@tagName(t)),
            };

            try statements.append(analyzer.allocator, statement_value);
        }

        const block_allocation = try analyzer.module.blocks.append(analyzer.allocator, .{
            .statements = statements,
            .reaches_end = reaches_end,
        });

        return block_allocation.index;
    }

    fn processCall(analyzer: *Analyzer, scope_index: Scope.Index, node_index: Node.Index) !Call.Index {
        const node = analyzer.getScopeNode(scope_index, node_index);
        print("Node index: {}. Left index: {}\n", .{ node_index.uniqueInteger(), node.left.uniqueInteger() });
        assert(node.left.valid);
        const left_value_index = switch (node.left.valid) {
            true => blk: {
                const member_or_namespace_node_index = node.left;
                assert(member_or_namespace_node_index.valid);
                const this_value_allocation = try analyzer.unresolvedAllocate(scope_index, ExpectType.none, member_or_namespace_node_index);
                break :blk this_value_allocation.index;
            },
            false => unreachable, //Value.Index.invalid,
        };

        const left_type = switch (left_value_index.valid) {
            true => switch (analyzer.module.values.get(left_value_index).*) {
                .function => |function_index| analyzer.module.function_prototypes.get(analyzer.module.functions.get(function_index).prototype).return_type,
                else => |t| @panic(@tagName(t)),
            },
            false => Type.Index.invalid,
        };
        const arguments_index = switch (node.id) {
            .call, .call_two => |call_tag| (try analyzer.module.argument_lists.append(analyzer.allocator, .{
                .array = b: {
                    const argument_list_node_index = node.right;
                    const call_argument_node_list = switch (call_tag) {
                        .call => analyzer.getScopeNodeList(scope_index, analyzer.getScopeNode(scope_index, argument_list_node_index)).items,
                        .call_two => &.{argument_list_node_index},
                        else => unreachable,
                    };

                    switch (analyzer.module.values.get(left_value_index).*) {
                        .function => |function_index| {
                            const function = analyzer.module.functions.get(function_index);
                            const function_prototype = analyzer.module.function_prototypes.get(function.prototype);
                            const argument_declarations = function_prototype.arguments.?;
                            print("Argument declaration count: {}. Argument node list count: {}\n", .{ argument_declarations.len, call_argument_node_list.len });
                            var argument_array = ArrayList(Value.Index){};
                            if (argument_declarations.len == call_argument_node_list.len) {
                                for (argument_declarations, call_argument_node_list) |argument_declaration_index, argument_node_index| {
                                    const argument_declaration = analyzer.module.declarations.get(argument_declaration_index);
                                    assert(argument_declaration.type.valid);
                                    const argument_allocation = try analyzer.unresolvedAllocate(scope_index, ExpectType{
                                        .type_index = argument_declaration.type,
                                    }, argument_node_index);
                                    try argument_array.append(analyzer.allocator, argument_allocation.index);
                                }

                                break :b argument_array;
                            } else {
                                std.debug.panic("Function call has argument count mismatch: call has {}, function declaration has {}\n", .{ call_argument_node_list.len, argument_declarations.len });
                            }
                        },
                        else => |t| @panic(@tagName(t)),
                    }
                },
            })).index,
            .call_one => ArgumentList.Index.invalid,
            else => |t| @panic(@tagName(t)),
        };
        const call_allocation = try analyzer.module.calls.append(analyzer.allocator, .{
            .value = left_value_index,
            .arguments = arguments_index,

            .type = left_type,
        });

        return call_allocation.index;
    }

    const DeclarationLookup = struct {
        declaration: Declaration.Index,
        scope: Scope.Index,
    };

    fn lookupDeclarationInCurrentAndParentScopes(analyzer: *Analyzer, scope_index: Scope.Index, identifier_hash: u32) ?DeclarationLookup {
        var scope_iterator = scope_index;
        while (scope_iterator.valid) {
            const scope = analyzer.module.scopes.get(scope_iterator);
            if (scope.declarations.get(identifier_hash)) |declaration_index| {
                return .{
                    .declaration = declaration_index,
                    .scope = scope_iterator,
                };
            }

            scope_iterator = scope.parent;
        }

        return null;
    }

    fn doIdentifier(analyzer: *Analyzer, scope_index: Scope.Index, expect_type: ExpectType, node_token: Token.Index, node_scope_index: Scope.Index) !Value.Index {
        const identifier = analyzer.tokenIdentifier(node_scope_index, node_token);
        print("Referencing identifier: \"{s}\"\n", .{identifier});
        const identifier_hash = try analyzer.processIdentifier(identifier);

        if (analyzer.lookupDeclarationInCurrentAndParentScopes(scope_index, identifier_hash)) |lookup| {
            const declaration_index = lookup.declaration;
            const declaration = analyzer.module.declarations.get(declaration_index);

            // Up until now, only arguments have no initialization value
            if (declaration.init_value.valid) {
                const init_value = analyzer.module.values.get(declaration.init_value);
                print("Declaration found: {}\n", .{init_value});
                switch (init_value.*) {
                    .unresolved => |ur| try analyzer.resolveNode(init_value, lookup.scope, expect_type, ur.node_index),
                    else => {},
                }
                print("Declaration resolved as: {}\n", .{init_value});
                print("Declaration mutability: {s}. Is comptime: {}\n", .{ @tagName(declaration.mutability), init_value.isComptime() });

                if (init_value.isComptime() and declaration.mutability == .@"const") {
                    return declaration.init_value;
                }
            }

            const ref_allocation = try analyzer.module.values.append(analyzer.allocator, .{
                .declaration_reference = declaration_index,
            });
            return ref_allocation.index;
        } else {
            const scope = analyzer.module.scopes.get(scope_index);
            std.debug.panic("Identifier \"{s}\" not found in scope #{} of file #{} referenced by scope #{} of file #{}: {s}", .{ identifier, scope_index.uniqueInteger(), scope.file.uniqueInteger(), node_scope_index.uniqueInteger(), analyzer.module.scopes.get(node_scope_index).file.uniqueInteger(), tokenBytes(analyzer.getScopeToken(scope_index, node_token), analyzer.getScopeSourceFile(scope_index)) });
        }
    }

    fn getArguments(analyzer: *Analyzer, scope_index: Scope.Index, node_index: Node.Index) !ArrayList(Node.Index) {
        var arguments = ArrayList(Node.Index){};
        const node = analyzer.getScopeNode(scope_index, node_index);
        switch (node.id) {
            .compiler_intrinsic_two => {
                try arguments.append(analyzer.allocator, node.left);
                try arguments.append(analyzer.allocator, node.right);
            },
            .compiler_intrinsic => {
                const argument_list_node_index = node.left;
                assert(argument_list_node_index.valid);
                const node_list_node = analyzer.getScopeNode(scope_index, argument_list_node_index);
                const node_list = analyzer.getScopeNodeList(scope_index, node_list_node);

                return node_list;
            },
            else => |t| @panic(@tagName(t)),
        }

        return arguments;
    }

    fn resolveNode(analyzer: *Analyzer, value: *Value, scope_index: Scope.Index, expect_type: ExpectType, node_index: Node.Index) anyerror!void {
        const node = analyzer.getScopeNode(scope_index, node_index);
        print("Resolving node #{} in scope #{} from file #{}: {}\n", .{ node_index.uniqueInteger(), scope_index.uniqueInteger(), analyzer.module.scopes.get(scope_index).file.uniqueInteger(), node });

        assert(value.* == .unresolved);

        value.* = switch (node.id) {
            .identifier => blk: {
                const value_index = try analyzer.doIdentifier(scope_index, expect_type, node.token, scope_index);
                const value_ref = analyzer.module.values.get(value_index);
                break :blk value_ref.*;
            },
            .keyword_true => {
                switch (expect_type) {
                    .none => {},
                    .type_index => |expected_type| {
                        if (@as(u32, @bitCast(type_boolean)) != @as(u32, @bitCast(expected_type))) {
                            @panic("TODO: compile error");
                        }
                    },
                    else => unreachable,
                }

                // TODO
                unreachable;

                // break :blk Values.getIndex(.bool_true);
            },
            .compiler_intrinsic_one, .compiler_intrinsic_two, .compiler_intrinsic => blk: {
                const intrinsic_name = analyzer.tokenIdentifier(scope_index, node.token + 1);
                const intrinsic = data_structures.enumFromString(Intrinsic, intrinsic_name) orelse unreachable;
                print("Intrinsic: {s}\n", .{@tagName(intrinsic)});
                switch (intrinsic) {
                    .import => {
                        assert(node.id == .compiler_intrinsic_one);
                        const import_argument = analyzer.getScopeNode(scope_index, node.left);
                        switch (import_argument.id) {
                            .string_literal => {
                                const import_name = analyzer.tokenStringLiteral(scope_index, import_argument.token);
                                const import_file = try analyzer.module.importFile(analyzer.allocator, analyzer.current_file, import_name);
                                print("Importing \"{s}\"...\n", .{import_name});

                                const result = .{
                                    .type = switch (import_file.file.is_new) {
                                        true => true_block: {
                                            const new_file_index = import_file.file.index;
                                            if (equal(u8, import_name, "os.nat")) {
                                                print("FOOO\n", .{});
                                            }
                                            try analyzer.module.generateAbstractSyntaxTreeForFile(analyzer.allocator, new_file_index);
                                            if (equal(u8, import_name, "os.nat")) {
                                                unreachable;
                                            }
                                            const analyze_result = try analyzeFile(value, analyzer.allocator, analyzer.module, new_file_index);
                                            if (equal(u8, import_name, "os.nat")) {
                                                unreachable;
                                            }
                                            print("Done analyzing {s}!\n", .{import_name});
                                            break :true_block analyze_result;
                                        },
                                        false => false_block: {
                                            const file_type = import_file.file.ptr.type;
                                            assert(file_type.valid);
                                            break :false_block file_type;
                                        },
                                    },
                                };

                                break :blk result;
                            },
                            else => unreachable,
                        }
                    },
                    .syscall => {
                        var argument_nodes = try analyzer.getArguments(scope_index, node_index);
                        print("Argument count: {}\n", .{argument_nodes.items.len});
                        if (argument_nodes.items.len > 0 and argument_nodes.items.len <= 6 + 1) {
                            const number_allocation = try analyzer.unresolvedAllocate(scope_index, .{
                                .flexible_integer = .{
                                    .byte_count = 8,
                                },
                            }, argument_nodes.items[0]);
                            const number = number_allocation.index;
                            assert(number.valid);
                            var arguments = std.mem.zeroes([6]Value.Index);
                            for (argument_nodes.items[1..], 0..) |argument_node_index, argument_index| {
                                const argument_allocation = try analyzer.unresolvedAllocate(scope_index, ExpectType.none, argument_node_index);
                                arguments[argument_index] = argument_allocation.index;
                            }

                            // TODO: typecheck for usize
                            for (arguments[0..argument_nodes.items.len]) |argument| {
                                _ = argument;
                            }

                            break :blk .{
                                .syscall = (try analyzer.module.syscalls.append(analyzer.allocator, .{
                                    .number = number,
                                    .arguments = arguments,
                                    .argument_count = @intCast(argument_nodes.items.len - 1),
                                })).index,
                            };
                        } else {
                            unreachable;
                        }
                    },
                }
                unreachable;
            },
            .function_definition => blk: {
                const function_scope_allocation = try analyzer.allocateScope(.{
                    .parent = scope_index,
                    .file = analyzer.module.scopes.get(scope_index).file,
                });

                const function_prototype_index = try analyzer.functionPrototype(function_scope_allocation.index, node.left);

                const function_body = try analyzer.block(function_scope_allocation.index, .{
                    .type_index = analyzer.functionPrototypeReturnType(function_prototype_index),
                }, node.right);

                const function_allocation = try analyzer.module.functions.append(analyzer.allocator, .{
                    .prototype = function_prototype_index,
                    .body = function_body,
                    .scope = function_scope_allocation.index,
                });
                break :blk .{
                    .function = function_allocation.index,
                };
            },
            .simple_while => unreachable,
            .block_zero, .block_one => blk: {
                const block_index = try analyzer.block(scope_index, expect_type, node_index);
                break :blk .{
                    .block = block_index,
                };
            },
            .number_literal => switch (std.zig.parseNumberLiteral(analyzer.numberBytes(scope_index, node.token))) {
                .int => |integer| blk: {
                    assert(expect_type != .none);
                    const int_type = switch (expect_type) {
                        .flexible_integer => |flexible_integer_type| Compilation.Type.Integer{
                            .bit_count = flexible_integer_type.byte_count << 3,
                            .signedness = .unsigned,
                        },
                        .type_index => |type_index| a: {
                            const type_info = analyzer.module.types.get(type_index);
                            break :a switch (type_info.*) {
                                .integer => |int| int,
                                else => |t| @panic(@tagName(t)),
                            };
                        },
                        else => |t| @panic(@tagName(t)),
                    };
                    break :blk .{
                        .integer = .{
                            .value = integer,
                            .type = int_type,
                        },
                    };
                },
                else => |t| @panic(@tagName(t)),
            },
            .call, .call_one => .{
                .call = try analyzer.processCall(scope_index, node_index),
            },
            .field_access => blk: {
                const left_allocation = try analyzer.unresolvedAllocate(scope_index, ExpectType.none, node.left);
                const identifier = analyzer.tokenIdentifier(scope_index, node.right.value);
                print("Field access identifier for RHS: \"{s}\"\n", .{identifier});
                switch (left_allocation.ptr.*) {
                    .type => |type_index| {
                        const left_type = analyzer.module.types.get(type_index);
                        switch (left_type.*) {
                            .@"struct" => |struct_index| {
                                const struct_type = analyzer.module.structs.get(struct_index);
                                const right_index = try analyzer.doIdentifier(struct_type.scope, ExpectType.none, node.right.value, scope_index);
                                const right_value = analyzer.module.values.get(right_index);
                                switch (right_value.*) {
                                    .function, .type => break :blk right_value.*,
                                    else => |t| @panic(@tagName(t)),
                                }
                                print("Right: {}\n", .{right_value});
                                // struct_scope.declarations.get(identifier);

                                unreachable;
                            },
                            else => |t| @panic(@tagName(t)),
                        }
                        unreachable;
                    },
                    .declaration_reference => |declaration_reference| {
                        switch (left_allocation.ptr.*) {
                            .declaration_reference => |decl_index| {
                                const declaration = analyzer.module.declarations.get(decl_index);
                                const declaration_type_index = switch (declaration.is_argument) {
                                    true => declaration.type,
                                    false => unreachable,
                                };
                                const declaration_type = analyzer.module.types.get(declaration_type_index);
                                switch (declaration_type.*) {
                                    .slice => unreachable,
                                    else => |t| @panic(@tagName(t)),
                                }
                            },
                            else => |t| @panic(@tagName(t)),
                        }
                        _ = declaration_reference;
                        unreachable;
                    },
                    else => |t| @panic(@tagName(t)),
                }
                unreachable;
            },
            .string_literal => .{
                .string_literal = try analyzer.processStringLiteral(scope_index, node_index),
            },
            else => |t| @panic(@tagName(t)),
        };
    }

    fn processStringLiteral(analyzer: *Analyzer, scope_index: Scope.Index, node_index: Node.Index) !u32 {
        const string_literal_node = analyzer.getScopeNode(scope_index, node_index);
        assert(string_literal_node.id == .string_literal);
        const string_literal = analyzer.tokenStringLiteral(scope_index, string_literal_node.token);
        const string_key = try analyzer.module.addStringLiteral(analyzer.allocator, string_literal);
        return string_key;
    }

    fn functionPrototypeReturnType(analyzer: *Analyzer, function_prototype_index: Function.Prototype.Index) Type.Index {
        const function_prototype = analyzer.module.function_prototypes.get(function_prototype_index);
        return function_prototype.return_type;
    }

    fn resolveType(analyzer: *Analyzer, scope_index: Scope.Index, node_index: Node.Index) !Type.Index {
        const type_node = analyzer.getScopeNode(scope_index, node_index);
        const type_index: Type.Index = switch (type_node.id) {
            .identifier => {
                const token = analyzer.getScopeToken(scope_index, type_node.token);
                const source_file = analyzer.getScopeSourceFile(scope_index);
                const identifier = tokenBytes(token, source_file);
                print("Identifier: \"{s}\"\n", .{identifier});
                unreachable;
            },
            .keyword_noreturn => .{ .block = 0, .index = FixedTypeKeyword.offset + @intFromEnum(FixedTypeKeyword.noreturn) },
            inline .signed_integer_type, .unsigned_integer_type => |int_type_signedness| blk: {
                const bit_count: u16 = @intCast(type_node.left.value);
                print("Bit count: {}\n", .{bit_count});
                break :blk switch (bit_count) {
                    inline 8, 16, 32, 64 => |hardware_bit_count| Type.Index{
                        .block = 0,
                        .index = @ctz(hardware_bit_count) - @ctz(@as(u8, 8)) + switch (int_type_signedness) {
                            .signed_integer_type => HardwareSignedIntegerType,
                            .unsigned_integer_type => HardwareUnsignedIntegerType,
                            else => unreachable,
                        }.offset,
                    },
                    else => unreachable,
                };
            },
            .many_pointer_type => blk: {
                const type_allocation = try analyzer.module.types.append(analyzer.allocator, .{
                    .pointer = .{
                        .element_type = try resolveType(analyzer, scope_index, type_node.left),
                        .many = true,
                    },
                });
                break :blk type_allocation.index;
            },
            .slice_type => blk: {
                const type_allocation = try analyzer.module.types.append(analyzer.allocator, .{
                    .slice = .{
                        .element_type = try resolveType(analyzer, scope_index, type_node.right),
                    },
                });
                break :blk type_allocation.index;
            },
            .void_type => type_void,
            .ssize_type => type_ssize,
            .usize_type => type_usize,
            else => |t| @panic(@tagName(t)),
        };
        return type_index;
    }

    fn functionPrototype(analyzer: *Analyzer, scope_index: Scope.Index, node_index: Node.Index) !Function.Prototype.Index {
        const function_prototype_node = analyzer.getScopeNode(scope_index, node_index);
        switch (function_prototype_node.id) {
            .simple_function_prototype => {
                print("Function prototype node: {}\n", .{node_index.uniqueInteger()});
                const arguments: ?[]const Declaration.Index = switch (function_prototype_node.left.get() == null) {
                    true => null,
                    false => blk: {
                        const argument_list_node = analyzer.getScopeNode(scope_index, function_prototype_node.left);
                        // print("Function prototype argument list node: {}\n", .{function_prototype_node.left.uniqueInteger()});
                        const argument_node_list = switch (argument_list_node.id) {
                            .node_list => analyzer.getScopeNodeList(scope_index, argument_list_node),
                            else => |t| @panic(@tagName(t)),
                        };

                        assert(argument_node_list.items.len > 0);
                        if (argument_node_list.items.len > 0) {
                            var arguments = try ArrayList(Declaration.Index).initCapacity(analyzer.allocator, argument_node_list.items.len);
                            const scope = analyzer.module.scopes.get(scope_index);
                            _ = scope;
                            for (argument_node_list.items) |argument_node_index| {
                                const argument_node = analyzer.getScopeNode(scope_index, argument_node_index);
                                switch (argument_node.id) {
                                    .argument_declaration => {
                                        const argument_type = try analyzer.resolveType(scope_index, argument_node.left);
                                        const is_argument = true;
                                        const argument_declaration = try analyzer.declarationCommon(scope_index, .local, .@"const", argument_node.token, argument_type, Value.Index.invalid, is_argument);

                                        arguments.appendAssumeCapacity(argument_declaration);
                                    },
                                    else => |t| @panic(@tagName(t)),
                                }
                            }

                            break :blk arguments.items;
                        } else {
                            break :blk null;
                        }
                    },
                };

                const return_type = try analyzer.resolveType(scope_index, function_prototype_node.right);

                const function_prototype_allocation = try analyzer.module.function_prototypes.append(analyzer.allocator, .{
                    .arguments = arguments,
                    .return_type = return_type,
                });

                return function_prototype_allocation.index;
            },
            else => |t| @panic(@tagName(t)),
        }
    }

    fn structType(analyzer: *Analyzer, value: *Value, parent_scope_index: Scope.Index, index: Node.Index, file_index: File.Index) !Type.Index {
        var node_buffer: [2]Node.Index = undefined;
        // We have the file because this might be the first file
        const file = analyzer.module.files.get(file_index);
        const node = file.syntactic_analyzer_result.nodes.items[index.unwrap()];
        const nodes = switch (node.id) {
            .main_one => blk: {
                node_buffer[0] = node.left;
                break :blk node_buffer[0..1];
            },
            .main_two => blk: {
                node_buffer[0] = node.left;
                node_buffer[1] = node.right;
                break :blk &node_buffer;
            },
            .main => blk: {
                const node_list_node = analyzer.getFileNode(file_index, node.left);
                const node_list = switch (node_list_node.id) {
                    .node_list => analyzer.getFileNodeList(file_index, node_list_node),
                    else => |t| @panic(@tagName(t)),
                };
                break :blk node_list.items;
                // const node_list = file.syntactic_analyzer_result.node_lists.items[node.left.unwrap()];
                // break :blk node_list.items;
            },
            else => |t| @panic(@tagName(t)),
        };

        if (nodes.len > 0) {
            const new_scope = try analyzer.allocateScope(.{
                .parent = parent_scope_index,
                .file = file_index,
            });
            const scope = new_scope.ptr;
            const scope_index = new_scope.index;

            const is_file = !parent_scope_index.valid;
            assert(is_file);

            const struct_allocation = try analyzer.module.structs.append(analyzer.allocator, .{
                .scope = new_scope.index,
            });
            const type_allocation = try analyzer.module.types.append(analyzer.allocator, .{
                .@"struct" = struct_allocation.index,
            });

            if (!parent_scope_index.valid) {
                file.type = type_allocation.index;
            }

            scope.type = type_allocation.index;
            value.* = .{
                .type = type_allocation.index,
            };

            const count = blk: {
                var result: struct {
                    fields: u32 = 0,
                    declarations: u32 = 0,
                } = .{};
                for (nodes) |member_index| {
                    const member = analyzer.getFileNode(file_index, member_index);
                    const member_type = getContainerMemberType(member.id);

                    switch (member_type) {
                        .declaration => result.declarations += 1,
                        .field => result.fields += 1,
                    }
                }
                break :blk result;
            };

            var declaration_nodes = try ArrayList(Node.Index).initCapacity(analyzer.allocator, count.declarations);
            var field_nodes = try ArrayList(Node.Index).initCapacity(analyzer.allocator, count.fields);

            for (nodes) |member_index| {
                const member = analyzer.getFileNode(file_index, member_index);
                const member_type = getContainerMemberType(member.id);
                const array_list = switch (member_type) {
                    .declaration => &declaration_nodes,
                    .field => &field_nodes,
                };
                array_list.appendAssumeCapacity(member_index);
            }

            for (declaration_nodes.items) |declaration_node_index| {
                const declaration_node = analyzer.getFileNode(file_index, declaration_node_index);
                switch (declaration_node.id) {
                    .@"comptime" => {},
                    .simple_variable_declaration => _ = try analyzer.symbolDeclaration(scope_index, declaration_node_index, .global),
                    else => unreachable,
                }
            }

            // TODO: consider iterating over scope declarations instead?
            for (declaration_nodes.items) |declaration_node_index| {
                const declaration_node = analyzer.getFileNode(file_index, declaration_node_index);
                switch (declaration_node.id) {
                    .@"comptime" => _ = try analyzer.comptimeBlock(scope_index, declaration_node_index),
                    .simple_variable_declaration => {},
                    else => |t| @panic(@tagName(t)),
                }
            }

            for (field_nodes.items) |field_index| {
                const field_node = analyzer.getFileNode(file_index, field_index);
                _ = field_node;

                @panic("TODO: fields");
            }

            return type_allocation.index;
        } else {
            return Type.Index.invalid;
        }
    }

    fn declarationCommon(analyzer: *Analyzer, scope_index: Scope.Index, scope_type: ScopeType, mutability: Compilation.Mutability, identifier_token: Token.Index, type_index: Type.Index, init_value: Value.Index, is_argument: bool) !Declaration.Index {
        const identifier = analyzer.tokenIdentifier(scope_index, identifier_token);
        const identifier_index = try analyzer.processIdentifier(identifier);

        if (analyzer.lookupDeclarationInCurrentAndParentScopes(scope_index, identifier_index)) |lookup| {
            const declaration_name = analyzer.tokenIdentifier(lookup.scope, identifier_token);
            std.debug.panic("Existing name in lookup: {s}", .{declaration_name});
        }

        // Check if the symbol name is already occupied in the same scope
        const scope = analyzer.module.scopes.get(scope_index);
        const declaration_allocation = try analyzer.module.declarations.append(analyzer.allocator, .{
            .name = identifier_index,
            .scope_type = scope_type,
            .mutability = mutability,
            .init_value = init_value,
            .type = type_index,
            .is_argument = is_argument,
        });

        try scope.declarations.put(analyzer.allocator, identifier_index, declaration_allocation.index);

        return declaration_allocation.index;
    }

    fn symbolDeclaration(analyzer: *Analyzer, scope_index: Scope.Index, node_index: Node.Index, scope_type: ScopeType) !Declaration.Index {
        const declaration_node = analyzer.getScopeNode(scope_index, node_index);
        assert(declaration_node.id == .simple_variable_declaration);
        assert(!declaration_node.left.valid);
        const mutability: Compilation.Mutability = switch (analyzer.getScopeToken(scope_index, declaration_node.token).id) {
            .fixed_keyword_const => .@"const",
            .fixed_keyword_var => .@"var",
            else => |t| @panic(@tagName(t)),
        };
        const expected_identifier_token_index = declaration_node.token + 1;
        const expected_identifier_token = analyzer.getScopeToken(scope_index, expected_identifier_token_index);
        if (expected_identifier_token.id != .identifier) {
            print("Error: found: {}", .{expected_identifier_token.id});
            @panic("Expected identifier");
        }
        // TODO: Check if it is a keyword

        assert(declaration_node.right.valid);

        const is_argument = false;
        const init_value_allocation = switch (scope_type == .local and !is_argument) {
            true => try analyzer.unresolvedAllocate(scope_index, ExpectType.none, declaration_node.right),
            false => try analyzer.module.values.append(analyzer.allocator, .{
                .unresolved = .{
                    .node_index = declaration_node.right,
                },
            }),
        };

        const result = try analyzer.declarationCommon(scope_index, scope_type, mutability, expected_identifier_token_index, Type.Index.invalid, init_value_allocation.index, is_argument);

        return result;
    }

    const MemberType = enum {
        declaration,
        field,
    };

    fn getContainerMemberType(member_id: Node.Id) MemberType {
        return switch (member_id) {
            .@"comptime" => .declaration,
            .simple_variable_declaration => .declaration,
            else => unreachable,
        };
    }

    fn processIdentifier(analyzer: *Analyzer, string: []const u8) !u32 {
        return analyzer.module.addName(analyzer.allocator, string);
    }

    fn tokenIdentifier(analyzer: *Analyzer, scope_index: Scope.Index, token_index: Token.Index) []const u8 {
        const token = analyzer.getScopeToken(scope_index, token_index);
        assert(token.id == .identifier);
        const source_file = analyzer.getScopeSourceFile(scope_index);
        const identifier = tokenBytes(token, source_file);

        return identifier;
    }

    fn tokenBytes(token: Token, source_code: []const u8) []const u8 {
        return source_code[token.start..][0..token.len];
    }

    fn numberBytes(analyzer: *Analyzer, scope_index: Scope.Index, token_index: Token.Index) []const u8 {
        const token = analyzer.getScopeToken(scope_index, token_index);
        assert(token.id == .number_literal);
        const source_file = analyzer.getScopeSourceFile(scope_index);
        const bytes = tokenBytes(token, source_file);

        return bytes;
    }

    fn tokenStringLiteral(analyzer: *Analyzer, scope_index: Scope.Index, token_index: Token.Index) []const u8 {
        const token = analyzer.getScopeToken(scope_index, token_index);
        assert(token.id == .string_literal);
        const source_file = analyzer.getScopeSourceFile(scope_index);
        // Eat double quotes
        const string_literal = tokenBytes(token, source_file)[1..][0 .. token.len - 2];

        return string_literal;
    }

    fn allocateScope(analyzer: *Analyzer, scope_value: Scope) !Scope.Allocation {
        return analyzer.module.scopes.append(analyzer.allocator, scope_value);
    }
};

const ExpectType = union(enum) {
    none,
    type_index: Type.Index,
    flexible_integer: FlexibleInteger,

    pub const none = ExpectType{
        .none = {},
    };
    pub const boolean = ExpectType{
        .type_index = type_boolean,
    };

    const FlexibleInteger = struct {
        byte_count: u8,
        sign: ?bool = null,
    };
};

const type_void = Type.Index{
    .block = 0,
    .index = FixedTypeKeyword.offset + @intFromEnum(FixedTypeKeyword.void),
};

const type_boolean = Type.Index{
    .block = 0,
    .index = FixedTypeKeyword.offset + @intFromEnum(FixedTypeKeyword.bool),
};

const type_ssize = Type.Index{
    .block = 0,
    .index = FixedTypeKeyword.offset + @intFromEnum(FixedTypeKeyword.ssize),
};

const type_usize = Type.Index{
    .block = 0,
    .index = FixedTypeKeyword.offset + @intFromEnum(FixedTypeKeyword.usize),
};

// Each time an enum is added here, a corresponding insertion in the initialization must be made
const Values = enum {
    bool_false,
    bool_true,
    @"unreachable",

    fn getIndex(value: Values) Value.Index {
        const absolute: u32 = @intFromEnum(value);
        const foo = @as(Value.Index, undefined);
        const ElementT = @TypeOf(@field(foo, "index"));
        const BlockT = @TypeOf(@field(foo, "block"));
        const divider = std.math.maxInt(ElementT);
        const element_index: ElementT = @intCast(absolute % divider);
        const block_index: BlockT = @intCast(absolute / divider);
        return .{
            .index = element_index,
            .block = block_index,
        };
    }
};

const Intrinsic = enum {
    import,
    syscall,
};

const FixedTypeKeyword = enum {
    void,
    noreturn,
    bool,
    usize,
    ssize,

    const offset = 0;
};

const HardwareUnsignedIntegerType = enum {
    u8,
    u16,
    u32,
    u64,

    const offset = @typeInfo(FixedTypeKeyword).Enum.fields.len;
};

const HardwareSignedIntegerType = enum {
    s8,
    s16,
    s32,
    s64,

    const offset = HardwareUnsignedIntegerType.offset + @typeInfo(HardwareUnsignedIntegerType).Enum.fields.len;
};

pub fn initialize(compilation: *Compilation, module: *Module, package: *Package, file_index: File.Index) !Type.Index {
    _ = file_index;
    inline for (@typeInfo(FixedTypeKeyword).Enum.fields) |enum_field| {
        _ = try module.types.append(compilation.base_allocator, switch (@field(FixedTypeKeyword, enum_field.name)) {
            .usize => @unionInit(Type, "integer", .{
                .bit_count = 64,
                .signedness = .unsigned,
            }),
            .ssize => @unionInit(Type, "integer", .{
                .bit_count = 64,
                .signedness = .signed,
            }),
            else => @unionInit(Type, enum_field.name, {}),
        });
    }

    inline for (@typeInfo(HardwareUnsignedIntegerType).Enum.fields) |enum_field| {
        _ = try module.types.append(compilation.base_allocator, .{
            .integer = .{
                .signedness = .unsigned,
                .bit_count = switch (@field(HardwareUnsignedIntegerType, enum_field.name)) {
                    .u8 => 8,
                    .u16 => 16,
                    .u32 => 32,
                    .u64 => 64,
                },
            },
        });
    }

    inline for (@typeInfo(HardwareSignedIntegerType).Enum.fields) |enum_field| {
        _ = try module.types.append(compilation.base_allocator, .{
            .integer = .{
                .signedness = .signed,
                .bit_count = switch (@field(HardwareSignedIntegerType, enum_field.name)) {
                    .s8 => 8,
                    .s16 => 16,
                    .s32 => 32,
                    .s64 => 64,
                },
            },
        });
    }

    _ = try module.values.append(compilation.base_allocator, .{
        .bool = false,
    });

    _ = try module.values.append(compilation.base_allocator, .{
        .bool = true,
    });

    _ = try module.values.append(compilation.base_allocator, .{
        .@"unreachable" = {},
    });

    const value_allocation = try module.values.append(compilation.base_allocator, .{
        .unresolved = .{
            .node_index = .{ .value = 0 },
        },
    });

    const result = analyzeExistingPackage(value_allocation.ptr, compilation, module, package);

    var decl_iterator = module.declarations.iterator();
    while (decl_iterator.nextPointer()) |decl| {
        const declaration_name = module.getName(decl.name).?;
        if (equal(u8, declaration_name, "_start")) {
            const value = module.values.get(decl.init_value);
            module.entry_point = switch (value.*) {
                .function => |function_index| function_index.uniqueInteger(),
                .unresolved => std.debug.panic("Unresolved declaration: {s}\n", .{declaration_name}),
                else => |t| @panic(@tagName(t)),
            };
            break;
        }
    } else {
        @panic("Entry point not found");
    }

    return result;
}

pub fn analyzeExistingPackage(value: *Value, compilation: *Compilation, module: *Module, package: *Package) !Type.Index {
    const package_import = try module.importPackage(compilation.base_allocator, package);
    assert(!package_import.file.is_new);
    const file_index = package_import.file.index;

    return try analyzeFile(value, compilation.base_allocator, module, file_index);
}

pub fn analyzeFile(value: *Value, allocator: Allocator, module: *Module, file_index: File.Index) !Type.Index {
    const file = module.files.get(file_index);
    assert(value.* == .unresolved);
    assert(file.status == .parsed);

    var analyzer = Analyzer{
        .current_file = file_index,
        .allocator = allocator,
        .module = module,
    };

    const result = try analyzer.structType(value, Scope.Index.invalid, .{ .value = 0 }, file_index);
    return result;
}
