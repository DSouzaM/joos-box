const std = @import("std");
const fs = std.fs;
const io = std.io;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;

const decode = @import("classfile/decode.zig");
const structs = @import("classfile/structs.zig");

pub fn fromFile(path: []const u8, allocator: *Allocator) !structs.ClassFile {
    // TODO: support any directory
    const cwd = fs.cwd();
    const file = try cwd.openFile(path, .{});
    defer file.close();

    // Class files are encoded in big-endian.
    var input = io.bitInStream(.Big, file.inStream());

    return decode.decode_class_file(&input, allocator);
}

test "fromFile" {
    const allocator = std.testing.allocator;
    const c = try fromFile("test/res/Foo.class", allocator);

    expect(c.magic == 0xCAFEBABE);
    expect(c.minor_version == 0);
    expect(c.major_version == 55);
    expect(c.constant_pool.len == 41);
    expect(c.access_flags == @enumToInt(structs.ClassAccessFlags.Public) | @enumToInt(structs.ClassAccessFlags.Super));
    expect(c.this_class == 12);
    expect(c.super_class == 13);
    expect(c.interfaces.len == 1);
    expect(c.fields.len == 4);
    expect(c.methods.len == 4);
    expect(c.attributes.len == 1);

    c.destroy(allocator);
}
