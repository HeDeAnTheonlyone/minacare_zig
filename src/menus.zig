const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const stg = @import("settings.zig");
const app_state = @import("app_state.zig");
const game_state = @import("game_state.zig");
const translation = @import("translation.zig");
const Rectangle = rl.Rectangle;
const Vector2 = rl.Vector2;
const Translatable = translation.Translatable;

pub const main = struct {
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
        rg.setStyle(.default, .{ .default = .text_size }, 100);
        rg.setStyle(.default, .{ .default = .text_alignment_vertical }, 0);
        rg.setStyle(.label, .{ .control = .text_alignment }, 1);
        rg.setStyle(.label, .{ .control = .text_color_normal }, rl.colorToInt(.black));
        _ = rg.label(Rectangle.init(0, 100, @floatFromInt(stg.render_width), 110), "Minacare");

        rg.setStyle(.default, .{ .default = .text_size }, 64);
        rg.setStyle(.default, .{ .default = .text_alignment_vertical }, 1);
        const button_height: f32 = 100;
        const buttons = [_]struct{Translatable, *bool}{
            .{.{ .id = "menu.load_game" }, &load_game},
            .{.{ .id = "menu.new_game" }, &new_game},
            .{.{ .id = "menu.settings" }, &settings_},
            .{.{ .id = "menu.exit" }, &exit},
        };

        for (buttons, 0..) |button, i| {
            const button_area_y = @as(f32, @floatFromInt(stg.render_height)) * 0.4;
            const button_area_height = @as(f32, @floatFromInt(stg.render_height)) - button_area_y - 100; // -100 from the bottom
            const button_spacing = (button_area_height - button_height * buttons.len) / (buttons.len - 1) + button_height;

            button[1].* = rg.button(
                Rectangle.init(
                    @as(f32, @floatFromInt(stg.render_width)) * 0.25,
                    button_area_y + @as(f32, @floatFromInt(i)) * button_spacing,
                    @as(f32, @floatFromInt(stg.render_width)) * 0.5,
                    button_height,
                ),
                button[0].translate(),
            );
        }
    }
};

pub const settings= struct {
    const fps = struct {
        var edit_mode: bool = false;
        var prev_selected: i32 = 0;
        var selected: i32 = 0;
        const text = blk: {
            var txt: [:0]const u8 = "";
            const name_list = std.meta.fieldNames(values);
            for (name_list, 0..) |name, i| {
                txt =
                    if (i == name_list.len - 1) txt ++ name
                    else txt ++ name ++ ";";
            }
            break :blk txt;
        };
        const values = enum(u32) {
            @"60" = 60,
            @"120" = 120,
            @"144" = 144,
            @"165" = 165,
            @"240" = 240,
            uncapped = 100_000_000,
        };
    };


    pub fn update(_: f32) !void {
        std.debug.print("{s}\n", .{fps.text});
    }

    pub fn draw() void {
        if (
            rg.dropdownBox(
                Rectangle.init(
                    @as(f32, @floatFromInt(stg.render_width)) * 0.25,
                    100,
                    @as(f32, @floatFromInt(stg.render_width)) * 0.5,
                    100
                ),
                fps.text,
                &fps.selected,
                fps.edit_mode,
            ) == 1
        ) fps.edit_mode = !fps.edit_mode;
    }
};

pub const pause = struct {
    pub fn draw() void {
        // TODO;
    }
};

    // TODO add function for switching and reloading all the translations
    