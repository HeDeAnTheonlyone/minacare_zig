
pub const native_width: i32 = 630;
pub const native_height: i32 = 360;
pub var window_width: i32 = 1920;
pub var window_height:i32 = 1080;
pub var target_fps: i32 = 170;
pub const tile_size: u8 = 16; // this number squared
pub const chunk_size: u8 = 32; // this number squared

pub fn getRsolutionRation() f32 {
    return @as(f32, @floatFromInt(window_width)) / @as(f32, @floatFromInt(native_width));
}

