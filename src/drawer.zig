const settings = @import("Settings.zig");
const rl = @import("raylib").raylib_module;
const Rectangle = rl.Rectangle;
const Vector2 = rl.Vector2;
const Color = rl.Color;

pub fn drawTexturePro(
    texture: rl.Texture2D,
    source: Rectangle,
    dest: Rectangle,
    origin: Vector2,
    rotation: f32,
    tint: Color
) void {
    rl.drawTexturePro(
        texture,
        source,
        dest.scale(settings.resolution_ratio),
        origin.scale(settings.resolution_ratio),
        rotation,
        tint
    );
}

pub fn drawRectOutline(rect: Rectangle, line_thickness: f32, color: Color) void {
    rl.drawRectangleLinesEx(
        rect.scale(settings.resolution_ratio),
        line_thickness,
        color
    );
}

pub fn drawCircle(center_x: f32, center_y: f32, radius: f32, color: Color) void {
    rl.drawCircle(
        @intFromFloat(center_x * settings.resolution_ratio),
        @intFromFloat(center_y * settings.resolution_ratio),
        radius,
        color
    );
}
