const std = @import("std");
const rl = @import("raylib");
const settings = @import("settings.zig");
const app_state = @import("app_state.zig");
const game_state = @import("game_state.zig");
const menus = @import("menus.zig");
var debug_allocator = std.heap.DebugAllocator(.{}).init;
const gpa = switch (@import("builtin").mode) {
    .Debug => debug_allocator.allocator(),
    else => std.heap.smp_allocator,
};

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

    rl.setTargetFPS(settings.target_fps);

    try translation.init(gpa);
    defer translation.deinit();

    try game_state.init();
    defer game_state.deinit();

    // DEBUG switch out for real map later
    try game_state.map.loadMap(gpa, "test");

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

        state: switch (app_state.state) {
            .menu => {
                try menus.main.update(delta);
                
                rl.beginDrawing();
                defer rl.endDrawing();
                rl.clearBackground(.white);
                
                menus.main.draw();
            },
            .load_game => {
                try game_state.loadGame(gpa);
                app_state.state = .game;
                continue :state app_state.state;
            },
            .new_game => {
                // TODO prompt the user for confirmation.
                try game_state.newGame();
                app_state.state = .game;
                continue :state app_state.state;
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
        }
    }
}
