const std = @import("std");
const rl = @import("raylib");
const settings = @import("Settings.zig");
const unpackParam = @import("signals.zig").CallbackCaster.unpackParam; 
const AnimationPlayer = @import("components.zig").AnimationPlayer;
const Rectangle = rl.Rectangle;
const Vector2 = rl.Vector2;

animation: AnimationPlayer,
hitbox: Rectangle,
pos: Vector2,
motion: Vector2 = Vector2{.x = 0, .y = 0},
acceleration: f32 = 3,
max_speed: f32 = 35,
stopping_distance: f32 = 350,
velocity: f32 = 0,

const Self = @This();

pub fn init(animation: AnimationPlayer, acceleration: f32, max_speed: f32) Self {
    return Self{
        .animation = animation,
        .hitbox = animation.getFrameRect(),
        .pos = Vector2{
            .x = @floatFromInt(@divFloor(settings.window_width, 2)),
            .y = @floatFromInt(@divFloor(settings.window_height, 2)),
        },
        .acceleration = acceleration,
        .max_speed = max_speed,
    };
}

pub fn updateCallbackAdapter(ctx: *anyopaque, param: ?usize) !void {
    const self: *Self = @alignCast(@ptrCast(ctx));
    const delta = unpackParam(f32, param.?);

    try update(self, delta);
}

fn update(self: *Self, delta: f32) !void {
    const target_pos = rl.getMousePosition();

    move(self, target_pos, delta);
    try updateVisuals(self);

    self.animation.update(delta);
}

pub fn draw(self: *Self) void {
    self.animation.draw(
        self.pos.subtract(
            Vector2{
                .x = @divFloor(self.hitbox.width, 2),
                .y = @divFloor(self.hitbox.height, 2),
            }
        )
    );
}

fn move(self: *Self, target_pos: Vector2, delta: f32) void {
    self.motion = Vector2.subtract(target_pos, self.pos);

    self.velocity =
        if (self.motion.length() > self.stopping_distance) std.math.clamp(
            self.velocity + self.acceleration * delta,
            0,
            self.max_speed * 0.1
        )
        else std.math.clamp(
            self.velocity - self.acceleration * 1.5 * delta,
            0,
            self.max_speed * 0.1
        );
    
    const lerp_amount = std.math.clamp(self.velocity / self.motion.length(), 0, 1);
    self.pos = Vector2.lerp(self.pos, target_pos, lerp_amount);
}

fn updateVisuals(self: *Self) !void {
    if (self.motion.x > 0) self.animation.h_flip = false
    else if (self.motion.x < 0) self.animation.h_flip = true;

    if (self.velocity == 0) try self.animation.switchAnimation(1)
    else try self.animation.switchAnimation(0);
}