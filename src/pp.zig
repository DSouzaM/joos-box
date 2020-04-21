const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const io = std.io;
const Allocator = std.mem.Allocator;

const structs = @import("classfile/structs.zig");

pub fn pp_numeric(value: var, allocator: *Allocator) ![]u8 {
    return fmt.allocPrint(allocator, "{}", .{value});
}

pub fn pp_class(s: var, c: structs.ClassFile, allocator: *Allocator) ![]u8 {
    const utf8 = c.constant_pool[s.name_index].Utf8;
    return utf8.bytes;
}

pub fn pp_field_or_method_ref(s: var, c: structs.ClassFile, allocator: *Allocator) ![]u8 {
    const class = try pp_class(c.constant_pool[s.class_index].Class, c, allocator);
    const name_and_type = try pp_name_and_type(c.constant_pool[s.name_and_type_index].NameAndType, c, allocator);
    const buf = try allocator.alloc(u8, class.len + 2 + name_and_type.len);
    mem.copy(u8, buf, class);
    mem.copy(u8, buf[class.len..], "::");
    mem.copy(u8, buf[class.len+2..], name_and_type);
    return buf;
}

pub fn pp_string(s: var, c: structs.ClassFile, allocator: *Allocator) ![]u8 {
    const utf8 = c.constant_pool[s.string_index].Utf8;
    return utf8.bytes;
}

pub fn pp_name_and_type(s: var, c: structs.ClassFile, allocator: *Allocator) ![]u8 {
    const name = c.constant_pool[s.name_index].Utf8;
    const descriptor = c.constant_pool[s.descriptor_index].Utf8;
    const buf = try allocator.alloc(u8, name.length + 1 + descriptor.length);
    mem.copy(u8, buf, name.bytes);
    buf[name.length] = ':';
    mem.copy(u8, buf[name.length+1..], descriptor.bytes);
    return buf;
}

pub fn pp_utf8(s: var, c: structs.ClassFile, allocator: *Allocator) ![]u8 {
    const buf = try allocator.alloc(u8, s.length + 2);
    buf[0] = '"';
    mem.copy(u8, buf[1..], s.bytes);
    buf[s.length+1] = '"';
    return buf;
}

pub fn pp_field(s: var, c: structs.ClassFile, allocator: *Allocator) ![]u8 {
    return pp_name_and_type(s, c, allocator);
}

pub fn pp_method(s: var, c: structs.ClassFile, allocator: *Allocator) ![]u8 {
    return pp_name_and_type(s, c, allocator);
}