const std = @import("std");
const Allocator = std.mem.Allocator;
const warn = std.debug.warn;

const classfile = @import("classfile.zig");
const structs = @import("classfile/structs.zig");
const pp = @import("pp.zig");

const Error = error{BadArguments};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = &arena.allocator;
    const args = try std.process.argsAlloc(allocator);
    defer arena.deinit();

    if (args.len != 2) {
        warn("Expected a single command line argument, but found {}.\n", .{args.len - 1});
        return error.BadArguments;
    }

    const c = try classfile.fromFile(args[1], allocator);

    warn("Magic: 0x{X}\n", .{c.magic});
    warn("Version: {}.{}\n", .{ c.major_version, c.minor_version });
    printConstants(c, allocator);
    warn("Access flags: 0x{X:0>4}\n", .{c.access_flags});
    warn("This class: {}\n", .{pp.ppClass(c.constant_pool[c.this_class].Class, c, allocator)});
    if (c.super_class != 0) {
        warn("Super class: {}\n", .{pp.ppClass(c.constant_pool[c.super_class].Class, c, allocator)});
    }
    printInterfaces(c, allocator);
    printFields(c, allocator);
    printMethods(c, allocator);
    printAttributes(c, allocator);
}

fn printConstants(c: structs.ClassFile, allocator: *Allocator) void {
    warn("Constant pool (size: {}):\n", .{c.constant_pool.len});
    var i: u16 = 1;
    while (i < c.constant_pool.len) : (i += 1) {
        const entry = c.constant_pool[i];
        warn("\t{:4}: {s:18}", .{i, @tagName(entry)});
        switch(entry) {
            .Class => |s| warn("{} (name_index: {})", .{pp.ppClass(s, c, allocator), s.name_index}),
            .FieldRef => |s| warn("{} (class_index: {}, name_and_type_index: {})", .{pp.ppFieldOrMethodRef(s, c, allocator), s.class_index, s.name_and_type_index}),
            .MethodRef => |s| warn("{} (class_index: {}, name_and_type_index: {})", .{pp.ppFieldOrMethodRef(s, c, allocator), s.class_index, s.name_and_type_index}),
            .InterfaceMethodRef => |s| warn("{} (class_index: {}, name_and_type_index: {})", .{pp.ppFieldOrMethodRef(s, c, allocator), s.class_index, s.name_and_type_index}),
            .String => |s| warn("{} (string_index: {})", .{pp.ppString(s, c, allocator), s.string_index}),
            .Integer => |s| warn("{} (bytes: 0x{x:0>8})", .{pp.ppNumeric(s.bytes, allocator), s.bytes}),
            .Float => |s| {
                const as_float = @bitCast(f32, s.bytes);
                warn("{} (bytes: 0x{x:0>8})", .{pp.ppNumeric(as_float, allocator), s.bytes});
            },
            .Long => |s| {
                const as_int = @as(u64, s.high_bytes) << 32 | s.low_bytes;
                warn("{} (high_bytes: 0x{x:0>8}, low_bytes: 0x{x:0>8})", .{pp.ppNumeric(as_int, allocator), s.high_bytes, s.low_bytes});
                i += 1;
            },
            .Double => |s| { 
                const as_float = @bitCast(f64, @as(u64, s.high_bytes) << 32 | s.low_bytes);
                warn("{} (high_bytes: 0x{x:0>8}, low_bytes: 0x{x:0>8})", .{pp.ppNumeric(as_float, allocator), s.high_bytes, s.low_bytes});
                i += 1;
            },
            .NameAndType => |s| warn("{} (name_index: {}, descriptor_index: {})", .{pp.ppNameAndType(s, c, allocator), s.name_index, s.descriptor_index}),
            .Utf8 => |s| warn("{} (length: {}, bytes: {})", .{pp.ppUtf8(s, c, allocator), s.length, s.bytes}),
            .MethodHandle => |s| warn("(reference_kind: {}, reference_index: {})", .{s.reference_kind, s.reference_index}),
            .MethodType => |s| warn("(descriptor_kind: {})", .{s.descriptor_index}),
            .InvokeDynamic => |s| warn("(bootstrap_method_attr_index: {}, name_and_type_index: {})", .{s.bootstrap_method_attr_index, s.name_and_type_index}),
        }
        warn("\n", .{});
    }
}

fn printInterfaces(c: structs.ClassFile, allocator: *Allocator) void {
    warn("Interfaces: ", .{});
    for (c.interfaces) |interface, i| {
        const class = c.constant_pool[interface].Class;
        const sep = if (i == c.interfaces.len - 1) "" else ", ";
        warn("{}{}", .{pp.ppClass(class, c, allocator), sep});
    }
    warn("\n", .{});
}

fn printFields(c: structs.ClassFile, allocator: *Allocator) void {
    warn("Fields: ", .{});
    for (c.fields) |field, i| {
        const sep = if (i == c.fields.len - 1) "" else ", ";
        warn("{}{}", .{pp.ppField(field, c, allocator), sep});
    }
    warn("\n", .{});
}

fn printMethods(c: structs.ClassFile, allocator: *Allocator) void {
    warn("Methods: ", .{});
    for (c.methods) |method, i| {
        const sep = if (i == c.methods.len - 1) "" else ", ";
        warn("{}{}", .{pp.ppMethod(method, c, allocator), sep});
    }
    warn("\n", .{});
}

fn printAttributes(c: structs.ClassFile, allocator: *Allocator) void {
    warn("Attributes: ", .{});
    for (c.attributes) |attribute, i| {
        const sep = if (i == c.attributes.len - 1) "" else ", ";
        warn("{}{}", .{pp.ppAttribute(attribute, c, allocator), sep});
    }
    warn("\n", .{});
}
