const std = @import("std");

var debug_allocator = std.heap.DebugAllocator(.{}).init;
pub const allocator = switch (@import("builtin").mode) {
    .Debug => debug_allocator.allocator(),
    else => std.heap.smp_allocator,
};
