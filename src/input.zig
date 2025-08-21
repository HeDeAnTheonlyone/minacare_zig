const rl = @import("raylib");

pub fn getInputVector() rl.Vector2 {
    const v = @as(i8, @intFromBool(rl.isKeyDown(.s))) - @as(i8, @intFromBool(rl.isKeyDown(.w)));
    const h = @as(i8, @intFromBool(rl.isKeyDown(.d))) - @as(i8,@intFromBool(rl.isKeyDown(.a)));

    const vec = rl.Vector2{.x = @floatFromInt(h), .y = @floatFromInt(v)};
    return vec.normalize();
}