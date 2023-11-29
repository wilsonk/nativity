const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const equal = std.mem.eql;

const Compilation = @import("../Compilation.zig");
const logln = Compilation.logln;
const Module = Compilation.Module;
const data_structures = @import("../data_structures.zig");
const ArrayList = data_structures.ArrayList;
const AutoArrayHashMap = data_structures.AutoArrayHashMap;
const StringArrayHashMap = data_structures.StringArrayHashMap;

pub const Logger = enum {
    g,

    pub var bitset = std.EnumSet(Logger).initMany(&.{
        .g,
    });
};

const margin_width = 4;

pub const TranslationUnit = struct {
    string_literals: ArrayList(u8) = .{},
    primitive_type_declarations: ArrayList(u8) = .{},
    type_forward_declarations: ArrayList(u8) = .{},
    type_declarations: ArrayList(u8) = .{},
    function_declarations: ArrayList(u8) = .{},
    global_variable_declarations: ArrayList(u8) = .{},
    function_definitions: ArrayList(u8) = .{},
    syscall_bitset: SyscallBitset = SyscallBitset.initEmpty(),
    struct_type_set: AutoArrayHashMap(Compilation.Type.Index, []const u8) = .{},
    optional_type_set: AutoArrayHashMap(Compilation.Type.Index, []const u8) = .{},
    function_set: AutoArrayHashMap(Compilation.Function.Index, []const u8) = .{},
    slice_type_set: AutoArrayHashMap(Compilation.Type.Index, []const u8) = .{},
    declaration_set: AutoArrayHashMap(Compilation.Declaration.Index, []const u8) = .{},

    const SyscallBitset = std.StaticBitSet(6);

    fn create(module: *Module, allocator: Allocator) !*TranslationUnit {
        var unit = try allocator.create(TranslationUnit);
        unit.* = .{};
        try unit.primitive_type_declarations.appendSlice(allocator,
            \\typedef unsigned char u8;
            \\typedef unsigned short u16;
            \\typedef unsigned int u32;
            \\typedef unsigned long u64;
            \\typedef u64 usize;
            \\static_assert(sizeof(u8) == 1);
            \\static_assert(sizeof(u16) == 2);
            \\static_assert(sizeof(u32) == 4);
            \\static_assert(sizeof(u64) == 8);
            \\typedef signed char s8;
            \\typedef signed short s16;
            \\typedef signed int s32;
            \\typedef signed long s64;
            \\typedef s64 ssize;
            \\static_assert(sizeof(s8) == 1);
            \\static_assert(sizeof(s16) == 2);
            \\static_assert(sizeof(s32) == 4);
            \\static_assert(sizeof(s64) == 8);
            \\
            \\
        );

        {
            var function_definitions = module.function_definitions.iterator();
            while (function_definitions.nextIndex()) |function_definition_index| {
                _ = try unit.writeFunctionDefinition(module, allocator, function_definition_index);
            }
        }

        return unit;
    }

    fn writeFunctionDefinition(unit: *TranslationUnit, module: *Module, allocator: Allocator, function_definition_index: Compilation.Function.Index) ![]const u8 {
        const gop = try unit.function_set.getOrPut(allocator, function_definition_index);

        if (!gop.found_existing) {
            const function_definition = module.function_definitions.get(function_definition_index);
            const function_prototype_type = function_definition.prototype;
            const function_prototype = module.function_prototypes.get(module.types.get(function_prototype_type).function);

            const function_name = try unit.writeFunctionHeader(module, &unit.function_declarations, allocator, function_definition_index);
            gop.value_ptr.* = function_name;

            _ = try unit.writeFunctionHeader(module, &unit.function_definitions, allocator, function_definition_index);
            try unit.function_declarations.appendSlice(allocator, ";\n\n");

            try unit.function_definitions.append(allocator, ' ');
            try unit.writeBlock(module, &unit.function_definitions, allocator, function_definition.body, function_prototype.return_type, 0);
            try unit.function_definitions.append(allocator, '\n');
        }

        return gop.value_ptr.*;
    }

    fn writeDeclaration(unit: *TranslationUnit, module: *Module, list: *ArrayList(u8), allocator: Allocator, declaration_index: Compilation.Declaration.Index, indentation: usize) !void {
        const declaration = module.declarations.get(declaration_index);
        const mangle = false;
        const name = try unit.renderDeclarationName(module, allocator, declaration_index, mangle);

        if (declaration.mutability == .@"const") {
            switch (module.types.get(declaration.type).*) {
                .optional => |optional| switch (module.types.get(optional.element_type).*) {
                    .pointer => {},
                    else => try list.appendSlice(allocator, "const "),
                },
                .pointer => {},
                .integer,
                .@"struct",
                .slice,
                .bool,
                => try list.appendSlice(allocator, "const "),
                else => |t| @panic(@tagName(t)),
                //else => try list.appendSlice(allocator, "const "),
            }
        }

        try unit.writeType(module, list, allocator, declaration.type);

        try list.append(allocator, ' ');

        try list.appendSlice(allocator, name);

        try list.appendSlice(allocator, " = ");

        try unit.writeValue(module, list, allocator, Compilation.Type.Index.invalid, indentation, .{
            .value_index = declaration.init_value,
            .type_index = declaration.type,
        });
        try list.append(allocator, ';');
    }

    fn writeBlock(unit: *TranslationUnit, module: *Module, list: *ArrayList(u8), allocator: Allocator, block_index: Compilation.Block.Index, function_return_type: Compilation.Type.Index, old_indentation: usize) !void {
        try list.appendSlice(allocator, "{\n");
        const block = module.blocks.get(block_index);

        const indentation = old_indentation + 1;

        for (block.statements.items) |statement_index| {
            try list.appendNTimes(allocator, ' ', indentation * margin_width);

            const statement = module.values.get(statement_index);
            switch (statement.*) {
                .declaration => |declaration_index| {
                    try unit.writeDeclaration(module, list, allocator, declaration_index, indentation);
                },
                .assign => |assignment_index| {
                    const assignment = module.assignments.get(assignment_index);
                    const left_type = module.values.get(assignment.source).getType(module);
                    try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                        .value_index = assignment.destination,
                        .type_index = left_type,
                    });
                    try list.appendSlice(allocator, " = ");
                    try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                        .value_index = assignment.source,
                        .type_index = Compilation.Type.Index.invalid,
                    });
                    try list.append(allocator, ';');
                },
                .@"return" => |return_index| {
                    const return_expr = module.returns.get(return_index);
                    try list.appendSlice(allocator, "return ");
                    const return_value = module.values.get(return_expr.value);
                    const return_value_type_index = return_value.getType(module);
                    // _ = return_value_type_index;
                    switch (module.types.get(function_return_type).*) {
                        .optional => switch (module.types.get(return_value_type_index).*) {
                            .optional => try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                                .value_index = return_expr.value,
                                .type_index = function_return_type,
                            }),
                            else => {
                                try list.append(allocator, '(');
                                try unit.writeType(module, list, allocator, function_return_type);
                                try list.appendSlice(allocator, ") {\n");

                                try list.appendNTimes(allocator, ' ', indentation * margin_width);
                                try list.appendSlice(allocator, ".value = ");
                                try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                                    .value_index = return_expr.value,
                                    .type_index = return_value_type_index,
                                });
                                try list.appendSlice(allocator, ",\n");
                                try list.appendNTimes(allocator, ' ', indentation * margin_width);
                                try list.appendSlice(allocator, ".is_null = false,\n");
                                try list.appendNTimes(allocator, ' ', indentation * margin_width);
                                try list.append(allocator, '}');
                            },
                        },
                        else => try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                            .value_index = return_expr.value,
                            .type_index = function_return_type,
                        }),
                    }

                    try list.append(allocator, ';');
                },
                .syscall => |syscall_index| {
                    try unit.writeSyscall(module, list, allocator, syscall_index, function_return_type, indentation);
                    try list.append(allocator, ';');
                },
                .@"unreachable" => {
                    try writeUnreachable(list, allocator);
                    try list.append(allocator, ';');
                },
                .call => |call_index| {
                    try unit.writeCall(module, list, allocator, call_index, function_return_type, indentation);
                    try list.append(allocator, ';');
                },
                .branch => |branch_index| {
                    const branch = module.branches.get(branch_index);
                    try list.appendSlice(allocator, "if (");
                    try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                        .value_index = branch.expression,
                        .type_index = Compilation.Type.Index.invalid,
                    });
                    try list.appendSlice(allocator, ") ");
                    try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                        .value_index = branch.taken_expression,
                        .type_index = function_return_type,
                    });

                    if (!branch.not_taken_expression.invalid) {
                        if (module.values.get(branch.taken_expression).* == .block) {
                            _ = list.pop();
                            try list.appendSlice(allocator, " else ");
                        } else {
                            unreachable;
                        }
                        try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                            .value_index = branch.not_taken_expression,
                            .type_index = function_return_type,
                        });

                        if (module.values.get(branch.not_taken_expression).* == .block) {
                            continue;
                        }
                    }
                },
                .assembly_block => |assembly_block_index| {
                    try unit.writeAssembly(module, list, allocator, assembly_block_index, indentation);
                    try list.append(allocator, ';');
                },
                else => |t| @panic(@tagName(t)),
            }

            try list.append(allocator, '\n');
        }

        try list.appendNTimes(allocator, ' ', old_indentation * margin_width);
        try list.appendSlice(allocator, "}\n");
    }

    const FunctionHeaderType = enum {
        pointer,
        header,
    };

    fn renderTypeName(unit: *TranslationUnit, module: *Module, allocator: Allocator, type_index: Compilation.Type.Index) ![]const u8 {
        const declaration_index = module.type_map.get(type_index).?;
        const mangle = true;
        const result = try unit.renderDeclarationName(module, allocator, declaration_index, mangle);
        return result;
    }

    fn renderFunctionName(unit: *TranslationUnit, module: *Module, allocator: Allocator, function_index: Compilation.Function.Index) ![]const u8 {
        const function_definition = module.function_definitions.get(function_index);
        const function_prototype_type = module.types.get(function_definition.prototype);
        const function_prototype_index = function_prototype_type.function;
        const function_prototype = module.function_prototypes.get(function_prototype_index);
        const mangle = !(function_prototype.attributes.@"export" or function_prototype.attributes.@"extern");
        const function_declaration_index = module.function_map.get(function_index).?;
        const name = try unit.renderDeclarationName(module, allocator, function_declaration_index, mangle);
        return name;
    }

    fn renderDeclarationName(unit: *TranslationUnit, module: *Module, allocator: Allocator, declaration_index: Compilation.Declaration.Index, mangle: bool) anyerror![]const u8 {
        const gop = try unit.declaration_set.getOrPut(allocator, declaration_index);

        if (!gop.found_existing) {
            const declaration = module.declarations.get(declaration_index);
            const base_declaration_name = module.getName(declaration.name).?;
            var list = ArrayList(u8){};

            try list.insertSlice(allocator, 0, base_declaration_name);

            if (mangle) {
                var scope_index = declaration.scope;

                var iterations: usize = 0;
                switch (declaration.scope_type) {
                    .global => {
                        while (!scope_index.invalid) {
                            const scope = module.scopes.get(scope_index);

                            if (module.type_map.get(scope.type)) |type_declaration| {
                                const scope_type_declaration = module.declarations.get(type_declaration);
                                const scope_type_declaration_name = module.getName(scope_type_declaration.name).?;
                                try list.insert(allocator, 0, '_');
                                try list.insertSlice(allocator, 0, scope_type_declaration_name);

                                scope_index = scope.parent;
                            } else {
                                break;
                            }

                            iterations += 1;
                        }
                    },
                    .local => {},
                }
            }

            // TODO: enhance declaration name rendering with file scope name
            // const scope =  declaration.scope;
            gop.value_ptr.* = list.items;

            switch (declaration.scope_type) {
                .global => switch (module.types.get(declaration.type).*) {
                    .function,
                    .type,
                    => {},
                    .@"struct" => {
                        try unit.writeDeclaration(module, &unit.global_variable_declarations, allocator, declaration_index, 0);
                        try unit.global_variable_declarations.appendNTimes(allocator, '\n', 2);
                    },
                    else => |t| @panic(@tagName(t)),
                },
                .local => {},
            }
        }

        assert(@intFromPtr(gop.value_ptr.*.ptr) != 0xaaaa_aaaa_aaaa_aaaa);
        logln(.c, .g, "Rendering name: {s}", .{gop.value_ptr.*});

        return gop.value_ptr.*;
    }

    fn writeFunctionPrototype(unit: *TranslationUnit, module: *Module, list: *ArrayList(u8), allocator: Allocator, function_prototype_index: Compilation.Function.Prototype.Index, name: []const u8) !void {
        const function_prototype = module.function_prototypes.get(function_prototype_index);
        switch (function_prototype.attributes.calling_convention) {
            .system_v => {},
            .naked => try list.appendSlice(allocator, "[[gnu::naked]] "),
        }

        try unit.writeType(module, list, allocator, function_prototype.return_type);

        try list.append(allocator, ' ');

        try list.appendSlice(allocator, name);

        try list.append(allocator, '(');

        if (function_prototype.arguments) |function_arguments| {
            for (function_arguments) |argument_index| {
                const arg_declaration = module.declarations.get(argument_index);
                try unit.writeType(module, list, allocator, arg_declaration.type);
                try list.append(allocator, ' ');
                const arg_name = module.getName(arg_declaration.name).?;
                try list.appendSlice(allocator, arg_name);
                try list.appendSlice(allocator, ", ");
            }
            _ = list.pop();
            _ = list.pop();
        }

        try list.appendSlice(allocator, ")");
    }

    fn writeFunctionHeader(unit: *TranslationUnit, module: *Module, list: *ArrayList(u8), allocator: Allocator, function_index: Compilation.Function.Index) ![]const u8 {
        const name = try unit.renderFunctionName(module, allocator, function_index);
        const function_definition = module.function_definitions.get(function_index);
        const function_prototype_type = module.types.get(function_definition.prototype);
        const function_prototype_index = function_prototype_type.function;
        try unit.writeFunctionPrototype(module, list, allocator, function_prototype_index, name);

        return name;
    }

    fn writeType(unit: *TranslationUnit, module: *Module, list: *ArrayList(u8), allocator: Allocator, type_index: Compilation.Type.Index) anyerror!void {
        const sema_type = module.types.get(type_index);

        switch (sema_type.*) {
            .void => try list.appendSlice(allocator, "void"),
            .noreturn => try list.appendSlice(allocator, "[[noreturn]] void"),
            .bool => try list.appendSlice(allocator, "bool"),
            .integer => |integer| {
                try list.append(allocator, switch (integer.signedness) {
                    .signed => 's',
                    .unsigned => 'u',
                });
                try list.writer(allocator).print("{}", .{integer.bit_count});
            },
            .pointer => |pointer| {
                switch (module.types.get(pointer.element_type).*) {
                    .function => {
                        @panic("This should be unreachable");
                    },
                    else => {
                        if (pointer.@"const") {
                            try list.appendSlice(allocator, "const ");
                        }
                        try unit.writeType(module, list, allocator, pointer.element_type);
                        try list.append(allocator, '*');
                    },
                }
            },
            .@"struct" => {
                const name = try unit.cacheStructType(module, allocator, type_index);
                try list.appendSlice(allocator, name);
            },
            .optional => {
                const name = try unit.cacheOptionalType(module, allocator, type_index);
                try list.appendSlice(allocator, name);
            },
            .slice => {
                const name = try unit.cacheSliceType(module, allocator, type_index);
                try list.appendSlice(allocator, name);
            },
            .any => @panic("Internal compiler error: 'any' made it to the backend"),
            else => |t| @panic(@tagName(t)),
        }
    }

    fn writeCDeclaration(unit: *TranslationUnit, module: *Module, list: *ArrayList(u8), allocator: Allocator, name: []const u8, type_index: Compilation.Type.Index) !void {
        const declaration_type = module.types.get(type_index);
        switch (declaration_type.*) {
            .pointer => |pointer| {
                switch (module.types.get(pointer.element_type).*) {
                    .function => |function| return try unit.writeFunctionPrototype(module, list, allocator, function, try std.mem.concat(allocator, u8, &.{ "(*", name, ")" })),
                    else => |t| @panic(@tagName(t)),
                }
            },
            else => {},
        }

        try unit.writeType(module, list, allocator, type_index);
        try list.append(allocator, ' ');
        try list.appendSlice(allocator, name);
    }

    fn writeAssembly(unit: *TranslationUnit, module: *Module, list: *ArrayList(u8), allocator: Allocator, assembly_block_index: Compilation.Assembly.Block.Index, indentation: usize) !void {
        const assembly_block = module.assembly_blocks.get(assembly_block_index);
        try list.appendSlice(allocator, "__asm__ __volatile__(\n");
        for (assembly_block.instructions) |instruction_index| {
            const generic_instruction = module.assembly_instructions.get(instruction_index);
            try list.appendNTimes(allocator, ' ', (indentation + 1) * margin_width);
            try list.append(allocator, '"');
            switch (module.descriptor.target.cpu.arch) {
                .x86_64 => {
                    const architecture = @field(Compilation.Assembly, "x86_64");

                    const instruction: architecture.Instruction = @enumFromInt(generic_instruction.id);
                    const instruction_name = switch (instruction) {
                        .@"and" => "andq",
                        .xor => @tagName(instruction),
                        .call => "callq",
                    };
                    try list.appendSlice(allocator, instruction_name);

                    assert(generic_instruction.operands.len <= 2);
                    if (generic_instruction.operands.len > 0) {
                        try list.append(allocator, ' ');
                        var operand_i: usize = generic_instruction.operands.len;

                        while (operand_i > 0) {
                            operand_i -= 1;

                            const operand = generic_instruction.operands[operand_i];
                            switch (operand) {
                                .register => |generic_register| {
                                    const register: architecture.Register = @enumFromInt(generic_register);
                                    try list.append(allocator, '%');
                                    try list.appendSlice(allocator, @tagName(register));
                                },
                                .number_literal => |number_literal| {
                                    try list.writer(allocator).print("$0x{x}", .{number_literal});
                                },
                                .value_index => |value_index| {
                                    try unit.writeValue(module, list, allocator, Compilation.Type.Index.invalid, indentation + 1, .{
                                        .value_index = value_index,
                                        .type_index = Compilation.Type.Index.invalid,
                                    });
                                },
                            }

                            try list.appendSlice(allocator, ", ");
                        }

                        _ = list.pop();
                        _ = list.pop();
                    }
                },
                else => unreachable,
            }
            try list.appendSlice(allocator, "\\n\\t\"\n");
        }

        try list.appendNTimes(allocator, ' ', indentation * margin_width);
        try list.append(allocator, ')');
    }

    fn cacheStructType(unit: *TranslationUnit, module: *Module, allocator: Allocator, type_index: Compilation.Type.Index) ![]const u8 {
        const t = module.types.get(type_index);
        assert(t.* == .@"struct");
        const gop = try unit.struct_type_set.getOrPut(allocator, type_index);

        if (!gop.found_existing) {
            const struct_type = module.structs.get(t.@"struct");
            const type_name = try unit.renderTypeName(module, allocator, type_index);
            gop.value_ptr.* = type_name;
            // Forward declare the struct
            {
                try unit.type_forward_declarations.appendSlice(allocator, "typedef struct ");
                try unit.type_forward_declarations.appendSlice(allocator, type_name);
                try unit.type_forward_declarations.append(allocator, ' ');
                try unit.type_forward_declarations.appendSlice(allocator, type_name);
                try unit.type_forward_declarations.appendSlice(allocator, ";\n");
            }

            // Actually declare the struct
            {
                try unit.type_declarations.appendSlice(allocator, "typedef struct ");
                try unit.type_declarations.appendSlice(allocator, type_name);
                try unit.type_declarations.appendSlice(allocator, " {\n");

                for (struct_type.fields.items) |struct_field_index| {
                    try unit.type_declarations.appendNTimes(allocator, ' ', margin_width);

                    const struct_field = module.container_fields.get(struct_field_index);
                    const struct_field_name = module.getName(struct_field.name).?;

                    switch (struct_type.backing_type.invalid) {
                        false => {
                            try unit.writeType(module, &unit.type_declarations, allocator, struct_type.backing_type);
                            try unit.type_declarations.append(allocator, ' ');
                            try unit.type_declarations.appendSlice(allocator, struct_field_name);
                            try unit.type_declarations.appendSlice(allocator, " : ");
                            try unit.type_declarations.writer(allocator).print("{}", .{module.types.get(struct_field.type).getBitSize()});
                        },
                        true => try unit.writeCDeclaration(module, &unit.type_declarations, allocator, struct_field_name, struct_field.type),
                    }

                    try unit.type_declarations.appendSlice(allocator, ";\n");
                }

                try unit.type_declarations.appendSlice(allocator, "} ");
                try unit.type_declarations.appendSlice(allocator, type_name);
                try unit.type_declarations.appendSlice(allocator, ";\n\n");
            }
        }

        assert(@intFromPtr(gop.value_ptr.*.ptr) != 0xaaaa_aaaa_aaaa_aaaa);

        return gop.value_ptr.*;
    }

    fn cacheOptionalType(unit: *TranslationUnit, module: *Module, allocator: Allocator, type_index: Compilation.Type.Index) ![]const u8 {
        const optional_type = module.types.get(type_index);
        assert(optional_type.* == .optional);
        const optional = optional_type.optional;

        const gop = try unit.optional_type_set.getOrPut(allocator, optional.element_type);

        if (!gop.found_existing) {
            var type_name = ArrayList(u8){};
            const optional_element_type = module.types.get(optional.element_type);

            switch (optional_element_type.*) {
                .pointer => {
                    try unit.writeType(module, &type_name, allocator, optional.element_type);
                },
                else => {
                    try type_name.appendSlice(allocator, "Optional_");
                    try unit.writeType(module, &type_name, allocator, optional.element_type);

                    if (!gop.found_existing) {
                        try unit.type_forward_declarations.appendSlice(allocator, "typedef struct ");
                        try unit.type_forward_declarations.appendSlice(allocator, type_name.items);
                        try unit.type_forward_declarations.append(allocator, ' ');
                        try unit.type_forward_declarations.appendSlice(allocator, type_name.items);
                        try unit.type_forward_declarations.appendSlice(allocator, ";\n");

                        try unit.type_declarations.appendSlice(allocator, "typedef struct ");
                        try unit.type_declarations.appendSlice(allocator, type_name.items);
                        try unit.type_declarations.appendSlice(allocator, " {\n");

                        try unit.type_declarations.appendNTimes(allocator, ' ', margin_width);
                        try unit.writeCDeclaration(module, &unit.type_declarations, allocator, "value", optional.element_type);
                        try unit.type_declarations.appendSlice(allocator, ";\n");

                        try unit.type_declarations.appendNTimes(allocator, ' ', margin_width);
                        try unit.writeCDeclaration(module, &unit.type_declarations, allocator, "is_null", Compilation.Type.boolean);
                        try unit.type_declarations.appendSlice(allocator, ";\n");

                        try unit.type_declarations.appendSlice(allocator, "} ");
                        try unit.type_declarations.appendSlice(allocator, type_name.items);
                        try unit.type_declarations.appendSlice(allocator, ";\n\n");
                    }
                },
            }
            gop.value_ptr.* = type_name.items;
        }

        return gop.value_ptr.*;
    }

    fn cacheSliceType(unit: *TranslationUnit, module: *Module, allocator: Allocator, type_index: Compilation.Type.Index) ![]const u8 {
        const slice = module.types.get(type_index).slice;

        const gop = try unit.slice_type_set.getOrPut(allocator, slice.element_type);

        if (!gop.found_existing) {
            var type_name = ArrayList(u8){};
            try type_name.appendSlice(allocator, "Slice_");
            try unit.writeType(module, &type_name, allocator, slice.element_type);
            gop.value_ptr.* = type_name.items;

            try unit.type_forward_declarations.appendSlice(allocator, "typedef struct ");
            try unit.type_forward_declarations.appendSlice(allocator, type_name.items);
            try unit.type_forward_declarations.append(allocator, ' ');
            try unit.type_forward_declarations.appendSlice(allocator, type_name.items);
            try unit.type_forward_declarations.appendSlice(allocator, ";\n");

            try unit.type_declarations.appendSlice(allocator, "typedef struct ");
            try unit.type_declarations.appendSlice(allocator, type_name.items);
            try unit.type_declarations.appendSlice(allocator, " {\n");

            try unit.type_declarations.appendNTimes(allocator, ' ', margin_width);
            try unit.writeType(module, &unit.type_declarations, allocator, slice.element_type);
            try unit.type_declarations.appendSlice(allocator, "* ptr;\n");

            try unit.type_declarations.appendNTimes(allocator, ' ', margin_width);
            try unit.type_declarations.appendSlice(allocator, "usize len;\n");

            try unit.type_declarations.appendSlice(allocator, "} ");
            try unit.type_declarations.appendSlice(allocator, type_name.items);
            try unit.type_declarations.appendSlice(allocator, ";\n\n");
        }

        return gop.value_ptr.*;
    }

    fn writeSyscall(unit: *TranslationUnit, module: *Module, list: *ArrayList(u8), allocator: Allocator, syscall_index: Compilation.Syscall.Index, function_return_type: Compilation.Type.Index, indentation: usize) !void {
        const syscall = module.syscalls.get(syscall_index);
        const arguments = syscall.getArguments();

        if (!unit.syscall_bitset.isSet(arguments.len - 1)) {
            try unit.function_declarations.appendSlice(allocator, "static __inline u64 syscall");
            try unit.function_declarations.writer(allocator).print("{}(", .{arguments.len});
            try unit.function_declarations.appendSlice(allocator, "u64 n, ");
            for (0..arguments.len) |arg_i| {
                try unit.function_declarations.writer(allocator).print("u64 arg{}, ", .{arg_i});
            }
            _ = unit.function_declarations.pop();
            _ = unit.function_declarations.pop();
            try unit.function_declarations.appendSlice(allocator,
                \\) {
                \\
            );

            const simple_register_argument_count = @min(arguments.len, 3);
            const complex_register_argument_count = arguments.len - simple_register_argument_count;
            const simple_argument_registers = [_]u8{ 'D', 'S', 'd' };
            const complex_argument_registers = [_]u8{ 10, 8, 9 };

            for (0..complex_register_argument_count) |i| {
                try unit.function_declarations.appendNTimes(allocator, ' ', indentation * margin_width);
                try unit.function_declarations.writer(allocator).print("register unsigned long r{} __asm__(\"r{}\") = arg{};\n", .{ complex_argument_registers[i], complex_argument_registers[i], 3 + i });
            }

            try unit.function_declarations.appendSlice(allocator,
                \\    unsigned long ret;
                \\
                \\    __asm__ __volatile__("syscall"
                \\        : "=a"(ret)
                \\        : "a"(n), 
            );

            for (0..simple_register_argument_count, simple_argument_registers[0..simple_register_argument_count]) |arg_i, arg_register| {
                try unit.function_declarations.writer(allocator).print("\"{c}\"(arg{}), ", .{ arg_register, arg_i });
            }

            for (complex_argument_registers[0..complex_register_argument_count]) |arg_register| {
                try unit.function_declarations.writer(allocator).print("\"r\"(r{}), ", .{arg_register});
            }

            _ = unit.function_declarations.pop();
            _ = unit.function_declarations.pop();

            try unit.function_declarations.appendSlice(allocator,
                \\
                \\        : "rcx", "r11", "memory"
                \\    );
                \\
                \\    return ret;
                \\}
                \\
                \\
            );

            unit.syscall_bitset.set(arguments.len - 1);
        }

        try list.writer(allocator).print("syscall{}(", .{arguments.len});

        try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
            .value_index = syscall.number,
            .type_index = function_return_type,
        });
        try list.appendSlice(allocator, ", ");

        for (arguments) |argument_index| {
            try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                .value_index = argument_index,
                .type_index = Compilation.Type.Index.invalid,
            });
            try list.appendSlice(allocator, ", ");
        }

        _ = list.pop();
        _ = list.pop();
        try list.append(allocator, ')');
    }

    fn writeUnreachable(list: *ArrayList(u8), allocator: Allocator) !void {
        try list.appendSlice(allocator, "__builtin_unreachable()");
    }

    fn writeCall(unit: *TranslationUnit, module: *Module, list: *ArrayList(u8), allocator: Allocator, call_index: Compilation.Call.Index, function_return_type: Compilation.Type.Index, indentation: usize) !void {
        const call = module.calls.get(call_index);
        const call_value = module.values.get(call.value);
        switch (call_value.*) {
            .function_definition => |function_definition_index| {
                const name = try unit.renderFunctionName(module, allocator, function_definition_index);
                try list.appendSlice(allocator, name);
                try list.append(allocator, '(');
            },
            .field_access => |field_access_index| {
                const field_access = module.field_accesses.get(field_access_index);
                try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                    .value_index = field_access.declaration_reference,
                    .type_index = function_return_type,
                });

                const left_type = module.types.get(module.values.get(field_access.declaration_reference).declaration_reference.type);
                const is_pointer = switch (left_type.*) {
                    .pointer => true,
                    else => false,
                };

                if (is_pointer) {
                    try list.appendSlice(allocator, "->");
                } else {
                    try list.append(allocator, '.');
                }

                const field = module.container_fields.get(field_access.field);
                const field_name = module.getName(field.name).?;
                try list.appendSlice(allocator, field_name);
                try list.append(allocator, '(');
            },
            else => |t| @panic(@tagName(t)),
        }

        if (!call.arguments.invalid) {
            const argument_list = module.argument_lists.get(call.arguments);

            if (argument_list.array.items.len > 0) {
                for (argument_list.array.items) |argument_index| {
                    try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                        .value_index = argument_index,
                        .type_index = Compilation.Type.Index.invalid,
                    });
                    try list.appendSlice(allocator, ", ");
                }

                _ = list.pop();
                _ = list.pop();
            }
        }

        try list.append(allocator, ')');
    }

    const ValueArguments = struct {
        value_index: Compilation.Value.Index,
        type_index: Compilation.Type.Index,
    };

    fn writeValue(unit: *TranslationUnit, module: *Module, list: *ArrayList(u8), allocator: Allocator, function_return_type: Compilation.Type.Index, indentation: usize, arguments: ValueArguments) anyerror!void {
        const value_index = arguments.value_index;
        const type_index = arguments.type_index;
        _ = type_index;
        const value = module.values.get(value_index);
        switch (value.*) {
            .integer => |integer| {
                try list.writer(allocator).print("{}", .{integer.value});
            },
            .declaration_reference => |declaration_reference| {
                const mangle = true;
                const name = try unit.renderDeclarationName(module, allocator, declaration_reference.value, mangle);
                try list.appendSlice(allocator, name);
            },
            .binary_operation => |binary_operation_index| {
                const binary_operation = module.binary_operations.get(binary_operation_index);
                try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                    .value_index = binary_operation.left,
                    .type_index = binary_operation.type,
                });
                try list.append(allocator, ' ');

                switch (binary_operation.id) {
                    .add => try list.append(allocator, '+'),
                    .sub => try list.append(allocator, '-'),
                    .bit_and => try list.append(allocator, '&'),
                    .bit_or => try list.append(allocator, '|'),
                    .bit_xor => try list.append(allocator, '^'),
                    .multiply => try list.append(allocator, '*'),
                    .divide => try list.append(allocator, '/'),
                    .compare_greater_than => try list.append(allocator, '>'),
                    .compare_less_than => try list.append(allocator, '<'),
                    .shift_left => try list.appendSlice(allocator, "<<"),
                    .shift_right => try list.appendSlice(allocator, ">>"),
                    .compare_equal => try list.appendSlice(allocator, "=="),
                    .compare_greater_or_equal => try list.appendSlice(allocator, ">="),
                    .compare_less_or_equal => try list.appendSlice(allocator, "<="),
                }

                try list.append(allocator, ' ');
                try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                    .value_index = binary_operation.right,
                    .type_index = binary_operation.type,
                });
            },
            .sign_extend => |cast_index| {
                const sign_extend = module.casts.get(cast_index);
                try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                    .value_index = sign_extend.value,
                    .type_index = sign_extend.type,
                });
            },
            .cast => |cast_index| {
                const cast = module.casts.get(cast_index);
                try list.append(allocator, '(');
                try unit.writeType(module, list, allocator, cast.type);
                try list.append(allocator, ')');
                const cast_value = module.values.get(cast.value);
                const cast_value_type = module.types.get(cast_value.getType(module));

                switch (cast_value_type.*) {
                    .@"struct" => |struct_index| {
                        const struct_type = module.structs.get(struct_index);
                        switch (struct_type.backing_type.invalid) {
                            false => {
                                try list.appendSlice(allocator, "*(");
                                try unit.writeType(module, list, allocator, struct_type.backing_type);
                                try list.appendSlice(allocator, "*)&(");
                                try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                                    .value_index = cast.value,
                                    .type_index = function_return_type,
                                });
                                try list.append(allocator, ')');
                            },
                            true => @panic("Unable to bitcast non-packed struct"),
                        }
                    },
                    else => try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                        .value_index = cast.value,
                        .type_index = Compilation.Type.Index.invalid,
                    }),
                }
            },
            .string_literal => |string_literal_hash| {
                try list.appendSlice(allocator, "(const u8*)");
                const string_literal = module.string_literals.getValue(string_literal_hash).?;
                try list.append(allocator, '"');
                try list.appendSlice(allocator, string_literal);
                try list.append(allocator, '"');
            },
            .@"unreachable" => {
                try writeUnreachable(list, allocator);
            },
            .call => |call_index| try unit.writeCall(module, list, allocator, call_index, function_return_type, indentation),
            .syscall => |syscall_index| try unit.writeSyscall(module, list, allocator, syscall_index, function_return_type, indentation),
            .bool => |boolean| try list.appendSlice(allocator, if (boolean) "true" else "false"),
            .block => |block_index| try unit.writeBlock(module, list, allocator, block_index, function_return_type, indentation),
            .unary_operation => |unary_operation_index| {
                const unary_operation = module.unary_operations.get(unary_operation_index);
                const expression_character: u8 = switch (unary_operation.id) {
                    .boolean_not => '!',
                    .negation => '-',
                    .address_of => '&',
                    .pointer_dereference => '*',
                };

                try list.append(allocator, expression_character);
                try list.append(allocator, '(');
                try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                    .value_index = unary_operation.value,
                    .type_index = unary_operation.type,
                });
                try list.append(allocator, ')');
            },
            .container_initialization => |container_initialization_index| {
                const container_initialization = module.container_initializations.get(container_initialization_index);
                try list.append(allocator, '(');
                try unit.writeType(module, list, allocator, container_initialization.type);
                try list.appendSlice(allocator, ") {\n");

                const container_type = module.types.get(container_initialization.type);
                const container_fields = switch (container_type.*) {
                    .@"struct" => module.structs.get(container_type.@"struct").fields,
                    else => |t| @panic(@tagName(t)),
                };

                for (container_initialization.field_initializations.items, container_fields.items) |field_initialization_index, container_field_index| {
                    try list.appendNTimes(allocator, ' ', (indentation + 1) * margin_width);
                    try list.append(allocator, '.');
                    const container_field = module.container_fields.get(container_field_index);
                    const field_name = module.getName(container_field.name).?;
                    try list.appendSlice(allocator, field_name);
                    try list.appendSlice(allocator, " = ");
                    try unit.writeValue(module, list, allocator, function_return_type, indentation + 1, .{
                        .value_index = field_initialization_index,
                        .type_index = container_field.type,
                    });
                    try list.appendSlice(allocator, ",\n");
                }

                try list.appendNTimes(allocator, ' ', indentation * margin_width);
                try list.append(allocator, '}');
            },
            .field_access => |field_access_index| {
                const field_access = module.field_accesses.get(field_access_index);
                const left = module.values.get(field_access.declaration_reference);
                const left_type = module.types.get(left.getType(module));
                const right_field = module.container_fields.get(field_access.field);
                const right_field_name = module.getName(right_field.name).?;
                const is_pointer = switch (left_type.*) {
                    .@"struct" => false,
                    .pointer => true,
                    else => |t| @panic(@tagName(t)),
                };
                try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                    .value_index = field_access.declaration_reference,
                    .type_index = right_field.type,
                });

                if (is_pointer) {
                    try list.appendSlice(allocator, "->");
                } else {
                    try list.append(allocator, '.');
                }

                try list.appendSlice(allocator, right_field_name);
            },
            .pointer_null_literal => try list.appendSlice(allocator, "nullptr"),
            .optional_null_literal => {
                assert(!arguments.type_index.invalid);
                try list.append(allocator, '(');
                try unit.writeType(module, list, allocator, arguments.type_index);
                try list.appendSlice(allocator, ") { .is_null = true }");
            },
            .slice => |slice_index| {
                const slice = module.slices.get(slice_index);
                const sliceable = module.values.get(slice.sliceable);

                const sliceable_type_index = switch (sliceable.*) {
                    .declaration_reference => |declaration_reference| declaration_reference.type,
                    else => |t| @panic(@tagName(t)),
                };
                const sliceable_type = module.types.get(sliceable_type_index);
                const sliceable_element_type = switch (sliceable_type.*) {
                    .pointer => |pointer| pointer.element_type,
                    else => |t| @panic(@tagName(t)),
                };

                try list.appendSlice(allocator, "(Slice_");
                try unit.writeType(module, list, allocator, sliceable_element_type);
                try list.appendSlice(allocator, ") {\n");

                try list.appendNTimes(allocator, ' ', (indentation + 1) * margin_width);
                try list.appendSlice(allocator, ".ptr = ");

                switch (sliceable_type.*) {
                    .pointer => {
                        try list.append(allocator, '(');
                        try unit.writeValue(module, list, allocator, function_return_type, indentation + 1, .{
                            .value_index = slice.sliceable,
                            .type_index = sliceable_type_index,
                        });
                        try list.appendSlice(allocator, ") + (");
                        try unit.writeValue(module, list, allocator, function_return_type, indentation + 1, .{
                            .value_index = slice.start,
                            .type_index = Compilation.Type.Index.invalid,
                        });
                        try list.appendSlice(allocator, "),\n");
                    },
                    else => |t| @panic(@tagName(t)),
                }

                try list.appendNTimes(allocator, ' ', (indentation + 1) * margin_width);
                try list.appendSlice(allocator, ".len = ");

                switch (sliceable_type.*) {
                    .pointer => {
                        switch (slice.end.invalid) {
                            false => {
                                try list.append(allocator, '(');
                                try unit.writeValue(module, list, allocator, function_return_type, indentation + 1, .{
                                    .value_index = slice.end,
                                    .type_index = Compilation.Type.Index.invalid,
                                });
                                try list.appendSlice(allocator, ") - (");
                                try unit.writeValue(module, list, allocator, function_return_type, indentation + 1, .{
                                    .value_index = slice.start,
                                    .type_index = Compilation.Type.Index.invalid,
                                });
                                try list.appendSlice(allocator, ")\n");
                            },
                            true => {
                                unreachable;
                            },
                        }
                    },
                    else => |t| @panic(@tagName(t)),
                }

                try list.appendNTimes(allocator, ' ', indentation * margin_width);
                try list.append(allocator, '}');
            },
            .function_definition => |function_definition_index| {
                const function_name = try unit.writeFunctionDefinition(module, allocator, function_definition_index);
                try list.appendSlice(allocator, function_name);
            },
            .optional_check => |optional_check_index| {
                const optional_check = module.optional_checks.get(optional_check_index);
                const optional_type = module.types.get(module.values.get(optional_check.value).getType(module));
                assert(optional_type.* == .optional);
                const optional_element_type = module.types.get(optional_type.optional.element_type);
                const is_null_suffix_expression = switch (optional_element_type.*) {
                    .pointer => false,
                    else => true,
                };
                if (is_null_suffix_expression) {
                    try list.append(allocator, '!');
                }

                try list.append(allocator, '(');
                try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                    .value_index = optional_check.value,
                    .type_index = Compilation.Type.Index.invalid,
                });
                try list.append(allocator, ')');

                if (is_null_suffix_expression) {
                    try list.appendSlice(allocator, ".is_null");
                }
            },
            .optional_unwrap => |optional_unwrap_index| {
                const optional_unwrap = module.optional_unwraps.get(optional_unwrap_index);
                const optional_value = module.values.get(optional_unwrap.value);
                const optional_type = module.types.get(optional_value.getType(module));
                assert(optional_type.* == .optional);
                const optional_element_type_index = optional_type.optional.element_type;
                const optional_element_type = module.types.get(optional_element_type_index);

                try list.append(allocator, '(');
                try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                    .value_index = optional_unwrap.value,
                    .type_index = optional_element_type_index,
                });
                try list.append(allocator, ')');

                switch (optional_element_type.*) {
                    .pointer => {},
                    else => try list.appendSlice(allocator, ".value"),
                }
            },
            .slice_access => |slice_access_index| {
                const slice_access = module.slice_accesses.get(slice_access_index);
                try list.append(allocator, '(');
                try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                    .value_index = slice_access.value,
                    .type_index = slice_access.type,
                });
                try list.appendSlice(allocator, ").");
                try list.appendSlice(allocator, @tagName(slice_access.field));
            },
            .indexed_access => |indexed_access_index| {
                const indexed_access = module.indexed_accesses.get(indexed_access_index);
                try list.append(allocator, '(');
                const indexed_expression_index = indexed_access.indexed_expression;
                const indexed_expression = module.values.get(indexed_expression_index);
                const indexed_expression_type_index = indexed_expression.getType(module);
                try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                    .value_index = indexed_expression_index,
                    .type_index = indexed_expression_type_index,
                });

                const indexed_expression_type = module.types.get(indexed_expression_type_index);
                switch (indexed_expression_type.*) {
                    .slice => {
                        try list.appendSlice(allocator, ".ptr");
                    },
                    else => |t| @panic(@tagName(t)),
                }

                try list.appendSlice(allocator, ")[");
                try unit.writeValue(module, list, allocator, function_return_type, indentation, .{
                    .value_index = indexed_access.index_expression,
                    .type_index = Compilation.Type.Index.invalid,
                });
                try list.append(allocator, ']');
            },
            else => |t| @panic(@tagName(t)),
        }
    }
};

