const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const data_structures = @import("data_structures.zig");
const fs = @import("fs.zig");

const compiler = @import("compiler.zig");

pub const seed = std.math.maxInt(u64);

pub fn main() !void {
    try compiler.cycle(fs.first);
}

test {
    _ = compiler;
    // _ = parser;
    // _ = ir;
    // _ = emit;
}
