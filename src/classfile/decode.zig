const std = @import("std");
const structs = @import("structs.zig");
const expect = std.testing.expect;

fn read_int(comptime T: type, input: var) !T {
    return input.*.readBitsNoEof(T, @bitSizeOf(T));
}

pub fn decode_class_file(input: var) !structs.ClassFile {
    const magic = try read_int(u32, &input);
    const minor_version = try read_int(u16, &input);
    const major_version = try read_int(u16, &input);

    return structs.ClassFile {
        .magic = magic,
        .minor_version = minor_version,
        .major_version = major_version,
    };
}

test "read_int" {
    var buf = [_]u8 {0xCA, 0xFE, 0xBA, 0xBE, 0x01, 0x02, 0x03, 0x04, 0x05};
    var input = std.io.bitInStream(.Big, std.io.fixedBufferStream(&buf).inStream());

    expect((try read_int(u32, &input)) == 0xCAFEBABE);
    expect((try read_int(u16, &input)) == 0x0102);
    expect((try read_int(u8, &input)) == 0x03);
    expect((try read_int(u16, &input)) == 0x0405);
}