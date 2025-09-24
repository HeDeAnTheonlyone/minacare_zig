const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const settings = @import("settings.zig");
const app_state = @import("app_state.zig");
const game_state = @import("game_state.zig");
const Rectangle = rl.Rectangle;
const Vector2 = rl.Vector2;


const Self = @This();
var load_game: bool = false;
var new_game: bool = false;
var settings_: bool = false;
var exit: bool = false;

pub fn update(_: f32) !void {
    app_state.state = if (load_game) .load_game
        else if (new_game) .new_game
        else if (settings_) .settings
        else if (exit) .exit
        else .menu;
} 

pub fn draw() void {
    rl.beginDrawing();
    defer rl.endDrawing();
    rl.clearBackground(.white);

    rg.setStyle(.default, .{ .default = .text_size }, 100);
    rg.setStyle(.default, .{ .default = .text_alignment_vertical }, 0);
    rg.setStyle(.label, .{ .control = .text_alignment }, 1);
    rg.setStyle(.label, .{ .control = .text_color_normal }, rl.colorToInt(.black));
    _ = rg.label(Rectangle.init(0, 100, @floatFromInt(settings.render_width), 110), "Minacare");

    rg.setStyle(.default, .{ .default = .text_size }, 64);
    rg.setStyle(.default, .{ .default = .text_alignment_vertical }, 1);
    const button_height: f32 = 100;
    const buttons = [_]struct{[:0]const u8, *bool}{
        .{"Load Game", &load_game},
        .{"New Game", &new_game},
        .{"Settings", &settings_},
        .{"Exit", &exit},
    };

    for (buttons, 0..) |button, i| {
        const button_area_y = @as(f32, @floatFromInt(settings.render_height)) * 0.4;
        const button_area_height = @as(f32, @floatFromInt(settings.render_height)) - button_area_y - 100; // -100 from the bottom
        const button_spacing = (button_area_height - button_height * buttons.len) / (buttons.len - 1) + button_height;

        button[1].* = rg.button(
            Rectangle.init(
                @as(f32, @floatFromInt(settings.render_width)) * 0.25,
                button_area_y + @as(f32, @floatFromInt(i)) * button_spacing,
                @as(f32, @floatFromInt(settings.render_width)) * 0.5,
                button_height,
            ),
            button[0],
        );
    }
}
