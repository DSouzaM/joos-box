const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ClassFile = struct {
    magic: u32,
    minor_version: u16,
    major_version: u16,
    constant_pool: []ConstantPoolInfo,
    access_flags: u16,
    this_class: u16,
    super_class: u16,

    fn destroy(self: ClassFile, allocator: *Allocator) void {
        for (self.constant_pool) |entry| {
            entry.destroy(allocator);
        }
        allocator.free(self.constant_pool);
    }
};

pub const ConstantPoolTag = enum(u8) {
    Class = 7,
    FieldRef = 9,
    MethodRef = 10,
    InterfaceMethodRef = 11,
    String = 8,
    Integer = 3,
    Float = 4,
    Long = 5,
    Double = 6,
    NameAndType = 12,
    Utf8 = 1,
    MethodHandle = 15,
    MethodType = 16,
    InvokeDynamic = 18,
};

pub const ConstantPoolInfo = union(ConstantPoolTag) {
    Class: struct {
        name_index: u16,
    },
    FieldRef: struct {
        class_index: u16,
        name_and_type_index: u16,
    },
    MethodRef: struct {
        class_index: u16,
        name_and_type_index: u16,
    },
    InterfaceMethodRef: struct {
        class_index: u16,
        name_and_type_index: u16,
    },
    String: struct {
        string_index: u16,
    },

    Integer: struct {
        bytes: u32,
    },
    Float: struct {
        bytes: u32,
    },
    Long: struct {
        high_bytes: u32,
        low_bytes: u32,
    },
    Double: struct {
        high_bytes: u32,
        low_bytes: u32,
    },
    NameAndType: struct {
        name_index: u16,
        descriptor_index: u16,
    },
    Utf8: struct {
        length: u16,
        bytes: []u8,
    },
    MethodHandle: struct {
        reference_kind: u8, reference_index: u16
    },
    MethodType: struct {
        descriptor_index: u16,
    },
    InvokeDynamic: struct {
        bootstrap_method_attr_index: u16,
        name_and_type_index: u16,
    },

    fn destroy(self: ConstantPoolInfo, allocator: *Allocator) void {
        switch (self) {
            .Utf8 => |data| {
                allocator.free(data.bytes);
            },
            else => {},
        }
    }
};

pub const AccessFlags = enum(u16) {
    Public = 0x0001, Final = 0x0010, Super = 0x0020, Interface = 0x0200, Abstract = 0x0400, Synthetic = 0x1000, Annotation = 0x2000, Enum = 0x4000
};
