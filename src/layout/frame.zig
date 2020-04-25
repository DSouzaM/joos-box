const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const expect = testing.expect;
const ConstantPool = @import("constant_pool.zig").ConstantPool;

// Frames are stored as contiguous blocks of memory.

// The JVM spec requires longs and doubles to occupy two local/operand slots,
// and all other types (including returnAddresses and references) to occupy one.
// This model maps well to 32-bit architectures: every local/operand occupies 32 bits.
// Unfortunately, on 64-bit, every local/operand requires at most 64 bits, but we still need
// to split longs and doubles across two indices.

pub const Frame = [*]usize;

const Header = packed struct {
    // public fields
    size: usize,
    return_address: [*]const u8,
    constant_pool: *ConstantPool,
    // hidden fields
    max_locals: usize,
    stack_index: usize,
};

const header_size = @sizeOf(Header) / @sizeOf(usize);

pub inline fn frameSize(max_locals: u16, max_operands: u16) u32 {
    return header_size + max_locals + max_operands;
}

pub fn initFrame(frame: Frame, return_address: [*] const u8, constant_pool: *ConstantPool, max_locals: u16, max_operands: u16) void {
    const header = asHeader(frame);
    header.size = header_size + max_locals + max_operands;
    header.return_address = return_address;
    header.constant_pool = constant_pool;
    header.max_locals = max_locals;
    header.stack_index = header.size;
}

inline fn asHeader(frame: Frame) *Header {
    return @ptrCast(*Header, frame);
}

inline fn asLocalArray(frame: Frame) [*]usize {
    return frame + header_size;
}

inline fn stackPointer(frame: Frame) [*]usize {
    return frame + asHeader(frame).stack_index;
}

pub inline fn size(frame: Frame) usize {
    return asHeader(frame).*.size;
}

pub inline fn returnAddress(frame: Frame) [*]const u8 {
    return asHeader(frame).*.return_address;
}

pub inline fn constantPool(frame: Frame) *ConstantPool {
    return asHeader(frame).*.constant_pool;
}

pub inline fn readLocal(frame: Frame, local: u16) usize {
    return asLocalArray(frame)[local];
}

pub inline fn writeLocal(frame: Frame, local: u16, value: var) void {
    asLocalArray(frame)[local] = @intCast(usize, value);
}

pub inline fn pop(frame: Frame) usize {
    const result = stackPointer(frame)[0];
    asHeader(frame).stack_index += 1;
    return result;
}

pub inline fn push(frame: Frame, value: var) void {
    asHeader(frame).stack_index -= 1;
    stackPointer(frame)[0] = @intCast(usize, value);
}

comptime {
    assert(header_size == 5);
    assert(frameSize(0, 1) == header_size + 1);
    assert(frameSize(1, 0) == header_size + 1);
    assert(frameSize(3, 3) == header_size + 6);
}

test "frame creation and access" {
    const allocator = std.testing.allocator; 
    // Allocate frame
    const frame_size = frameSize(2, 2);
    const buf = try allocator.alloc(usize, frame_size);
    var frame: Frame = buf.ptr;
    
    // Initialize frame
    var code = [_]u8{0, 1, 2, 3, 4, 5};
    const return_address: []u8 = code[2..];
    var constant_pool = ConstantPool { .dummy = 0 };
    initFrame(frame, return_address.ptr, &constant_pool, 2, 2);

    // Set locals, push/pop
    writeLocal(frame, 0, 1234);
    writeLocal(frame, 1, @ptrToInt(return_address.ptr));
    push(frame, 99);
    push(frame, 41);
    _ = pop(frame);
    push(frame, 42);
    writeLocal(frame, 0, 5678);

    // Access members of frame
    expect(size(frame) == header_size + 2 + 2);
    expect(returnAddress(frame) == return_address.ptr);
    expect(constantPool(frame) == &constant_pool);
    expect(readLocal(frame, 0) == 5678);
    expect(@intToPtr([*]u8, readLocal(frame, 1)) == return_address.ptr);
    expect(pop(frame) == 42);
    expect(pop(frame) == 99);

    allocator.free(buf);
}
