const std = @import("std");
const rl = @import("raylib");
const settings = @import("settings.zig"); 
const Character = @import("Character.zig");
const char_spawner = @import("character_spawner.zig");
const components = @import("components.zig");
const game_state = @import("game_state.zig");
const Vector2 = rl.Vector2;

char: Character,
cam: rl.Camera2D,

const Self = @This();

pub fn init(char: Character) !Self {
    var c = Self{
        .char = char,
        .cam = rl.Camera2D{
            .target = undefined,
            .offset = rl.Vector2{
                .x = @as(f32, @floatFromInt(@divFloor(settings.window_width, 2))) - settings.tile_size / 2,
                .y = @as(f32, @floatFromInt(@divFloor(settings.window_height, 2))) - settings.tile_size / 2,
            },
            .rotation = 0,
            .zoom = 1,
        },
    };
    
    try c.char.movement.events.pos_changed.add(.{
        .func = @import("TileMap.zig").updateTileRenderCacheCallback,
        .ctx = &game_state.map,
    });

    return c;
}

pub fn updateCallback(self_: *anyopaque, delta: f32) !void {
    const self: Self = @alignCast(@ptrCast(self_));
    self.update(delta);
}

pub fn update(self: *Self, delta: f32) !void {
    if (rl.isKeyReleased(.t)) try self.transform();
    try self.char.update(delta);
    updateCamPos(&self.cam, self.char.getCenter());
}

pub fn draw(self: *Self) void {
    self.char.draw();
}

/// Transforms between Cerber and Cerby
fn transform(self: *Self) !void {
    var trans =
        if (std.mem.eql(u8, self.char.name, "cerby")) try char_spawner.Cerber.spawn(self.char.movement.pos)
        else try char_spawner.Cerby.spawn(self.char.movement.pos); 

    // TODO Fix offsetting the player for correct transformation position
    trans.movement.pos = trans.movement.pos.add(.{
        .x = (self.char.collider.hitbox.width - trans.collider.hitbox.width) / 2,
        .y = (self.char.collider.hitbox.height - trans.collider.hitbox.height) / 2,
    });

    if (trans.collider.checkCollisionAtPos(trans.movement.pos)) return;

    self.char = trans;
}

fn updateCamPos(cam: *rl.Camera2D, pos: Vector2) void {
    cam.target = pos.scale(settings.resolution_ratio);
}
