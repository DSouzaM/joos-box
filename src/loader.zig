const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const Dir = fs.Dir;
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const Allocator = mem.Allocator;
const StringHashMap = std.hash_map.StringHashMap;
const Class = @import("layout/class.zig").Class;
const classfile = @import("classfile.zig");
const structs = @import("classfile/structs.zig");

const ClassMap = StringHashMap(Class);

pub const ClassLoadError = error {
    ClassDefNotFound,
    UnsupportedClassVersion,
    NoClassDefFound,
} || mem.Allocator.Error;

// TODO: change once Joos compiler can emit classfiles
const JoosMajorVersion = 55;
const JoosMinorVersion = 0;

pub fn ClassLoader(
    comptime forName: fn (cwd: Dir, name: []const u8, allocator: *Allocator) anyerror!Class,
) type {
    return struct {
        loaded: ClassMap,
        cwd: Dir,
        allocator: *Allocator,

        const Self = @This();

        pub fn init(cwd: Dir, allocator: *Allocator) Self {
            return Self {
                .loaded = ClassMap.init(allocator),
                .cwd = cwd,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: Self) void {
            var it = self.loaded.iterator();
            while (it.next()) |kv| {
                kv.value.deinit();
            }
            self.loaded.deinit();
        }

        pub fn get(self: *Self, name: []const u8) !Class {
            if (self.loaded.getValue(name)) |value| {
                return value;
            } else {
                var class = try forName(self.cwd, name, self.allocator);
                errdefer class.deinit();
                if (class.decoded.major_version != JoosMajorVersion or class.decoded.minor_version != JoosMinorVersion) {
                    return error.UnsupportedClassVersion;
                } else if (!mem.eql(u8, name, class.name())) {
                    return error.NoClassDefFound;
                }

                _ = try self.loaded.put(name, class);
                return class;
            }
        }
    };
}

pub const FileClassLoader = ClassLoader(fromFile);

fn pathForName(name: []const u8, allocator: *Allocator) ![]const u8 {
    var with_suffix = try mem.concat(allocator, u8, &[_][]const u8{name, ".class"});
    for (with_suffix) |char, i| {
        if (with_suffix[i] == '/') {
            with_suffix[i] = fs.path.sep;
        }
    }
    return with_suffix;
}

fn fromFile(cwd: Dir, name: []const u8, allocator: *Allocator) !Class {
    const path = try pathForName(name, allocator);
    defer allocator.free(path);

    const class_struct = try classfile.fromFile(cwd, path, allocator);
    return Class {
        .decoded = class_struct,
        .allocator = allocator,
    };
}

test "pathForName" {
    const allocator = std.testing.allocator;
    var result = try pathForName("foo/bar/Baz", allocator);
    expect(mem.eql(u8, result, "foo/bar/Baz.class"));
    allocator.free(result);
}

test "fromFile" {
    const allocator = std.testing.allocator;
    var result = try fromFile(fs.cwd(), "test/res/Foo", allocator);

    result.decoded.destroy(allocator);
}

test "FileClassLoader" {
    const allocator = std.testing.allocator;
    var cwd = try fs.cwd().openDir("test/res", .{});
    defer cwd.close();

    var class_loader = FileClassLoader.init(cwd, allocator);
    const foo = try class_loader.get("Foo");
    const foo_again = try class_loader.get("Foo");
    expect(class_loader.loaded.count() == 1);

    class_loader.deinit();
}

test "mock loader" {
    const allocator = std.testing.allocator;
    const MyClassLoader = ClassLoader(testForName);
    var loader = MyClassLoader.init(fs.cwd(), allocator);

    const java_lang_object = try loader.get("java/lang/Object");
    expect(java_lang_object.decoded.minor_version == 0);

    const java_lang_object_again = try loader.get("java/lang/Object");
    expect(java_lang_object_again.decoded.minor_version == 0);

    expectError(error.ClassDefNotFound, loader.get("java/lang/Undefined"));

    // just deinit the map; don't deinit the whole class because this method will clean up the decoded class struct
    loader.loaded.deinit();
}

var testForName_counter: u8 = 0;
var test_constant_pool = [_]structs.ConstantPoolInfo {
    undefined,
    structs.ConstantPoolInfo{ .Class = .{ .name_index = 2 }},
    structs.ConstantPoolInfo{ .Utf8 = .{ .length = 16, .bytes = "java/lang/Object"[0..] }},
};
fn testForName(cwd: Dir, name: []const u8, allocator: *Allocator) ClassLoadError!Class {
    if (mem.eql(u8, name, "java/lang/Object")) {
        defer testForName_counter += 1;
        return Class {
            .decoded = structs.ClassFile {
                .magic = 0xCAFEBABE,
                .minor_version = testForName_counter,
                .major_version = JoosMajorVersion,
                // note: cannot invoke Class.deinit as usual since this memory is not owned.
                .constant_pool = &test_constant_pool,
                .access_flags = @enumToInt(structs.ClassAccessFlags.Public),
                .this_class = 1,
                .super_class = 0,
                .interfaces = &[0]u16{},
                .fields = undefined,
                .methods = undefined,
                .attributes = undefined
            },
            .allocator = allocator
        };
    } else {
        return error.ClassDefNotFound;
    }
}