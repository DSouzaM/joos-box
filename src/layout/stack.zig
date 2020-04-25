const std = @import("std");
const frame = @import("frame.zig");
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const Frame = frame.Frame;

// Structure representing the runtime stack. The stack is a resizable chunk of contiguous memory
// which contains frames. Unlike heap objects, stack frames can be relocated during resizing
// since addresses to frames are not taken.
pub const Stack = struct {
    data: []usize,
    sp: usize,
    allocator: *Allocator,

    const Self = @This();

    pub fn init(initial_size: usize, allocator: *Allocator) !Self {
        assert(std.math.isPowerOfTwo(initial_size));
        const data = try allocator.alloc(usize, initial_size);

        return Self {
            .data = data,
            .sp = initial_size,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.data);
    }

    pub fn frame(self: *Self) Frame {
        return @ptrCast(Frame, self.data[self.sp..].ptr);
    }

    pub fn pushFrame(self: *Self, max_locals: u16, max_operands: u16) !Frame {
        const to_alloc = frame.frameSize(max_locals, max_operands);
        // Check if we need to resize the stack (sp is the number of free words in the stack).
        if (self.sp < to_alloc) {
            try resize(self, self.data.len + to_alloc - self.sp);
        }

        self.sp -= to_alloc;
        return Stack.frame(self);
    }

    pub fn popFrame(self: *Self) !Frame {
        assert(self.sp < self.data.len);
        const to_free = frame.size(Stack.frame(self));
        self.sp += to_free;
        return Stack.frame(self);
    }

    fn resize(self: *Self, desired_size: usize) !void {
        const new_size = try std.math.ceilPowerOfTwo(usize, desired_size);
        if (new_size < self.data.len) {
            return; // TODO: shrink stack
        }
        
        const new_data = try self.allocator.alloc(usize, new_size);
        // Copy existing stack data to the end of the new buffer.
        const offset = new_size - self.data.len;
        mem.copy(usize, new_data[offset..], self.data);
        self.allocator.free(self.data);
        self.data = new_data;
        self.sp += offset;
    }
};


test "allocation and reallocation" {
    const allocator = std.testing.allocator;
    var stack = try Stack.init(2, allocator);

    stack.data[0] = 42;
    stack.data[1] = 43;
    stack.sp = 0;

    try Stack.resize(&stack, 7);
    expect(stack.data[6] == 42);
    expect(stack.data[7] == 43);
    expect(stack.sp == 6);

    stack.data[4] = 40;
    stack.data[5] = 41;
    stack.sp = 4;

    try Stack.resize(&stack, 16);
    expect(stack.data[12] == 40);
    expect(stack.data[13] == 41);
    expect(stack.data[14] == 42);
    expect(stack.data[15] == 43);
    expect(stack.sp == 12);

    stack.deinit();
}

test "frame pushing and popping" {
    const allocator = std.testing.allocator;
    // Start with enough to hold at most 1 frame.
    const init_size = try std.math.ceilPowerOfTwo(usize, frame.frameSize(2,2));
    var stack = try Stack.init(init_size, allocator);

    // | frame1 ->
    var currentFrame = try Stack.pushFrame(&stack, 2, 2);
    frame.initFrame(currentFrame, undefined, undefined, 2, 2);
    frame.writeLocal(currentFrame, 0, 42);
    frame.writeLocal(currentFrame, 1, 23);
    frame.push(currentFrame, 12);
    frame.push(currentFrame, 69);

    // | frame1, frame2 ->
    currentFrame = try Stack.pushFrame(&stack, 2, 2);
    frame.initFrame(currentFrame, undefined, undefined, 2, 2);
    frame.writeLocal(currentFrame, 0, 11);
    frame.writeLocal(currentFrame, 1, 22);
    frame.push(currentFrame, 33);
    frame.push(currentFrame, 44);

    expect(stack.data.len == 2 * init_size);
    expect(frame.readLocal(currentFrame, 0) == 11);
    expect(frame.readLocal(currentFrame, 1) == 22);

    // | frame1, frame3 ->
    _ = try Stack.popFrame(&stack);
    currentFrame = try Stack.pushFrame(&stack, 2, 8);
    frame.initFrame(currentFrame, undefined, undefined, 2, 8);
    frame.writeLocal(currentFrame, 0, 99);
    frame.writeLocal(currentFrame, 1, 99);
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        frame.push(currentFrame, i+99);
    }

    expect(frame.readLocal(currentFrame, 0) == 99);
    expect(frame.readLocal(currentFrame, 1) == 99);
    i = 8;
    while (i > 0) : (i -= 1) {
        expect(frame.pop(currentFrame) == i-1+99);
    }

    // | frame1 ->
    currentFrame = try Stack.popFrame(&stack);
    expect(frame.readLocal(currentFrame, 0) == 42);
    expect(frame.readLocal(currentFrame, 1) == 23);
    expect(frame.pop(currentFrame) == 69);
    expect(frame.pop(currentFrame) == 12);

    _ = try Stack.popFrame(&stack);

    stack.deinit();
}

fn printStack(stack: *Stack) void {
    std.debug.warn("Stack contents:\n", .{});
    for (stack.data) |word, i| {
        const sp = if (i == stack.sp) "*" else " ";
        std.debug.warn("{} {:4}: {}\n", .{sp, i, word});
    }
}