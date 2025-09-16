const std = @import("std");
const rl = @import("raylib");
const rg= @import("raygui");

pub const native_width: i32 = 630;
pub const native_height: i32 = 360;
pub var window_width: i32 = 1920;
pub var window_height:i32 = 1080;
/// Only use this value in display/drawing context.
pub var resolution_ratio: f32 = undefined;
pub const base_framerate = 60;
pub var target_fps: i32 = 100000;
pub const frame_time_cap: f32 = 0.05;
pub var font: rl.Font = undefined; // needs OpenGL context
pub const tile_size: u8 = 16; // counts for x and y
pub const chunk_size: u8 = 32; // counts for x and y

const Saveable = struct {
    window_width: *i32,
    window_height: *i32,
    target_fps: *i32,
};

/// Initializes all settings that can not be comptime evaluated
pub fn init() !void {
    resolution_ratio = getResolutionRatio();
    font = try rl.loadFontEx("assets/fonts/vividly_extended.ttf", 32, null);
    rg.setFont(font);
    rg.setStyle(.default, .{ .default = .text_wrap_mode }, 1);
}

pub fn deinit() void {
    font.unload();
}

pub fn getSaveable() Saveable {
    return .{
        .window_width = &window_width,
        .window_height = &window_height,
        .target_fps = &target_fps,
    };
}

pub fn getResolutionRatio() f32 {
    // The compensation value is to make slightly change the final multiplier to make the look right.
    const compensation: f32 = 1.5;
    return @as(f32, @floatFromInt(window_width)) / @as(f32, @floatFromInt(native_width)) * compensation;
}

pub fn changeResolution(width: i32, height: i32) void {
    window_width = width;
    window_height = height;
    resolution_ratio = getResolutionRatio();
}
