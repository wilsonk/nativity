const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Compilation = @import("../Compilation.zig");
const log = Compilation.log;
const logln = Compilation.logln;
const Module = Compilation.Module;
const Package = Compilation.Package;

const data_structures = @import("../data_structures.zig");
const ArrayList = data_structures.ArrayList;
const BlockList = data_structures.BlockList;
const AutoArrayHashMap = data_structures.AutoArrayHashMap;
const AutoHashMap = data_structures.AutoHashMap;
const StringKeyMap = data_structures.StringKeyMap;

const emit = @import("emit.zig");
const SectionManager = emit.SectionManager;

pub const Logger = enum {
    function,
    phi_removal,

    pub var bitset = std.EnumSet(Logger).initMany(&.{
        .function,
    });
};

pub const Result = struct {
    blocks: BlockList(BasicBlock) = .{},
    calls: BlockList(Call) = .{},
    function_declarations: BlockList(Function.Declaration) = .{},
    function_definitions: BlockList(Function) = .{},
    instructions: BlockList(Instruction) = .{},
    jumps: BlockList(Jump) = .{},
    loads: BlockList(Load) = .{},
    phis: BlockList(Phi) = .{},
    stores: BlockList(Store) = .{},
    syscalls: BlockList(Syscall) = .{},
    arguments: BlockList(Argument) = .{},
    returns: BlockList(Return) = .{},
    stack_references: BlockList(StackReference) = .{},
    string_literals: BlockList(StringLiteral) = .{},
    casts: BlockList(Cast) = .{},
    binary_operations: BlockList(BinaryOperation) = .{},
    section_manager: emit.SectionManager,
    module: *Module,
    entry_point: Function.Index = Function.Index.invalid,

    pub fn getFunctionName(ir: *Result, function_index: Function.Declaration.Index) []const u8 {
        return ir.module.getName(ir.module.function_name_map.get(@bitCast(function_index)).?).?;
    }
};

pub fn initialize(compilation: *Compilation, module: *Module) !*Result {
    var function_iterator = module.functions.iterator();
    const builder = try compilation.base_allocator.create(Builder);
    builder.* = .{
        .allocator = compilation.base_allocator,
        .ir = .{
            .module = module,
            .section_manager = SectionManager{
                .allocator = compilation.base_allocator,
            },
        },
    };

    builder.ir.module = module;
    _ = try builder.ir.section_manager.addSection(.{
        .name = ".text",
        .size_guess = 0,
        .alignment = 0x1000,
        .flags = .{
            .execute = true,
            .read = true,
            .write = false,
        },
        .type = .loadable_program,
    });

    var sema_function_index = function_iterator.getCurrentIndex();
    while (function_iterator.next()) |sema_function| {
        const function_index = try builder.buildFunction(sema_function);
        if (sema_function_index.eq(module.entry_point)) {
            assert(!function_index.invalid);
            builder.ir.entry_point = function_index;
        }

        sema_function_index = function_iterator.getCurrentIndex();
    }

    assert(!builder.ir.entry_point.invalid);

    return &builder.ir;
}

pub const BasicBlock = struct {
    instructions: ArrayList(Instruction.Index) = .{},
    incomplete_phis: ArrayList(Instruction.Index) = .{},
    filled: bool = false,
    sealed: bool = false,

    pub const List = BlockList(@This());
    pub const Index = List.Index;

    fn seal(basic_block: *BasicBlock) void {
        for (basic_block.incomplete_phis.items) |incomplete_phi| {
            _ = incomplete_phi;
            unreachable;
        }

        basic_block.sealed = true;
    }

    fn hasJump(basic_block: *BasicBlock, ir: *Result) bool {
        if (basic_block.instructions.items.len > 0) {
            const last_instruction = ir.instructions.get(basic_block.instructions.getLast());
            return switch (last_instruction.u) {
                .jump => true,
                else => false,
            };
        } else return false;
    }
};

const Phi = struct {
    instruction: Instruction.Index,
    jump: Jump.Index,
    block: BasicBlock.Index,
    next: Phi.Index,
    pub const List = BlockList(@This());
    pub const Index = List.Index;
};

pub const Jump = struct {
    source: BasicBlock.Index,
    destination: BasicBlock.Index,
    pub const List = BlockList(@This());
    pub const Index = List.Index;
};

const Syscall = struct {
    arguments: ArrayList(Instruction.Index),
    pub const List = BlockList(@This());
    pub const Index = List.Index;
};

pub const AtomicOrder = enum {
    unordered,
    monotonic,
    acquire,
    release,
    acquire_release,
    sequentially_consistent,
};

pub const Load = struct {
    instruction: Instruction.Index,
    ordering: ?AtomicOrder = null,
    @"volatile": bool = false,

    pub fn isUnordered(load: *const Load) bool {
        return (load.ordering == null or load.ordering == .unordered) and !load.@"volatile";
    }

    pub const List = BlockList(@This());
    pub const Index = List.Index;
};

pub const Store = struct {
    source: Instruction.Index,
    destination: Instruction.Index,
    ordering: ?AtomicOrder = null,
    @"volatile": bool = false,

    pub const List = BlockList(@This());
    pub const Index = List.Index;
};

pub const StackReference = struct {
    type: Type,
    count: usize = 1,
    alignment: u64,
    offset: u64,
    pub const List = BlockList(@This());
    pub const Index = List.Index;
};

pub const Call = struct {
    function: Function.Declaration.Index,
    arguments: []const Instruction.Index,

    pub const List = BlockList(@This());
    pub const Index = List.Index;
    pub const Allocation = List.Allocation;
};

pub const Argument = struct {
    type: Type,
    // index: usize,
    pub const List = BlockList(@This());
    pub const Index = List.Index;
    pub const Allocation = List.Allocation;
};

pub const Return = struct {
    instruction: Instruction.Index,
    pub const List = BlockList(@This());
    pub const Index = List.Index;
    pub const Allocation = List.Allocation;
};

pub const Copy = struct {
    foo: u64 = 0,
    pub const List = BlockList(@This());
    pub const Index = List.Index;
    pub const Allocation = List.Allocation;
};

