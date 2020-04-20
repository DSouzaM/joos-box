const std = @import("std");
const io = std.io;
const fs = std.fs;

const classfile = @import("classfile.zig");

pub fn main() anyerror!u8 {
    const c = try classfile.from_file("test/res/Foo.class");

    std.debug.warn("magic 0x{X}\n", .{c.magic});
    std.debug.warn("version {}.{}\n", .{c.major_version, c.minor_version});

    return 0;
}
