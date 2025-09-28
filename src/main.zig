const std = @import("std");
const rl = @import("raylib");
const app_context = @import("app_context.zig");
const app_state = @import("app_state.zig");
const settings = @import("settings.zig");
const persistance = @import("persistance.zig");
const game_state = @import("game_state.zig");
const menus = @import("menus.zig");
const translation = @import("translation.zig");

pub fn main() !void {
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
    persistance.load(settings, .settings);

    rl.setTargetFPS(settings.target_fps);

    try translation.init(app_context.gpa);
    defer translation.deinit(app_context.gpa);

    try game_state.init();
    defer game_state.deinit();

    // DEBUG switch out for real map later
    try game_state.map.loadMap(app_context.gpa, "test");

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

        switch (app_state.current) {
            .menu => {
                try menus.main.update(delta);
                
                rl.beginDrawing();
                defer rl.endDrawing();
                rl.clearBackground(.white);
                
                menus.main.draw();
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
                menus.pause.draw();
            },
            .settings => {
                try menus.settings.update(delta);

                rl.beginDrawing();
                defer rl.endDrawing();
                rl.clearBackground(.white);
                
                menus.settings.draw();
            },
            .exit => break :game_loop,
            else => unreachable,
        }
    }
}
