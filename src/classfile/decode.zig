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
    const interfaces = try decode_interfaces(input, allocator);
    const fields = try decode_fields(input, constant_pool, allocator);
    const methods = try decode_methods(input, constant_pool, allocator);
    const attributes = try decode_attributes(input, constant_pool, allocator);

    return structs.ClassFile{
        .magic = magic,
        .minor_version = minor_version,
        .major_version = major_version,
        .constant_pool = constant_pool,
        .access_flags = access_flags,
        .this_class = this_class,
        .super_class = super_class,
        .interfaces = interfaces,
        .fields = fields,
        .methods = methods,
        .attributes = attributes,
    };
}

const Pool = []structs.ConstantPoolInfo;

fn decode_constant_pool(input: var, allocator: *Allocator) !Pool {
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
    const tag = @intToEnum(structs.ConstantPoolTag, try read_int(u8, input));
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

fn decode_interfaces(input: var, allocator: *Allocator) ![]u16 {
    const interfaces_count = try read_int(u16, input);
    const interfaces = try allocator.alloc(u16, interfaces_count);
    for (interfaces) |*interface| {
        interface.* = try read_int(u16, input);
    }
    return interfaces;
}

fn decode_fields(input: var, pool: Pool, allocator: *Allocator) ![]structs.Field {
    return decode_list(structs.Field, input, pool, allocator, decode_field);
}

fn decode_field(input: var, pool: Pool, allocator: *Allocator) !structs.Field {
    const access_flags = try read_int(u16, input);
    const name_index = try read_int(u16, input);
    const descriptor_index = try read_int(u16, input);
    const attributes = try decode_attributes(input, pool, allocator);
    return structs.Field {
        .access_flags = access_flags,
        .name_index = name_index,
        .descriptor_index = descriptor_index,
        .attributes = attributes,
    };
}

fn decode_methods(input: var, pool: Pool, allocator: *Allocator) ![]structs.Method {
    return decode_list(structs.Method, input, pool, allocator, decode_method);
}

fn decode_method(input: var, pool: Pool, allocator: *Allocator) !structs.Method {
    const access_flags = try read_int(u16, input);
    const name_index = try read_int(u16, input);
    const descriptor_index = try read_int(u16, input);
    const attributes = try decode_attributes(input, pool, allocator);
    return structs.Method {
        .access_flags = access_flags,
        .name_index = name_index,
        .descriptor_index = descriptor_index,
        .attributes = attributes,
    };
}

fn decode_attributes(input: var, pool: Pool, allocator: *Allocator) anyerror![]structs.Attribute {
    return decode_list(structs.Attribute, input, pool, allocator, decode_attribute);
}

fn decode_attribute(input: var, pool: Pool, allocator: *Allocator) !structs.Attribute {
    const attribute_name_index = try read_int(u16, input);
    const attribute_length = try read_int(u32, input);

    const string = pool[attribute_name_index].Utf8.bytes;
    return switch (structs.AttributeType.from_string(string)) {
        .ConstantValue => structs.Attribute { .ConstantValue = .{
            .constantvalue_index = try read_int(u16, input)
        }},
        .Code => blk: {
            const max_stack = try read_int(u16, input);
            const max_locals = try read_int(u16, input);

            const code_length = try read_int(u32, input);
            const code = try allocator.alloc(u8, code_length);
            if ((try input.*.read(code)) != code_length) unreachable;
            const exception_table = try decode_list(structs.ExceptionTableEntry, input, pool, allocator, decode_exception_table_entry);
            const attributes = try decode_attributes(input, pool, allocator);

            break :blk structs.Attribute { .Code = .{
                .max_stack = max_stack,
                .max_locals = max_locals,
                .code = code,
                .exception_table = exception_table,
                .attributes = attributes,
            }};
        },
        .SourceFile => structs.Attribute { .SourceFile = .{
            .sourcefile_index = try read_int(u16, input)
        }},
        else => blk: {
            const info = try allocator.alloc(u8, attribute_length);
            if ((try input.*.read(info)) != attribute_length) unreachable;
            break :blk structs.Attribute { .Unsupported = .{
                .attribute_name_index = attribute_name_index,
                .info = info,
            }};
        }
    };
}

fn decode_exception_table_entry(input: var, pool: Pool, allocator: *Allocator) !structs.ExceptionTableEntry {
    return structs.ExceptionTableEntry {
        .start_pc = try read_int(u16, input),
        .end_pc = try read_int(u16, input),
        .handler_pc = try read_int(u16, input),
        .catch_type = try read_int(u16, input),
    };
}

// Generic function to decode a list of type T. First 2 bytes of input contain the list size.
fn decode_list(comptime T: type, input: var, pool: Pool, allocator: *Allocator,  decoder: fn (var, Pool, *Allocator) anyerror!T) ![]T {
    const count = try read_int(u16, input);
    const list = try allocator.alloc(T, count);
    for (list) |*entry| {
        entry.* = try decoder(input, pool, allocator);
    }
    return list;
}

test "read_int" {
    const buf = [_]u8{ 0xCA, 0xFE, 0xBA, 0xBE, 0x01, 0x02, 0x03, 0x04, 0x05 };
    var input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&buf).inStream());

    expect((try read_int(u32, &input)) == 0xCAFEBABE);
    expect((try read_int(u16, &input)) == 0x0102);
    expect((try read_int(u8, &input)) == 0x03);
    expect((try read_int(u16, &input)) == 0x0405);
}

