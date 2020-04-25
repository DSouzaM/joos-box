const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const io = std.io;
const Allocator = std.mem.Allocator;

const structs = @import("classfile/structs.zig");

pub fn ppNumeric(value: var, allocator: *Allocator) ![]const u8 {
    return fmt.allocPrint(allocator, "{}", .{value});
}

pub fn ppClass(s: var, c: structs.ClassFile, allocator: *Allocator) ![]const u8 {
    const utf8 = c.constant_pool[s.name_index].Utf8;
    return utf8.bytes;
}

pub fn ppFieldOrMethodRef(s: var, c: structs.ClassFile, allocator: *Allocator) ![]const u8 {
    const class = try ppClass(c.constant_pool[s.class_index].Class, c, allocator);
    const name_and_type = try ppNameAndType(c.constant_pool[s.name_and_type_index].NameAndType, c, allocator);
    const buf = try allocator.alloc(u8, class.len + 2 + name_and_type.len);
    mem.copy(u8, buf, class);
    mem.copy(u8, buf[class.len..], "::");
    mem.copy(u8, buf[class.len+2..], name_and_type);
    return buf;
}

pub fn ppString(s: var, c: structs.ClassFile, allocator: *Allocator) ![]const u8 {
    const utf8 = c.constant_pool[s.string_index].Utf8;
    return utf8.bytes;
}

pub fn ppNameAndType(s: var, c: structs.ClassFile, allocator: *Allocator) ![]const u8 {
    const name = c.constant_pool[s.name_index].Utf8;
    const descriptor = c.constant_pool[s.descriptor_index].Utf8;
    const buf = try allocator.alloc(u8, name.length + 1 + descriptor.length);
    mem.copy(u8, buf, name.bytes);
    buf[name.length] = ':';
    mem.copy(u8, buf[name.length+1..], descriptor.bytes);
    return buf;
}

pub fn ppUtf8(s: var, c: structs.ClassFile, allocator: *Allocator) ![]const u8 {
    const buf = try allocator.alloc(u8, s.length + 2);
    buf[0] = '"';
    mem.copy(u8, buf[1..], s.bytes);
    buf[s.length+1] = '"';
    return buf;
}

pub fn ppField(s: var, c: structs.ClassFile, allocator: *Allocator) ![]const u8 {
    return ppNameAndType(s, c, allocator);
}

pub fn ppMethod(s: var, c: structs.ClassFile, allocator: *Allocator) ![]const u8 {
    return ppNameAndType(s, c, allocator);
}

pub fn ppAttribute(s: var, c: structs.ClassFile, allocator: *Allocator) ![]const u8 {
    return std.meta.tagName(s);
}