pub fn initialize(compilation: *Compilation, module: *Module, descriptor: Compilation.Module.Descriptor) !void {
    const allocator = compilation.base_allocator;
    var unit = try TranslationUnit.create(module, allocator);
    const c_source_file_path = try std.mem.concat(allocator, u8, &.{ descriptor.executable_path, ".c" });
    const c_source_file = try std.fs.cwd().createFile(c_source_file_path, .{});

    try unit.type_forward_declarations.append(allocator, '\n');

    var offset: u64 = 0;
    const slices = [_][]const u8{ unit.primitive_type_declarations.items, unit.type_forward_declarations.items, unit.type_declarations.items, unit.function_declarations.items, unit.global_variable_declarations.items, unit.string_literals.items, unit.function_definitions.items };
    for (slices) |slice| {
        try c_source_file.pwriteAll(slice, offset);
        offset += slice.len;
    }

    c_source_file.close();
    const c_source_file_realpath = try std.fs.cwd().realpathAlloc(allocator, c_source_file_path);
    const c_flags = [_][]const u8{
        "-std=c2x",
        "-g",
    };

    var zig_command_line = ArrayList([]const u8){};
    try zig_command_line.append(allocator, "zig");
    try zig_command_line.append(allocator, "build-exe");
    try zig_command_line.append(allocator, try std.mem.concat(allocator, u8, &.{ "-femit-bin=", descriptor.executable_path }));
    try zig_command_line.append(allocator, "-cflags");
    for (c_flags) |c_flag| {
        try zig_command_line.append(allocator, c_flag);
    }
    try zig_command_line.append(allocator, "--");
    try zig_command_line.append(allocator, c_source_file_realpath);

    const run_result = try std.ChildProcess.run(.{
        .allocator = allocator,
        .argv = zig_command_line.items,
    });
    switch (run_result.term) {
        .Exited => |exit_code| {
            if (exit_code != 0) {
                for (zig_command_line.items) |arg| {
                    std.debug.print("{s} ", .{arg});
                }
                std.debug.panic("\nZig command exited with code {}:\n{s}", .{ exit_code, run_result.stderr });
            }
        },
        else => |t| @panic(@tagName(t)),
    }
}
