//! Handles projecting and screen size adjusting for draw function calls

const rl = @import("raylib").raylib_module;
const settings = @import("../lib.zig").app.settings;
const Rectangle = rl.Rectangle;
const Vector2 = rl.Vector2;
const Color = rl.Color;


pub fn drawFps(pos: Vector2) void {
    const scaled_pos = pos.multiply(settings.resolution_ratio);
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
        dest.scaledDirectionSeparate(settings.resolution_ratio),
        origin.multiply(settings.resolution_ratio),
        rotation,
        tint
    );
}

pub fn drawRectOutline(rect: Rectangle, line_thickness: f32, color: Color) void {
    rl.drawRectangleLinesEx(
        rect.scaledDirectionSeparate(settings.resolution_ratio),
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
    const scaled_center = center.multiply(settings.resolution_ratio);
    rl.drawCircle(
        @intFromFloat(scaled_center.x),
        @intFromFloat(scaled_center.y),
        radius,
        color
    );
}

