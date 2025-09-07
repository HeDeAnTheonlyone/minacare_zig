const std = @import("std");
const rl = @import("raylib");
const settings = @import("Settings.zig");
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

const Self = @This();

/// Deinitialize with `deinit()`
fn init(animation: AnimationPlayer, movement: Movement, collider: Collider) !Self {
    return .{
        .animation = animation,
        .movement = movement,
        .collider = collider,
    };
}

pub fn deinit(self: *Self) void {
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
    self.animation.draw(self.movement.pos);
    
    if (@import("builtin").mode == .Debug) {
        self.collider.debugDraw(self.movement.pos);
        self.movement.debugDraw();
        self.debugDraw();
    }
}

pub fn debugDraw(self: *Self) void {
    drawer.drawCircle(
        self.getCenter(),
        5,
        .pink
    );
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

const Template = enum {
    Cerby,
    BlueMinawan,
};

/// Init a new character with the given template. Deinitialize with `deinit()`.
pub fn initTemplate(template: Template, spawn_pos: Vector2) !Self {
    return switch (template) {
        .Cerby => blk: {           
            const tex = try rl.loadTexture("assets/textures/characters_spritesheet.png");
            const animation = AnimationPlayer.init(
                tex,
                1,
                1,
                7
            );

            const movement = Movement.init(
                spawn_pos,
                100,
            );
            
            const collider = Collider{
                .hitbox = Rectangle.init(
                    0,
                    3,
                    16,
                    13,
                ),
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
                1,
                1,
                7
            );

            const movement = Movement.init(
                spawn_pos,
                40,
            );
            
            const collider = Collider{
                .hitbox = Rectangle.init(
                    0,
                    3,
                    16,
                    13,
                ),
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
