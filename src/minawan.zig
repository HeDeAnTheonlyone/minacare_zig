const std = @import("std");
const rl = @import("raylib");
const unpackParam = @import("signals.zig").CallbackCaster.unpackParam; 
const AnimationPlayer = @import("animation.zig").AnimationPlayer;
const Rectangle = rl.Rectangle;
const Vector2 = rl.Vector2;

pub const Minawan = struct {
    animation: AnimationPlayer,
    hitbox: Rectangle,
    pos: Vector2 = undefined,
    speed: f32 = 10,

    const Self = @This();

    pub fn init(animation: AnimationPlayer) Self {
        return Self{
            .animation = animation,
            .hitbox = animation.getFrameRect(),
        };
    }

    pub fn updateCallbackAdapter(ctx: *anyopaque, param: ?usize) !void {
        const self: *Minawan = @alignCast(@ptrCast(ctx));
        const delta = unpackParam(f32, param.?);

        update(self, delta);
    }

    pub fn update(self: *Self, delta: f32) void {
        const new_pos = rl.getMousePosition();
        const motion = new_pos.subtract(self.pos).normalize();
        self.pos = new_pos;

        std.debug.print("{any}\n", .{motion});

        if (motion.x > 0) self.animation.h_flip = false
        else if (motion.x < 0) self.animation.h_flip = true;

        self.animation.update(delta);
    }

    pub fn draw(self: *Self) void {
        self.animation.draw(self.pos.subtract(Vector2{.x = @divFloor(self.hitbox.width, 2), .y = @divFloor(self.hitbox.height, 2)}));
    }
};