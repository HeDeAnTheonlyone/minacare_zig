const std = @import("std");
const rl = @import("raylib");
const settings = @import("Settings.zig");
const input = @import("input.zig");
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
    const vec = input.getInputVector();

    self.movement.move(vec, delta);
    try self.updateVisuals();
    self.animation.update(delta);
}

fn updateVisuals(self: *Self) !void {
    if (self.movement.motion.x < 0) self.animation.h_flip = false
    else if (self.movement.motion.x > 0) self.animation.h_flip = true;

    if (self.movement.motion.length() == 0) try self.animation.setAnimation(0)
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
    BlueMinawan,
    Debug,
};

/// Init a new character with the given template. Caller is responsible to deinit the Character at the end of its use.
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
                .{
                    .speed = 100,
                },
            );

            // Standing
            try obj.animation.addAnimation(.{ .start_frame = 0, .end_frame = 0 });

            // Walking
            try obj.animation.addAnimation(.{ .start_frame = 0, .end_frame = 4 });

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
                Movement.init(40),
            );

            // Standing
            try obj.animation.addAnimation(.{ .start_frame = 16, .end_frame = 16 });

            // Walking
            try obj.animation.addAnimation(.{ .start_frame = 16, .end_frame = 16 });

            break :blk obj;
        },
        .Debug => blk: {
            const tex = try rl.loadTexture("assets/textures/characters_spritesheet.png");
            var obj = Self.init(
                AnimationPlayer.init(
                    tex,
                    16,
                    16,
                    0
                ),
                Movement.init(100)
            );

            // Standing
            try obj.animation.addAnimation(.{ .start_frame = 32, .end_frame = 32 });

            // Walking
            try obj.animation.addAnimation(.{ .start_frame = 32, .end_frame = 32 });

            break :blk obj;
        },
    };
}