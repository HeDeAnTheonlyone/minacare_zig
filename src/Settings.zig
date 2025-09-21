const std = @import("std");
const rl = @import("raylib");
const rg= @import("raygui");

pub var resolution_ratio: rl.Vector2 = undefined;
pub const native_width: i32 = 640;
pub const native_height: i32 = 360;
pub var window_width: i32 = 1920;
pub var window_height:i32 = 1080;
/// Only use this value in display/drawing context.
pub const base_framerate = 60;
pub var target_fps: i32 = 100000;
pub const frame_time_cap: f32 = 0.05;
pub var font: rl.Font = undefined; // needs OpenGL context
pub const tile_size: u8 = 16; // counts for x and y
pub const chunk_size: u8 = 32; // counts for x and y
pub var is_borderless: bool = false;


/// Initializes all settings that can not be comptime evaluated
pub fn init() !void {
    resolution_ratio = getResolutionRatio();
    font = try rl.loadFontEx("assets/fonts/vividly_extended.ttf", 128, null);
    rg.setFont(font);
    rg.setStyle(.default, .{ .default = .text_wrap_mode }, 1);
    rg.setStyle(.label, .{ .control = .text_color_normal }, rl.colorToInt(.black));
}

pub fn deinit() void {
    font.unload();
}

pub fn getSaveable() struct {*i32, *i32, *i32, *bool} {
    return .{
        &window_width,
        &window_height,
        &target_fps,
        &is_borderless,
    };
}

fn getResolutionRatio() rl.Vector2 {
    // Value to scale up the game and make it look right without the sub pixel imprecision from camera zoom.
    const pixel_perfect_zoom: f32 = 1.5;
    defer std.debug.print("{any}", .{resolution_ratio});
    
    // TODO This method may not be the best way to handle this. Will get changed maybe.
    const w_size = @min(window_width, window_height);
    const n_size = @min(native_width, native_height);
    return .{
        .x = @floor(@as(f32, @floatFromInt(w_size)) / @as(f32, @floatFromInt(n_size)) * pixel_perfect_zoom),
        .y = @floor(@as(f32, @floatFromInt(w_size)) / @as(f32, @floatFromInt(n_size)) * pixel_perfect_zoom),
    };
}

pub fn changeResolution(width: i32, height: i32) void {
    window_width = width;
    window_height = height;
    resolution_ratio = getResolutionRatio();
}