//zig fmt: off
test "decode_constant_pool" {
    const allocator = std.testing.allocator;

    var input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{
        0x00, 0x08,                                           // constant_pool_size = 8
        0x07, 0x00, 0x02,                                     // 1: class
        0x05, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, // 2 (and 3): long
        0x08, 0x00, 0x05,                                     // 4: string
        0x06, 0x55, 0x66, 0x77, 0x88, 0x11, 0x22, 0x33, 0x44, // 5 (and 6): double
        0x03, 0x12, 0x34, 0x56, 0x78,                         // 7: int
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

// zig fmt: off
test "decode_interfaces" {
    const allocator = std.testing.allocator;

    var input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{
        0x00, 0x02, // interfaces_size = 8
        0x12, 0x34,
        0x56, 0x78
    }).inStream());
    var decoded = try decode_interfaces(&input, allocator);
    expect(decoded.len == 2);
    expect(decoded[0] == 0x1234);
    expect(decoded[1] == 0x5678);

    allocator.free(decoded);
}

// zig fmt: off
test "decode_fields" {
    const allocator = std.testing.allocator;

    var input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{
        0x00, 0x02, // fields_size = 2
        // field 1
        0x00, 0x02, // access_flags
        0x00, 0x07, // name_index
        0x00, 0x08, // descriptor_index
        0x00, 0x01, // attributes_count = 1
        // attribute 1
        0x00, 0x01,             // attribute_name_index
        0x00, 0x00, 0x00, 0x02, // attribute_length
        0x01, 0x02,
        // field 2
        0x00, 0x01, // access flags
        0x00, 0x09, // name_index
        0x00, 0x0a, // descriptor_index
        0x00, 0x00, // attributes_count = 0
    }).inStream());
    var pool = [2]structs.ConstantPoolInfo {
        undefined,
        structs.ConstantPoolInfo { .Utf8 = .{
            .length = 13,
            .bytes = "AttributeName"[0..],
        }}
    };
    var decoded = try decode_fields(&input, &pool, allocator);
    expect(decoded.len == 2);
    expect(decoded[0].access_flags == @enumToInt(structs.FieldAccessFlags.Private));
    expect(decoded[0].name_index == 0x07);
    expect(decoded[0].descriptor_index == 0x08);
    expect(decoded[0].attributes.len == 1);
    expect(decoded[0].attributes[0] == structs.AttributeType.Unsupported);
    expect(decoded[1].access_flags == @enumToInt(structs.FieldAccessFlags.Public));
    expect(decoded[1].name_index == 0x09);
    expect(decoded[1].descriptor_index == 0x0a);
    expect(decoded[1].attributes.len == 0);

    decoded[0].destroy(allocator);
    decoded[1].destroy(allocator);
    allocator.free(decoded);
}