pub const Cast = struct {
    value: Instruction.Index,
    type: Type,
    pub const List = BlockList(@This());
    pub const Index = List.Index;
    pub const Allocation = List.Allocation;
};

pub const BinaryOperation = struct {
    left: Instruction.Index,
    right: Instruction.Index,
    id: Id,
    type: Type,

    const Id = enum {
        add,
        sub,
    };

    pub const List = BlockList(@This());
    pub const Index = List.Index;
    pub const Allocation = List.Allocation;
};

pub const CastType = enum {
    sign_extend,
};

pub const Type = enum {
    void,
    noreturn,
    i8,
    i16,
    i32,
    i64,

    fn isInteger(t: Type) bool {
        return switch (t) {
            .i8,
            .i16,
            .i32,
            .i64,
            => true,
            .void,
            .noreturn,
            => false,
        };
    }

    pub fn getSize(t: Type) u64 {
        return switch (t) {
            .i8 => @sizeOf(i8),
            .i16 => @sizeOf(i16),
            .i32 => @sizeOf(i32),
            .i64 => @sizeOf(i64),
            .void,
            .noreturn,
            => unreachable,
        };
    }

    pub fn getAlignment(t: Type) u64 {
        return switch (t) {
            .i8 => @alignOf(i8),
            .i16 => @alignOf(i16),
            .i32 => @alignOf(i32),
            .i64 => @alignOf(i64),
            .void,
            .noreturn,
            => unreachable,
        };
    }
};

pub const Instruction = struct {
    u: U,
    use_list: ArrayList(Instruction.Index) = .{},

    const U = union(enum) {
        call: Call.Index,
        jump: Jump.Index,
        load: Load.Index,
        phi: Phi.Index,
        ret: Return.Index,
        store: Store.Index,
        syscall: Syscall.Index,
        copy: Instruction.Index,
        @"unreachable",
        argument: Argument.Index,
        load_integer: Integer,
        load_string_literal: StringLiteral.Index,
        stack: StackReference.Index,
        sign_extend: Cast.Index,
        binary_operation: BinaryOperation.Index,
    };

    pub const List = BlockList(@This());
    pub const Index = List.Index;
};

pub const StringLiteral = struct {
    offset: u32,

    pub const List = BlockList(@This());
    pub const Index = List.Index;
};

pub const Function = struct {
    declaration: Declaration.Index = Declaration.Index.invalid,
    blocks: ArrayList(BasicBlock.Index) = .{},
    stack_map: AutoHashMap(Compilation.Declaration.Index, Instruction.Index) = .{},
    current_basic_block: BasicBlock.Index = BasicBlock.Index.invalid,
    return_phi_node: Instruction.Index = Instruction.Index.invalid,
    return_phi_block: BasicBlock.Index = BasicBlock.Index.invalid,
    ir: *Result,
    current_stack_offset: usize = 0,

    pub const List = BlockList(@This());
    pub const Index = List.Index;

    pub const Declaration = struct {
        definition: Function.Index = Function.Index.invalid,
        arguments: AutoArrayHashMap(Compilation.Declaration.Index, Instruction.Index) = .{},
        calling_convention: Compilation.CallingConvention,
        return_type: Type,

        pub const List = BlockList(@This());
        pub const Index = Declaration.List.Index;
    };

    pub fn format(function: *const Function, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        const function_index = function.declaration;
        const sema_function_index: Compilation.Function.Index = @bitCast(function_index);
        const function_name_hash = function.ir.module.function_name_map.get(sema_function_index).?;
        const function_name = function.ir.module.getName(function_name_hash).?;
        try writer.print("Function #{} \"{s}\"\n", .{ function_index.uniqueInteger(), function_name });
        for (function.blocks.items, 0..) |block_index, function_block_index| {
            try writer.print("#{}: ({})\n", .{ function_block_index, block_index.uniqueInteger() });
            const block = function.ir.blocks.get(block_index);
            for (block.instructions.items, 0..) |instruction_index, block_instruction_index| {
                try writer.print("%{} (${}): ", .{ block_instruction_index, instruction_index.uniqueInteger() });
                const instruction = function.ir.instructions.get(instruction_index);
                if (instruction.u != .binary_operation) try writer.writeAll(@tagName(instruction.u));
                switch (instruction.u) {
                    .syscall => |syscall_index| {
                        const syscall = function.ir.syscalls.get(syscall_index);
                        try writer.writeAll(" (");
                        for (syscall.arguments.items, 0..) |arg_index, i| {
                            const arg_value = function.ir.instructions.get(arg_index);

                            try writer.print("${}: {s}", .{ i, @tagName(arg_value.u) });

                            if (i < syscall.arguments.items.len - 1) {
                                try writer.writeAll(", ");
                            }
                        }
                        try writer.writeAll(")");
                    },
                    .jump => |jump_index| {
                        const jump = function.ir.jumps.get(jump_index);
                        try writer.print(" ${}", .{jump.destination.uniqueInteger()});
                    },
                    .phi => {},
                    .ret => |ret_index| {
                        const ret = function.ir.returns.get(ret_index);
                        switch (ret.instruction.invalid) {
                            false => {
                                const ret_value = function.ir.instructions.get(ret.instruction);
                                try writer.print(" {s}", .{@tagName(ret_value.u)});
                            },
                            true => try writer.writeAll(" void"),
                        }
                    },
                    // .load => |load_index| {
                    //     const load = function.ir.loads.get(load_index);
                    //     try writer.print(" {s}", .{@tagName(function.ir.values.get(load.value).*)});
                    // },
                    .store => |store_index| {
                        const store = function.ir.stores.get(store_index);
                        const source = function.ir.instructions.get(store.source);
                        const destination = function.ir.instructions.get(store.destination);
                        try writer.print(" {s}, {s}", .{ @tagName(destination.u), @tagName(source.u) });
                    },
                    .call => |call_index| {
                        const call = function.ir.calls.get(call_index);
                        try writer.print(" ${} {s}(", .{ call.function.uniqueInteger(), function.ir.getFunctionName(call.function) });
                        for (call.arguments, 0..) |arg_index, i| {
                            const arg_value = function.ir.instructions.get(arg_index);

                            try writer.print("${}: {s}", .{ i, @tagName(arg_value.u) });

                            if (i < call.arguments.len - 1) {
                                try writer.writeAll(", ");
                            }
                        }
                        try writer.writeAll(")");
                    },
                    .load_integer => |integer| {
                        try writer.print(" {s} (unsigned: 0x{x}, signed {})", .{ @tagName(integer.type), integer.value.unsigned, integer.value.unsigned });
                    },
                    .@"unreachable" => {},
                    .load_string_literal => |string_literal_index| {
                        const string_literal = function.ir.string_literals.get(string_literal_index);
                        try writer.print(" at 0x{x}", .{string_literal.offset});
                    },
                    .stack => |stack_index| {
                        const stack = function.ir.stack_references.get(stack_index);
                        try writer.print(" offset: {}. size: {}. alignment: {}", .{ stack.offset, stack.type.getSize(), stack.alignment });
                    },
                    .argument => |argument_index| {
                        const argument = function.ir.arguments.get(argument_index);
                        try writer.print("${}, size: {}. alignment: {}", .{ argument_index, argument.type.getSize(), argument.type.getAlignment() });
                    },
                    .sign_extend => |cast_index| {
                        const cast = function.ir.casts.get(cast_index);
                        try writer.print(" {s} ${}", .{ @tagName(cast.type), cast.value.uniqueInteger() });
                    },
                    .load => |load_index| {
                        const load = function.ir.loads.get(load_index);
                        try writer.print(" ${}", .{load.instruction.uniqueInteger()});
                    },
                    .binary_operation => |binary_operation_index| {
                        const binary_operation = function.ir.binary_operations.get(binary_operation_index);
                        try writer.writeAll(@tagName(binary_operation.id));
                        try writer.print(" {s} ${}, ${}", .{ @tagName(binary_operation.type), binary_operation.left.uniqueInteger(), binary_operation.right.uniqueInteger() });
                    },
                    else => |t| @panic(@tagName(t)),
                }

                try writer.writeByte('\n');
            }

            try writer.writeByte('\n');
        }
        _ = options;
        _ = fmt;
    }
};

