//! Instantiate a character only through the `character_spawner`.

const std = @import("std");
const rl = @import("raylib");
const lib = @import("../lib.zig");
const game = lib.game;
const util = lib.util;
const Rectangle = rl.Rectangle;
const Vector2 = rl.Vector2;

animation: game.components.AnimationPlayer,
movement: game.components.Movement,
collider: game.components.Collider,
name: []const u8,
vtable: *const VTable,

const Self = @This();

pub const VTable = struct {
    updateRotation: *const fn(self: *Self) anyerror!void,
    getInputVector: *const fn() Vector2,
};

pub fn update(self: *Self, delta: f32) !void {
    // TODO Maybe remove the pause check here and only put it in wrapper structs
    if (game.state.paused) return;
    try self.moveAndCollide(delta);
    try self.updateRotation();
    self.animation.update(delta);
}

fn updateRotation(self: *Self) !void {
    try self.vtable.updateRotation(self);
}

pub fn draw(self: *Self) !void {
    self.animation.draw(self.movement.pos);
    
    if (@import("builtin").mode == .Debug) {
        self.debugDraw();
    }
}

pub fn debugDraw(self: *Self) void {
    const debug = util.debug;
    const drawer = util.drawer;
    if (debug.show_character_hitbox) {
        drawer.drawRectOutline(
            Rectangle.init(
                self.collider.hitbox.x + self.movement.pos.x,
                self.collider.hitbox.y + self.movement.pos.y,
                self.collider.hitbox.width,
                self.collider.hitbox.height,
            ),
            5,
            .red
        );
    }
    if (debug.show_character_origin) {
        drawer.drawCircle(
            self.movement.pos,
            5,
            .orange,
        );
    }
    if (debug.show_character_center) {
        drawer.drawCircle(
            self.getCenter(),
            5,
            .orange
        );
    }
}

/// Returns the position of the logical center point
pub fn getCenter(self: *Self) Vector2 {
    return self.movement.pos.add(self.collider.getCenter());
}

fn moveAndCollide(self: *Self, delta: f32) !void {
    const input_vec = self.vtable.getInputVector();
    if (input_vec.equals(Vector2.zero()) != 0) return;

    const motion= self.movement.getMotion(input_vec, delta);
    const x_motion = Vector2{ .x = motion.x, .y = 0 };
    const y_motion = Vector2{ .x = 0, .y = motion.y };

    const is_x_colliding = self.collider.checkCollisionAtPos(self.movement.pos.add(x_motion));
    const is_y_colliding = self.collider.checkCollisionAtPos(self.movement.pos.add(y_motion));

    if (is_x_colliding and is_y_colliding) return;
    
    if (is_x_colliding) try self.movement.move(self.movement.pos.add(y_motion))
    else if (is_y_colliding) try self.movement.move(self.movement.pos.add(x_motion))
    else try self.movement.move(self.movement.pos.add(motion));
}
