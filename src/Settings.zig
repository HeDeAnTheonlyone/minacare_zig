
pub const native_width: i32 = 630;
pub const native_height: i32 = 360;
pub var window_width: i32 = 1920;
pub var window_height:i32 = 1080;
pub var target_fps: i32 = 170;
pub const tile_size: u8 = 16; // this number squared
pub const chunk_size: u8 = 32; // this number squared

pub fn getRsolutionRatio() f32 {
    // The compensation value is to make slightly change the final multiplier to make the look right.
    const compensation: f32 = 2; 
    return @as(f32, @floatFromInt(window_width)) / @as(f32, @floatFromInt(native_width)) * compensation;
}

