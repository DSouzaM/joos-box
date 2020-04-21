const std = @import("std");
const io = std.io;
const fs = std.fs;
const Allocator = std.mem.Allocator;

const classfile = @import("classfile.zig");

pub fn main() anyerror!u8 {
    const allocator = std.heap.c_allocator;
    const c = try classfile.from_file("test/res/Foo.class", allocator);

    std.debug.warn("magic 0x{X}\n", .{c.magic});
    std.debug.warn("version {}.{}\n", .{ c.major_version, c.minor_version });

    c.destroy(allocator);
    return 0;
}