// zig fmt: off
test "decode_methods" {
    const allocator = std.testing.allocator;

    var input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{
        0x00, 0x02, // methods_count = 2
        // method 1
        0x00, 0x02, // access_flags
        0x00, 0x07, // name_index
        0x00, 0x08, // descriptor_index
        0x00, 0x01, // attributes_count = 1
        // attribute 1
        0x00, 0x01,             // attribute_name_index
        0x00, 0x00, 0x00, 0x02, // attribute_length
        0x01, 0x02,
        // method 2
        0x00, 0x01, // access flags
        0x00, 0x09, // name_index
        0x00, 0x0a, // descriptor_index
        0x00, 0x00, // attributes_count = 0
    }).inStream());
    var pool = [2]structs.ConstantPoolInfo {
        undefined,
        structs.ConstantPoolInfo { .Utf8 = .{
            .length = 13,
            .bytes = "AttributeName"[0..],
        }}
    };
    var decoded = try decode_methods(&input, &pool, allocator);
    expect(decoded.len == 2);
    expect(decoded[0].access_flags == @enumToInt(structs.MethodAccessFlags.Private));
    expect(decoded[0].name_index == 0x07);
    expect(decoded[0].descriptor_index == 0x08);
    expect(decoded[0].attributes.len == 1);
    expect(decoded[0].attributes[0] == structs.AttributeType.Unsupported);
    expect(decoded[1].access_flags == @enumToInt(structs.MethodAccessFlags.Public));
    expect(decoded[1].name_index == 0x09);
    expect(decoded[1].descriptor_index == 0x0a);
    expect(decoded[1].attributes.len == 0);

    decoded[0].destroy(allocator);
    decoded[1].destroy(allocator);
    allocator.free(decoded);
}

// zig fmt: off
test "decode_attributes" {
    const allocator = std.testing.allocator;

    var input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&[_]u8{
        0x00, 0x04,                                 // attributes_count
        // attribute 1
        0x00, 0x01,                                 // -> "AttributeName", unsupported
        0x00, 0x00, 0x00, 0x07,                         // attribute_length
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,       // info
        // attribute 2
        0x00, 0x02,                                 // -> "ConstantValue"
        0x00, 0x00, 0x00, 0x02,                         // attribute_length
        0x01, 0x02,                                     // constantvalue_index
        // attribute 3
        0x00, 0x03,                                 // -> "Code"
        0x00, 0x00, 0x00, 0x25,                         // attribute_length
        0x11, 0x11,                                     // max_stack
        0x22, 0x22,                                     // max_locals
        0x00, 0x00, 0x00, 0x03,                         // code_length
        0x10, 0x42, 0xAC,                               // code
        0x00, 0x02,                                     // exception_table_length
        0x11, 0x22, 0x33, 0x44, 0x55, 066, 0x77, 0x88,      // exception_table_entry 1
        0x12, 0x23, 0x34, 0x45, 0x56, 067, 0x78, 0x89,      // exception_table_entry 2
        0x00, 0x01,                                     // attributes_count
        0x00, 0x01,                                     // -> "AttributeName", unsupported
        0x00, 0x00, 0x00, 0x00,                         // attribute_length
        // attribute 4
        0x00, 0x04,                                 // -> "SourceFile"
        0x00, 0x00, 0x00, 0x02,                         // attribute_length
        0x03, 0x04,                                     // sourcefile_index
    }).inStream());
    var pool = [_]structs.ConstantPoolInfo {
        undefined,
        structs.ConstantPoolInfo { .Utf8 = .{
            .length = 13,
            .bytes = "AttributeName"[0..],
        }},
        structs.ConstantPoolInfo { .Utf8 = .{
            .length = 13,
            .bytes = "ConstantValue"[0..],
        }},
        structs.ConstantPoolInfo { .Utf8 = .{
            .length = 4,
            .bytes = "Code"[0..],
        }},
        structs.ConstantPoolInfo { .Utf8 = .{
            .length = 10,
            .bytes = "SourceFile"[0..],
        }},
    };
    var decoded = try decode_attributes(&input, &pool, allocator);
    expect(decoded.len == 4);
    expect(decoded[0] == .Unsupported);
    expect(decoded[0].Unsupported.attribute_name_index == 0x01);
    expect(decoded[0].Unsupported.info.len == 7);
    for (decoded[0].Unsupported.info) |byte, i| {
        expect(byte == (i+1));
    }

    expect(decoded[1] == .ConstantValue);
    expect(decoded[1].ConstantValue.constantvalue_index == 0x0102);

    expect(decoded[2] == .Code);
    expect(decoded[2].Code.max_stack == 0x1111);
    expect(decoded[2].Code.max_locals == 0x2222);
    expect(decoded[2].Code.code.len == 3);
    expect(decoded[2].Code.exception_table.len == 2);
    expect(decoded[2].Code.attributes.len == 1);

    expect(decoded[3] == .SourceFile);
    expect(decoded[3].SourceFile.sourcefile_index == 0x0304);

    for (decoded) |entry| {
        entry.destroy(allocator);
    }
    allocator.free(decoded);
}
