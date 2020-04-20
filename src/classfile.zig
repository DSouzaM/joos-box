const std = @import("std");
const fs = std.fs;
const io = std.io;
const expect = std.testing.expect;

const decode = @import("classfile/decode.zig");
const structs = @import("classfile/structs.zig");

pub fn from_file(path: []const u8) !structs.ClassFile {
    // TODO: support any directory
    const cwd = fs.cwd();
    const file = try cwd.openFile(path, .{});
    defer file.close();

    // Class files are encoded in big-endian.
    var input = io.bitInStream(.Big, file.inStream());

    return decode.decode_class_file(&input);
}

test "from_file" {
    const c = try from_file("test/res/Foo.class");

    expect(c.magic == 0xCAFEBABE);
    expect(c.minor_version == 0);
    expect(c.major_version == 55);
}