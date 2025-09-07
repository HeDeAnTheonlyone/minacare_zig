const std = @import("std");
const rl = @import("raylib");
const settings = @import("settings.zig");
const debug = @import("debug.zig");
const event = @import("event.zig");
const drawer = @import("drawer.zig");
const components = @import("components.zig");
const TileMap = @import("TileMap.zig");
const Coordinates = TileMap.Coordinates;
const AnimationPlayer = components.AnimationPlayer;
const Movement = components.Movement;
const Collider = components.Collider;
const input = components.input;
const Rectangle = rl.Rectangle;
const Vector2 = rl.Vector2;

animation: AnimationPlayer,
movement: Movement,
collider: Collider,
vtable: *const VTable,

const Self = @This();

pub const VTable = struct {
    updateVisuals: *const fn(self: *Self) anyerror!void,
};

pub fn update(self_: *anyopaque, delta: f32) !void {
    const self: *Self = @alignCast(@ptrCast(self_));

    try self.moveAndCollide(delta);
    try self.updateVisuals();
    AnimationPlayer.update(&self.animation, delta);
}

fn updateVisuals(self: *Self) !void {
    try self.vtable.updateVisuals(self);
}

pub fn draw(self: *Self) void {
    self.animation.draw(self.movement.pos);
    
    if (@import("builtin").mode == .Debug) {
        self.debugDraw();
    }
}

pub fn debugDraw(self: *Self) void {
    if (debug.show_character_hitbox) {
        drawer.drawRectOutline(
            Rectangle.init(
                self.collider.hitbox.x + self.movement.pos.x,
                self.collider.hitbox.y + self.movement.pos.y,
                self.collider.hitbox.width,
                self.collider.hitbox.width,
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

/// Returns the position of the center point
fn getCenter(self: *Self) Vector2 {
    return self.collider
        .getCenter()
        .add(self.movement.pos);
}

fn moveAndCollide(self: *Self, delta: f32) !void {
    const input_vec = input.getInputVector();
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
