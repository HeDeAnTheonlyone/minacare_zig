const std = @import("std");
const rl = @import("raylib");
const settings = @import("Settings.zig");
const event = @import("event.zig");
const components = @import("components.zig");
const AnimationPlayer = components.AnimationPlayer;
const Movement = components.Movement;
const input = components.input;
const Rectangle = rl.Rectangle;
const Vector2 = rl.Vector2;

animation: AnimationPlayer,
movement: Movement,
hitbox: Rectangle,

const Self = @This();

/// Deinitialize with `deinit()`
fn init(animation: AnimationPlayer, movement: Movement) Self {
    return .{
        .animation = animation,
        .movement = movement,
        .hitbox = animation.getFrameRect(),
    };
}

pub fn deinit(self: *Self) void {
    self.animation.deinit();
}

pub fn update(self_: *anyopaque, delta: f32) !void {
    const self: *Self = @alignCast(@ptrCast(self_));

    const vec = input.getInputVector();
    //TODO make update collision and movement so that movement can be canceled if it would end up in a collision shape
    self.updateHitbox();
    try self.movement.move(vec, delta);
    try self.updateVisuals();
    AnimationPlayer.update(&self.animation, delta);
}

fn updateVisuals(self: *Self) !void {
    if (self.movement.motion.x < 0) self.animation.h_flip = false
    else if (self.movement.motion.x > 0) self.animation.h_flip = true;

    if (self.movement.motion.length() == 0) try self.animation.setAnimation(0)
    else try self.animation.setAnimation(1);
}

pub fn draw(self: *Self) void {
    if (@import("builtin").mode == .Debug) {
        debugDraw(self);
    }
    
    self.animation.draw(self.movement.pos);
}

fn updateHitbox(self: *Self) void {
    self.hitbox.x = self.movement.pos.x;
    self.hitbox.y = self.movement.pos.y;
}

fn debugDraw(self: *Self) void {
    const hitbox = self.hitbox;
    if (false) rl.drawRectangle(
        @intFromFloat(hitbox.x),
        @intFromFloat(hitbox.y),
        @intFromFloat(hitbox.width * settings.getResolutionRatio()),
        @intFromFloat(hitbox.height * settings.getResolutionRatio()),
        rl.Color.red
    );

    const pos = self.movement.pos;
    if (false) rl.drawCircle(
        @intFromFloat(pos.x),
        @intFromFloat(pos.y),
        5,
        rl.Color.green
    );
}

const Template = enum {
    Cerby,
    BlueMinawan,
};

/// Init a new character with the given template. Deinitialize with `deinit()`.
pub fn initTemplate(template: Template) !Self {
    return switch (template) {
        .Cerby => blk: {
            const tex = try rl.loadTexture("assets/textures/characters_spritesheet.png");
            var obj = Self.init(
                AnimationPlayer.init(
                    tex,
                    16,
                    16,
                    7
                ),
                Movement.init(
                    .{
                        .x = 0,
                        .y = -240
                    },
                    100,
                ),
            );

            // Standing
            try obj.animation.addAnimation(.{ .start_frame = 0, .end_frame = 0 });

            // Walking
            try obj.animation.addAnimation(.{ .start_frame = 1, .end_frame = 8 });

            break :blk obj;
        },
        .BlueMinawan => blk: {
            const tex = try rl.loadTexture("assets/textures/characters_spritesheet.png");
            var obj = Self.init(
                AnimationPlayer.init(
                    tex,
                    16,
                    16,
                    5
                ),
                Movement.init(
                    Vector2.zero(),
                    40,
                ),
            );

            // Standing
            try obj.animation.addAnimation(.{ .start_frame = 81, .end_frame = 84 });

            // Walking
            try obj.animation.addAnimation(.{ .start_frame = 81, .end_frame = 84 });

            break :blk obj;
        } 
    };
}