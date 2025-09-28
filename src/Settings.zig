const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");

pub var font: rl.Font = undefined; // needs OpenGL context
/// Only use this value in display/drawing context.
pub var resolution_ratio: rl.Vector2 = undefined;
pub const window_width: i32 = 1920;
pub const window_height: i32 = 1080;
pub const native_width: i32 = 640;
pub const native_height: i32 = 360;
pub var render_width: i32 = undefined;
pub var render_height:i32 = undefined;
pub const base_framerate = 60;
pub var target_fps: i32 = 100000;
pub const frame_time_cap: f32 = 0.05;
pub var text_speed: f32 = 0.02;
pub var language: Language = .de;
pub const tile_size: u8 = 16; // counts for x and y
pub const chunk_size: u8 = 32; // counts for x and y
pub var is_borderless: bool = false;

const Language = enum{
    // TODO make this dynamic based on the translation file.
    en,
    de,
    fr, // not implemented
    sp, // not implemented
    // others
};

/// Initializes all settings that can not be comptime evaluated
pub fn init() !void {
    updateRenderSize();
    font = try rl.loadFontEx("assets/fonts/vividly_extended.ttf", 128, null);
    rg.setFont(font);
    rg.setStyle(.default, .{ .default = .text_wrap_mode }, 1);
    rg.setStyle(.label, .{ .control = .text_color_normal }, rl.colorToInt(.black));
}

pub fn deinit() void {
    font.unload();
}

pub fn getSaveable() struct {*i32, *i32, *i32, *f32, *Language, *bool} {
    return .{
        &render_width,
        &render_height,
        &target_fps,
        &text_speed,
        &language,
        &is_borderless,
    };
}

fn getResolutionRatio() rl.Vector2 {
    // Value to scale up the game and make it look right without the sub pixel imprecision from camera zoom.
    const pixel_perfect_zoom = 1.5;
    
    // TODO This method may not be the best way to handle this. Will get changed maybe.
    const w_size = @min(render_width, render_height);
    const n_size = @min(native_width, native_height);
    return .{
        .x = @floor(@as(f32, @floatFromInt(w_size)) / @as(f32, @floatFromInt(n_size)) * pixel_perfect_zoom),
        .y = @floor(@as(f32, @floatFromInt(w_size)) / @as(f32, @floatFromInt(n_size)) * pixel_perfect_zoom),
    };
}

pub fn updateRenderSize() void {
    render_width = rl.getRenderWidth();
    render_height = rl.getRenderHeight();
    resolution_ratio = getResolutionRatio();
}
