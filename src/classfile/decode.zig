const std = @import("std");
const structs = @import("structs.zig");
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;

fn read_int(comptime T: type, input: var) !T {
    return input.*.readBitsNoEof(T, @bitSizeOf(T));
}

pub fn decode_class_file(input: var, allocator: *Allocator) !structs.ClassFile {
    const magic = try read_int(u32, input);
    const minor_version = try read_int(u16, input);
    const major_version = try read_int(u16, input);
    const constant_pool = try decode_constant_pool(input, allocator);
    const access_flags = try read_int(u16, input);
    const this_class = try read_int(u16, input);
    const super_class = try read_int(u16, input);

    return structs.ClassFile{
        .magic = magic,
        .minor_version = minor_version,
        .major_version = major_version,
        .constant_pool = constant_pool,
        .access_flags = access_flags,
        .this_class = this_class,
        .super_class = super_class,
    };
}

fn decode_constant_pool(input: var, allocator: *Allocator) ![]structs.ConstantPoolInfo {
    const constant_pool_count = try read_int(u16, input);
    const constant_pool = try allocator.alloc(structs.ConstantPoolInfo, constant_pool_count);
    // Valid constant pool indices start at 1.
    var i: u16 = 1;
    while (i < constant_pool_count) {
        constant_pool[i] = try decode_constant_pool_entry(input, allocator);
        // Longs and doubles take up 2 "slots" in the constant pool.
        switch (constant_pool[i]) {
            .Long, .Double => i += 1,
            else => {},
        }
        i += 1;
    }
    return constant_pool;
}

fn decode_constant_pool_entry(input: var, allocator: *Allocator) !structs.ConstantPoolInfo {
    const tag_int = try read_int(u8, input);
    const tag = @intToEnum(structs.ConstantPoolTag, tag_int);
    return switch (tag) {
        structs.ConstantPoolTag.Class => structs.ConstantPoolInfo{
            .Class = .{
                .name_index = try read_int(u16, input),
            },
        },
        structs.ConstantPoolTag.FieldRef => structs.ConstantPoolInfo{
            .FieldRef = .{
                .class_index = try read_int(u16, input),
                .name_and_type_index = try read_int(u16, input),
            },
        },
        structs.ConstantPoolTag.MethodRef => structs.ConstantPoolInfo{
            .MethodRef = .{
                .class_index = try read_int(u16, input),
                .name_and_type_index = try read_int(u16, input),
            },
        },
        structs.ConstantPoolTag.InterfaceMethodRef => structs.ConstantPoolInfo{
            .InterfaceMethodRef = .{
                .class_index = try read_int(u16, input),
                .name_and_type_index = try read_int(u16, input),
            },
        },
        structs.ConstantPoolTag.String => structs.ConstantPoolInfo{
            .String = .{
                .string_index = try read_int(u16, input),
            },
        },
        structs.ConstantPoolTag.Integer => structs.ConstantPoolInfo{
            .Integer = .{
                .bytes = try read_int(u32, input),
            },
        },
        structs.ConstantPoolTag.Float => structs.ConstantPoolInfo{
            .Float = .{
                .bytes = try read_int(u32, input),
            },
        },
        structs.ConstantPoolTag.Long => structs.ConstantPoolInfo{
            .Long = .{
                .high_bytes = try read_int(u32, input),
                .low_bytes = try read_int(u32, input),
            },
        },
        structs.ConstantPoolTag.Double => structs.ConstantPoolInfo{
            .Double = .{
                .high_bytes = try read_int(u32, input),
                .low_bytes = try read_int(u32, input),
            },
        },
        structs.ConstantPoolTag.NameAndType => structs.ConstantPoolInfo{
            .NameAndType = .{
                .name_index = try read_int(u16, input),
                .descriptor_index = try read_int(u16, input),
            },
        },
        structs.ConstantPoolTag.Utf8 => blk: {
            const length = try read_int(u16, input);
            const bytes = try allocator.alloc(u8, length);
            if ((try input.*.read(bytes)) != length) unreachable;
            break :blk structs.ConstantPoolInfo{
                .Utf8 = .{
                    .length = length,
                    .bytes = bytes,
                },
            };
        },
        structs.ConstantPoolTag.MethodHandle => structs.ConstantPoolInfo{
            .MethodHandle = .{
                .reference_kind = try read_int(u8, input),
                .reference_index = try read_int(u16, input),
            },
        },
        structs.ConstantPoolTag.MethodType => structs.ConstantPoolInfo{
            .MethodType = .{
                .descriptor_index = try read_int(u16, input),
            },
        },
        structs.ConstantPoolTag.InvokeDynamic => structs.ConstantPoolInfo{
            .InvokeDynamic = .{
                .bootstrap_method_attr_index = try read_int(u16, input),
                .name_and_type_index = try read_int(u16, input),
            },
        },
    };
}

test "read_int" {
    const buf = [_]u8{ 0xCA, 0xFE, 0xBA, 0xBE, 0x01, 0x02, 0x03, 0x04, 0x05 };
    var input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&buf).inStream());

    expect((try read_int(u32, &input)) == 0xCAFEBABE);
    expect((try read_int(u16, &input)) == 0x0102);
    expect((try read_int(u8, &input)) == 0x03);
    expect((try read_int(u16, &input)) == 0x0405);
}

