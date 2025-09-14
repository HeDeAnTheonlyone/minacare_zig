//! Handles projecting and screen size adjusting for draw function calls

const settings = @import("settings.zig");
const rl = @import("raylib").raylib_module;
const Rectangle = rl.Rectangle;
const Vector2 = rl.Vector2;
const Color = rl.Color;


pub fn drawFps(pos: Vector2) void {
    const scaled_pos = pos.scale(settings.resolution_ratio);
    rl.drawFPS(
        @intFromFloat(scaled_pos.x),
        @intFromFloat(scaled_pos.y)
    );
}

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

pub fn drawRectOutlineAsIs(rect: Rectangle, line_thickness: f32, color: Color) void {
    rl.drawRectangleLinesEx(
        rect,
        line_thickness,
        color
    );
}


pub fn drawCircle(center: Vector2, radius: f32, color: Color) void {
    const scaled_center = center.scale(settings.resolution_ratio);
    rl.drawCircle(
        @intFromFloat(scaled_center.x),
        @intFromFloat(scaled_center.y),
        radius,
        color
    );
}

pub fn drawRectAsIs(rect: Rectangle, color: rl.Color) void {
    rl.drawRectangle(
        @intFromFloat(rect.x),
        @intFromFloat(rect.y),
        @intFromFloat(rect.width),
        @intFromFloat(rect.height),
        color,
    );
}
