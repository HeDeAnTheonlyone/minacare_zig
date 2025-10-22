const std = @import("std");
const rl = @import("raylib");
pub const lib = @import("lib.zig");
const app = lib.app;
const game = lib.game;
const util = lib.util;
const gpa = app.gpa;
const app_state = app.state;
const settings = app.settings;
const persistence = util.persistence;
const translation = util.translation;
const tween = util.tween;
const game_state = game.state;
const menu = game.menu;

pub fn main() !void {
    persistence.load(settings, .settings);

    rl.setExitKey(.null);
    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(
        settings.window_width,
        settings.window_height,
        "Minaland"
    );
    defer rl.closeWindow();

    try settings.init();
    defer settings.deinit();
    persistence.load(settings, .settings);

    rl.setTargetFPS(settings.target_fps);

    try translation.init(gpa.allocator, settings.selected_language);
    defer translation.deinit(gpa.allocator);

    try game_state.init();
    defer game_state.deinit();

    game_loop: while(!rl.windowShouldClose())
    {
        // DEBUG start
        if(rl.isWindowResized()) {
            settings.updateRenderSize();
            game_state.player.recenterCam();
        }

        if (rl.isKeyPressed(.f6)) {
            rl.toggleBorderlessWindowed();
            settings.updateRenderSize();
            game_state.player.recenterCam();
        }
        // DEBUG end

        const delta = std.math.clamp(
            rl.getFrameTime(),
            0,
            settings.frame_time_cap
        );

        app_state.counter += delta;
        try app_state.events.on_global_update.dispatch(delta);

        switch (app_state.current) {
            .menu => {
                try menu.main.update(delta);
                
                rl.beginDrawing();
                defer rl.endDrawing();
                rl.clearBackground(.white);
                
                menu.main.draw();
            },
            .game => {
                try game_state.update(delta);
                
                rl.beginDrawing();
                defer rl.endDrawing();
                rl.clearBackground(.black);
                
                try game_state.draw();
            },
            .pause => {
                rl.beginDrawing();
                defer rl.endDrawing();
                rl.clearBackground(.black);
                
                try game_state.draw();
                menu.pause.draw();
            },
            .settings => {
                try menu.settings.update(delta);

                rl.beginDrawing();
                defer rl.endDrawing();
                rl.clearBackground(.white);
                
                menu.settings.draw();
            },
            .exit => break :game_loop,
            else => unreachable,
        }
    }
}
