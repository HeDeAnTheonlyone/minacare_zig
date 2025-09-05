const std = @import("std");
const rl = @import("raylib");
const settings = @import("Settings.zig");
const event = @import("event.zig");
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

const Self = @This();

/// Deinitialize with `deinit()`
fn init(animation: AnimationPlayer, movement: Movement, collider: Collider) !Self {
    return .{
        .animation = animation,
        .movement = movement,
        // TODO think of a more dynamic and flexible way for collider hitbox
        .collider = collider,
    };
}

pub fn deinit(self: *Self) void {
    self.movement.pos_changed_event.remove(.{
        .func = Collider.moveHitbox,
        .ctx = &self.collider,
    });
    self.animation.deinit();
}

pub fn update(self_: *anyopaque, delta: f32) !void {
    const self: *Self = @alignCast(@ptrCast(self_));

    try self.moveAndCollide(delta);
    try self.updateVisuals();
    AnimationPlayer.update(&self.animation, delta);
}

fn updateVisuals(self: *Self) !void {
    const input_vec = input.getInputVector();
    if (input_vec.x < 0) self.animation.h_flip = false
    else if (input_vec .x > 0) self.animation.h_flip = true;

    if (input_vec.length() == 0) try self.animation.setAnimation(0)
    else try self.animation.setAnimation(1);
}

pub fn draw(self: *Self) void {
    if (@import("builtin").mode == .Debug) {
        debugDraw(self);
    }
    
    self.animation.draw(self.movement.pos);
}

fn debugDraw(self: *Self) void {
    if (settings.debug) {
        const hitbox = self.collider.hitbox;
        rl.drawRectangleLinesEx(
            Rectangle.init(
                hitbox.x * settings.resolution_ratio,
                hitbox.y * settings.resolution_ratio,
                hitbox.width * settings.resolution_ratio,
                hitbox.height * settings.resolution_ratio,
            ),
            5,
            rl.Color.red
        );
    }

    if (settings.debug) {
        const pos = self.movement.pos;
        rl.drawCircle(
            @intFromFloat(pos.x * settings.resolution_ratio),
            @intFromFloat(pos.y * settings.resolution_ratio),
            5,
            rl.Color.green
        );
    }
}

// /// Returns the position of the center point
// fn getCenter(self: *Self) Vector2 {
//     const center_offset = self.animation.getCenter();
//     return center_offset
//         .scale(settings.resolution_ratio)
//         .
// }

fn moveAndCollide(self: *Self, delta: f32) !void {
    const input_vec = input.getInputVector();
    if (input_vec.equals(Vector2.zero()) != 0) return;

    const next_pos = self.movement.getNextPos(input_vec, delta);
    const is_colliding = self.collider.checkCollisionAtPos(next_pos);
    if (is_colliding) return;
    try self.movement.move(next_pos);
}

const Template = enum {
    Cerby,
    BlueMinawan,
};

/// Init a new character with the given template. Deinitialize with `deinit()`.
pub fn initTemplate(template: Template, current_map: *TileMap.RuntimeMap.CollisionMap, spawn_pos: Vector2) !Self {
    return switch (template) {
        .Cerby => blk: {           
            const tex = try rl.loadTexture("assets/textures/characters_spritesheet.png");
            const animation = AnimationPlayer.init(
                tex,
                16,
                16,
                7
            );

            const movement = Movement.init(
                spawn_pos,
                100,
            );
            
            const collider = Collider{
                .hitbox = animation.getFrameRect(),
                .current_map = current_map,
            };

            var obj = try Self.init(
                animation,
                movement,
                collider,
            );

            // Standing
            try obj.animation.addAnimation(.{ .start_frame = 0, .end_frame = 0 });

            // Walking
            try obj.animation.addAnimation(.{ .start_frame = 1, .end_frame = 8 });

            break :blk obj;
        },
        .BlueMinawan => blk: {
            const tex = try rl.loadTexture("assets/textures/characters_spritesheet.png");
            const animation = AnimationPlayer.init(
                tex,
                16,
                16,
                7
            );

            const movement = Movement.init(
                spawn_pos,
                40,
            );
            
            const collider = Collider{
                .hitbox = animation.getFrameRect(),
                .current_map = current_map,
            };

            var obj = try Self.init(
                animation,
                movement,
                collider,
            );

            // Standing
            try obj.animation.addAnimation(.{ .start_frame = 81, .end_frame = 84 });

            // Walking
            try obj.animation.addAnimation(.{ .start_frame = 81, .end_frame = 84 });

            break :blk obj;
        } 
    };
}
