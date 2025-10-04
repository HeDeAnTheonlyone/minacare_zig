const std = @import("std");
const settings = @import("../lib.zig").app.settings;
const rl = @import("raylib");
const rg = @import("raygui");

const Styles = enum {
    main_menu_title,
    main_menu_buttons,
    settings_menu_buttons,
};

pub fn apply(style: Styles) void {
    switch (style) {
        .main_menu_title => {
            rg.setStyle(.default, .{ .default = .text_size }, @intFromFloat(30 * settings.resolution_ratio.x));
            rg.setStyle(.default, .{ .default = .text_alignment_vertical }, 0);
            rg.setStyle(.label, .{ .control = .text_alignment }, 1);
            rg.setStyle(.label, .{ .control = .text_color_normal }, rl.colorToInt(.black));
        },
        .main_menu_buttons => {
            rg.setStyle(.default, .{ .default = .text_size }, @intFromFloat(14 * settings.resolution_ratio.x));
            rg.setStyle(.default, .{ .default = .text_alignment_vertical }, 1);
        },
        .settings_menu_buttons => {
            rg.setStyle(.default, .{ .default = .text_size }, @intFromFloat(14 * settings.resolution_ratio.x));
        },
    }
}
