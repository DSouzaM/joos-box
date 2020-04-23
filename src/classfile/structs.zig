const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

pub const ClassFile = struct {
    magic: u32,
    minor_version: u16,
    major_version: u16,
    constant_pool: []ConstantPoolInfo,
    access_flags: u16,
    this_class: u16,
    super_class: u16,
    interfaces: []u16,
    fields: []Field,
    methods: []Method,
    attributes: []Attribute,

    fn destroy(self: ClassFile, allocator: *Allocator) void {
        destroyList(ConstantPoolInfo, self.constant_pool, allocator);
        allocator.free(self.interfaces);
        destroyList(Field, self.fields, allocator);
        destroyList(Method, self.methods, allocator);
        destroyList(Attribute, self.attributes, allocator);
    }
};

fn destroyList(comptime T: type, list: []T, allocator: *Allocator) void {
    for (list) |entry| {
        entry.destroy(allocator);
    }
    allocator.free(list);
}

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
        // TODO: these should always be decoded/interpreted as MUTF-8
        bytes: []const u8,
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

pub const ClassAccessFlags = enum(u16) {
    Public = 0x0001,
    Final = 0x0010,
    Super = 0x0020,
    Interface = 0x0200,
    Abstract = 0x0400,
    Synthetic = 0x1000,
    Annotation = 0x2000,
    Enum = 0x4000,
};

pub const Field = struct {
    access_flags: u16,
    name_index: u16,
    descriptor_index: u16,
    attributes: []Attribute,

    fn destroy(self: Field, allocator: *Allocator) void {
        destroyList(Attribute, self.attributes, allocator);
    }
};

pub const FieldAccessFlags = enum(u16) {
    Public = 0x0001,
    Private = 0x0002,
    Protected = 0x0004,
    Static =  0x0008,
    Final = 0x0010,
    Volatile = 0x0040,
    Transient = 0x0080,
    Synthetic = 0x0100,
    Enum = 0x4000,
};

pub const Method = struct {
    access_flags: u16,
    name_index: u16,
    descriptor_index: u16,
    attributes: []Attribute,

    fn destroy(self: Method, allocator: *Allocator) void {
        destroyList(Attribute, self.attributes, allocator);
    }
};

pub const MethodAccessFlags = enum(u16) {
    Public = 0x0001,
    Private = 0x0002,
    Protected = 0x0004,
    Static =  0x0008,
    Final = 0x0010,
    Synchronized = 0x0020,
    Bridge = 0x0040,
    Varargs = 0x0080,
    Native = 0x0100,
    Abstract = 0x0400,
    Strict = 0x0800,
    Synthetic = 0x1000,
};

pub const AttributeType = enum {
    ConstantValue,
    Code,
    SourceFile,
    Unsupported,

    pub fn from_string(str: []const u8) AttributeType {
        return std.meta.stringToEnum(AttributeType, str) orelse .Unsupported;
    }
};

pub const Attribute = union(AttributeType) {
    ConstantValue: struct {
        constantvalue_index: u16,
    },
    Code: struct {
        max_stack: u16,
        max_locals: u16,
        code: []const u8,
        exception_table: []ExceptionTableEntry,
        attributes: []Attribute
    },
    SourceFile: struct {
        sourcefile_index: u16,
    },
    Unsupported : struct {
        attribute_name_index: u16,
        info: []u8,
    },

    fn destroy(self: Attribute, allocator: *Allocator) void {
        switch (self) {
            .Code => |s| {
                allocator.free(s.code);
                allocator.free(s.exception_table);
                destroyList(Attribute, s.attributes, allocator);
            },
            .Unsupported => |s| allocator.free(s.info),
            else => {}
        }
    }
};

pub const ExceptionTableEntry = struct {
    start_pc: u16,
    end_pc: u16,
    handler_pc: u16,
    catch_type: u16,
};

test "attribute type from_string" {
    std.testing.expect(AttributeType.from_string("ConstantValue"[0..]) == .ConstantValue);
    std.testing.expect(AttributeType.from_string("Code"[0..]) == .Code);
    std.testing.expect(AttributeType.from_string("SomethingElse"[0..]) == .Unsupported);
}
