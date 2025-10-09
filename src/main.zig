const std = @import("std");
const rl = @import("raylib");
const lib = @import("lib.zig");
const app = lib.app;
const game = lib.game;
const util = lib.util;
const app_context = app.context;
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
        "Minacare"
    );
    defer rl.closeWindow();

    try settings.init();
    defer settings.deinit();
    persistence.load(settings, .settings);

    rl.setTargetFPS(settings.target_fps);

    try translation.init(app_context.gpa, settings.selected_language);
    defer translation.deinit(app_context.gpa);

    tween.init(app_context.gpa);
    defer tween.deinit();

    try game_state.init();
    defer game_state.deinit();

    // DEBUG switch out for real map later
    try game_state.map.loadMap(app_context.gpa, "minaland");

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
        try util.tween.update();

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
