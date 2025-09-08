const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const settings = @import("settings.zig");

pub var show_debug_menu = false;

pub var show_fps = true;
pub var show_character_hitbox = false;
pub var show_character_origin = false;
pub var show_character_center = false;
pub var show_tile_map_collisions = false;

comptime {
    if (@import("builtin").mode != .Debug)
        @compileError("The debug module is not allowed in release builds.");
}

pub fn draw() void {
    if (rl.isKeyPressed(.f3)) show_debug_menu = !show_debug_menu;
    if (!show_debug_menu) return;

    rg.setFont(settings.font);
    rg.setStyle( .default, .{ .default = .text_size }, 24);
    rg.setStyle(
        .default,
        .{ .default = .background_color },
        rl.Color.white.alpha(0.8).toInt(),
    );

    _ = rg.panel(
        .{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(@divFloor(settings.window_width, 4)),
            .height = @floatFromInt(settings.window_height),
        },
        "Debug Display Panel",
    );

    const boxes = [_]struct{[:0]const u8, *bool}{
        .{"FPS", &show_fps},
        .{"Player Hitbox", &show_character_hitbox},
        .{"Player Origin", &show_character_origin},
        .{"Player Centerpoint", &show_character_center},
        .{"Tilemap Collisions", &show_tile_map_collisions},
    };

    for (boxes, 0..) |box, i| {
        const y_pos: f32 =  @floatFromInt(40 + 30 * i);
        _ = rg.checkBox(
            .{
                .x = 10,
                .y = y_pos,
                .width = 20,
                .height = 20,
            },
            box[0],
            box[1],
        );
    }

}
