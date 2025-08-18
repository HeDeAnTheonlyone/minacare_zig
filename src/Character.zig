const std = @import("std");
const rl = @import("raylib");
const settings = @import("Settings.zig");
const unpackParam = @import("signals.zig").CallbackCaster.unpackParam; 
const AnimationPlayer = @import("components.zig").AnimationPlayer;
const Movement = @import("components.zig").Movement;
const Rectangle = rl.Rectangle;
const Vector2 = rl.Vector2;

animation: AnimationPlayer,
movement: Movement,
hitbox: Rectangle,

const Self = @This();

fn init(animation: AnimationPlayer, movement: Movement) Self {
    return Self{
        .animation = animation,
        .movement = movement,
        .hitbox = animation.getFrameRect(),
    };
}

pub fn deinit(self: *Self) void {
    self.animation.deinit();
}

pub fn updateCallbackAdapter(ctx: *anyopaque, param: ?usize) !void {
    const self: *Self = @alignCast(@ptrCast(ctx));
    const delta = unpackParam(f32, param.?);

    try update(self, delta);
}

fn update(self: *Self, delta: f32) !void {
    const target_pos = rl.getMousePosition();

    self.movement.move(target_pos, delta);
    try self.updateVisuals();
    std.debug.print("{d}, {d}\n", .{self.animation.current_animation, self.animation.current_frame + self.animation.animations[self.animation.current_animation].start_frame});
    self.animation.update(delta);
}

fn updateVisuals(self: *Self) !void {
    if (self.movement.motion.x > 0) self.animation.h_flip = false
    else if (self.movement.motion.x < 0) self.animation.h_flip = true;

    if (self.movement.velocity == 0) try self.animation.setAnimation(0)
    else try self.animation.setAnimation(1);
}

pub fn draw(self: *Self) void {
    self.animation.draw(
        self.movement.pos.subtract(
            Vector2{
                .x = @floatFromInt(@divFloor(self.animation.frame_width, 2)),
                .y = @floatFromInt(@divFloor(self.animation.frame_height, 2)),
            }
        )
    );
}

const Template = enum {
    Cerby,
    Minagyatt,
};

/// Init a new character with the given template. Caller is responsible to deinit the Character at the end of its use.
pub fn initTemplate(template: Template) !Self {
    return switch (template) {
        .Cerby => blk: {
            const tex = try rl.loadTexture("assets/textures/cerby_spritesheet.png");
            var obj = Self.init(
                AnimationPlayer.init(
                    tex,
                    256,
                    256,
                    7
                ),
                .{
                    .acceleration = 5,
                    .max_speed = 50,
                    .stopping_distance = 350
                },
            );

            // Standing
            try obj.animation.addAnimation(.{ .start_frame = 0, .end_frame = 0 });

            // Walking
            try obj.animation.addAnimation(.{ .start_frame = 0, .end_frame = 1 });

            break :blk obj;
        },
        .Minagyatt => blk: {
            const tex = try rl.loadTexture("assets/textures/minagyatt_spritesheet.png");
            var obj = Self.init(
                AnimationPlayer.init(
                    tex,
                    512,
                    256,
                    5
                ),
                .{
                    .acceleration = 3,
                    .max_speed = 35,
                    .stopping_distance = 350
                },
            );

            // Standing
            try obj.animation.addAnimation(.{ .start_frame = 6, .end_frame = 6 });

            // Walking
            try obj.animation.addAnimation(.{ .start_frame = 0, .end_frame = 22 });

            break :blk obj;
        },
    };
}