test "decode_constant_pool" {
    const allocator = std.testing.allocator;

    var input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{
        0x00, 0x08, // constant_pool_size = 8
        0x07, 0x00,
        0x02, // 1: class
            0x05,
        0x11, 0x22,
        0x33, 0x44,
        0x55, 0x66,
        0x77, 0x88, // 2 (and 3): long
        0x08, 0x00,
        0x05, // 4: string
            0x06,
        0x55, 0x66,
        0x77, 0x88,
        0x11, 0x22,
        0x33, 0x44, // 5 (and 6): double
        0x03, 0x12,
        0x34, 0x56,
        0x78, // 7: int
    }).inStream());
    var decoded = try decode_constant_pool(&input, allocator);
    expect(decoded.len == 8);
    expect(decoded[1] == structs.ConstantPoolTag.Class);
    expect(decoded[2] == structs.ConstantPoolTag.Long);
    expect(decoded[4] == structs.ConstantPoolTag.String);
    expect(decoded[5] == structs.ConstantPoolTag.Double);
    expect(decoded[7] == structs.ConstantPoolTag.Integer);

    allocator.free(decoded);
}

test "decode_constant_pool_entry" {
    const allocator = std.testing.allocator;

    var input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{ 0x07, 0x12, 0x34 }).inStream());
    var decoded = try decode_constant_pool_entry(&input, allocator);
    expect(decoded == structs.ConstantPoolTag.Class);
    expect(decoded.Class.name_index == 0x1234);

    input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{ 0x09, 0x12, 0x34, 0x56, 0x78 }).inStream());
    decoded = try decode_constant_pool_entry(&input, allocator);
    expect(decoded == structs.ConstantPoolTag.FieldRef);
    expect(decoded.FieldRef.class_index == 0x1234);
    expect(decoded.FieldRef.name_and_type_index == 0x5678);

    input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{ 0x0a, 0x12, 0x34, 0x56, 0x78 }).inStream());
    decoded = try decode_constant_pool_entry(&input, allocator);
    expect(decoded == structs.ConstantPoolTag.MethodRef);
    expect(decoded.MethodRef.class_index == 0x1234);
    expect(decoded.MethodRef.name_and_type_index == 0x5678);

    input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{ 0x0b, 0x12, 0x34, 0x56, 0x78 }).inStream());
    decoded = try decode_constant_pool_entry(&input, allocator);
    expect(decoded == structs.ConstantPoolTag.InterfaceMethodRef);
    expect(decoded.InterfaceMethodRef.class_index == 0x1234);
    expect(decoded.InterfaceMethodRef.name_and_type_index == 0x5678);

    input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{ 0x08, 0xde, 0xad }).inStream());
    decoded = try decode_constant_pool_entry(&input, allocator);
    expect(decoded == structs.ConstantPoolTag.String);
    expect(decoded.String.string_index == 0xdead);

    input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{ 0x03, 0x12, 0x34, 0x56, 0x78 }).inStream());
    decoded = try decode_constant_pool_entry(&input, allocator);
    expect(decoded == structs.ConstantPoolTag.Integer);
    expect(decoded.Integer.bytes == 0x12345678);

    input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{ 0x04, 0x12, 0x34, 0x56, 0x78 }).inStream());
    decoded = try decode_constant_pool_entry(&input, allocator);
    expect(decoded == structs.ConstantPoolTag.Float);
    expect(decoded.Float.bytes == 0x12345678);

    input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{ 0x05, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88 }).inStream());
    decoded = try decode_constant_pool_entry(&input, allocator);
    expect(decoded == structs.ConstantPoolTag.Long);
    expect(decoded.Long.high_bytes == 0x11223344);
    expect(decoded.Long.low_bytes == 0x55667788);

    input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{ 0x06, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88 }).inStream());
    decoded = try decode_constant_pool_entry(&input, allocator);
    expect(decoded == structs.ConstantPoolTag.Double);
    expect(decoded.Double.high_bytes == 0x11223344);
    expect(decoded.Double.low_bytes == 0x55667788);

    input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{ 0x0c, 0x12, 0x34, 0x56, 0x78 }).inStream());
    decoded = try decode_constant_pool_entry(&input, allocator);
    expect(decoded == structs.ConstantPoolTag.NameAndType);
    expect(decoded.NameAndType.name_index == 0x1234);
    expect(decoded.NameAndType.descriptor_index == 0x5678);

    input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{ 0x01, 0x00, 0x04, 'n', 'i', 'c', 'e' }).inStream());
    decoded = try decode_constant_pool_entry(&input, allocator);
    expect(decoded == structs.ConstantPoolTag.Utf8);
    expect(decoded.Utf8.length == 4);
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        expect(decoded.Utf8.bytes[i] == "nice"[i]);
    }
    decoded.destroy(allocator);

    input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{ 0x0f, 1, 0x12, 0x34 }).inStream());
    decoded = try decode_constant_pool_entry(&input, allocator);
    expect(decoded == structs.ConstantPoolTag.MethodHandle);
    expect(decoded.MethodHandle.reference_kind == 1);
    expect(decoded.MethodHandle.reference_index == 0x1234);

    input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{ 0x10, 0x12, 0x34 }).inStream());
    decoded = try decode_constant_pool_entry(&input, allocator);
    expect(decoded == structs.ConstantPoolTag.MethodType);
    expect(decoded.MethodType.descriptor_index == 0x1234);

    input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{ 0x12, 0x12, 0x34, 0x56, 0x78 }).inStream());
    decoded = try decode_constant_pool_entry(&input, allocator);
    expect(decoded == structs.ConstantPoolTag.InvokeDynamic);
    expect(decoded.InvokeDynamic.bootstrap_method_attr_index == 0x1234);
    expect(decoded.InvokeDynamic.name_and_type_index == 0x5678);
}
