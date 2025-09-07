const Allocator = @import("std").mem.Allocator;
const TileMap = @import("TileMap.zig");

pub var map: TileMap = undefined;

pub fn deinit(allocator: Allocator) void {
    map.deinit(allocator);
}
