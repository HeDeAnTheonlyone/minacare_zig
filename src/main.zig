const std = @import("std");
const rl = @import("raylib");
const settings = @import("settings.zig");
const app_state = @import("app_state.zig");
const game_state = @import("game_state.zig");
const main_menu = @import("main_menu.zig");
const settings_menu = @import("menus/main_menu.zig");
var debug_allocator = std.heap.DebugAllocator(.{}).init;
const gpa = switch (@import("builtin").mode) {
    .Debug => debug_allocator.allocator(),
    else => std.heap.smp_allocator,
};

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
                try main_menu.update(delta);
                main_menu.draw(); 
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
                try game_state.draw();
            },
            .pause => {

            },
            .settings => {

            },
            .exit => break :game_loop,
        }
    }
}