pub const Integer = struct {
    value: extern union {
        signed: i64,
        unsigned: u64,
    },
    type: Type,
};

pub const Builder = struct {
    allocator: Allocator,
    ir: Result,
    current_function_index: Function.Index = Function.Index.invalid,

    fn currentFunction(builder: *Builder) *Function {
        return builder.ir.function_definitions.get(builder.current_function_index);
    }

    fn useInstruction(builder: *Builder, args: struct {
        instruction: Instruction.Index,
        user: Instruction.Index,
    }) !void {
        try builder.ir.instructions.get(args.instruction).use_list.append(builder.allocator, args.user);
    }

    fn buildFunction(builder: *Builder, sema_function: Compilation.Function) !Function.Index {
        const sema_prototype = builder.ir.module.function_prototypes.get(builder.ir.module.types.get(sema_function.prototype).function);
        const function_declaration_allocation = try builder.ir.function_declarations.addOne(builder.allocator);
        const function_declaration = function_declaration_allocation.ptr;
        function_declaration.* = .{
            .calling_convention = sema_prototype.attributes.calling_convention,
            .return_type = try builder.translateType(sema_prototype.return_type),
        };

        const function_decl_name = builder.ir.getFunctionName(function_declaration_allocation.index);
        _ = function_decl_name;

        if (sema_prototype.arguments) |sema_arguments| {
            try function_declaration.arguments.ensureTotalCapacity(builder.allocator, @intCast(sema_arguments.len));
            for (sema_arguments) |sema_argument_declaration_index| {
                const sema_argument_declaration = builder.ir.module.declarations.get(sema_argument_declaration_index);
                const argument_allocation = try builder.ir.arguments.append(builder.allocator, .{
                    .type = try builder.translateType(sema_argument_declaration.type),
                });
                const value_allocation = try builder.ir.instructions.append(builder.allocator, .{
                    .u = .{
                        .argument = argument_allocation.index,
                    },
                });
                function_declaration.arguments.putAssumeCapacity(sema_argument_declaration_index, value_allocation.index);
            }
        }

        switch (sema_prototype.attributes.@"extern") {
            true => return Function.Index.invalid,
            false => {
                const function_allocation = try builder.ir.function_definitions.append(builder.allocator, .{
                    .ir = &builder.ir,
                });
                const function = function_allocation.ptr;

                builder.current_function_index = function_allocation.index;
                function.declaration = function_declaration_allocation.index;

                // TODO: arguments
                function.current_basic_block = try builder.newBlock();

                const return_type = builder.ir.module.types.get(sema_prototype.return_type);
                const is_noreturn = return_type.* == .noreturn;

                if (!is_noreturn) {
                    const exit_block = try builder.newBlock();
                    const phi_instruction = try builder.appendToBlock(exit_block, .{
                        .u = .{
                            .phi = Phi.Index.invalid,
                        },
                    });
                    // phi.ptr.* = .{
                    //     .value = Value.Index.invalid,
                    //     .jump = Jump.Index.invalid,
                    //     .block = exit_block,
                    //     .next = Phi.Index.invalid,
                    // };
                    const ret = try builder.appendToBlock(exit_block, .{
                        .u = .{
                            .ret = (try builder.ir.returns.append(builder.allocator, .{
                                .instruction = phi_instruction,
                            })).index,
                        },
                    });
                    try builder.useInstruction(.{
                        .instruction = phi_instruction,
                        .user = ret,
                    });
                    function.return_phi_node = phi_instruction;
                    function.return_phi_block = exit_block;
                }

                try function.stack_map.ensureUnusedCapacity(builder.allocator, @intCast(function_declaration.arguments.keys().len));

                for (function_declaration.arguments.keys(), function_declaration.arguments.values()) |sema_argument_index, ir_argument_instruction_index| {
                    const ir_argument_instruction = builder.ir.instructions.get(ir_argument_instruction_index);
                    const ir_argument = builder.ir.arguments.get(ir_argument_instruction.u.argument);

                    _ = try builder.stackReference(.{
                        .type = ir_argument.type,
                        .sema = sema_argument_index,
                    });
                }

                for (function_declaration.arguments.keys(), function_declaration.arguments.values()) |sema_argument_index, ir_argument_instruction_index| {
                    const stack_reference = builder.currentFunction().stack_map.get(sema_argument_index).?;

                    const store_instruction = try builder.store(.{
                        .source = ir_argument_instruction_index,
                        .destination = stack_reference,
                    });
                    _ = store_instruction;
                }

                const sema_block = sema_function.getBodyBlock(builder.ir.module);
                try builder.block(sema_block, .{ .emit_exit_block = !is_noreturn });

                if (!is_noreturn and sema_block.reaches_end) {
                    if (!builder.ir.blocks.get(builder.currentFunction().current_basic_block).hasJump(&builder.ir)) {
                        _ = try builder.append(.{
                            .u = .{
                                .jump = try builder.jump(.{
                                    .source = builder.currentFunction().current_basic_block,
                                    .destination = builder.currentFunction().return_phi_block,
                                }),
                            },
                        });
                    }
                }

                builder.currentFunction().current_stack_offset = std.mem.alignForward(usize, builder.currentFunction().current_stack_offset, 0x10);
                try builder.optimizeFunction(builder.currentFunction());

                return function_allocation.index;
            },
        }
    }

    fn blockInsideBasicBlock(builder: *Builder, sema_block: *Compilation.Block, block_index: BasicBlock.Index) !BasicBlock.Index {
        const current_function = builder.currentFunction();
        current_function.current_basic_block = block_index;
        try builder.block(sema_block, .{});
        return current_function.current_basic_block;
    }

    const BlockOptions = packed struct {
        emit_exit_block: bool = true,
    };

    fn emitSyscallArgument(builder: *Builder, sema_syscall_argument_value_index: Compilation.Value.Index) !Instruction.Index {
        const sema_syscall_argument_value = builder.ir.module.values.get(sema_syscall_argument_value_index);
        return switch (sema_syscall_argument_value.*) {
            .integer => |integer| try builder.processInteger(integer),
            .sign_extend => |cast_index| try builder.processCast(cast_index, .sign_extend),
            .declaration_reference => |declaration_reference| try builder.loadDeclarationReference(declaration_reference.value),
            else => |t| @panic(@tagName(t)),
        };
    }

    fn processCast(builder: *Builder, sema_cast_index: Compilation.Cast.Index, cast_type: CastType) !Instruction.Index {
        const sema_cast = builder.ir.module.casts.get(sema_cast_index);
        const sema_source_value = builder.ir.module.values.get(sema_cast.value);
        const source_value = switch (sema_source_value.*) {
            .declaration_reference => |declaration_reference| try builder.loadDeclarationReference(declaration_reference.value),
            else => |t| @panic(@tagName(t)),
        };

        const cast_allocation = try builder.ir.casts.append(builder.allocator, .{
            .value = source_value,
            .type = try builder.translateType(sema_cast.type),
        });

        const result = try builder.append(.{
            .u = @unionInit(Instruction.U, switch (cast_type) {
                inline else => |ct| @tagName(ct),
            }, cast_allocation.index),
        });

        return result;
    }

    fn processDeclarationReferenceRaw(builder: *Builder, declaration_index: Compilation.Declaration.Index) !Instruction.Index {
        const sema_declaration = builder.ir.module.declarations.get(declaration_index);
        const result = switch (sema_declaration.scope_type) {
            .local => builder.currentFunction().stack_map.get(declaration_index).?,
            .global => unreachable,
        };
        return result;
    }

    fn loadDeclarationReference(builder: *Builder, declaration_index: Compilation.Declaration.Index) !Instruction.Index {
        const stack_instruction = try builder.processDeclarationReferenceRaw(declaration_index);
        const load = try builder.ir.loads.append(builder.allocator, .{
            .instruction = stack_instruction,
        });
        return try builder.append(.{
            .u = .{
                .load = load.index,
            },
        });
    }

    fn processInteger(builder: *Builder, integer_value: Compilation.Value.Integer) !Instruction.Index {
        const integer = Integer{
            .value = .{
                .unsigned = integer_value.value,
            },
            .type = try builder.translateType(integer_value.type),
        };
        assert(integer.type.isInteger());
        const instruction_allocation = try builder.ir.instructions.append(builder.allocator, .{
            .u = .{
                .load_integer = integer,
            },
        });
        // const load_integer = try builder.append(.{
        //     .load_integer = integer,
        // });
        return instruction_allocation.index;
    }

    fn processSyscall(builder: *Builder, sema_syscall_index: Compilation.Syscall.Index) anyerror!Instruction.Index {
        const sema_syscall = builder.ir.module.syscalls.get(sema_syscall_index);
        var arguments = try ArrayList(Instruction.Index).initCapacity(builder.allocator, sema_syscall.argument_count + 1);

        const sema_syscall_number = sema_syscall.number;
        assert(!sema_syscall_number.invalid);
        const number_value_index = try builder.emitSyscallArgument(sema_syscall_number);

        arguments.appendAssumeCapacity(number_value_index);

        for (sema_syscall.getArguments()) |sema_syscall_argument| {
            assert(!sema_syscall_argument.invalid);
            const argument_value_index = try builder.emitSyscallArgument(sema_syscall_argument);
            arguments.appendAssumeCapacity(argument_value_index);
        }

        const syscall_allocation = try builder.ir.syscalls.append(builder.allocator, .{
            .arguments = arguments,
        });

        const instruction_index = try builder.append(.{
            .u = .{
                .syscall = syscall_allocation.index,
            },
        });

        for (arguments.items) |argument| {
            try builder.useInstruction(.{
                .instruction = argument,
                .user = instruction_index,
            });
        }

        return instruction_index;
    }

    fn processBinaryOperation(builder: *Builder, sema_binary_operation_index: Compilation.BinaryOperation.Index) !Instruction.Index {
        const sema_binary_operation = builder.ir.module.binary_operations.get(sema_binary_operation_index);

        const left = try builder.emitBinaryOperationOperand(sema_binary_operation.left);
        const right = try builder.emitBinaryOperationOperand(sema_binary_operation.right);

        const binary_operation = try builder.ir.binary_operations.append(builder.allocator, .{
            .left = left,
            .right = right,
            .id = switch (sema_binary_operation.id) {
                .add => .add,
                .sub => .sub,
            },
            .type = try builder.translateType(sema_binary_operation.type),
        });

        const instruction = try builder.append(.{
            .u = .{
                .binary_operation = binary_operation.index,
            },
        });

        try builder.useInstruction(.{
            .instruction = left,
            .user = instruction,
        });

        try builder.useInstruction(.{
            .instruction = right,
            .user = instruction,
        });

        return instruction;
    }

    fn block(builder: *Builder, sema_block: *Compilation.Block, options: BlockOptions) anyerror!void {
        for (sema_block.statements.items) |sema_statement_index| {
            const sema_statement = builder.ir.module.values.get(sema_statement_index);
            switch (sema_statement.*) {
                .loop => |loop_index| {
                    const sema_loop = builder.ir.module.loops.get(loop_index);
                    const sema_loop_condition = builder.ir.module.values.get(sema_loop.condition);
                    const sema_loop_body = builder.ir.module.values.get(sema_loop.body);
                    const condition: Compilation.Value.Index = switch (sema_loop_condition.*) {
                        .bool => |bool_value| switch (bool_value) {
                            true => Compilation.Value.Index.invalid,
                            false => unreachable,
                        },
                        else => |t| @panic(@tagName(t)),
                    };

                    const original_block = builder.currentFunction().current_basic_block;
                    const jump_to_loop = try builder.append(.{
                        .u = .{
                            .jump = undefined,
                        },
                    });
                    const loop_body_block = try builder.newBlock();
                    const loop_prologue_block = if (options.emit_exit_block) try builder.newBlock() else BasicBlock.Index.invalid;

                    const loop_head_block = switch (!condition.invalid) {
                        false => loop_body_block,
                        true => unreachable,
                    };

                    builder.ir.instructions.get(jump_to_loop).u.jump = try builder.jump(.{
                        .source = original_block,
                        .destination = loop_head_block,
                    });

                    const sema_body_block = builder.ir.module.blocks.get(sema_loop_body.block);
                    builder.currentFunction().current_basic_block = try builder.blockInsideBasicBlock(sema_body_block, loop_body_block);
                    if (!loop_prologue_block.invalid) {
                        builder.ir.blocks.get(loop_prologue_block).seal();
                    }

                    if (sema_body_block.reaches_end) {
                        _ = try builder.append(.{
                            .u = .{
                                .jump = try builder.jump(.{
                                    .source = builder.currentFunction().current_basic_block,
                                    .destination = loop_head_block,
                                }),
                            },
                        });
                    }

                    builder.ir.blocks.get(builder.currentFunction().current_basic_block).filled = true;
                    builder.ir.blocks.get(loop_body_block).seal();
                    if (!loop_head_block.eq(loop_body_block)) {
                        unreachable;
                    }

                    if (!loop_prologue_block.invalid) {
                        builder.currentFunction().current_basic_block = loop_prologue_block;
                    }
                },
                .syscall => |sema_syscall_index| _ = try builder.processSyscall(sema_syscall_index),
                .@"unreachable" => _ = try builder.append(.{
                    .u = .{
                        .@"unreachable" = {},
                    },
                }),
                .@"return" => |sema_ret_index| {
                    const sema_ret = builder.ir.module.returns.get(sema_ret_index);
                    const return_value = try builder.emitReturnValue(sema_ret.value);
                    const phi_instruction = builder.ir.instructions.get(builder.currentFunction().return_phi_node);
                    const phi = switch (phi_instruction.u.phi.invalid) {
                        false => unreachable,
                        true => (try builder.ir.phis.append(builder.allocator, std.mem.zeroes(Phi))).ptr,
                    }; //builder.ir.phis.get(phi_instruction.phi);
                    const exit_jump = try builder.jump(.{
                        .source = builder.currentFunction().current_basic_block,
                        .destination = switch (!phi_instruction.u.phi.invalid) {
                            true => phi.block,
                            false => builder.currentFunction().return_phi_block,
                        },
                    });

                    phi_instruction.u.phi = (try builder.ir.phis.append(builder.allocator, .{
                        .instruction = return_value,
                        .jump = exit_jump,
                        .next = phi_instruction.u.phi,
                        .block = phi.block,
                    })).index;

                    try builder.useInstruction(.{
                        .instruction = return_value,
                        .user = builder.currentFunction().return_phi_node,
                    });

                    _ = try builder.append(.{
                        .u = .{
                            .jump = exit_jump,
                        },
                    });
                },
                .declaration => |sema_declaration_index| {
                    const sema_declaration = builder.ir.module.declarations.get(sema_declaration_index);
                    //logln("Name: {s}\n", .{builder.module.getName(sema_declaration.name).?});
                    assert(sema_declaration.scope_type == .local);
                    const declaration_type = builder.ir.module.types.get(sema_declaration.type);
                    switch (declaration_type.*) {
                        .comptime_int => unreachable,
                        else => {
                            var value_index = try builder.emitDeclarationInitValue(sema_declaration.init_value);
                            const value = builder.ir.instructions.get(value_index);
                            value_index = switch (value.u) {
                                .load_integer,
                                .call,
                                .binary_operation,
                                => value_index,
                                // .call => try builder.load(value_index),
                                else => |t| @panic(@tagName(t)),
                            };

                            const ir_type = try builder.translateType(sema_declaration.type);

                            const stack_i = try builder.stackReference(.{
                                .type = ir_type,
                                .sema = sema_declaration_index,
                            });
                            const store_instruction = try builder.store(.{
                                .source = value_index,
                                .destination = stack_i,
                            });
                            _ = store_instruction;
                        },
                    }
                },
                .call => |sema_call_index| _ = try builder.processCall(sema_call_index),
                else => |t| @panic(@tagName(t)),
            }
        }
    }

    fn emitDeclarationInitValue(builder: *Builder, declaration_init_value_index: Compilation.Value.Index) !Instruction.Index {
        const declaration_init_value = builder.ir.module.values.get(declaration_init_value_index);
        return switch (declaration_init_value.*) {
            .call => |call_index| try builder.processCall(call_index),
            .integer => |integer| try builder.processInteger(integer),
            .binary_operation => |binary_operation_index| try builder.processBinaryOperation(binary_operation_index),
            else => |t| @panic(@tagName(t)),
        };
    }

    fn emitReturnValue(builder: *Builder, return_value_index: Compilation.Value.Index) !Instruction.Index {
        const return_value = builder.ir.module.values.get(return_value_index);
        return switch (return_value.*) {
            .syscall => |syscall_index| try builder.processSyscall(syscall_index),
            .integer => |integer| try builder.processInteger(integer),
            .call => |call_index| try builder.processCall(call_index),
            .declaration_reference => |declaration_reference| try builder.loadDeclarationReference(declaration_reference.value),
            else => |t| @panic(@tagName(t)),
        };
    }

    fn emitBinaryOperationOperand(builder: *Builder, binary_operation_index: Compilation.Value.Index) !Instruction.Index {
        const value = builder.ir.module.values.get(binary_operation_index);
        return switch (value.*) {
            .integer => |integer| try builder.processInteger(integer),
            .call => |call_index| try builder.processCall(call_index),
            .declaration_reference => |declaration_reference| try builder.loadDeclarationReference(declaration_reference.value),
            else => |t| @panic(@tagName(t)),
        };
    }

    fn stackReference(builder: *Builder, arguments: struct {
        type: Type,
        sema: Compilation.Declaration.Index,
        alignment: ?u64 = null,
    }) !Instruction.Index {
        const size = arguments.type.getSize();
        assert(size > 0);
        const alignment = if (arguments.alignment) |a| a else arguments.type.getAlignment();
        builder.currentFunction().current_stack_offset = std.mem.alignForward(u64, builder.currentFunction().current_stack_offset, alignment);
        builder.currentFunction().current_stack_offset += size;
        const stack_offset = builder.currentFunction().current_stack_offset;
        const stack_reference_allocation = try builder.ir.stack_references.append(builder.allocator, .{
            .offset = stack_offset,
            .type = arguments.type,
            .alignment = alignment,
        });

        const instruction_index = try builder.append(.{
            .u = .{
                .stack = stack_reference_allocation.index,
            },
        });

        try builder.currentFunction().stack_map.put(builder.allocator, arguments.sema, instruction_index);

        return instruction_index;
    }

    fn store(builder: *Builder, descriptor: Store) !Instruction.Index {
        const store_allocation = try builder.ir.stores.append(builder.allocator, descriptor);

        const result = try builder.append(.{
            .u = .{
                .store = store_allocation.index,
            },
        });

        try builder.useInstruction(.{
            .instruction = descriptor.source,
            .user = result,
        });

        try builder.useInstruction(.{
            .instruction = descriptor.destination,
            .user = result,
        });

        return result;
    }

    fn emitCallArgument(builder: *Builder, call_argument_value_index: Compilation.Value.Index) !Instruction.Index {
        const call_argument_value = builder.ir.module.values.get(call_argument_value_index);
        return switch (call_argument_value.*) {
            .integer => |integer| try builder.processInteger(integer),
            .declaration_reference => |declaration_reference| try builder.loadDeclarationReference(declaration_reference.value),
            .string_literal => |string_literal_index| try builder.processStringLiteral(string_literal_index),
            else => |t| @panic(@tagName(t)),
        };
    }

    fn processCall(builder: *Builder, sema_call_index: Compilation.Call.Index) anyerror!Instruction.Index {
        const sema_call = builder.ir.module.calls.get(sema_call_index);
        const sema_argument_list_index = sema_call.arguments;
        const argument_list: []const Instruction.Index = switch (sema_argument_list_index.invalid) {
            false => blk: {
                var argument_list = ArrayList(Instruction.Index){};
                const sema_argument_list = builder.ir.module.argument_lists.get(sema_argument_list_index);
                try argument_list.ensureTotalCapacity(builder.allocator, sema_argument_list.array.items.len);
                for (sema_argument_list.array.items) |sema_argument_value_index| {
                    const argument_value_index = try builder.emitCallArgument(sema_argument_value_index);
                    argument_list.appendAssumeCapacity(argument_value_index);
                }
                break :blk argument_list.items;
            },
            true => &.{},
        };

        const call_index = try builder.call(.{
            .function = switch (builder.ir.module.values.get(sema_call.value).*) {
                .function => |function_index| .{
                    .index = function_index.index,
                    .block = function_index.block,
                },
                else => |t| @panic(@tagName(t)),
            },
            .arguments = argument_list,
        });

        const instruction_index = try builder.append(.{
            .u = .{
                .call = call_index,
            },
        });

        for (argument_list) |argument| {
            try builder.useInstruction(.{
                .instruction = argument,
                .user = instruction_index,
            });
        }

        return instruction_index;
    }

    fn processStringLiteral(builder: *Builder, string_literal_hash: u32) !Instruction.Index {
        const string_literal = builder.ir.module.string_literals.getValue(string_literal_hash).?;

        if (builder.ir.section_manager.rodata == null) {
            const rodata_index = try builder.ir.section_manager.addSection(.{
                .name = ".rodata",
                .size_guess = 0,
                .alignment = 0x1000,
                .flags = .{
                    .read = true,
                    .write = false,
                    .execute = false,
                },
                .type = .loadable_program,
            });

            builder.ir.section_manager.rodata = @intCast(rodata_index);
        }

        const rodata_index = builder.ir.section_manager.rodata orelse unreachable;
        const rodata_section_offset = builder.ir.section_manager.getSectionOffset(rodata_index);

        try builder.ir.section_manager.appendToSection(rodata_index, string_literal);
        try builder.ir.section_manager.appendByteToSection(rodata_index, 0);

        const string_literal_allocation = try builder.ir.string_literals.append(builder.allocator, .{
            .offset = @intCast(rodata_section_offset),
        });

        const result = try builder.append(.{
            .u = .{
                .load_string_literal = string_literal_allocation.index,
            },
        });

        return result;
    }

    fn translateType(builder: *Builder, type_index: Compilation.Type.Index) !Type {
        const sema_type = builder.ir.module.types.get(type_index);
        return switch (sema_type.*) {
            .integer => |integer| switch (integer.bit_count) {
                8 => .i8,
                16 => .i16,
                32 => .i32,
                64 => .i64,
                else => unreachable,
            },
            // TODO
            .pointer => .i64,
            .void => .void,
            .noreturn => .noreturn,
            else => |t| @panic(@tagName(t)),
        };
    }

    fn call(builder: *Builder, descriptor: Call) !Call.Index {
        const call_allocation = try builder.ir.calls.append(builder.allocator, descriptor);
        return call_allocation.index;
    }

    fn jump(builder: *Builder, descriptor: Jump) !Jump.Index {
        const destination_block = builder.ir.blocks.get(descriptor.destination);
        assert(!destination_block.sealed);
        assert(!descriptor.source.invalid);
        const jump_allocation = try builder.ir.jumps.append(builder.allocator, descriptor);
        return jump_allocation.index;
    }

    fn append(builder: *Builder, instruction: Instruction) !Instruction.Index {
        assert(!builder.current_function_index.invalid);
        const current_function = builder.currentFunction();
        assert(!current_function.current_basic_block.invalid);
        return builder.appendToBlock(current_function.current_basic_block, instruction);
    }

    fn appendToBlock(builder: *Builder, block_index: BasicBlock.Index, instruction: Instruction) !Instruction.Index {
        const instruction_allocation = try builder.ir.instructions.append(builder.allocator, instruction);
        try builder.ir.blocks.get(block_index).instructions.append(builder.allocator, instruction_allocation.index);

        return instruction_allocation.index;
    }

    fn newBlock(builder: *Builder) !BasicBlock.Index {
        const new_block_allocation = try builder.ir.blocks.append(builder.allocator, .{});
        const current_function = builder.currentFunction();
        try current_function.blocks.append(builder.allocator, new_block_allocation.index);

        return new_block_allocation.index;
    }

    const BlockSearcher = struct {
        to_visit: ArrayList(BasicBlock.Index) = .{},
        visited: AutoArrayHashMap(BasicBlock.Index, void) = .{},
    };

    fn findReachableBlocks(builder: *Builder, first: BasicBlock.Index) !ArrayList(BasicBlock.Index) {
        var searcher = BlockSearcher{};
        try searcher.to_visit.append(builder.allocator, first);
        try searcher.visited.put(builder.allocator, first, {});

        while (searcher.to_visit.items.len > 0) {
            const block_index = searcher.to_visit.swapRemove(0);
            const block_to_visit = builder.ir.blocks.get(block_index);
            const last_instruction_index = block_to_visit.instructions.items[block_to_visit.instructions.items.len - 1];
            const last_instruction = builder.ir.instructions.get(last_instruction_index);
            const block_to_search = switch (last_instruction.u) {
                .jump => |jump_index| blk: {
                    const ir_jump = builder.ir.jumps.get(jump_index);
                    assert(ir_jump.source.eq(block_index));
                    const new_block = ir_jump.destination;
                    break :blk new_block;
                },
                .call => |call_index| blk: {
                    const ir_call = builder.ir.calls.get(call_index);
                    const function_declaration_index = ir_call.function;
                    const function_declaration = builder.ir.function_declarations.get(function_declaration_index);
                    const function_definition_index = function_declaration.definition;
                    switch (function_definition_index.invalid) {
                        false => {
                            const function = builder.ir.function_definitions.get(function_definition_index);
                            const first_block = function.blocks.items[0];
                            break :blk first_block;
                        },
                        true => continue,
                    }
                },
                .@"unreachable", .ret, .store => continue,
                else => |t| @panic(@tagName(t)),
            };

            if (searcher.visited.get(block_to_search) == null) {
                try searcher.to_visit.append(builder.allocator, block_to_search);
                try searcher.visited.put(builder.allocator, block_to_search, {});
            }
        }

        var list = try ArrayList(BasicBlock.Index).initCapacity(builder.allocator, searcher.visited.keys().len);
        list.appendSliceAssumeCapacity(searcher.visited.keys());

        return list;
    }

    fn optimizeFunction(builder: *Builder, function: *Function) !void {
        // HACK
        logln(.ir, .function, "\n[BEFORE OPTIMIZE]:\n{}", .{function});
        var reachable_blocks = try builder.findReachableBlocks(function.blocks.items[0]);
        var did_something = true;

        while (did_something) {
            did_something = false;
            for (reachable_blocks.items) |basic_block_index| {
                const basic_block = builder.ir.blocks.get(basic_block_index);
                for (basic_block.instructions.items) |instruction_index| {
                    did_something = did_something or try builder.removeUnreachablePhis(reachable_blocks.items, instruction_index);
                    did_something = did_something or try builder.removeTrivialPhis(instruction_index);
                    const copy = try builder.removeCopyReferences(instruction_index);
                    did_something = did_something or copy;
                }

                if (basic_block.instructions.items.len > 0) {
                    const instruction = builder.ir.instructions.get(basic_block.instructions.getLast());
                    switch (instruction.u) {
                        .jump => |jump_index| {
                            const jump_instruction = builder.ir.jumps.get(jump_index);
                            const source = basic_block_index;
                            assert(source.eq(jump_instruction.source));
                            const destination = jump_instruction.destination;

                            const source_index = for (function.blocks.items, 0..) |bi, index| {
                                if (source.eq(bi)) break index;
                            } else unreachable;
                            const destination_index = for (function.blocks.items, 0..) |bi, index| {
                                if (destination.eq(bi)) break index;
                            } else unreachable;

                            if (destination_index == source_index + 1) {
                                const destination_block = builder.ir.blocks.get(destination);
                                _ = basic_block.instructions.pop();
                                try basic_block.instructions.appendSlice(builder.allocator, destination_block.instructions.items);
                                _ = function.blocks.orderedRemove(destination_index);
                                const reachable_index = for (reachable_blocks.items, 0..) |bi, index| {
                                    if (destination.eq(bi)) break index;
                                } else unreachable;
                                _ = reachable_blocks.swapRemove(reachable_index);
                                did_something = true;
                                break;
                            }
                        },
                        .ret, .@"unreachable", .call => {},
                        else => |t| @panic(@tagName(t)),
                    }
                } else {
                    unreachable;
                }
            }
        }

        var instructions_to_delete = ArrayList(u32){};
        for (reachable_blocks.items) |basic_block_index| {
            instructions_to_delete.clearRetainingCapacity();
            const basic_block = builder.ir.blocks.get(basic_block_index);
            for (basic_block.instructions.items, 0..) |instruction_index, index| {
                const instruction = builder.ir.instructions.get(instruction_index);
                switch (instruction.u) {
                    .copy => try instructions_to_delete.append(builder.allocator, @intCast(index)),
                    else => {},
                }
            }

            var deleted_instruction_count: usize = 0;
            for (instructions_to_delete.items) |instruction_to_delete| {
                _ = basic_block.instructions.orderedRemove(instruction_to_delete - deleted_instruction_count);
            }
        }

        logln(.ir, .function, "[AFTER OPTIMIZE]:\n{}", .{function});
    }

    fn removeUnreachablePhis(builder: *Builder, reachable_blocks: []const BasicBlock.Index, instruction_index: Instruction.Index) !bool {
        const instruction = builder.ir.instructions.get(instruction_index);
        return switch (instruction.u) {
            .phi => blk: {
                var did_something = false;
                var head = &instruction.u.phi;
                next: while (!head.invalid) {
                    const phi = builder.ir.phis.get(head.*);
                    const phi_jump = builder.ir.jumps.get(phi.jump);
                    assert(!phi_jump.source.invalid);

                    for (reachable_blocks) |block_index| {
                        if (phi_jump.source.eq(block_index)) {
                            head = &phi.next;
                            continue :next;
                        }
                    }

                    head.* = phi.next;
                    did_something = true;
                }

                break :blk did_something;
            },
            else => false,
        };
    }

    fn removeTrivialPhis(builder: *Builder, instruction_index: Instruction.Index) !bool {
        const instruction = builder.ir.instructions.get(instruction_index);
        return switch (instruction.u) {
            .phi => |phi_index| blk: {
                const trivial_phi: ?Instruction.Index = trivial_blk: {
                    var only_value = Instruction.Index.invalid;
                    var it = phi_index;

                    while (!it.invalid) {
                        const phi = builder.ir.phis.get(it);
                        const phi_value = builder.ir.instructions.get(phi.instruction);
                        if (phi_value.u == .phi) unreachable;
                        // TODO: undefined
                        if (!only_value.invalid) {
                            if (!only_value.eq(phi.instruction)) {
                                break :trivial_blk null;
                            }
                        } else {
                            only_value = phi.instruction;
                        }

                        it = phi.next;
                    }

                    break :trivial_blk only_value;
                };

                if (trivial_phi) |trivial_value| {
                    if (!trivial_value.invalid) {
                        // Option to delete
                        const delete = false;
                        if (delete) {
                            unreachable;
                        } else {
                            instruction.* = .{
                                .u = .{
                                    .copy = trivial_value,
                                },
                            };
                        }
                    } else {
                        logln(.ir, .phi_removal, "TODO: maybe this phi removal is wrong?", .{});
                        instruction.* = .{
                            .u = .{
                                .copy = trivial_value,
                            },
                        };
                    }
                }

                break :blk instruction.u != .phi;
            },
            else => false,
        };
    }

    fn removeCopyReferences(builder: *Builder, instruction_index: Instruction.Index) !bool {
        const instruction = builder.ir.instructions.get(instruction_index);
        return switch (instruction.u) {
            .copy => false,
            else => {
                var did_something = false;

                const operands: []const *Instruction.Index = switch (instruction.u) {
                    .jump, .@"unreachable", .load_integer, .load_string_literal, .stack, .argument => &.{},
                    .ret => &.{&builder.ir.returns.get(instruction.u.ret).instruction},
                    // TODO: arguments
                    .call => blk: {
                        var list = ArrayList(*Instruction.Index){};
                        break :blk list.items;
                    },
                    .store => |store_index| blk: {
                        const store_instr = builder.ir.stores.get(store_index);
                        break :blk &.{ &store_instr.source, &store_instr.destination };
                    },
                    .syscall => |syscall_index| blk: {
                        const syscall = builder.ir.syscalls.get(syscall_index);
                        var list = ArrayList(*Instruction.Index){};
                        try list.ensureTotalCapacity(builder.allocator, syscall.arguments.items.len);
                        for (syscall.arguments.items) |*arg| {
                            list.appendAssumeCapacity(arg);
                        }

                        break :blk list.items;
                    },
                    .sign_extend => |cast_index| blk: {
                        const cast = builder.ir.casts.get(cast_index);
                        break :blk &.{&cast.value};
                    },
                    .load => |load_index| blk: {
                        const load = builder.ir.loads.get(load_index);
                        break :blk &.{&load.instruction};
                    },
                    .binary_operation => |binary_operation_index| blk: {
                        const binary_operation = builder.ir.binary_operations.get(binary_operation_index);
                        break :blk &.{ &binary_operation.left, &binary_operation.right };
                    },
                    else => |t| @panic(@tagName(t)),
                };

                for (operands) |operand_instruction_index_pointer| {
                    switch (operand_instruction_index_pointer.invalid) {
                        false => {
                            const operand_value = builder.ir.instructions.get(operand_instruction_index_pointer.*);
                            switch (operand_value.u) {
                                .copy => |copy_value| {
                                    operand_instruction_index_pointer.* = copy_value;
                                    did_something = true;
                                },
                                .load_integer,
                                .stack,
                                .call,
                                .argument,
                                .syscall,
                                .sign_extend,
                                .load,
                                .binary_operation,
                                => {},
                                else => |t| @panic(@tagName(t)),
                            }
                        },
                        true => {},
                    }
                }

                return did_something;
            },
        };
    }
};
