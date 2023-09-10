const std = @import("std");
const assert = std.debug.assert;

pub const Allocator = std.mem.Allocator;
pub const ArrayList = std.ArrayListUnmanaged;
pub const AutoHashMap = std.AutoHashMapUnmanaged;
pub const HashMap = std.HashMapUnmanaged;
pub const SegmentedList = std.SegmentedList;
pub const StringHashMap = std.StringHashMapUnmanaged;
pub const StringArrayHashMap = std.StringArrayHashMapUnmanaged;

pub fn BlockList(comptime T: type) type {
    const item_count = 64;
    const Block = struct {
        items: [item_count]T = undefined,
        bitset: Bitset = Bitset.initEmpty(),

        const Bitset = std.StaticBitSet(item_count);

        fn allocateIndex(block: *@This()) !u6 {
            if (block.bitset.mask != std.math.maxInt(@TypeOf(block.bitset.mask))) {
                const index = @ctz(~block.bitset.mask);
                block.bitset.set(index);
                return @intCast(index);
            } else {
                return error.OutOfMemory;
            }
        }
    };

    return struct {
        blocks: ArrayList(Block) = .{},
        len: usize = 0,
        first_block: u32 = 0,

        const List = @This();

        pub const Index = packed struct(u32) {
            valid: bool = true,
            index: u6,
            block: u25,

            pub const invalid = Index{
                .valid = false,
                .index = 0,
                .block = 0,
            };
        };

        pub fn get(list: *List, index: Index) *T {
            assert(index.valid);
            return &list.blocks.items[index.block].items[index.index];
        }

        pub fn append(list: *List, allocator: Allocator, element: T) !Index {
            try list.ensureCapacity(allocator, list.len + 1);
            const max_allocation = list.blocks.items.len * item_count;
            if (list.len < max_allocation) {
                // Follow the guess
                if (list.blocks.items[list.first_block].allocateIndex()) |index| {
                    list.blocks.items[list.first_block].items[index] = element;
                    return .{
                        .index = index,
                        .block = @intCast(list.first_block),
                    };
                } else |_| {
                    @panic("TODO");
                }
            } else {
                const block_index = list.blocks.items.len;
                const new_block = list.blocks.addOneAssumeCapacity();
                const index = new_block.allocateIndex() catch unreachable;
                new_block.items[index] = element;
                return .{
                    .index = index,
                    .block = @intCast(block_index),
                };
            }
        }

        pub fn ensureCapacity(list: *List, allocator: Allocator, new_capacity: usize) !void {
            const max_allocation = list.blocks.items.len * item_count;
            if (max_allocation < new_capacity) {
                const block_count = new_capacity / item_count + @intFromBool(new_capacity % item_count != 0);
                try list.blocks.ensureTotalCapacity(allocator, block_count);
            }
        }

        test "Bitset index allocation" {
            const expect = std.testing.expect;
            var block = Block{};
            for (0..item_count) |expected_index| {
                const new_index = try block.allocateIndex();
                try expect(new_index == expected_index);
            }

            _ = block.allocateIndex() catch return;

            return error.TestUnexpectedResult;
        }
    };
}

pub fn enumFromString(comptime E: type, string: []const u8) ?E {
    return inline for (@typeInfo(E).Enum.fields) |enum_field| {
        if (std.mem.eql(u8, string, enum_field.name)) {
            break @field(E, enum_field.name);
        }
    } else null;
}
