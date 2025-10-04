const std = @import("std");
const rl = @import("raylib");
const lib = @import("../lib.zig");
const app = lib.app;
const game = lib.game;
const settings = app.settings; 
const Character = game.Character;
const char_spawner = game.character_spawner;
const Vector2 = rl.Vector2;

char: Character,
// TODO maybe make Cam independent and just connect it to the player via events
cam: rl.Camera2D,
is_transformed: bool = true,

const Self = @This();

pub fn init(char: Character) !Self {    
    return .{
        .char = char,
        .cam = rl.Camera2D{
            .target = undefined,
            .offset = .{
                .x = @as(f32, @floatFromInt(@divFloor(settings.render_width, 2))) - settings.tile_size / 2,
                .y = @as(f32, @floatFromInt(@divFloor(settings.render_height, 2))) - settings.tile_size / 2,
            },
            .rotation = 0,
            .zoom = 1,
        },
    };
}

pub fn getSaveable(self: *Self) struct {*Vector2, *bool} {
    return .{
        &self.char.movement.pos,
        &self.is_transformed,
    };
}

pub fn update(self: *Self, delta: f32) !void {
    if (game.state.paused) return; 
    if (rl.isKeyReleased(.t)) try self.transform();
    try self.char.update(delta);
    updateCamPos(&self.cam, self.char.getCenter());
}

pub fn draw(self: *Self) !void {
    try self.char.draw();
}

/// Syncs the visual transformation with the internal transformation state.
pub fn syncTransformation(self: *Self) !void {
    if (
        (std.mem.eql(u8, self.char.name, "cerby") and self.is_transformed) or
        (std.mem.eql(u8, self.char.name, "cerber") and !self.is_transformed)
    ) return;

    const pos = self.char.movement.pos;
    self.is_transformed = !self.is_transformed;
    try self.transform();
    self.char   .movement.pos = pos;
}

/// Transforms between Cerber and Cerby
fn transform(self: *Self) !void {
    var trans = blk: {
        if (self.is_transformed) {
            self.is_transformed = false;
            break :blk try char_spawner.Cerber.spawn(.{ .position = self.char.movement.pos });
        }
        else {
            self.is_transformed = true;
            break :blk try char_spawner.Cerby.spawn(.{ .position = self.char.movement.pos});
        }
    };

    const char_center = self.char.collider.getCenter();
    const trans_center = trans.collider.getCenter();
    trans.movement.pos = self.char.movement.pos.add(Vector2.subtract(char_center, trans_center));

    if (trans.collider.checkCollisionAtPos(trans.movement.pos)) return;

    self.char = trans;
}

fn updateCamPos(cam: *rl.Camera2D, pos: Vector2) void {
    cam.target = pos.multiply(settings.resolution_ratio);
}

pub fn recenterCam(self: *Self) void {
    const char_offset = self.char.animation.getCenter();

    self.cam.offset = .{
        .x = @as(f32, @floatFromInt(@divFloor(settings.render_width, 2))) - char_offset.x,
        .y = @as(f32, @floatFromInt(@divFloor(settings.render_height, 2))) - char_offset.y,
    };
} 
