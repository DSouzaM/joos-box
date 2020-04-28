const std = @import("std");
const mem = std.mem;
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const Allocator = mem.Allocator;
const StringHashMap = std.hash_map.StringHashMap;
const Class = @import("layout/class.zig").Class;

const ClassMap = StringHashMap(Class);

pub const ClassLoadError = error {
    ClassDefNotFound
};

pub fn ClassLoader(
    comptime forName: fn (name: []const u8) ClassLoadError!Class,
) type {
    return struct {
        loaded: ClassMap,
        allocator: *Allocator,

        const Self = @This();

        pub fn init(allocator: *Allocator) Self {
            return Self {
                .loaded = ClassMap.init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: Self) void {
            self.loaded.deinit();
        }

        pub fn get(self: *Self, name: []const u8) !Class {
            if (self.loaded.getValue(name)) |value| {
                return value;
            } else {
                const class = try forName(name);
                _ = try self.loaded.put(name, class);
                return class;
            }
        }
    };
}


test "mock loader" {
    const allocator = std.testing.allocator;
    const MyClassLoader = ClassLoader(testForName);
    var loader = MyClassLoader.init(allocator);

    const java_lang_object = try loader.get("java/lang/Object");
    expect(java_lang_object.dummy == 0);

    const java_lang_object_again = try loader.get("java/lang/Object");
    expect(java_lang_object_again.dummy == 0);

    expectError(error.ClassDefNotFound, loader.get("java/lang/Undefined"));
    loader.deinit();
}

var testForNameCounter: u8 = 0;
fn testForName(name: []const u8) ClassLoadError!Class {
    if (mem.eql(u8, name, "java/lang/Object")) {
        defer testForNameCounter += 1;
        return Class { .dummy = testForNameCounter };
    } else {
        return error.ClassDefNotFound;
    }
}