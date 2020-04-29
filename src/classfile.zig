const std = @import("std");
const fs = std.fs;
const Dir = fs.Dir;
const io = std.io;
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const Allocator = std.mem.Allocator;

const decode = @import("classfile/decode.zig");
const structs = @import("classfile/structs.zig");

const ClassFileError = error {
    ClassNotFoundError,
};

pub fn fromFile(cwd: Dir, path: []const u8, allocator: *Allocator) !structs.ClassFile {
    const file = cwd.openFile(path, .{}) catch |err| switch(err) {
        error.FileNotFound => return error.ClassNotFoundError,
        else => return err,
    };
    defer file.close();

    // Class files are encoded in big-endian.
    var input = io.bitInStream(.Big, file.inStream());

    return decode.decode_class_file(&input, allocator);
}

test "fromFile" {
    const allocator = std.testing.allocator;
    const c = try fromFile(fs.cwd(), "test/res/Foo.class", allocator);

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

test "fromFile failure" {
    const allocator = std.testing.allocator;
    const c = fromFile(fs.cwd(), "does/not/Exist.class", allocator);

    expectError(error.ClassNotFoundError, c);
}