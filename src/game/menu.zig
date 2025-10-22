const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const lib = @import("../lib.zig");
const app = lib.app;
const game = lib.game;
const util = lib.util;
const stg = app.settings;
const style = util.style;
const translation = util.translation;
const Rectangle = rl.Rectangle;
const Translatable = translation.Translatable;

const button_height: f32 = 100;

pub const main = struct {
    var load_game: bool = false;
    var new_game: bool = false;
    var settings_: bool = false;
    var exit: bool = false;
    var buttons = [_]struct{Translatable, *bool}{
        .{Translatable.init("menu.load_game"), &load_game},
        .{Translatable.init("menu.new_game"), &new_game},
        .{Translatable.init("menu.settings"), &settings_},
        .{Translatable.init("menu.exit"), &exit},
    };

    pub fn update(_: f32) !void {
        if (load_game) try app.state.switchTo(.load_game)
            else if (new_game) try app.state.switchTo(.new_game)
            else if (settings_) try app.state.switchTo(.settings)
            else if (exit) try app.state.switchTo(.exit)
            else try app.state.switchTo(.menu);
    } 

    pub fn draw() void {
        style.apply(.main_menu_title);
        _ = rg.label(Rectangle.init(0, 100, @floatFromInt(stg.render_width), 260), "Minaland");

        style.apply(.main_menu_buttons);
        for (&buttons, 0..) |*button, i| {
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
    const button_spacing = 50;
    var is_synced: bool = false;

    pub fn update(_: f32) !void {
        var changed: bool = false;

        if (fps.changed()) {
            stg.target_fps = fps.getValue();
            changed = true;
        }

        if (language.changed()) {
            stg.selected_language = @intCast(language.selected);
            try translation.reloadTranslationData(stg.selected_language);
            changed = true;
        }

        if (resolution.changed()) {
            rl.setWindowSize(resolution.getValue()[0], resolution.getValue()[1]);
            stg.updateRenderSize();
        }

        if (changed) save();

        if (rl.isKeyPressed(.b)) try app.state.switchTo(.menu); // DEBUG
    }

    pub fn draw() void {
        // Menu elements get drawn from bottom to top to correctly handle overlapping

        const button_x = @as(f32, @floatFromInt(stg.render_width)) * 0.25;
        const button_width = @as(f32, @floatFromInt(stg.render_width)) * 0.5; 
        // const button

        style.apply(.settings_menu_buttons);
        if (
            rg.dropdownBox(
                Rectangle.init(
                    button_x,
                    100 * 3 + button_height * 2,
                    button_width,
                    button_height
                ),
                resolution.text.translate(),
                &resolution.selected,
                resolution.edit_mode,
            ) == 1
        ) resolution.edit_mode = !resolution.edit_mode;

        if (
            rg.dropdownBox(
                Rectangle.init(
                    button_x,
                    100 * 2 + button_height,
                    button_width,
                    button_height
                ),
                language.text,
                &language.selected,
                language.edit_mode,
            ) == 1
        ) language.edit_mode = !language.edit_mode;

        if (
            rg.dropdownBox(
                Rectangle.init(
                    button_x,
                    100,
                    button_width,
                    button_height
                ),
                fps.text.translate(),
                &fps.selected,
                fps.edit_mode,
            ) == 1
        ) fps.edit_mode = !fps.edit_mode;
    }

    pub fn syncToSettings() void {
        if (is_synced) return;
        is_synced = true;
        fps.init(stg.target_fps);
        language.init(stg.selected_language);
    }

    fn save() void {
        util.persistence.save(stg, .settings);
    }

    const resolution = struct {
        var selected: i32 = 0;
        var prev_selected: i32 = 0;
        var edit_mode: bool = false;
        var text = Translatable.init("settings.resolution");
        const values = [_]struct{i32, i32}{
            .{640, 360},
            .{1280, 720},
            .{1920, 1080},
            .{2560, 1440},
            .{3840, 2160},
        };

        fn init(res: struct {i32, i32}) void {
            const index = getIndex(res);
            selected = index;
            prev_selected = index;
        }

        fn changed() bool {
            defer prev_selected = selected;
            return selected != prev_selected;
        }

        /// Gets the index of the given resolution or 2 if not in the list.
        fn getIndex(res: struct {i32, i32}) i32 {
            std.mem.indexOfScalar(struct {i32, i32}, values, res) orelse 2;
        }

        /// Returns the current selected resolution value
        fn getValue() struct {i32, i32} {
            return values[@intCast(selected)];
        }
    };

    const fps = struct {
        var selected: i32 = 0;
        var prev_selected: i32 = 0;
        var edit_mode: bool = false;
        var text = Translatable.init("settings.fps");
        const values = [_]i32{
            60,
            120,
            144,
            165,
            240,
            350,
            std.math.maxInt(i32),
        };

        fn init(target_fps: i32) void {
            const index = getIndex(target_fps);
            selected = index;
            prev_selected = index;
        }

        fn changed() bool {
            defer prev_selected = selected;
            return selected != prev_selected;
        }

        /// Gets the index of the given fps value or 0 if not in the list.
        fn getIndex(target_fps: i32) i32 {
            return @intCast(std.mem.indexOfScalar(i32, &values, target_fps) orelse 0);
        }

        /// Returns the currently selected fps value
        fn getValue() i32 {
            return values[@intCast(selected)];
        }
    };

    const language = struct {
        var selected: i32 = 0;
        var prev_selected: i32 = 0;
        var edit_mode: bool = false;
        var text: [:0]const u8 = undefined;
        var buffer: [4096:0]u8 = @splat(0);
        
        fn init(selected_language: u8) void {
            selected = selected_language;
            prev_selected = selected_language;
            text = generateText();
        }

        fn changed() bool {
            defer prev_selected = selected;
            return selected != prev_selected;
        }

        fn generateText() [:0]const u8 {
            var bufAllocator = std.heap.FixedBufferAllocator.init(&buffer);
            const allocator = bufAllocator.allocator();

            return std.mem.joinZ(
                allocator,
                ";",
                translation.languages
            ) catch unreachable;
        }
    };
};

pub const pause = struct {
    pub fn draw() void {
        // TODO;
    }
};
