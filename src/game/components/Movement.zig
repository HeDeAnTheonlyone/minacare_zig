const rl = @import("raylib");
const event = @import("../../lib.zig").util.event;
const Vector2 = rl.Vector2;

pos: Vector2,
speed: f32,
events: struct {
    on_pos_changed: event.Dispatcher(Vector2, 8),
},

const Self = @This();

pub fn init(pos: Vector2, speed: f32) Self {
    return .{
        .pos = pos,
        .speed = speed,
        .events = .{ .on_pos_changed = .init },
    };
}

pub fn getMotion(self: *Self, input_vec: Vector2, delta: f32) Vector2 {
    const s = self.speed * delta;
    return input_vec.scale(s);
}

pub fn move(self: *Self, target_pos: Vector2, ) !void {
    try self.events.on_pos_changed.dispatch(target_pos);
    self.pos = target_pos;
}