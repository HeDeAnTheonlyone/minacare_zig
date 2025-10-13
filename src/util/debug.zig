const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const settings = @import("../lib.zig").app.settings;

pub var show_debug_menu = false;

pub var show_fps = true;
pub var show_player_pos = false;
pub var show_character_hitbox = false;
pub var show_character_origin = false;
pub var show_character_center = false;
pub var show_tile_map_collisions = false;
pub var show_character_bottom = false;
pub var show_tile_layering = false;
pub var show_current_chunk_bounds = false;
pub var show_error_tiles = false;

comptime {
    if (@import("builtin").mode != .Debug)
        @compileError("The debug module is not allowed in release builds.");
}

pub fn getSaveable() struct {*bool, *bool, *bool, *bool, *bool, *bool, *bool, *bool, *bool, *bool} {
    return .{
        &show_fps,
        &show_player_pos,
        &show_character_hitbox,
        &show_character_origin,
        &show_character_center,
        &show_tile_map_collisions,
        &show_character_bottom,
        &show_tile_layering,
        &show_current_chunk_bounds,
        &show_error_tiles,
    };
}

pub fn drawDebugPanel() !void {
    if (rl.isKeyPressed(.f3)) {
        show_debug_menu = !show_debug_menu;
        @import("persistence.zig").save(@This(), .debug);
    }
    if (!show_debug_menu) return;

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
            .width = @floatFromInt(@divFloor(settings.render_width, 4)),
            .height = @floatFromInt(settings.render_height),
        },
        "Debug Display Panel",
    );

    const check_boxes = [_]struct{[:0]const u8, *bool}{
        .{"FPS", &show_fps},
        .{"Player Pos", &show_player_pos},
        .{"Character Hitboxe", &show_character_hitbox},
        .{"Character Origin", &show_character_origin},
        .{"Character Centerpoint", &show_character_center},
        .{"Character Bottom", &show_character_bottom},
        .{"Tilemap Collisions", &show_tile_map_collisions},
        .{"Tile Layering", &show_tile_layering},
        .{"Chunk Bound", &show_current_chunk_bounds},
        .{"Error Tiles", &show_error_tiles},
    };

    for (check_boxes, 0..) |box, i| {
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
