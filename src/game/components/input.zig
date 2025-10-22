const rl = @import("raylib");
const Vector2 = rl.Vector2;

/// Returns a normalized vector that represents the input direction.
    // TODO Consider adding controller support
pub fn getInputVector() Vector2 {
    const v = @as(i8, @intFromBool(rl.isKeyDown(.s))) - @as(i8, @intFromBool(rl.isKeyDown(.w)));
    const h = @as(i8, @intFromBool(rl.isKeyDown(.d))) - @as(i8,@intFromBool(rl.isKeyDown(.a)));

    const vec = Vector2{
        .x = @floatFromInt(h),
        .y = @floatFromInt(v)
    };
    return vec.normalize();
}
