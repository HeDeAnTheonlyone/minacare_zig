const rl = @import("raylib");
const Allocator = @import("std").mem.Allocator;
const TileMap = @import("TileMap.zig");

pub var map: TileMap = undefined;
pub var character_spritesheet: rl.Texture2D = undefined; 

pub fn deinit(allocator: Allocator) void {
    map.deinit(allocator);
    character_spritesheet.unload();
}
