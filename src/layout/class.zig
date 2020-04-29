const std = @import("std");
const pp = @import("../pp.zig");
const structs = @import("../classfile/structs.zig");
const Allocator = std.mem.Allocator;

pub const Class = struct {
    decoded: structs.ClassFile,
    allocator: *Allocator,

    const Self = @This();

    pub fn name(self: Self) []const u8 {
        const class = self.decoded.constant_pool[self.decoded.this_class].Class;
        const utf8 = self.decoded.constant_pool[class.name_index].Utf8;
        return utf8.bytes;
    }

    pub fn deinit(self: *Self) void {
        self.decoded.destroy(self.allocator);
    }
};